open! Core
open! Async
open! Import

let ssh_args = [ "-o"; "BatchMode=yes"; "-e"; "none"; "-S"; "none"; "-T" ]

type t =
  | Local of { path : File_path.Absolute.t }
  | Ssh of
      { host : string
      ; path : File_path.Absolute.t
      }
[@@deriving sexp]

let snapshot_dir_path = function
  | Local { path } | Ssh { host = _; path } -> path
;;

let run_at t prog args =
  match t with
  | Local { path = _ } -> Shexp_process.run prog args
  | Ssh { host; path = _ } -> Shexp_process.run "ssh" (ssh_args @ [ host; prog ] @ args)
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
  match split_words line with
  | [ _; _; _; _; _; _; _; _; received_uuid; _; uuid; _; path ] ->
    let uuid = Uuid.of_string uuid in
    let received_uuid = parse_uuid_option received_uuid in
    let basename = File_path.Relative.of_string path |> File_path.Relative.basename in
    ({ uuid; received_uuid; basename } : Snapshot.t)
  | fields ->
    raise_s
      [%message "wrong number of fields" ~expected:13 ~got:(List.length fields : int)]
;;

let list_snapshots_including_incomplete t =
  let open Shexp_process.Let_syntax in
  let parse_snapshots =
    Shexp_process.fold_lines ~init:[] ~f:(fun ac line ->
      return (parse_snapshot line :: ac))
    >>| List.rev
  in
  run_at t "btrfs" [ "subvolume"; "list"; "-u"; "-R"; "-o"; !/$(snapshot_dir_path t) ]
  |- parse_snapshots
;;

let list_snapshots_complete_only t =
  let open Shexp_process.Let_syntax in
  let parse_snapshots =
    Shexp_process.fold_lines ~init:[] ~f:(fun ac line ->
      return (parse_snapshot line :: ac))
    >>| List.rev
  in
  run_at
    t
    "btrfs"
    [ "subvolume"; "list"; "-u"; "-R"; "-r"; "-o"; !/$(snapshot_dir_path t) ]
  |- parse_snapshots
;;

let send t ~snapshot ~available =
  let available_args =
    List.concat_map available ~f:(fun snapshot ->
      [ "-c"; !/$(snapshot_dir_path t /!. Snapshot.basename snapshot) ])
  in
  run_at
    t
    "btrfs"
    ([ "send"; "-q" ]
     @ available_args
     @ [ !/$(snapshot_dir_path t /!. Snapshot.basename snapshot) ])
;;

let receive t = run_at t "btrfs" [ "receive"; "-q"; !/$(snapshot_dir_path t) ]

let delete t snapshots =
  let open Shexp_process.Let_syntax in
  if List.is_empty snapshots
  then return ()
  else (
    let paths =
      List.map snapshots ~f:(fun snap -> snapshot_dir_path t /!. Snapshot.basename snap)
    in
    Shexp_process.List.iter paths ~f:(Shexp_process.printf !"%{File_path.Absolute}\000")
    |- run_at t "xargs" [ "-0"; "btrfs"; "subvolume"; "delete" ])
;;
