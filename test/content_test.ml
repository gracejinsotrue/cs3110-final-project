(** Tests for [Loader], [Validate] and the real files in [data/]. Tests run
    from [_build/default/test], so fixtures are at ["fixtures/..."] and the
    real content is at ["../data"]. *)

open OUnit2
open Types

(* ---------- Helpers ---------- *)

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

let show_errors es = String.concat "\n" es
let tiny_cards = "fixtures/tiny/cards.json"
let tiny_enemies = "fixtures/tiny/enemies.json"

(** Load a cards fixture together with the tiny (valid) enemies. *)
let load_cards file =
  Loader.load_files ~cards:("fixtures/" ^ file) ~enemies:tiny_enemies

let load_enemies file =
  Loader.load_files ~cards:tiny_cards ~enemies:("fixtures/" ^ file)

let get_ok what = function
  | Ok x -> x
  | Error es -> assert_failure (what ^ " failed:\n" ^ show_errors es)

(** Assert [r] is an error and that one message contains every string in
    [subs]. *)
let assert_error_with subs r =
  match r with
  | Ok _ -> assert_failure ("expected an error mentioning " ^ String.concat ", " subs)
  | Error es ->
      if not (List.exists (fun e -> List.for_all (contains e) subs) es) then
        assert_failure
          (Printf.sprintf "no error mentions all of [%s]; got:\n%s"
             (String.concat "; " subs) (show_errors es))

let assert_mentions subs msgs =
  if not (List.exists (fun e -> List.for_all (contains e) subs) msgs) then
    assert_failure
      (Printf.sprintf "no message mentions all of [%s]; got:\n%s"
         (String.concat "; " subs) (show_errors msgs))

let find_card c id = List.find (fun d -> d.card_id = id) c.content_cards
let find_enemy c id = List.find (fun d -> d.enemy_id = id) c.content_enemies

(* ---------- Hand-built content for Validate tests ---------- *)

let attack5 = { intent_label = "Attack 5"; intent_actions = [ Attack 5 ] }

let mk_card ?(id = "test_card") ?(name = "Test") ?(cost = 1)
    ?(description = "Does a thing") effects =
  {
    card_id = id;
    card_name = name;
    card_cost = cost;
    card_description = description;
    card_effects = effects;
  }

let mk_enemy ?(id = "test_enemy") ?(name = "Test Enemy") ?(max_hp = 20)
    ?(gold = 5) behavior =
  {
    enemy_id = id;
    enemy_name = name;
    enemy_max_hp = max_hp;
    enemy_gold = gold;
    enemy_behavior = behavior;
  }

let only_cards cards = { content_cards = cards; content_enemies = []; content_reward_pool = [] }
let only_enemies enemies = { content_cards = []; content_enemies = enemies; content_reward_pool = [] }
let errors_of c = match Validate.content c with Ok () -> [] | Error es -> es

let assert_invalid subs c = assert_error_with subs (Validate.content c)

let assert_valid c =
  match Validate.content c with
  | Ok () -> ()
  | Error es -> assert_failure ("expected valid content; got:\n" ^ show_errors es)

(* ---------- Loader: valid input ---------- *)

let loader_valid_tests =
  [
    ( "tiny fixture parses to exact records" >:: fun _ ->
      let c = get_ok "tiny" (Loader.load "fixtures/tiny") in
      assert_equal
        [
          {
            card_id = "strike";
            card_name = "Strike";
            card_cost = 1;
            card_description = "Deal 6 to one enemy";
            card_effects = [ Deal (Selected_enemy, 6) ];
          };
        ]
        c.content_cards;
      assert_equal
        [
          {
            enemy_id = "training_slime";
            enemy_name = "Training Slime";
            enemy_max_hp = 30;
            enemy_gold = 5;
            enemy_behavior =
              Cycle
                [
                  attack5;
                  { intent_label = "Defend 3"; intent_actions = [ Defend 3 ] };
                ];
          };
        ]
        c.content_enemies;
      assert_equal [] c.content_reward_pool );
    ( "real data has the MS2 starter cards and enemy" >:: fun _ ->
      let c = get_ok "data" (Loader.load "../data") in
      assert_equal [ Deal (Selected_enemy, 6) ] (find_card c "strike").card_effects;
      assert_equal [ Gain_block 5 ] (find_card c "defend").card_effects;
      assert_equal
        [ Deal (Selected_enemy, 8); Apply_status (Selected_enemy, Vulnerable, 2) ]
        (find_card c "bash").card_effects;
      assert_equal 2 (find_card c "bash").card_cost;
      assert_equal
        [ "twin_jab"; "wide_swing"; "venom_dart"; "dull_blade"; "war_cry"; "rally" ]
        c.content_reward_pool;
      assert_equal (Ok ()) (Validate.content c);
      let slime = find_enemy c "training_slime" in
      assert_equal 30 slime.enemy_max_hp;
      assert_equal 5 slime.enemy_gold );
    ( "real data offers at least three non-starter reward cards" >:: fun _ ->
      let c = get_ok "data" (Loader.load "../data") in
      let rewards =
        List.filter
          (fun d -> not (List.mem d.card_id [ "strike"; "defend"; "bash" ]))
          c.content_cards
      in
      assert_bool "need >= 3 reward cards" (List.length rewards >= 3) );
    ( "every effect, target, status and action kind parses" >:: fun _ ->
      let cards =
        {|{ "cards": [ { "id": "all_kinds", "name": "All", "cost": 0,
             "description": "Everything",
             "effects": [
               { "type": "deal", "target": "all_enemies", "amount": 1 },
               { "type": "gain_block", "amount": 2 },
               { "type": "apply_status", "target": "self", "status": "strength", "amount": 1 },
               { "type": "apply_status", "target": "selected_enemy", "status": "weak", "amount": 1 },
               { "type": "apply_status", "target": "selected_enemy", "status": "poison", "amount": 1 },
               { "type": "draw", "amount": 3 },
               { "type": "gain_energy", "amount": 4 } ] } ] }|}
      in
      let parsed =
        get_ok "cards"
          (Loader.parse_cards ~source:"inline" (Yojson.Safe.from_string cards))
      in
      assert_equal
        [
          Deal (All_enemies, 1);
          Gain_block 2;
          Apply_status (Self, Strength, 1);
          Apply_status (Selected_enemy, Weak, 1);
          Apply_status (Selected_enemy, Poison, 1);
          Draw 3;
          Gain_energy 4;
        ]
        (List.hd parsed).card_effects );
    ( "every behavior kind parses" >:: fun _ ->
      let intent l a = Printf.sprintf {|{ "label": "%s", "actions": [%s] }|} l a in
      let atk = intent "Attack 5" {|{ "type": "attack", "amount": 5 }|} in
      let def = intent "Defend 4" {|{ "type": "defend", "amount": 4 }|} in
      let hex =
        intent "Hex" {|{ "type": "inflict", "status": "vulnerable", "amount": 1 }|}
      in
      let rage = intent "Rage" {|{ "type": "buff", "status": "strength", "amount": 2 }|} in
      let enemy id b =
        Printf.sprintf
          {|{ "id": "%s", "name": "E", "max_hp": 10, "gold": 1, "behavior": %s }|}
          id b
      in
      let json =
        Printf.sprintf {|{ "enemies": [ %s, %s, %s ] }|}
          (enemy "a"
             (Printf.sprintf
                {|{ "type": "defend_below", "pct": 50, "defend": %s, "normal": [%s] }|}
                def atk))
          (enemy "b"
             (Printf.sprintf
                {|{ "type": "phase_at", "pct": 40, "high": [%s], "low": [%s, %s] }|}
                atk rage hex))
          (enemy "c"
             (Printf.sprintf {|{ "type": "random_choice", "intents": [%s, %s] }|}
                atk def))
      in
      let es =
        get_ok "enemies"
          (Loader.parse_enemies ~source:"inline" (Yojson.Safe.from_string json))
      in
      let a_ = { intent_label = "Attack 5"; intent_actions = [ Attack 5 ] } in
      let d_ = { intent_label = "Defend 4"; intent_actions = [ Defend 4 ] } in
      let h_ = { intent_label = "Hex"; intent_actions = [ Inflict (Vulnerable, 1) ] } in
      let r_ = { intent_label = "Rage"; intent_actions = [ Buff (Strength, 2) ] } in
      assert_equal
        [ Defend_below (50, d_, [ a_ ]); Phase_at (40, [ a_ ], [ r_; h_ ]);
          Random_choice [ a_; d_ ] ]
        (List.map (fun e -> e.enemy_behavior) es) );
  ]

(* ---------- Loader: bad input gives clear errors ---------- *)

let loader_error_tests =
  [
    ( "unknown status names file, card, field and the bad tag" >:: fun _ ->
      assert_error_with
        [
          "fixtures/bad_unknown_status_cards.json";
          {|cards[0] ("bash").effects[1].status|};
          {|unknown status "stun"|};
          "strength, weak, vulnerable, poison";
        ]
        (load_cards "bad_unknown_status_cards.json") );
    ( "unknown effect type" >:: fun _ ->
      assert_error_with
        [ {|effects[0].type|}; {|unknown effect type "heal"|} ]
        (load_cards "bad_unknown_effect_cards.json") );
    ( "missing field" >:: fun _ ->
      assert_error_with
        [ {|cards[0] ("strike")|}; {|missing field "cost"|} ]
        (load_cards "bad_missing_field_cards.json") );
    ( "misspelled field" >:: fun _ ->
      assert_error_with [ {|unknown field "cots"|} ]
        (load_cards "bad_typo_field_cards.json") );
    ( "wrong JSON type" >:: fun _ ->
      assert_error_with
        [ {|("strike").cost|}; "expected an integer, got a string" ]
        (load_cards "bad_wrong_type_cards.json") );
    ( "invalid JSON syntax" >:: fun _ ->
      assert_error_with
        [ "bad_syntax_cards.json"; "invalid JSON" ]
        (load_cards "bad_syntax_cards.json") );
    ( "missing file" >:: fun _ ->
      assert_error_with [ "cannot read"; "no_such_file.json" ]
        (load_cards "no_such_file.json") );
    ( "unknown behavior type" >:: fun _ ->
      assert_error_with
        [ {|enemies[0] ("sleepy_slime").behavior.type|}; {|unknown behavior type "sleep"|} ]
        (load_enemies "bad_unknown_behavior_enemies.json") );
    ( "errors from both files are reported together" >:: fun _ ->
      match
        Loader.load_files ~cards:"fixtures/bad_unknown_status_cards.json"
          ~enemies:"fixtures/bad_unknown_behavior_enemies.json"
      with
      | Ok _ -> assert_failure "expected errors"
      | Error es ->
          assert_mentions [ "stun" ] es;
          assert_mentions [ "sleep" ] es );
    ( "every bad card is reported, not just the first" >:: fun _ ->
      let json =
        {|{ "cards": [
             { "id": "a", "name": "A", "cost": 1, "description": "x",
               "effects": [ { "type": "zap", "amount": 1 } ] },
             { "id": "b", "name": "B", "description": "x", "effects": [] } ] }|}
      in
      match Loader.parse_cards ~source:"inline" (Yojson.Safe.from_string json) with
      | Ok _ -> assert_failure "expected errors"
      | Error es ->
          assert_mentions [ {|("a")|}; "zap" ] es;
          assert_mentions [ {|("b")|}; {|missing field "cost"|} ] es );
    ( "top level must be an object with the right key" >:: fun _ ->
      assert_error_with [ "inline"; {|missing field "cards"|} ]
        (Loader.parse_cards ~source:"inline" (`Assoc [ ("enemies", `List []) ]));
      assert_error_with [ "inline"; "expected an object, got a list" ]
        (Loader.parse_cards ~source:"inline" (`List [])) );
    ( "decimal number where an integer is required" >:: fun _ ->
      assert_error_with [ ".amount"; "expected an integer, got a decimal number" ]
        (Loader.parse_cards ~source:"inline"
           (Yojson.Safe.from_string
              {|{ "cards": [ { "id": "a", "name": "A", "cost": 1, "description": "x",
                  "effects": [ { "type": "draw", "amount": 1.5 } ] } ] }|})) );
  ]

(* ---------- Validate: hard errors ---------- *)

let validate_error_tests =
  [
    ( "real data passes validation" >:: fun _ ->
      assert_valid (get_ok "data" (Loader.load "../data")) );
    ( "tiny fixture passes validation" >:: fun _ ->
      assert_valid (get_ok "tiny" (Loader.load "fixtures/tiny")) );
    ( "duplicate card IDs (from JSON)" >:: fun _ ->
      let c = get_ok "load" (load_cards "bad_duplicate_id_cards.json") in
      assert_invalid [ {|duplicate card ID "strike"|} ] c );
    ( "negative cost (from JSON)" >:: fun _ ->
      let c = get_ok "load" (load_cards "bad_negative_cost_cards.json") in
      assert_invalid [ {|card "cheap": cost is -1; must be 0 or more|} ] c );
    ( "empty cycle (from JSON)" >:: fun _ ->
      let c = get_ok "load" (load_enemies "bad_empty_cycle_enemies.json") in
      assert_invalid
        [ {|enemy "empty_slime"|}; "behavior.intents"; "could not choose an intent" ]
        c );
    ( "duplicate enemy IDs" >:: fun _ ->
      let e = mk_enemy ~id:"slime" (Cycle [ attack5 ]) in
      assert_invalid [ {|duplicate enemy ID "slime"|} ] (only_enemies [ e; e ]) );
    ( "a duplicate is reported once even if repeated three times" >:: fun _ ->
      let c = mk_card [ Draw 1 ] in
      assert_equal 1 (List.length (errors_of (only_cards [ c; c; c ]))) );
    ( "IDs must be lowercase snake case" >:: fun _ ->
      assert_invalid [ {|card "Strike": ID must be lowercase|} ]
        (only_cards [ mk_card ~id:"Strike" [ Draw 1 ] ]);
      assert_invalid [ {|card "": ID must be lowercase|} ]
        (only_cards [ mk_card ~id:"" [ Draw 1 ] ]);
      assert_invalid [ {|card "1hit"|} ] (only_cards [ mk_card ~id:"1hit" [ Draw 1 ] ]) );
    ( "empty name and description" >:: fun _ ->
      let c = only_cards [ mk_card ~name:"" ~description:" " [ Draw 1 ] ] in
      assert_invalid [ "name is empty" ] c;
      assert_invalid [ "description is empty" ] c );
    ( "card with no effects" >:: fun _ ->
      assert_invalid [ {|card "test_card": has no effects|} ] (only_cards [ mk_card [] ]) );
    ( "deal cannot target self" >:: fun _ ->
      assert_invalid [ "effects[0]"; "deal cannot target self" ]
        (only_cards [ mk_card [ Deal (Self, 3) ] ]) );
    ( "negative effect amounts" >:: fun _ ->
      let c =
        only_cards
          [ mk_card [ Deal (Selected_enemy, -1); Gain_block (-2); Draw (-1); Gain_energy (-1) ] ]
      in
      assert_invalid [ "effects[0]: damage is -1" ] c;
      assert_invalid [ "effects[1]: block is -2" ] c;
      assert_invalid [ "effects[2]: draw amount is -1" ] c;
      assert_invalid [ "effects[3]: energy amount is -1" ] c );
    ( "status amount must be at least 1" >:: fun _ ->
      assert_invalid [ "Vulnerable amount is 0; must be at least 1" ]
        (only_cards [ mk_card [ Apply_status (Selected_enemy, Vulnerable, 0) ] ]) );
    ( "zero cost and zero damage are allowed" >:: fun _ ->
      assert_valid (only_cards [ mk_card ~cost:0 [ Deal (Selected_enemy, 0) ] ]) );
    ( "enemy HP must be positive, gold not negative" >:: fun _ ->
      let c = only_enemies [ mk_enemy ~max_hp:0 ~gold:(-1) (Cycle [ attack5 ]) ] in
      assert_invalid [ "max_hp is 0; must be at least 1" ] c;
      assert_invalid [ "gold is -1; must be 0 or more" ] c );
    ( "empty intent lists in every behavior kind" >:: fun _ ->
      assert_invalid [ "behavior.intents: is empty" ]
        (only_enemies [ mk_enemy (Random_choice []) ]);
      assert_invalid [ "behavior.normal: is empty" ]
        (only_enemies [ mk_enemy (Defend_below (50, attack5, [])) ]);
      let c = only_enemies [ mk_enemy (Phase_at (50, [], [])) ] in
      assert_invalid [ "behavior.high: is empty" ] c;
      assert_invalid [ "behavior.low: is empty" ] c );
    ( "HP percentage must be 0 to 100" >:: fun _ ->
      assert_invalid [ "pct is 150; must be between 0 and 100" ]
        (only_enemies [ mk_enemy (Phase_at (150, [ attack5 ], [ attack5 ])) ]);
      assert_invalid [ "pct is -5" ]
        (only_enemies [ mk_enemy (Defend_below (-5, attack5, [ attack5 ])) ]);
      assert_valid (only_enemies [ mk_enemy (Phase_at (100, [ attack5 ], [ attack5 ])) ]) );
    ( "intent labels and action amounts" >:: fun _ ->
      let bad =
        { intent_label = ""; intent_actions = [ Attack (-3); Inflict (Weak, 0) ] }
      in
      let c = only_enemies [ mk_enemy (Cycle [ attack5; bad ]) ] in
      assert_invalid [ "behavior.intents[1]: label is empty" ] c;
      assert_invalid [ "intents[1].actions[0]: attack damage is -3" ] c;
      assert_invalid [ "intents[1].actions[1]: Weak amount is 0" ] c );
    ( "an intent with no actions is allowed (a wait turn)" >:: fun _ ->
      let wait = { intent_label = "Wait"; intent_actions = [] } in
      assert_valid (only_enemies [ mk_enemy (Cycle [ attack5; wait ]) ]) );
  ]

(* ---------- Validate: warnings ---------- *)

let warning_tests =
  [
    ( "real data has no balance warnings" >:: fun _ ->
      assert_equal ~printer:show_errors []
        (Validate.warnings (get_ok "data" (Loader.load "../data"))) );
    ( "0-cost card dealing more than 6 (from JSON) is a warning, not an error" >:: fun _ ->
      let c = get_ok "load" (load_cards "warn_zero_cost_big_hit_cards.json") in
      assert_valid c;
      assert_mentions [ {|card "freebie": costs 0 but deals 9 damage|} ]
        (Validate.warnings c) );
    ( "0-cost limit counts every deal and is exclusive at 6" >:: fun _ ->
      let w cards = Validate.warnings (only_cards cards) in
      assert_equal [] (w [ mk_card ~cost:0 [ Deal (Selected_enemy, 6) ] ]);
      assert_mentions [ "deals 7 damage" ]
        (w [ mk_card ~cost:0 [ Deal (Selected_enemy, 4); Deal (Selected_enemy, 3) ] ]);
      assert_equal [] (w [ mk_card ~cost:1 [ Deal (Selected_enemy, 9) ] ]) );
    ( "card costing more than a turn's energy" >:: fun _ ->
      let w cards = Validate.warnings (only_cards cards) in
      assert_mentions [ "costs 4, more than the 3 energy" ] (w [ mk_card ~cost:4 [ Draw 1 ] ]);
      assert_equal [] (w [ mk_card ~cost:3 [ Draw 1 ] ]);
      assert_equal [] (w [ mk_card ~cost:4 [ Gain_energy 2 ] ]) );
    ( "statuses pointed the wrong way" >:: fun _ ->
      let ws =
        Validate.warnings
          (only_cards
             [ mk_card [ Apply_status (Self, Weak, 1); Apply_status (All_enemies, Strength, 1) ] ])
      in
      assert_mentions [ "applies Weak to the player" ] ws;
      assert_mentions [ "gives Strength to an enemy" ] ws );
    ( "unusually high card damage" >:: fun _ ->
      assert_mentions [ "deals 40 damage in total" ]
        (Validate.warnings (only_cards [ mk_card ~cost:3 [ Deal (Selected_enemy, 40) ] ])) );
    ( "enemy that never attacks" >:: fun _ ->
      let def = { intent_label = "Defend 3"; intent_actions = [ Defend 3 ] } in
      assert_mentions [ {|enemy "test_enemy": never attacks|} ]
        (Validate.warnings (only_enemies [ mk_enemy (Cycle [ def ]) ]));
      (* An attack in any branch counts. *)
      assert_equal []
        (Validate.warnings
           (only_enemies [ mk_enemy (Phase_at (50, [ def ], [ attack5 ])) ])) );
    ( "big enemy attack and gold" >:: fun _ ->
      let hit = { intent_label = "Crush"; intent_actions = [ Attack 50 ] } in
      let ws = Validate.warnings (only_enemies [ mk_enemy ~gold:500 (Cycle [ hit ]) ]) in
      assert_mentions [ "attack of 50" ] ws;
      assert_mentions [ "gives 500 gold" ] ws );
    ( "0% thresholds that can never trigger" >:: fun _ ->
      assert_mentions [ "never defends" ]
        (Validate.warnings (only_enemies [ mk_enemy (Defend_below (0, attack5, [ attack5 ])) ]));
      assert_mentions [ "never reaches its low phase" ]
        (Validate.warnings (only_enemies [ mk_enemy (Phase_at (0, [ attack5 ], [ attack5 ])) ])) );
  ]

(* ---------- Validate: references ---------- *)

let reference_tests =
  let c () = get_ok "data" (Loader.load "../data") in
  let starter =
    [ "strike"; "strike"; "strike"; "strike"; "strike";
      "defend"; "defend"; "defend"; "defend"; "bash" ]
  in
  [
    ( "the agreed starter deck only uses known cards" >:: fun _ ->
      assert_equal (Ok ()) (Validate.card_ids_known (c ()) starter) );
    ( "unknown card IDs are listed once each" >:: fun _ ->
      assert_equal
        (Error [ {|unknown card ID "fireball"|}; {|unknown card ID "zap"|} ])
        (Validate.card_ids_known (c ()) [ "strike"; "zap"; "fireball"; "zap" ]) );
    ( "enemy IDs" >:: fun _ ->
      assert_equal (Ok ()) (Validate.enemy_ids_known (c ()) [ "training_slime" ]);
      assert_error_with [ {|unknown enemy ID "dragon"|} ]
        (Validate.enemy_ids_known (c ()) [ "dragon" ]) );
    ( "empty ID list is fine" >:: fun _ ->
      assert_equal (Ok ()) (Validate.card_ids_known (c ()) []) );
    ( "unknown reward pool IDs fail content validation" >:: fun _ ->
      let c = { (c ()) with content_reward_pool = [ "missing_card" ] } in
      assert_error_with [ "reward_pool"; "missing_card" ] (Validate.content c) );
  ]

let suite =
  "content tests"
  >::: [
         "loader: valid" >::: loader_valid_tests;
         "loader: errors" >::: loader_error_tests;
         "validate: errors" >::: validate_error_tests;
         "validate: warnings" >::: warning_tests;
         "validate: references" >::: reference_tests;
       ]

let () = run_test_tt_main suite
