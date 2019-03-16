open! Core
open! Async

type t =
  { from : Location.t
  ; to_ : Location.t
  ; delete_extraneous : bool
  ; show_progress : bool
  }
[@@deriving sexp]

val read_from_file : string -> t list Deferred.Or_error.t
