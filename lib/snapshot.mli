open! Core
open! Async

type t =
  { uuid : Uuid.t
  ; received_uuid : Uuid.t option
  ; path : string
  }
[@@deriving fields]

include Comparable.S with type t := t
include Sexpable.S with type t := t

val name : t -> string
