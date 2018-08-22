open! Core
open! Async

module Location = Location

let pipe () =
  let%map (`Reader r, `Writer w) = Unix.pipe (Info.create_s [%sexp [%here]]) in
  let reader = Reader.create r in
  let writer = Writer.create w in
  Ok (reader, writer)
;;

let sync ~from ~to_ ~delete_extraneous =
  let open Deferred.Or_error.Let_syntax in
  let%bind snapshots_from = Location.list_snapshots from
  and snapshots_to = Location.list_snapshots to_
  in
  let snapshots_from = Snapshot.Set.of_list snapshots_from in
  let snapshots_to = Snapshot.Set.of_list snapshots_to in
  (* FIXME: This should be based on Uuid's, not names/paths. *)
  let common = Set.inter snapshots_from snapshots_to in
  let%bind (_ : Snapshot.Set.t) =
    Set.diff snapshots_from common
    |> Set.to_list
    |> Deferred.Or_error.List.fold ~init:common
         ~f:(fun common snapshot ->
           let%bind (reader, writer) = pipe () in
           let%map () =
             Location.send from ~snapshot
               ~available:(Set.to_list common)
               ~to_:writer
           and () = Location.receive to_ ~from:reader
           in
           Set.add common snapshot)
  in
  if delete_extraneous
  then (
    let to_delete = Set.diff snapshots_to snapshots_from in
    Location.delete to_ (Set.to_list to_delete))
  else Deferred.Or_error.ok_unit
;;
