open! Core
open! Async
include Deferred.Or_error.Let_syntax
include File_path.Operators

let () = Log.Global.set_output [ Log.Output.stdout ~format:`Sexp () ]
