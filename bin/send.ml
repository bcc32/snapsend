open! Core
open! Async
open! Import

let command =
  Command.async_or_error
    ~summary:"Send all snapshots from one location to another."
    (let%map_open.Command () = return ()
     and config_path = Params.config_path
     and () = Log.Global.set_level_via_param () in
     fun () ->
       let%bind configs = Snapsend.Config.read_from_file config_path in
       configs |> Deferred.Or_error.List.iter ~how:`Parallel ~f:Snapsend.sync)
;;
