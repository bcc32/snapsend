open! Core
open! Async
open! Import

module T = struct
  type t =
    { uuid : Uuid.Unstable.t [@compare.ignore]
    ; received_uuid : Uuid.Unstable.t option [@compare.ignore]
    ; basename : File_path.Part.t
    }
  [@@deriving compare, fields, sexp]
end

include T
include Comparable.Make (T)

let to_string_hum t = (t.basename :> string)
