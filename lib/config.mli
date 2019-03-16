open! Core
open! Async

type t =
  { from : Location.t
  ; to_ : Location.t
  ; delete_extraneous : bool [@default true] [@sexp.drop_default.equal]
  }
[@@deriving sexp]

val read_from_file : string -> t Deferred.Or_error.t
