open! Core
open! Async

type t =
  | Local of { path : string }
  | Remote of { ssh_url : string; path : string }

val of_string : string -> path:string -> t
val list_snapshots : t -> Snapshot.t list Shexp_process.t
val send : t -> snapshot:Snapshot.t -> available:Snapshot.t list -> unit Shexp_process.t
val receive : t -> unit Shexp_process.t
val delete : t -> Snapshot.t list -> unit Shexp_process.t
