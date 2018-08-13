open! Core
open! Async

module Location = Location

val sync
  :  from : Location.t
  -> to_ : Location.t
  -> unit Deferred.Or_error.t
