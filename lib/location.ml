open! Core
open! Async

type t =
  | Local of { path : string }
  | Remote of { ssh_url : string
              ; path : string
              }

let path = function
  | Local { path }
  | Remote { ssh_url = _; path } -> path
;;

let of_string string ~path =
  if string = "localhost"
  then Local { path }
  else if String.is_prefix string ~prefix:"ssh://"
  then Remote { ssh_url = string; path }
  else raise_s [%message "invalid location string" (string : string)]
;;

let run_at t ~f ~prog ~args =
  match t with
  | Local { path = _ } -> f ~prog ~args
  | Remote { ssh_url; path = _ } ->
    f ~prog:"ssh"
      ~args:([ ssh_url
             ; prog
             ] @ args)
;;

let run_lines_at =
  run_at ~f:(fun ~prog ~args -> Process.run_lines () ~prog ~args)
;;

let run_with_output_to_writer_at t ~writer =
  run_at t ~f:(fun ~prog ~args ->
    let open Deferred.Or_error.Let_syntax in
    let%bind proc = Process.create () ~prog ~args in
    let open Deferred.Let_syntax in
    let%bind () =
      Pipe.transfer_id
        (Reader.pipe (Process.stdout proc))
        (Writer.pipe writer)
    and () = Reader.transfer (Process.stderr proc) Writer.(pipe (force stderr))
    in
    let%bind exit_or_signal = Process.wait proc in
    Debug.eprint_s [%message "writer process exited"];
    let%bind () = Writer.close writer in
    Debug.eprint_s [%message "writer end closed"];
    return (Unix.Exit_or_signal.or_error exit_or_signal))
;;

let run_with_input_from_reader_at t ~reader =
  let transfer r w = Pipe.transfer_id (Reader.pipe r) (Writer.pipe w) in
  run_at t ~f:(fun ~prog ~args ->
    let open Deferred.Or_error.Let_syntax in
    let%bind proc = Process.create () ~prog ~args in
    let open Deferred.Let_syntax in
    let%bind () =
      let%bind () = transfer reader (Process.stdin proc) in
      Debug.eprint_s [%message "reader stdin written to"];
      let%bind () = Writer.close (Process.stdin proc) in
      Debug.eprint_s [%message "reader stdin closed"];
      return ()
    and () = transfer (Process.stdout proc) (force Writer.stdout)
    and () = transfer (Process.stderr proc) (force Writer.stderr)
    in
   let%bind exit_or_signal = Process.wait proc in
   Debug.eprint_s [%message "reader process exited"];
   return (Unix.Exit_or_signal.or_error exit_or_signal))
;;

let split_words =
  let re = Re.(compile (rep1 space)) in
  Re.split re
;;

let parse_snapshot line =
  let parse_uuid_option = function
    | "-" -> None
    | s -> Some (Uuid.of_string s)
  in
  Or_error.try_with_join (fun () ->
    match split_words line with
    | [ _; _; _; _; _; _; _; _; received_uuid; _; uuid; _; path ] ->
      let uuid = Uuid.of_string uuid in
      let received_uuid = parse_uuid_option received_uuid in
      Ok { Snapshot.uuid; received_uuid; path }
    | fields -> Or_error.error_s
                  [%message "wrong number of fields" [%here]
                              ~n:(List.length fields : int)])
;;

let list_snapshots t =
  let%map lines_or_error =
    run_lines_at t
      ~prog:"btrfs"
      ~args:[ "subvolume"
            ; "list"
            ; "-u"
            ; "-R"
            ; "-o"
            ; path t
            ]
  in
  let open Or_error.Let_syntax in
  let%bind lines = lines_or_error in
  lines
  |> List.map ~f:parse_snapshot
  |> Or_error.all
;;

let send t ~snapshot ~available ~to_:writer =
  let available_args =
    List.concat_map available ~f:(fun snapshot ->
      [ "-c"
      ; path t ^/ Snapshot.name snapshot
      ])
  in
  run_with_output_to_writer_at t
    ~writer
    ~prog:"btrfs"
    ~args:([ "send" ]
           @ available_args
           @ [ path t ^/ Snapshot.name snapshot ])
;;

let receive t ~from:reader =
  run_with_input_from_reader_at t
    ~reader
    ~prog:"btrfs"
    ~args:([ "receive"
           ; path t
           ])
;;
