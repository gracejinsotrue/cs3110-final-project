val ms2_map : Types.map_node list
(** A fixed one-fight route for the playable MS2 slice. *)

val generate : Random.State.t -> Types.map_node list
(** Currently returns the fixed MS2 route; the argument reserves the seeded
    interface for later generated routes. *)

val validate : Types.map_node list -> (unit, string list) result
val available : Types.map_node list -> int list -> int option -> Types.map_node list
