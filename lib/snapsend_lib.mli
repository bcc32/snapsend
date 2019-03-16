open! Core
open! Async
module Location = Location

val sync :
  ?delete_extraneous:bool (** @default [false] *)
  -> from:Location.t
  -> to_:Location.t
  -> unit
  -> unit Deferred.Or_error.t
