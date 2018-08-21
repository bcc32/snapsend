open! Core
open! Async

module Location = Location

val sync
  :  from : Location.t
  -> to_ : Location.t
  -> delete_extraneous : bool
  -> unit Deferred.Or_error.t
