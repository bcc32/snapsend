open! Core
open! Async

type t =
  { uuid : Uuid.t
  ; received_uuid : Uuid.t option
  ; basename : File_path.Part.t
  }
[@@deriving fields]

include Comparable.S with type t := t
include Sexpable.S with type t := t

val to_string_hum : t -> string
