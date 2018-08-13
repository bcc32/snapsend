open! Core
open! Async
open Snapsend_lib

let from_param =
  let open Command.Let_syntax in
  let%map_open path =
    flag "-from-path" (required file)
      ~doc:"PATH path to the snapshot source directory"
  and from =
    flag "-from" (required string)
      ~doc:"LOCATION snapshot source host (localhost or hostname/addr)"
  in
  Location.of_string from ~path
;;

let to_param =
  let open Command.Let_syntax in
  let%map_open path =
    flag "-to-path" (required file)
      ~doc:"PATH path to the snapshot destination directory"
  and to_ =
    flag "-to" (required string)
      ~doc:"LOCATION snapshot destination (localhost or hostname/addr)"
  in
  Location.of_string to_ ~path
;;

let command =
  Command.async_or_error ~summary:"Send all snapshots from one location to another."
    (let open Command.Let_syntax in
     let%map_open from = from_param
     and to_ = to_param
     in
     fun () -> sync ~from ~to_)
;;
