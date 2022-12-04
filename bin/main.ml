open! Core
open! Async
open! Import

let () =
  Command.group
    ~summary:"Send btrfs snapshots between hosts"
    [ "send", Send.command; "validate-config", Validate_config.command ]
  |> Command_unix.run
;;
