open Types

let new_run ~seed =
  { run_seed = seed; run_map = Map.ms2_map; run_current_node = None;
    run_visited = []; run_deck = List.init 5 (fun _ -> "strike") @
      List.init 4 (fun _ -> "defend") @ [ "bash" ]; run_hp = 80;
    run_max_hp = 80; run_gold = 0; run_next_encounter = 0; run_phase = On_map }

let available_nodes r = Map.available r.run_map r.run_visited r.run_current_node

let enter_node r node_id =
  if r.run_phase <> On_map then Error "cannot enter a node outside the map"
  else match List.find_opt (fun n -> n.node_id = node_id) (available_nodes r) with
    | None -> Error (Printf.sprintf "node %d is not reachable" node_id)
    | Some node ->
        let base = { r with run_current_node = Some node_id;
          run_visited = r.run_visited @ [ node_id ];
          run_next_encounter = r.run_next_encounter + 1 } in
        (match node.node_kind with
         | Fight id | Elite id | Boss id -> Ok { base with run_phase = Fighting id }
         | Rest ->
             let heal = (r.run_max_hp * 30 + 99) / 100 in
             Ok { base with run_hp = min r.run_max_hp (r.run_hp + heal) })

let after_combat r result ~reward_ids =
  match r.run_phase with
  | Fighting _ ->
      let node = Option.bind r.run_current_node (fun id ->
        List.find_opt (fun n -> n.node_id = id) r.run_map) in
      let boss = match node with Some { node_kind = Boss _; _ } -> true | _ -> false in
      if not result.res_won then Ok { r with run_hp = max 0 result.res_hp_left; run_phase = Lost }
      else if boss then Ok { r with run_hp = result.res_hp_left;
        run_gold = r.run_gold + result.res_gold; run_phase = Won }
      else Ok { r with run_hp = result.res_hp_left;
        run_gold = r.run_gold + result.res_gold; run_phase = Reward_pending reward_ids }
  | _ -> Error "combat result is only valid while fighting"

let choose_reward r choice = match r.run_phase with
  | Reward_pending ids when choice > 0 && choice <= List.length ids ->
      let id = List.nth ids (choice - 1) in
      Ok { r with run_deck = r.run_deck @ [ id ]; run_phase = On_map }
  | Reward_pending _ -> Error "reward choice is out of range"
  | _ -> Error "no reward is pending"

let is_terminal r = match r.run_phase with Won | Lost -> true | _ -> false
