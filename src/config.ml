open! Core
open! Async

type t =
  { from : Location.t
  ; to_ : Location.t
  ; delete_extraneous : bool [@default true] [@sexp.drop_default.equal]
  ; show_progress : bool [@default true] [@sexp.drop_default.equal]
  }
[@@deriving sexp]

let read_from_file filename = Reader.load_sexps filename [%of_sexp: t]
