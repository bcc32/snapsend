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
  | Local { path = _ } ->
    Log.Global.debug !"%{sexp: string list}" (prog :: args);
    f ~prog ~args
  | Remote { ssh_url; path = _ } ->
    Log.Global.debug !"%{sexp: string list}" ("ssh" :: ssh_url :: prog :: args);
    f ~prog:"ssh"
      ~args:([ ssh_url
             ; prog
             ] @ args)
;;

let run_lines_at =
  run_at ~f:(fun ~prog ~args -> Process.run_lines () ~prog ~args)
;;

let run_share_output_at t ~label =
  run_at t ~f:(fun ~prog ~args ->
    let open Deferred.Or_error.Let_syntax in
    (* TODO: when qualified bind is released, use that. *)
    let%bind proc = Process.create () ~prog ~args in
    let open Deferred.Let_syntax in
    let%bind () =
      Process.stdout proc
      |> Reader.lines
      |> Pipe.iter_without_pushback
           ~f:(Log.Global.info "%s"
                 ~tags:[ "cmd", label
                       ; "fd", "stdout"
                       ])
    and () =
      Process.stderr proc
      |> Reader.lines
      |> Pipe.iter_without_pushback
           ~f:(Log.Global.info "%s"
                 ~tags:[ "cmd", label
                       ; "fd", "stderr"
                       ])
    in
    let%bind exit_or_signal = Process.wait proc in
    return (Unix.Exit_or_signal.or_error exit_or_signal))
;;

let run_with_output_to_writer_at t ~writer ~label =
  run_at t ~f:(fun ~prog ~args ->
    let open Deferred.Or_error.Let_syntax in
    let%bind proc = Process.create () ~prog ~args in
    let open Deferred.Let_syntax in
    let%bind () =
      Pipe.transfer_id
        (Reader.pipe (Process.stdout proc))
        (Writer.pipe writer)
    and () =
      Process.stderr proc
      |> Reader.lines
      |> Pipe.iter_without_pushback
           ~f:(Log.Global.info "%s"
                 ~tags:[ "cmd", label
                       ; "fd", "stderr"
                       ])
    in
    let%bind exit_or_signal = Process.wait proc in
    let%bind () = Writer.close writer in
    return (Unix.Exit_or_signal.or_error exit_or_signal))
;;

let run_with_input_from_reader_at t ~reader ~label =
  run_at t ~f:(fun ~prog ~args ->
    let open Deferred.Or_error.Let_syntax in
    let%bind proc = Process.create () ~prog ~args in
    let open Deferred.Let_syntax in
    let%bind () =
      let%bind () =
        Pipe.transfer_id
          (Reader.pipe reader)
          (Writer.pipe (Process.stdin proc))
      in
      let%bind () = Writer.close (Process.stdin proc) in
      return ()
    and () =
      Process.stdout proc
      |> Reader.lines
      |> Pipe.iter_without_pushback
           ~f:(Log.Global.info "%s"
                 ~tags:[ "cmd", label
                       ; "fd", "stdout"
                       ])
    and () =
      Process.stderr proc
      |> Reader.lines
      |> Pipe.iter_without_pushback
           ~f:(Log.Global.info "%s"
                 ~tags:[ "cmd", label
                       ; "fd", "stderr"
                       ])
    in
   let%bind exit_or_signal = Process.wait proc in
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
                              (fields : string list)
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
    ~label:"send"
;;

let receive t ~from:reader =
  run_with_input_from_reader_at t
    ~reader
    ~prog:"btrfs"
    ~args:([ "receive"
           ; path t
           ])
    ~label:"receive"
;;

let delete t snapshots =
  match
    List.map snapshots ~f:(fun snap -> path t ^/ Snapshot.name snap)
  with
  | [] -> Deferred.Or_error.ok_unit
  | _::_ as paths ->
    run_share_output_at t
      ~prog:"btrfs"
      ~args:([ "subvolume"
             ; "delete"
             ] @ paths)
      ~label:"delete"
;;
