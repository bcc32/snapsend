open! Core
open! Async

type t =
  | Local of { path : string }
  | Remote of { ssh_url : string
              ; path : string
              }

val of_string : string -> path:string -> t

val list_snapshots : t -> Snapshot.t list Deferred.Or_error.t

val send
  :  t
  -> snapshot : Snapshot.t
  -> available : Snapshot.t list
  -> to_ : Writer.t
  -> unit Deferred.Or_error.t

val receive
  :  t
  -> from : Reader.t
  -> unit Deferred.Or_error.t

val delete
  :  t
  -> Snapshot.t list
  -> unit Deferred.Or_error.t
