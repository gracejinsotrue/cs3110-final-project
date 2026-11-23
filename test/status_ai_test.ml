(** Tests for [Status] (status arithmetic) and [Enemy_ai] (intent choice).
    Both modules are pure, so every test is a plain function call. *)

open OUnit2
open Types

(** Status maps have no meaningful order, so compare them sorted. *)
let sorted m = List.sort compare m

let assert_map expected actual =
  assert_equal ~printer:(fun m ->
      String.concat "; "
        (List.map
           (fun (s, n) ->
             (match s with
             | Strength -> "Strength"
             | Weak -> "Weak"
             | Vulnerable -> "Vulnerable"
             | Poison -> "Poison")
             ^ " " ^ string_of_int n)
           m))
    (sorted expected) (sorted actual)

let int_eq = assert_equal ~printer:string_of_int

(* ---------- Status ---------- *)

let status_tests =
  "Status"
  >::: [
         ( "apply adds a new status" >:: fun _ ->
           assert_map [ (Weak, 2) ] (Status.apply Weak 2 []) );
         ( "apply stacks additively" >:: fun _ ->
           assert_map [ (Weak, 3) ] (Status.apply Weak 2 [] |> Status.apply Weak 1) );
         ( "apply keeps other statuses" >:: fun _ ->
           assert_map
             [ (Poison, 4); (Strength, 1) ]
             (Status.apply Poison 4 [ (Strength, 1) ]) );
         ( "apply with 0 or negative is a no-op" >:: fun _ ->
           assert_map [ (Weak, 1) ] (Status.apply Vulnerable 0 [ (Weak, 1) ]);
           assert_map [ (Weak, 1) ] (Status.apply Weak (-3) [ (Weak, 1) ]) );
         ( "tick returns poison damage and lowers poison" >:: fun _ ->
           let m, dmg = Status.tick [ (Poison, 3) ] in
           int_eq 3 dmg;
           assert_map [ (Poison, 2) ] m );
         ( "tick with no poison deals 0" >:: fun _ ->
           int_eq 0 (snd (Status.tick [ (Weak, 2) ])) );
         ( "tick lowers Weak and Vulnerable, keeps Strength" >:: fun _ ->
           let m, _ = Status.tick [ (Weak, 2); (Vulnerable, 3); (Strength, 2) ] in
           assert_map [ (Weak, 1); (Vulnerable, 2); (Strength, 2) ] m );
         ( "tick removes statuses that reach 0" >:: fun _ ->
           let m, dmg = Status.tick [ (Weak, 1); (Poison, 1); (Strength, 1) ] in
           int_eq 1 dmg;
           assert_map [ (Strength, 1) ] m );
         ( "tick on empty map" >:: fun _ ->
           let m, dmg = Status.tick [] in
           int_eq 0 dmg;
           assert_map [] m );
         ( "outgoing with no statuses is unchanged" >:: fun _ ->
           int_eq 6 (Status.outgoing [] 6) );
         ( "outgoing adds Strength" >:: fun _ ->
           int_eq 9 (Status.outgoing [ (Strength, 3) ] 6) );
         ( "outgoing Weak multiplies by 0.75, rounding down" >:: fun _ ->
           int_eq 7 (Status.outgoing [ (Weak, 1) ] 10) );
         ( "outgoing applies Strength before Weak" >:: fun _ ->
           (* (6 + 4) * 0.75 = 7.5 -> 7. Weak first would give 4 + 4 = 8. *)
           int_eq 7 (Status.outgoing [ (Strength, 4); (Weak, 1) ] 6) );
         ( "outgoing of 0 stays 0" >:: fun _ ->
           int_eq 0 (Status.outgoing [ (Weak, 2) ] 0) );
         ( "incoming with no statuses is unchanged" >:: fun _ ->
           int_eq 10 (Status.incoming [] 10) );
         ( "incoming Vulnerable turns 10 into 15" >:: fun _ ->
           int_eq 15 (Status.incoming [ (Vulnerable, 1) ] 10) );
         ( "incoming Vulnerable rounds down" >:: fun _ ->
           int_eq 10 (Status.incoming [ (Vulnerable, 2) ] 7) );
         ( "incoming ignores Weak and Strength" >:: fun _ ->
           int_eq 8 (Status.incoming [ (Weak, 1); (Strength, 5) ] 8) );
         ( "full pipeline: Strength 2 + Weak attacker vs Vulnerable defender" >:: fun _ ->
           (* (8 + 2) * 0.75 = 7, then 7 * 1.5 = 10 *)
           int_eq 10
             (Status.incoming [ (Vulnerable, 1) ]
                (Status.outgoing [ (Strength, 2); (Weak, 1) ] 8)) );
       ]

(* ---------- Enemy_ai ---------- *)

let intent label = { intent_label = label; intent_actions = [ Attack 1 ] }
let a = intent "A"
let b = intent "B"
let c = intent "C"
let defend = { intent_label = "Defend 5"; intent_actions = [ Defend 5 ] }

let enemy behavior =
  {
    enemy_id = "test";
    enemy_name = "Test";
    enemy_max_hp = 100;
    enemy_gold = 0;
    enemy_behavior = behavior;
  }

let view ?(hp = 100) ?(max_hp = 100) turn =
  { ev_hp = hp; ev_max_hp = max_hp; ev_block = 0; ev_turn = turn; ev_statuses = [] }

let rng () = Random.State.make [| 42 |]

(** Label of the intent chosen for [behavior] at [view]. *)
let pick ?(rng = rng ()) behavior v =
  (Enemy_ai.next_intent rng (enemy behavior) v).intent_label

let str_eq = assert_equal ~printer:(fun s -> s)

let ai_tests =
  "Enemy_ai"
  >::: [
         ( "cycle starts at the first intent on turn 0" >:: fun _ ->
           str_eq "A" (pick (Cycle [ a; b; c ]) (view 0)) );
         ( "cycle follows list order and wraps" >:: fun _ ->
           let labels = List.map (fun t -> pick (Cycle [ a; b; c ]) (view t)) [ 0; 1; 2; 3; 4 ] in
           assert_equal [ "A"; "B"; "C"; "A"; "B" ] labels );
         ( "single-intent cycle always repeats" >:: fun _ ->
           str_eq "A" (pick (Cycle [ a ]) (view 7)) );
         ( "empty cycle waits" >:: fun _ ->
           let i = Enemy_ai.next_intent (rng ()) (enemy (Cycle [])) (view 0) in
           str_eq "Wait" i.intent_label;
           assert_equal [] i.intent_actions );
         ( "defend_below defends at 40% HP with threshold 50" >:: fun _ ->
           str_eq "Defend 5" (pick (Defend_below (50, defend, [ a; b ])) (view ~hp:40 0)) );
         ( "defend_below cycles normally at or above threshold" >:: fun _ ->
           str_eq "A" (pick (Defend_below (50, defend, [ a; b ])) (view ~hp:50 0));
           str_eq "B" (pick (Defend_below (50, defend, [ a; b ])) (view ~hp:90 1)) );
         ( "defend_below threshold uses exact integer math" >:: fun _ ->
           (* 14/30 = 46.7% < 50%; 15/30 = 50% is not below *)
           str_eq "Defend 5"
             (pick (Defend_below (50, defend, [ a ])) (view ~hp:14 ~max_hp:30 0));
           str_eq "A" (pick (Defend_below (50, defend, [ a ])) (view ~hp:15 ~max_hp:30 0)) );
         ( "defend_below with empty normal list waits" >:: fun _ ->
           str_eq "Wait" (pick (Defend_below (50, defend, [])) (view 0)) );
         ( "phase_at cycles high list while HP >= pct" >:: fun _ ->
           str_eq "A" (pick (Phase_at (50, [ a; b ], [ c ])) (view ~hp:60 0));
           str_eq "B" (pick (Phase_at (50, [ a; b ], [ c ])) (view ~hp:50 1)) );
         ( "phase_at cycles low list once HP < pct" >:: fun _ ->
           str_eq "C" (pick (Phase_at (50, [ a ], [ b; c ])) (view ~hp:49 1)) );
         ( "random_choice is repeatable with the same seed" >:: fun _ ->
           let run () =
             let r = rng () in
             List.map (fun t -> pick ~rng:r (Random_choice [ a; b; c ]) (view t)) [ 0; 1; 2; 3; 4; 5 ]
           in
           assert_equal (run ()) (run ()) );
         ( "random_choice only returns listed intents" >:: fun _ ->
           let r = rng () in
           for t = 0 to 50 do
             let l = pick ~rng:r (Random_choice [ a; b ]) (view t) in
             assert_bool ("unexpected " ^ l) (l = "A" || l = "B")
           done );
         ( "random_choice eventually picks every intent" >:: fun _ ->
           let r = rng () in
           let seen = List.init 100 (fun t -> pick ~rng:r (Random_choice [ a; b; c ]) (view t)) in
           List.iter (fun l -> assert_bool ("never picked " ^ l) (List.mem l seen)) [ "A"; "B"; "C" ] );
         ( "empty random_choice waits" >:: fun _ ->
           str_eq "Wait" (pick (Random_choice []) (view 0)) );
         ( "non-random behaviors do not use the rng" >:: fun _ ->
           let r = rng () in
           ignore (Enemy_ai.next_intent r (enemy (Cycle [ a; b ])) (view 0));
           ignore (Enemy_ai.next_intent r (enemy (Phase_at (50, [ a ], [ b ]))) (view 0));
           assert_equal (Random.State.bits (rng ())) (Random.State.bits r) );
       ]

(* ---------- Boss content ---------- *)

let boss_tests =
  "camel_king boss"
  >::: [
         ( "switches to its low phase below 50% HP" >:: fun _ ->
           let content = Result.get_ok (Loader.load "../data") in
           let boss = List.find (fun e -> e.enemy_id = "camel_king") content.content_enemies in
           let label hp t =
             (Enemy_ai.next_intent (rng ()) boss (view ~hp ~max_hp:boss.enemy_max_hp t)).intent_label
           in
           str_eq "Gather Strength (+2 Strength)" (label 120 0);
           str_eq "Attack 8" (label 60 1);
           str_eq "Spit: Attack 6, Poison 3" (label 59 1) );
       ]

let () = run_test_tt_main ("status and enemy ai" >::: [ status_tests; ai_tests; boss_tests ])
