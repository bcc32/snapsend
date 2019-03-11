open! Core
open! Async
open Snapsend_lib

let from_param =
  let open Command.Let_syntax in
  let%map_open path =
    flag
      "-from-path"
      (required Filename.arg_type)
      ~doc:"PATH path to the snapshot source directory"
  and from =
    flag
      "-from"
      (required string)
      ~doc:"LOCATION snapshot source host (localhost or hostname/addr)"
  in
  Location.of_string from ~path
;;

let to_param =
  let open Command.Let_syntax in
  let%map_open path =
    flag
      "-to-path"
      (required Filename.arg_type)
      ~doc:"PATH path to the snapshot destination directory"
  and to_ =
    flag
      "-to"
      (required string)
      ~doc:"LOCATION snapshot destination (localhost or hostname/addr)"
  in
  Location.of_string to_ ~path
;;

let delete_extraneous_param =
  Command.Param.flag
    "-delete-extraneous"
    Command.Param.no_arg
    ~doc:" delete extraneous snapshots on TO-side"
;;

let command =
  Command.async_or_error
    ~summary:"Send all snapshots from one location to another."
    (let open Command.Let_syntax in
    let%map_open from = from_param
    and to_ = to_param
    and delete_extraneous = delete_extraneous_param
    and () = Log.Global.set_level_via_param () in
    fun () -> sync () ~from ~to_ ~delete_extraneous)
;;
