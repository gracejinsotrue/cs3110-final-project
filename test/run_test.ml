open OUnit2
open Types

let combat_result won hp gold =
  { res_won = won; res_hp_left = hp; res_gold = gold }

let tests = "run" >::: [
  "new run and reachable node" >:: (fun _ ->
    let r = Run.new_run ~seed:42 in
    assert_equal 80 r.run_hp;
    assert_equal [1] (List.map (fun n -> n.node_id) (Run.available_nodes r));
    assert_bool "unreachable choice rejected" (Result.is_error (Run.enter_node r 9));
    let r = match Run.enter_node r 1 with Ok r -> r | Error e -> assert_failure e in
    assert_equal (Fighting "training_slime") r.run_phase);
  "reject unreachable node" >:: (fun _ ->
    let r = Run.new_run ~seed:1 in
    assert_equal (Error "node 2 is not reachable") (Run.enter_node r 2));
  "win reward adds card" >:: (fun _ ->
    let r = Run.new_run ~seed:7 |> fun r -> Result.get_ok (Run.enter_node r 1) in
    let r = Result.get_ok (Run.after_combat r (combat_result true 61 5) ~reward_ids:["twin_jab"; "rally"]) in
    assert_equal 5 r.run_gold;
    assert_equal (Reward_pending ["twin_jab"; "rally"]) r.run_phase;
    let r = Result.get_ok (Run.choose_reward r 2) in
    assert_equal "rally" (List.hd (List.rev r.run_deck));
    assert_equal On_map r.run_phase);
  "loss awards no gold" >:: (fun _ ->
    let r = Run.new_run ~seed:7 |> fun r -> Result.get_ok (Run.enter_node r 1) in
    let r = Result.get_ok (Run.after_combat r (combat_result false 0 0) ~reward_ids:[]) in
    assert_equal Lost r.run_phase; assert_equal 0 r.run_gold);
  "reject invalid reward choice" >:: (fun _ ->
    let r = Run.new_run ~seed:2 |> fun r -> Result.get_ok (Run.enter_node r 1) in
    let r = Result.get_ok (Run.after_combat r (combat_result true 70 5) ~reward_ids:["rally"]) in
    assert_bool "zero is invalid" (Result.is_error (Run.choose_reward r 0));
    assert_bool "past offer list is invalid" (Result.is_error (Run.choose_reward r 2)));
  "reject combat result outside fight" >:: (fun _ ->
    let r = Run.new_run ~seed:3 in
    assert_equal (Error "combat result is only valid while fighting")
      (Run.after_combat r (combat_result true 80 5) ~reward_ids:["rally"]));
  "phase transitions from map through reward" >:: (fun _ ->
    let start = Run.new_run ~seed:4 in
    assert_equal On_map start.run_phase;
    let fighting = Result.get_ok (Run.enter_node start 1) in
    assert_equal (Fighting "training_slime") fighting.run_phase;
    let reward = Result.get_ok (Run.after_combat fighting (combat_result true 69 5)
      ~reward_ids:["rally"]) in
    assert_equal (Reward_pending ["rally"]) reward.run_phase;
    let returned = Result.get_ok (Run.choose_reward reward 1) in
    assert_equal On_map returned.run_phase;
    assert_equal ["rally"] (List.filter ((=) "rally") returned.run_deck));
  "reward repeatability and distinctness" >:: (fun _ ->
    let cards = (Result.get_ok (Loader.load "../data")).content_cards in
    let rng () = Random.State.make [| 123 |] in
    let a = Rewards.generate (rng ()) cards and b = Rewards.generate (rng ()) cards in
    assert_equal (List.map (fun c -> c.card_id) a) (List.map (fun c -> c.card_id) b);
    assert_equal 3 (List.length a);
    assert_equal 3 (List.length (List.sort_uniq String.compare (List.map (fun c -> c.card_id) a))));
  "map validates and rejects missing edges" >:: (fun _ ->
    assert_equal (Ok ()) (Map.validate Map.ms2_map);
    let bad = [{ node_id=1; node_kind=Fight "training_slime"; node_row=1; node_next=[99] }] in
    assert_bool "missing edge rejected" (Result.is_error (Map.validate bad)))
]

let () = run_test_tt_main tests
