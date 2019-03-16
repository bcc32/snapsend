open! Core
open! Async

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
       let%bind configs = Snapsend.Config.read_from_file config_path in
       let lock_path = config_path ^ ".lock" in
       let%bind () =
         if%map.Deferred.Let_syntax Lock_file_async.create ~unlink_on_exit:true lock_path
         then Ok ()
         else Or_error.error_s [%message "couldn't acquire lockfile" (lock_path : string)]
       in
       configs |> Deferred.Or_error.List.iter ~how:`Parallel ~f:Snapsend.sync)
;;
