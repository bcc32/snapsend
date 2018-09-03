open! Core
open! Async
module Location = Location

let context =
  Lazy_deferred.create (fun () ->
    let%bind `Reader r, `Writer stdout =
      Unix.pipe (Info.create_s [%message "stdout pipe" [%here]])
    in
    don't_wait_for
      (Pipe.iter_without_pushback
         (Reader.lines (Reader.create r))
         ~f:(fun line ->
           Log.Global.sexp ~level:`Debug [%message "command output" ~stdout:line]));
    let%bind `Reader r, `Writer stderr =
      Unix.pipe (Info.create_s [%message "stderr pipe" [%here]])
    in
    don't_wait_for
      (Pipe.iter_without_pushback
         (Reader.lines (Reader.create r))
         ~f:(fun line ->
           Log.Global.sexp ~level:`Debug [%message "command output" ~stderr:line]));
    return
      (Shexp_process.Context.create
         ()
         ~stdout:(Fd.file_descr_exn stdout)
         ~stderr:(Fd.file_descr_exn stderr)))
;;

let eval proc =
  let%bind context = Lazy_deferred.force_exn context in
  Monitor.try_with_or_error (fun () ->
    In_thread.run (fun () ->
      Shexp_process.Logged.eval proc ~context ~log:(Log.Global.sexp ~level:`Debug)))
;;

let send_one snapshot ~from ~to_ ~common =
  Async_interactive.Job.run !"sending snapshot %{Snapshot#hum}" snapshot ~f:(fun () ->
    let open Shexp_process.Let_syntax in
    Location.send from ~snapshot ~available:(Set.to_list common)
    |- Location.receive to_
    |> eval)
;;

let sync ?(delete_extraneous = false) ~from ~to_ () =
  let open Deferred.Or_error.Let_syntax in
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
  else return ()
;;
