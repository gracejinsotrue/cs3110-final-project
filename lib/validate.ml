open Types

(* ---------- Thresholds ---------- *)

let energy_per_turn = 3
let free_card_damage_limit = 6
let big_card_damage = 30
let big_enemy_attack = 30
let big_gold = 100

(* ---------- Helpers ---------- *)

let sprintf = Printf.sprintf

let string_of_status = function
  | Strength -> "Strength"
  | Weak -> "Weak"
  | Vulnerable -> "Vulnerable"
  | Poison -> "Poison"

let valid_id id =
  id <> ""
  && (match id.[0] with 'a' .. 'z' -> true | _ -> false)
  && String.for_all
       (function 'a' .. 'z' | '0' .. '9' | '_' -> true | _ -> false)
       id

let check_id what id =
  if valid_id id then []
  else
    [
      sprintf
        "%s %S: ID must be lowercase letters, digits and '_', starting with a \
         letter"
        what id;
    ]

let duplicates ids =
  let rec go seen reported = function
    | [] -> List.rev reported
    | id :: rest ->
        if List.mem id seen && not (List.mem id reported) then
          go seen (id :: reported) rest
        else go (id :: seen) reported rest
  in
  go [] [] ids

let check_duplicates what ids =
  List.map
    (fun id -> sprintf "duplicate %s ID %S (IDs must be unique)" what id)
    (duplicates ids)

let non_negative where what n =
  if n >= 0 then [] else [ sprintf "%s: %s is %d; must be 0 or more" where what n ]

let positive where what n =
  if n > 0 then [] else [ sprintf "%s: %s is %d; must be at least 1" where what n ]

let non_empty where what s =
  if String.trim s <> "" then [] else [ sprintf "%s: %s is empty" where what ]

let concat_mapi f l = List.concat (List.mapi f l)

(* ---------- Cards ---------- *)

let effect_errors where i e =
  let where = sprintf "%s: effects[%d]" where i in
  match e with
  | Deal (Self, _) ->
      [ sprintf "%s: deal cannot target self (use an enemy target)" where ]
  | Deal (_, n) -> non_negative where "damage" n
  | Gain_block n -> non_negative where "block" n
  | Apply_status (_, s, n) ->
      positive where (string_of_status s ^ " amount") n
  | Draw n -> non_negative where "draw amount" n
  | Gain_energy n -> non_negative where "energy amount" n

let card_errors (c : card_def) =
  let where = sprintf "card %S" c.card_id in
  List.concat
    [
      check_id "card" c.card_id;
      non_empty where "name" c.card_name;
      non_empty where "description" c.card_description;
      non_negative where "cost" c.card_cost;
      (if c.card_effects = [] then [ where ^ ": has no effects" ] else []);
      concat_mapi (effect_errors where) c.card_effects;
    ]

(* ---------- Enemies ---------- *)

let action_errors where i a =
  let where = sprintf "%s.actions[%d]" where i in
  match a with
  | Attack n -> non_negative where "attack damage" n
  | Defend n -> non_negative where "block" n
  | Inflict (s, n) | Buff (s, n) ->
      positive where (string_of_status s ^ " amount") n

let intent_errors where (it : intent) =
  non_empty where "label" it.intent_label
  @ concat_mapi (action_errors where) it.intent_actions

let intent_list_errors where name intents =
  let where = sprintf "%s.%s" where name in
  if intents = [] then
    [ sprintf "%s: is empty, so the enemy could not choose an intent" where ]
  else concat_mapi (fun i it -> intent_errors (sprintf "%s[%d]" where i) it) intents

let pct_errors where pct =
  if pct >= 0 && pct <= 100 then []
  else [ sprintf "%s: pct is %d; must be between 0 and 100" where pct ]

let behavior_errors where = function
  | Cycle l -> intent_list_errors where "intents" l
  | Random_choice l -> intent_list_errors where "intents" l
  | Defend_below (pct, d, normal) ->
      pct_errors where pct
      @ intent_errors (where ^ ".defend") d
      @ intent_list_errors where "normal" normal
  | Phase_at (pct, high, low) ->
      pct_errors where pct
      @ intent_list_errors where "high" high
      @ intent_list_errors where "low" low

let enemy_errors (e : enemy_def) =
  let where = sprintf "enemy %S" e.enemy_id in
  List.concat
    [
      check_id "enemy" e.enemy_id;
      non_empty where "name" e.enemy_name;
      positive where "max_hp" e.enemy_max_hp;
      non_negative where "gold" e.enemy_gold;
      behavior_errors (where ^ ": behavior") e.enemy_behavior;
    ]

(* ---------- Entry points ---------- *)

let content (c : content) =
  let errors =
    List.concat
      [
        check_duplicates "card" (List.map (fun c -> c.card_id) c.content_cards);
        check_duplicates "enemy"
          (List.map (fun e -> e.enemy_id) c.content_enemies);
        List.concat_map card_errors c.content_cards;
        List.concat_map enemy_errors c.content_enemies;
      ]
  in
  if errors = [] then Ok () else Error errors

(* ---------- Warnings ---------- *)

let card_damage (c : card_def) =
  List.fold_left
    (fun acc -> function Deal (_, n) -> acc + n | _ -> acc)
    0 c.card_effects

let gains_energy (c : card_def) =
  List.exists (function Gain_energy _ -> true | _ -> false) c.card_effects

let card_warnings (c : card_def) =
  let where = sprintf "card %S" c.card_id in
  let dmg = card_damage c in
  let free_big =
    if c.card_cost = 0 && dmg > free_card_damage_limit then
      [
        sprintf "%s: costs 0 but deals %d damage (more than %d)" where dmg
          free_card_damage_limit;
      ]
    else []
  in
  let expensive =
    if c.card_cost > energy_per_turn && not (gains_energy c) then
      [
        sprintf "%s: costs %d, more than the %d energy a turn gives" where
          c.card_cost energy_per_turn;
      ]
    else []
  in
  let big =
    if dmg > big_card_damage then
      [ sprintf "%s: deals %d damage in total, which is unusually high" where dmg ]
    else []
  in
  let odd_status =
    List.filter_map
      (function
        | Apply_status (Self, ((Weak | Vulnerable | Poison) as s), _) ->
            Some (sprintf "%s: applies %s to the player" where (string_of_status s))
        | Apply_status ((Selected_enemy | All_enemies), Strength, _) ->
            Some (sprintf "%s: gives Strength to an enemy" where)
        | _ -> None)
      c.card_effects
  in
  List.concat [ free_big; expensive; big; odd_status ]

let behavior_intents = function
  | Cycle l | Random_choice l -> l
  | Defend_below (_, d, normal) -> d :: normal
  | Phase_at (_, high, low) -> high @ low

let enemy_warnings (e : enemy_def) =
  let where = sprintf "enemy %S" e.enemy_id in
  let actions =
    List.concat_map (fun it -> it.intent_actions) (behavior_intents e.enemy_behavior)
  in
  let attacks = List.filter_map (function Attack n -> Some n | _ -> None) actions in
  let no_attack =
    if attacks = [] then [ where ^ ": never attacks (no attack in its behavior)" ]
    else []
  in
  let big_attack =
    match List.filter (fun n -> n > big_enemy_attack) attacks with
    | [] -> []
    | n :: _ ->
        [ sprintf "%s: has an attack of %d, which is unusually high" where n ]
  in
  let gold =
    if e.enemy_gold > big_gold then
      [ sprintf "%s: gives %d gold, which is unusually high" where e.enemy_gold ]
    else []
  in
  let pct =
    match e.enemy_behavior with
    | Defend_below (0, _, _) -> [ where ^ ": defend_below at 0% never defends" ]
    | Phase_at (0, _, _) -> [ where ^ ": phase_at 0% never reaches its low phase" ]
    | _ -> []
  in
  List.concat [ no_attack; big_attack; gold; pct ]

let warnings (c : content) =
  List.concat_map card_warnings c.content_cards
  @ List.concat_map enemy_warnings c.content_enemies

(* ---------- References ---------- *)

let ids_known what known ids =
  match List.filter (fun id -> not (List.mem id known)) ids with
  | [] -> Ok ()
  | missing ->
      Error
        (List.map (fun id -> sprintf "unknown %s ID %S" what id)
           (List.sort_uniq compare missing))

let card_ids_known (c : content) ids =
  ids_known "card" (List.map (fun c -> c.card_id) c.content_cards) ids

let enemy_ids_known (c : content) ids =
  ids_known "enemy" (List.map (fun e -> e.enemy_id) c.content_enemies) ids
