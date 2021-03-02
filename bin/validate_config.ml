open! Core
open! Async
open! Import

let command =
  Command.async_or_error
    ~summary:"Validate config file"
    (let%map_open.Command () = return ()
     and config_path = Params.config_path
     and () = Log.Global.set_level_via_param () in
     fun () ->
       let%bind configs = Snapsend.Config.read_from_file config_path in
       ignore (configs : Snapsend.Config.t list);
       return ())
;;
