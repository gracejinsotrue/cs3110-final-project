open Types

(** Returned when a behavior has no intent to offer (e.g. an empty list). *)
let wait = { intent_label = "Wait"; intent_actions = [] }

(** [cycle intents turn] is element [turn mod length], or [wait] if empty. *)
let cycle intents turn =
  match intents with
  | [] -> wait
  | _ -> List.nth intents (turn mod List.length intents)

(** [below_pct view pct] is whether HP is strictly below [pct]% of max HP.
    Uses integer arithmetic so there is no rounding. *)
let below_pct view pct = view.ev_hp * 100 < pct * view.ev_max_hp

let next_intent rng def view =
  match def.enemy_behavior with
  | Cycle intents -> cycle intents view.ev_turn
  | Defend_below (pct, defend, normal) ->
      if below_pct view pct then defend else cycle normal view.ev_turn
  | Phase_at (pct, high, low) ->
      if below_pct view pct then cycle low view.ev_turn
      else cycle high view.ev_turn
  | Random_choice [] -> wait
  | Random_choice intents ->
      List.nth intents (Random.State.int rng (List.length intents))
