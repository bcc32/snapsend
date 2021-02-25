open! Core
open! Async
open! Import
module Config = Config

let context =
  Lazy_deferred.create (fun () ->
    let%bind.Deferred `Reader r, `Writer stdout =
      Unix.pipe (Info.create_s [%message "stdout pipe" [%here]])
    in
    don't_wait_for
      (Pipe.iter_without_pushback
         (Reader.lines (Reader.create r))
         ~f:(fun line -> [%log.global.debug "command output" ~stdout:line]));
    let%bind.Deferred `Reader r, `Writer stderr =
      Unix.pipe (Info.create_s [%message "stderr pipe" [%here]])
    in
    don't_wait_for
      (Pipe.iter_without_pushback
         (Reader.lines (Reader.create r))
         ~f:(fun line -> [%log.global.debug "command output" ~stderr:line]));
    Deferred.return
      (Shexp_process.Context.create
         ()
         ~stdout:(Fd.file_descr_exn stdout)
         ~stderr:(Fd.file_descr_exn stderr)))
;;

let eval proc =
  let%bind context = Lazy_deferred.force context in
  let%bind result =
    match Log.Global.would_log (Some `Debug) with
    | true ->
      let%bind result, trace =
        Monitor.try_with_or_error (fun () ->
          In_thread.run (fun () -> Shexp_process.Traced.eval proc ~context))
      in
      Log.Global.debug_s trace;
      result |> Deferred.return |> Deferred.Or_error.of_exn_result
    | false ->
      Monitor.try_with_or_error (fun () ->
        In_thread.run (fun () -> Shexp_process.eval proc ~context))
  in
  return result
;;

let send_one snapshot ~from ~to_ ~common =
  Async_interactive.Job.run
    !"%{Sexp#hum}"
    [%message
      "Sending"
        ~snapshot:(snapshot |> Snapshot.to_string_hum : string)
        (from : Location.t)
        (to_ : Location.t)]
    ~f:(fun () ->
      let open Shexp_process.Let_syntax in
      Location.send from ~snapshot ~available:(Set.to_list common)
      |- Location.receive to_
      |> eval)
;;

let sync config =
  let { Config.from; to_; delete_extraneous } = config in
  Async_interactive.Job.run
    !"synchronizing from %{sexp:Location.t} to %{sexp:Location.t}"
    from
    to_
    ~f:(fun () ->
      let%bind snapshots_from = Location.list_snapshots from |> eval
      and snapshots_to = Location.list_snapshots to_ |> eval in
      let snapshots_from = Snapshot.Set.of_list snapshots_from in
      let snapshots_to = Snapshot.Set.of_list snapshots_to in
      (* FIXME: This should be based on Uuid's, not names/paths. *)
      let common = Set.inter snapshots_from snapshots_to in
      let%bind (_ : Snapshot.Set.t) =
        Set.diff snapshots_from common
        |> Set.to_list
        |> Deferred.Or_error.List.fold ~init:common ~f:(fun common snapshot ->
          let%map () = send_one snapshot ~from ~to_ ~common in
          Set.add common snapshot)
      in
      if delete_extraneous
      then (
        let to_delete = Set.diff snapshots_to snapshots_from in
        if Set.is_empty to_delete
        then return ()
        else
          Async_interactive.Job.run
            "deleting %d extraneous snapshots"
            (Set.length to_delete)
            ~f:(fun () -> Location.delete to_ (Set.to_list to_delete) |> eval))
      else return ())
;;
