open! Core
open! Async

type t =
  | Local of { path : string }
  | Ssh of { host : string; path : string }
[@@deriving sexp]

val list_snapshots : t -> Snapshot.t list Shexp_process.t
val send : t -> snapshot:Snapshot.t -> available:Snapshot.t list -> unit Shexp_process.t
val receive : t -> unit Shexp_process.t
val delete : t -> Snapshot.t list -> unit Shexp_process.t
