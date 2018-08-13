open! Core
open! Async

module T = struct
  type t =
    { uuid : Uuid.Unstable.t [@compare.ignore]
    ; received_uuid : Uuid.Unstable.t option [@compare.ignore]
    ; path : string
    }
  [@@deriving compare, fields, sexp]
end
include T
include Comparable.Make(T)

let name t = Filename.basename t.path
