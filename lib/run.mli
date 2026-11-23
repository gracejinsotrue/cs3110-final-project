val new_run : seed:int -> Types.run_state
val available_nodes : Types.run_state -> Types.map_node list
val enter_node : Types.run_state -> int -> (Types.run_state, string) result
val after_combat : Types.run_state -> Types.combat_result -> reward_ids:string list -> (Types.run_state, string) result
val choose_reward : Types.run_state -> int -> (Types.run_state, string) result
val is_terminal : Types.run_state -> bool
