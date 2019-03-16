open! Core
open! Async
open Snapsend_lib

let config_param =
  let open Command.Let_syntax in
  let%map_open path = anon ("CONFIG" %: Filename.arg_type) in
  path
;;

let command =
  Command.async_or_error
    ~summary:"Send all snapshots from one location to another."
    (let open Command.Let_syntax in
     let%map_open config_path = config_param
     and () = Log.Global.set_level_via_param () in
     fun () ->
       let open Deferred.Or_error.Let_syntax in
       let%bind config = Config.read_from_file config_path in
       sync config)
;;
