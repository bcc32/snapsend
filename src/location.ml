open! Core
open! Async

let ssh_args = [ "-o"; "BatchMode=yes"; "-S"; "none" ]

type t =
  | Local of { path : string }
  | Ssh of { host : string; path : string }
[@@deriving sexp]

let path = function
  | Local { path }
  | Ssh { host = _; path } -> path
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
    { Snapshot.uuid; received_uuid; path }
  | fields ->
    raise_s
      [%message "wrong number of fields" ~expected:13 ~got:(List.length fields : int)]
;;

let list_snapshots t =
  let open Shexp_process.Let_syntax in
  let parse_snapshots =
    Shexp_process.fold_lines ~init:[] ~f:(fun ac line ->
      return (parse_snapshot line :: ac))
    >>| List.rev
  in
  run_at t "btrfs" [ "subvolume"; "list"; "-u"; "-R"; "-o"; path t ] |- parse_snapshots
;;

let send t ~snapshot ~available =
  let available_args =
    List.concat_map available ~f:(fun snapshot ->
      [ "-c"; path t ^/ Snapshot.name snapshot ])
  in
  run_at t "btrfs" ([ "send" ] @ available_args @ [ path t ^/ Snapshot.name snapshot ])
;;

let receive t = run_at t "btrfs" [ "receive"; path t ]

let delete t snapshots =
  let open Shexp_process.Let_syntax in
  match List.map snapshots ~f:(fun snap -> path t ^/ Snapshot.name snap) with
  | [] -> return ()
  | _ :: _ as paths -> run_at t "btrfs" ([ "subvolume"; "delete" ] @ paths)
;;
