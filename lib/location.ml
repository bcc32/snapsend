open! Core
open! Async

type t =
  | Local of { path : string }
  | Remote of { ssh_url : string; path : string }

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

let run_at t prog args =
  match t with
  | Local { path = _ } -> Shexp_process.run prog args
  | Remote { ssh_url; path = _ } -> Shexp_process.run "ssh" ([ "-o"; "PasswordAuthentication=no"; ssh_url; prog ] @ args)
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
