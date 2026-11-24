(* AI acknowledgement: written with AI assistance (Claude Code); owner Nick
   Lennon (ncl46). Expected values come from the rules in README.md, worked
   out before running the code rather than copied from its output. PRs #9 and
   #11 give the details. *)

(** Black-box tests for [Combat]. They check only [view], [result] and
    [fight_cards], never Combat's private state. Hand order depends on the
    shuffle, so tests either use decks of one card kind or look a card up by ID
    in the hand ([H.number]); no test assumes a card is hand number 1 unless
    every card in the hand is the same.

    Most tests use fakes: [No_status] (statuses do nothing) with [Attack5_ai]
    (always "Attack 5"), or [Script_ai], which follows the enemy's [Cycle] list
    by [ev_turn] so a test can script each round. Status timing tests use the
    real [Status]; one test uses the real [Enemy_ai]. *)

open OUnit2
open Types

(* ---------- Content built in the test ---------- *)

let card ?(cost = 1) id effects =
  {
    card_id = id;
    card_name = String.capitalize_ascii id;
    card_cost = cost;
    card_description = id;
    card_effects = effects;
  }

let repeat n x = List.init n (fun _ -> x)
let strike = card "strike" [ Deal (Selected_enemy, 6) ]
let defend = card "defend" [ Gain_block 5 ]

let bash =
  card ~cost:2 "bash"
    [ Deal (Selected_enemy, 8); Apply_status (Selected_enemy, Vulnerable, 2) ]

let starter = repeat 5 strike @ repeat 4 defend @ [ bash ]
let guard = card "guard" [ Gain_block 3 ]
let wide = card "wide_swing" [ Deal (All_enemies, 5) ]

let twin =
  card "twin_jab" [ Deal (Selected_enemy, 4); Deal (Selected_enemy, 4) ]

let finisher = card "finisher" [ Deal (Selected_enemy, 10); Gain_block 5 ]
let scry = card ~cost:0 "scry" [ Draw 1 ]
let surge = card ~cost:0 "surge" [ Gain_energy 2 ]
let venom = card "venom" [ Apply_status (Selected_enemy, Poison, 4) ]
let war_cry = card "war_cry" [ Apply_status (Self, Strength, 2) ]

let dull_blade =
  card "dull_blade"
    [ Deal (Selected_enemy, 5); Apply_status (Selected_enemy, Weak, 2) ]

let bad_self_hit = card "bad" [ Deal (Self, 5) ]
let intent label actions = { intent_label = label; intent_actions = actions }
let attack n = intent (Printf.sprintf "Attack %d" n) [ Attack n ]
let defend_i n = intent (Printf.sprintf "Defend %d" n) [ Defend n ]
let inflict s n = intent "Hex" [ Inflict (s, n) ]
let buff s n = intent "Grow" [ Buff (s, n) ]

let enemy ?(name = "Dummy") ?(hp = 30) ?(gold = 5) intents =
  {
    enemy_id = String.lowercase_ascii name;
    enemy_name = name;
    enemy_max_hp = hp;
    enemy_gold = gold;
    enemy_behavior = Cycle intents;
  }

let dummy ?name ?hp ?gold () = enemy ?name ?hp ?gold [ attack 5 ]

(* ---------- Fake Status and AI modules ---------- *)

module No_status : Sigs.STATUS = struct
  let apply _ _ m = m
  let tick m = (m, 0)
  let outgoing _ d = d
  let incoming _ d = d
end

(** Outgoing doubles and incoming adds 1, so the call order shows in the result:
    6 becomes 13 if outgoing runs first, 14 otherwise. *)
module Order_status : Sigs.STATUS = struct
  let apply _ _ m = m
  let tick m = (m, 0)
  let outgoing _ d = d * 2
  let incoming _ d = d + 1
end

module Attack5_ai : Sigs.ENEMY_AI = struct
  let next_intent _ _ _ = attack 5
end

module Script_ai : Sigs.ENEMY_AI = struct
  let next_intent _ def view =
    match def.enemy_behavior with
    | Cycle (_ :: _ as l) -> List.nth l (view.ev_turn mod List.length l)
    | _ -> intent "Wait" []
end

(* ---------- Helpers ---------- *)

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

(** [rejected ~mentions r] checks that [r] is an error whose message contains
    [mentions]. *)
let rejected ~mentions = function
  | Ok _ -> assert_failure ("expected an error mentioning: " ^ mentions)
  | Error msg ->
      assert_bool
        (Printf.sprintf "error %S should mention %S" msg mentions)
        (contains msg mentions)

let int_eq = assert_equal ~printer:string_of_int
let str_eq = assert_equal ~printer:(fun s -> s)
let ids_eq = assert_equal ~printer:(String.concat ", ")
let sorted_ids cards = List.sort compare (List.map (fun c -> c.card_id) cards)

let show_status = function
  | Strength -> "Strength"
  | Weak -> "Weak"
  | Vulnerable -> "Vulnerable"
  | Poison -> "Poison"

let status_eq expected actual =
  assert_equal
    ~printer:(fun m ->
      String.concat "; "
        (List.map (fun (s, n) -> show_status s ^ " " ^ string_of_int n) m))
    (List.sort compare expected)
    (List.sort compare actual)

let result_eq =
  assert_equal ~printer:(function
    | None -> "None"
    | Some r ->
        Printf.sprintf "Some {won=%b; hp_left=%d; gold=%d}" r.res_won
          r.res_hp_left r.res_gold)

let won hp gold = Some { res_won = true; res_hp_left = hp; res_gold = gold }
let lost = Some { res_won = false; res_hp_left = 0; res_gold = 0 }

(** The signature of [Combat.Make (_) (_)], with [t] left abstract so one helper
    functor serves every instantiation. *)
module type COMBAT = sig
  type t

  val init :
    Random.State.t ->
    deck:card_def list ->
    hp:int ->
    max_hp:int ->
    enemy_def list ->
    (t, string) result

  val play_card :
    t -> hand_index:int -> target_index:int option -> (t, string) result

  val end_turn : t -> (t, string) result
  val view : t -> combat_view
  val result : t -> combat_result option
  val fight_cards : t -> card_def list
end

(** Helpers for one instantiation of the engine. *)
module H (C : COMBAT) = struct
  include C

  let start ?(seed = 1) ?(hp = 80) ?(max_hp = 80) deck enemies =
    match init (Random.State.make [| seed |]) ~deck ~hp ~max_hp enemies with
    | Ok t -> t
    | Error e -> assert_failure ("init failed: " ^ e)

  let get what = function
    | Ok t -> t
    | Error e -> assert_failure (what ^ " failed: " ^ e)

  let play ?target n t =
    get
      (Printf.sprintf "play %d" n)
      (play_card t ~hand_index:n ~target_index:target)

  let next_turn t = get "end" (end_turn t)
  let hand_ids t = List.map (fun (_, c) -> c.card_id) (view t).cv_hand

  (** The hand number of the first card with this ID. *)
  let number id t =
    match List.find_opt (fun (_, c) -> c.card_id = id) (view t).cv_hand with
    | Some (n, _) -> n
    | None -> assert_failure (id ^ " is not in the hand")

  let play_id ?target id t = play ?target (number id t) t

  (** The enemy shown with number [n]. *)
  let foe n t = List.nth (view t).cv_enemies (n - 1)

  let foe_hp n t = (foe n t).ce_hp
  let hp t = (view t).cv_player_hp

  (** Hand + draw + discard, from the view. *)
  let card_count t =
    let v = view t in
    List.length v.cv_hand + v.cv_draw_count + v.cv_discard_count
end

module F = H (Combat.Make (No_status) (Attack5_ai))
module S = H (Combat.Make (No_status) (Script_ai))
module O = H (Combat.Make (Order_status) (Script_ai))
module R = H (Combat.Make (Status) (Script_ai))
module Real = H (Combat.Make (Status) (Enemy_ai))

(* ---------- init ---------- *)

let init_tests =
  "init"
  >::: [
         ( "first hand, energy, piles and enemy" >:: fun _ ->
           let v = F.view (F.start starter [ dummy () ]) in
           int_eq 5 (List.length v.cv_hand);
           assert_equal [ 1; 2; 3; 4; 5 ] (List.map fst v.cv_hand);
           int_eq 3 v.cv_energy;
           int_eq 3 v.cv_max_energy;
           int_eq 1 v.cv_turn;
           int_eq 5 v.cv_draw_count;
           int_eq 0 v.cv_discard_count;
           int_eq 80 v.cv_player_hp;
           int_eq 80 v.cv_player_max_hp;
           int_eq 0 v.cv_player_block;
           status_eq [] v.cv_player_statuses;
           match v.cv_enemies with
           | [ e ] ->
               int_eq 1 e.ce_number;
               str_eq "Dummy" e.ce_name;
               int_eq 30 e.ce_hp;
               int_eq 30 e.ce_max_hp;
               int_eq 0 e.ce_block;
               str_eq "Attack 5" e.ce_intent.intent_label
           | _ -> assert_failure "expected exactly one enemy" );
         ( "a small deck draws what it can" >:: fun _ ->
           let v = F.view (F.start (repeat 3 strike) [ dummy () ]) in
           int_eq 3 (List.length v.cv_hand);
           int_eq 0 v.cv_draw_count );
         ( "the first intent uses ev_turn 0" >:: fun _ ->
           let t = S.start starter [ enemy [ defend_i 3; attack 5 ] ] in
           str_eq "Defend 3" (S.foe 1 t).ce_intent.intent_label );
         ( "starting below max HP" >:: fun _ ->
           int_eq 63 (F.hp (F.start ~hp:63 starter [ dummy () ])) );
         ( "rejects bad setups" >:: fun _ ->
           let rng () = Random.State.make [| 1 |] in
           rejected ~mentions:"at least one enemy"
             (F.init (rng ()) ~deck:starter ~hp:80 ~max_hp:80 []);
           rejected ~mentions:"Starting HP"
             (F.init (rng ()) ~deck:starter ~hp:0 ~max_hp:80 [ dummy () ]);
           rejected ~mentions:"Starting HP"
             (F.init (rng ()) ~deck:starter ~hp:81 ~max_hp:80 [ dummy () ]);
           rejected ~mentions:"Max HP"
             (F.init (rng ()) ~deck:starter ~hp:1 ~max_hp:0 [ dummy () ]) );
         ( "fight_cards is the whole deck, sorted by name" >:: fun _ ->
           let t = F.start starter [ dummy () ] in
           let cards = F.fight_cards t in
           ids_eq (sorted_ids starter) (sorted_ids cards);
           let names = List.map (fun c -> c.card_name) cards in
           ids_eq (List.sort compare names) names );
         ( "no result at the start" >:: fun _ ->
           result_eq None (F.result (F.start starter [ dummy () ])) );
       ]

(* ---------- play_card ---------- *)

let play_tests =
  "play_card"
  >::: [
         ( "Strike deals 6, costs 1 and goes to discard" >:: fun _ ->
           let t =
             F.start (repeat 5 strike) [ dummy () ] |> F.play ~target:1 1
           in
           let v = F.view t in
           int_eq 24 (F.foe_hp 1 t);
           int_eq 2 v.cv_energy;
           int_eq 4 (List.length v.cv_hand);
           int_eq 1 v.cv_discard_count;
           int_eq 0 v.cv_draw_count );
         ( "Strike against 3 block deals 3" >:: fun _ ->
           let t =
             S.start (repeat 10 strike) [ enemy [ defend_i 3 ] ] |> S.next_turn
           in
           int_eq 3 (S.foe 1 t).ce_block;
           let t = S.play ~target:1 1 t in
           int_eq 27 (S.foe_hp 1 t);
           int_eq 0 (S.foe 1 t).ce_block );
         ( "block absorbs an attack and leftover block is removed" >:: fun _ ->
           (* 10 block takes the 5-damage hit; the 5 left over must not
              carry into turn 2. *)
           let t =
             F.start (repeat 5 defend) [ dummy () ] |> F.play 1 |> F.play 1
           in
           int_eq 10 (F.view t).cv_player_block;
           let t = F.next_turn t in
           int_eq 80 (F.hp t);
           int_eq 0 (F.view t).cv_player_block );
         ( "block partly absorbs an attack" >:: fun _ ->
           let t =
             F.start (repeat 5 guard) [ dummy () ] |> F.play 1 |> F.next_turn
           in
           int_eq 78 (F.hp t) );
         ( "an unaffordable card is rejected" >:: fun _ ->
           let t = F.start (repeat 5 bash) [ dummy () ] |> F.play ~target:1 1 in
           int_eq 1 (F.view t).cv_energy;
           rejected ~mentions:"costs 2 energy, but you have 1"
             (F.play_card t ~hand_index:1 ~target_index:(Some 1)) );
         ( "the target is checked before energy" >:: fun _ ->
           (* Bash with 1 energy left: a missing or bad target is reported
              rather than the cost. *)
           let t = F.start (repeat 5 bash) [ dummy () ] |> F.play ~target:1 1 in
           rejected ~mentions:"needs an enemy number"
             (F.play_card t ~hand_index:1 ~target_index:None);
           rejected ~mentions:"no enemy 5"
             (F.play_card t ~hand_index:1 ~target_index:(Some 5)) );
         ( "bad hand numbers are rejected" >:: fun _ ->
           let t = F.start starter [ dummy () ] in
           List.iter
             (fun n ->
               rejected ~mentions:"choose a card from 1 to 5"
                 (F.play_card t ~hand_index:n ~target_index:(Some 1)))
             [ 0; 6; -1 ] );
         ( "with one card in hand, the error names it" >:: fun _ ->
           let t = F.start [ strike ] [ dummy () ] in
           rejected ~mentions:"no card 2 in your hand; your only card is 1"
             (F.play_card t ~hand_index:2 ~target_index:(Some 1)) );
         ( "playing from an empty hand is rejected" >:: fun _ ->
           let t = F.start [] [ dummy () ] in
           rejected ~mentions:"hand is empty"
             (F.play_card t ~hand_index:1 ~target_index:None) );
         ( "a targeted card without an enemy number is rejected" >:: fun _ ->
           let t = F.start (repeat 5 strike) [ dummy () ] in
           rejected ~mentions:"needs an enemy number"
             (F.play_card t ~hand_index:1 ~target_index:None) );
         ( "bad enemy numbers are rejected" >:: fun _ ->
           let t = F.start (repeat 5 strike) [ dummy () ] in
           List.iter
             (fun n ->
               rejected ~mentions:"the only enemy is 1"
                 (F.play_card t ~hand_index:1 ~target_index:(Some n)))
             [ 2; 0; -1 ];
           let t = F.start (repeat 5 strike) [ dummy (); dummy () ] in
           rejected ~mentions:"no enemy 3; choose an enemy from 1 to 2"
             (F.play_card t ~hand_index:1 ~target_index:(Some 3)) );
         ( "a self card given an enemy number is rejected" >:: fun _ ->
           let t = F.start (repeat 5 defend) [ dummy () ] in
           rejected ~mentions:"does not take an enemy number"
             (F.play_card t ~hand_index:1 ~target_index:(Some 1)) );
         ( "Bash deals 8 before applying Vulnerable" >:: fun _ ->
           let t = R.start (bash :: repeat 4 strike) [ enemy [ attack 5 ] ] in
           let t = R.play_id ~target:1 "bash" t in
           int_eq 22 (R.foe_hp 1 t);
           status_eq [ (Vulnerable, 2) ] (R.foe 1 t).ce_statuses;
           let t = R.play_id ~target:1 "strike" t in
           int_eq 13 (R.foe_hp 1 t);
           int_eq 0 (R.view t).cv_energy );
         ( "a hit runs outgoing, then incoming" >:: fun _ ->
           let t = O.start (repeat 5 strike) [ enemy [ attack 5 ] ] in
           let t = O.play ~target:1 1 t in
           int_eq 17 (O.foe_hp 1 t);
           let t = O.next_turn t in
           int_eq 69 (O.hp t) );
         ( "Strength from a self card adds to the player's hits" >:: fun _ ->
           let t =
             R.start (war_cry :: repeat 4 strike) [ enemy [ attack 5 ] ]
           in
           let t = R.play_id "war_cry" t in
           status_eq [ (Strength, 2) ] (R.view t).cv_player_statuses;
           let t = R.play_id ~target:1 "strike" t in
           int_eq 22 (R.foe_hp 1 t) );
         ( "All_enemies hits each living enemy once and takes no target"
         >:: fun _ ->
           let t = F.start (repeat 5 wide) [ dummy (); dummy () ] in
           rejected ~mentions:"does not take an enemy number"
             (F.play_card t ~hand_index:1 ~target_index:(Some 1));
           let t = F.play 1 t in
           int_eq 25 (F.foe_hp 1 t);
           int_eq 25 (F.foe_hp 2 t) );
         ( "enemy numbers shift after a death" >:: fun _ ->
           let t =
             F.start (repeat 5 strike)
               [ dummy ~name:"Alpha" ~hp:6 (); dummy ~name:"Beta" () ]
           in
           let t = F.play ~target:1 1 t in
           (match (F.view t).cv_enemies with
           | [ e ] ->
               str_eq "Beta" e.ce_name;
               int_eq 1 e.ce_number
           | _ -> assert_failure "expected only Beta");
           rejected ~mentions:"no enemy 2"
             (F.play_card t ~hand_index:1 ~target_index:(Some 2));
           let t = F.play ~target:1 1 t in
           int_eq 24 (F.foe_hp 1 t) );
         ( "a second hit on a dead target does nothing" >:: fun _ ->
           let t =
             F.start (repeat 5 twin)
               [ dummy ~name:"Alpha" ~hp:4 (); dummy ~name:"Beta" () ]
             |> F.play ~target:1 1
           in
           result_eq None (F.result t);
           int_eq 1 (List.length (F.view t).cv_enemies);
           int_eq 30 (F.foe_hp 1 t) );
         ( "a card stops as soon as the fight is won" >:: fun _ ->
           let t =
             F.start (repeat 5 finisher) [ dummy ~hp:5 () ]
             |> F.play ~target:1 1
           in
           result_eq (won 80 5) (F.result t);
           int_eq 0 (F.view t).cv_player_block );
         ( "Gain_energy can go above max for this turn only" >:: fun _ ->
           let t =
             F.start (surge :: repeat 4 strike) [ dummy () ]
             |> F.play_id "surge"
           in
           int_eq 5 (F.view t).cv_energy;
           int_eq 3 (F.view t).cv_max_energy;
           int_eq 3 (F.view (F.next_turn t)).cv_energy );
         ( "a played card is not redrawn by its own Draw" >:: fun _ ->
           let t =
             F.start (scry :: repeat 4 strike) [ dummy () ] |> F.play_id "scry"
           in
           let v = F.view t in
           ids_eq (repeat 4 "strike") (F.hand_ids t);
           int_eq 0 v.cv_draw_count;
           int_eq 1 v.cv_discard_count );
         ( "Draw reshuffles the discard pile mid-turn" >:: fun _ ->
           let t =
             F.start (scry :: repeat 4 strike) [ dummy () ]
             |> F.play_id ~target:1 "strike"
             |> F.play_id "scry"
           in
           let v = F.view t in
           ids_eq (repeat 4 "strike") (F.hand_ids t);
           int_eq 0 v.cv_draw_count;
           int_eq 1 v.cv_discard_count;
           int_eq 5 (F.card_count t) );
         ( "an invalid Deal (Self, _) does nothing and does not raise"
         >:: fun _ ->
           let t = F.start (repeat 5 bad_self_hit) [ dummy () ] |> F.play 1 in
           int_eq 80 (F.hp t);
           int_eq 2 (F.view t).cv_energy );
       ]

(* ---------- end_turn ---------- *)

let end_turn_tests =
  "end_turn"
  >::: [
         ( "the shown intent runs and a new turn starts" >:: fun _ ->
           let t =
             F.start (repeat 10 strike) [ dummy () ] |> F.play ~target:1 1
           in
           let v = F.view (F.next_turn t) in
           int_eq 75 v.cv_player_hp;
           int_eq 2 v.cv_turn;
           int_eq 3 v.cv_energy;
           int_eq 0 v.cv_player_block;
           int_eq 5 (List.length v.cv_hand);
           int_eq 0 v.cv_draw_count;
           int_eq 5 v.cv_discard_count;
           int_eq 3 (F.view (F.next_turn (F.next_turn t))).cv_turn );
         ( "the discard is reshuffled when the draw pile runs out" >:: fun _ ->
           let t = F.start (repeat 7 strike) [ dummy () ] |> F.next_turn in
           let v = F.view t in
           int_eq 5 (List.length v.cv_hand);
           int_eq 2 v.cv_draw_count;
           int_eq 0 v.cv_discard_count );
         ( "no card is lost or duplicated over several turns" >:: fun _ ->
           let deck = starter in
           let check t =
             ids_eq (sorted_ids deck) (sorted_ids (F.fight_cards t));
             int_eq (List.length deck) (F.card_count t)
           in
           let try_play t =
             match F.play_card t ~hand_index:1 ~target_index:(Some 1) with
             | Ok t -> t
             | Error _ -> (
                 match F.play_card t ~hand_index:1 ~target_index:None with
                 | Ok t -> t
                 | Error _ -> t)
           in
           let rec go k t =
             if k > 0 then begin
               let t = try_play t in
               check t;
               let t = F.next_turn t in
               check t;
               go (k - 1) t
             end
           in
           go 6 (F.start deck [ dummy ~hp:500 () ]) );
         ( "an enemy's block clears just before it acts" >:: fun _ ->
           let t =
             S.start (repeat 5 strike) [ enemy [ defend_i 3 ] ] |> S.next_turn
           in
           int_eq 3 (S.foe 1 t).ce_block;
           int_eq 3 (S.foe 1 (S.next_turn t)).ce_block );
         ( "intents follow the enemy's turn count" >:: fun _ ->
           let t =
             S.start (repeat 5 strike)
               [ enemy [ attack 1; defend_i 1; attack 2 ] ]
           in
           let label t = (S.foe 1 t).ce_intent.intent_label in
           str_eq "Attack 1" (label t);
           let t = S.next_turn t in
           str_eq "Defend 1" (label t);
           let t = S.next_turn t in
           str_eq "Attack 2" (label t);
           str_eq "Attack 1" (label (S.next_turn t)) );
         ( "enemies act in display order" >:: fun _ ->
           let t =
             S.start (repeat 5 strike)
               [ enemy [ attack 5 ]; enemy [ defend_i 3 ] ]
             |> S.next_turn
           in
           int_eq 75 (S.hp t);
           int_eq 3 (S.foe 2 t).ce_block );
         ( "the enemy round stops when the player dies" >:: fun _ ->
           let t =
             S.start ~hp:5 (repeat 5 strike)
               [ enemy [ attack 5 ]; enemy [ defend_i 3 ] ]
             |> S.next_turn
           in
           result_eq lost (S.result t);
           int_eq 0 (S.hp t);
           int_eq 0 (S.foe 2 t).ce_block );
         ( "player poison ticks at the end of the player's turn" >:: fun _ ->
           let t =
             R.start (repeat 5 strike)
               [ enemy [ inflict Poison 3; defend_i 1 ] ]
             |> R.next_turn
           in
           int_eq 80 (R.hp t);
           status_eq [ (Poison, 3) ] (R.view t).cv_player_statuses;
           let t = R.next_turn t in
           int_eq 77 (R.hp t);
           status_eq [ (Poison, 2) ] (R.view t).cv_player_statuses );
         ( "poison that kills the player stops the enemy round" >:: fun _ ->
           let t =
             R.start ~hp:3 (repeat 5 strike)
               [ enemy [ inflict Poison 3; defend_i 3 ] ]
             |> R.next_turn |> R.next_turn
           in
           result_eq lost (R.result t);
           int_eq 0 (R.foe 1 t).ce_block );
         ( "enemy poison ticks right after the enemy acts" >:: fun _ ->
           let t =
             R.start (repeat 5 venom) [ enemy [ attack 5 ] ]
             |> R.play ~target:1 1
           in
           status_eq [ (Poison, 4) ] (R.foe 1 t).ce_statuses;
           let t = R.next_turn t in
           int_eq 75 (R.hp t);
           int_eq 26 (R.foe_hp 1 t);
           status_eq [ (Poison, 3) ] (R.foe 1 t).ce_statuses );
         ( "an enemy killed by poison still makes its attack" >:: fun _ ->
           let t =
             R.start (repeat 5 venom) [ enemy ~hp:3 [ attack 5 ] ]
             |> R.play ~target:1 1 |> R.next_turn
           in
           result_eq (won 75 5) (R.result t) );
         ( "Buff gives the enemy Strength for later attacks" >:: fun _ ->
           let t =
             R.start (repeat 5 strike) [ enemy [ buff Strength 2; attack 5 ] ]
             |> R.next_turn
           in
           status_eq [ (Strength, 2) ] (R.foe 1 t).ce_statuses;
           int_eq 80 (R.hp t);
           int_eq 73 (R.hp (R.next_turn t)) );
         ( "player Vulnerable ticks before the enemy attacks" >:: fun _ ->
           (* Vulnerable 2 drops to 1 when the player ends turn 2, so the
              attack is still boosted: floor (5 * 1.5) = 7. *)
           let t =
             R.start (repeat 5 strike)
               [ enemy [ inflict Vulnerable 2; attack 5 ] ]
             |> R.next_turn |> R.next_turn
           in
           int_eq 73 (R.hp t);
           status_eq [ (Vulnerable, 1) ] (R.view t).cv_player_statuses );
         ( "Weak on an enemy lowers its attack" >:: fun _ ->
           let t =
             R.start (repeat 5 dull_blade) [ enemy [ attack 5 ] ]
             |> R.play ~target:1 1
           in
           int_eq 25 (R.foe_hp 1 t);
           let t = R.next_turn t in
           int_eq 77 (R.hp t);
           status_eq [ (Weak, 1) ] (R.foe 1 t).ce_statuses );
       ]

(* ---------- results ---------- *)

let result_tests =
  "result"
  >::: [
         ( "victory keeps HP and awards gold" >:: fun _ ->
           let t =
             F.start (repeat 5 strike) [ dummy ~hp:6 ~gold:7 () ]
             |> F.play ~target:1 1
           in
           result_eq (won 80 7) (F.result t);
           int_eq 0 (List.length (F.view t).cv_enemies);
           rejected ~mentions:"over"
             (F.play_card t ~hand_index:1 ~target_index:(Some 1));
           rejected ~mentions:"over" (F.end_turn t) );
         ( "gold is summed over every enemy" >:: fun _ ->
           let t =
             F.start (repeat 5 wide)
               [ dummy ~hp:5 ~gold:3 (); dummy ~hp:5 ~gold:4 () ]
             |> F.play 1
           in
           result_eq (won 80 7) (F.result t) );
         ( "defeat gives 0 HP and no gold" >:: fun _ ->
           let t =
             F.start ~hp:5 (repeat 5 strike) [ dummy () ] |> F.next_turn
           in
           result_eq lost (F.result t);
           int_eq 0 (F.hp t);
           rejected ~mentions:"over"
             (F.play_card t ~hand_index:1 ~target_index:(Some 1));
           rejected ~mentions:"over" (F.end_turn t) );
       ]

(* ---------- determinism and immutability ---------- *)

let distinct =
  List.init 7 (fun i -> card ~cost:0 (Printf.sprintf "c%d" i) [ Gain_block 1 ])

let determinism_tests =
  "determinism"
  >::: [
         ( "the same seed gives the same fight" >:: fun _ ->
           let a = F.start ~seed:42 distinct [ dummy () ] in
           let b = F.start ~seed:42 distinct [ dummy () ] in
           ids_eq (F.hand_ids a) (F.hand_ids b);
           ids_eq (F.hand_ids (F.next_turn a)) (F.hand_ids (F.next_turn b)) );
         ( "operations never change their argument" >:: fun _ ->
           let t = F.start ~seed:7 distinct [ dummy () ] in
           let before = F.view t in
           let a = F.next_turn t in
           let b = F.next_turn t in
           ids_eq (F.hand_ids a) (F.hand_ids b);
           assert_equal before (F.view t);
           ignore (F.play 1 t);
           assert_equal before (F.view t) );
         ( "a failed command leaves the fight as it was" >:: fun _ ->
           let t = F.start (repeat 5 bash) [ dummy () ] |> F.play ~target:1 1 in
           let before = F.view t in
           ignore (F.play_card t ~hand_index:1 ~target_index:(Some 1));
           ignore (F.play_card t ~hand_index:9 ~target_index:None);
           assert_equal before (F.view t) );
       ]

(* ---------- real Status and Enemy_ai ---------- *)

let training_slime =
  {
    enemy_id = "training_slime";
    enemy_name = "Training Slime";
    enemy_max_hp = 30;
    enemy_gold = 5;
    enemy_behavior = Cycle [ attack 5; defend_i 3 ];
  }

let integration_tests =
  "with real Status and Enemy_ai"
  >::: [
         ( "Training Slime alternates Attack 5 and Defend 3" >:: fun _ ->
           let t = Real.start starter [ training_slime ] in
           let label t = (Real.foe 1 t).ce_intent.intent_label in
           str_eq "Attack 5" (label t);
           let t = Real.next_turn t in
           int_eq 75 (Real.hp t);
           str_eq "Defend 3" (label t);
           let t = Real.next_turn t in
           int_eq 75 (Real.hp t);
           int_eq 3 (Real.foe 1 t).ce_block;
           str_eq "Attack 5" (label t) );
       ]

let () =
  run_test_tt_main
    ("Combat"
    >::: [
           init_tests;
           play_tests;
           end_turn_tests;
           result_tests;
           determinism_tests;
           integration_tests;
         ])
