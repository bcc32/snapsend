open! Core
open! Async
module Config = Config

val sync : Config.t -> unit Deferred.Or_error.t
