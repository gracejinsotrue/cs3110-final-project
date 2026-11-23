(** Behavior contracts used by [Combat].

    [Combat.Make (Status) (Enemy_ai)] is written against these signatures,
    so Combat can be tested with fake modules and the real [Status] and
    [Enemy_ai] must match them exactly.

    Division of responsibility: Combat owns the {i ordering} (when each
    function is called); Status owns the {i arithmetic}; Enemy_ai owns
    choosing intents. None of these functions raises on valid input. *)

(** Status arithmetic. All functions are pure.

    Damage order for one hit (Combat calls these in this order):
    + base damage of the [Deal] or [Attack]
    + [outgoing attacker_statuses] (Strength, then Weak)
    + [incoming defender_statuses] (Vulnerable)
    + clamp at 0, subtract the defender's block, then reduce HP.

    Turn timing: after an actor finishes acting (the player when they end
    the turn; each enemy right after its own intent), Combat calls [tick]
    on that actor's statuses and applies the returned poison damage
    directly to HP, ignoring block. *)
module type STATUS = sig
  val apply : Types.status -> int -> Types.status_map -> Types.status_map
  (** [apply s n m] adds [n] stacks/turns of [s] to [m]. Stacking is
      additive for every status (Weak 2 then Weak 1 gives Weak 3). If
      [n <= 0], returns [m] unchanged. The result satisfies the
      [status_map] invariant. *)

  val tick : Types.status_map -> Types.status_map * int
  (** [tick m] is the end-of-action update for one actor. Returns
      [(m', poison_damage)] where [poison_damage] is the actor's Poison
      stacks before the tick (0 if none), and [m'] has Poison, Weak and
      Vulnerable each reduced by 1 and zero entries removed. Strength is
      unchanged. *)

  val outgoing : Types.status_map -> int -> int
  (** [outgoing attacker dmg] is [dmg] after the attacker's statuses: add
      Strength, then if Weak, [floor (x * 0.75)]. Result is at least 0. *)

  val incoming : Types.status_map -> int -> int
  (** [incoming defender dmg] is [dmg] after the defender's statuses: if
      Vulnerable, [floor (x * 1.5)]. Result is at least 0. Block is applied
      afterwards by Combat. *)
end

(** Enemy intent selection. *)
module type ENEMY_AI = sig
  val next_intent :
    Random.State.t -> Types.enemy_def -> Types.enemy_view -> Types.intent
  (** [next_intent rng def view] is the intent the enemy will show next.
      It may use only [def], [view] and [rng] (no hidden global state);
      only [Random_choice] should draw from [rng]. Combat calls it once
      per living enemy at the start of the fight ([view.turn = 0]) and
      again after each enemy round finishes (with [view.turn] counting the
      turns already taken). The returned intent has a non-empty [label].
      [Validate] guarantees every behavior can produce an intent; if one
      cannot (e.g. an empty list), the result is
      [{ label = "Wait"; actions = [] }] rather than an exception. *)
end
