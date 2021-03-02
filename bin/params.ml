open! Core
open! Async
open! Import

let config_path =
  let open Command.Param in
  anon ("CONFIG" %: Filename.arg_type)
;;
