(** Shared data shapes for Slay the Caml.

    This file is the team contract: every owner may construct and inspect
    these values. It contains only type definitions (no logic), so it needs
    no [.mli]. Changes after the freeze need a short proposal to all five
    owners (see TEAM_PLAN.md).

    Conventions used throughout:
    - Content IDs (cards, enemies) are lowercase, stable strings such as
      ["strike"] or ["training_slime"]. Saved data stores IDs, never records.
    - Every number the player sees or types (hand positions, enemy numbers,
      menu choices) is 1-based. Internal lists may be 0-based; conversion
      happens once, at the UI/Combat boundary.
    - HP, block, damage, energy and gold are non-negative integers.
    - Every record field starts with its record's prefix, so no two records
      share a field name and [x.ev_hp] always means an [enemy_view]:

      {v
      card_def           card_      enemy_def      enemy_
      intent             intent_    enemy_view     ev_
      combat_enemy_view  ce_        combat_view    cv_
      combat_result      res_       map_node       node_
      run_state          run_       content        content_
      v} *)

(** {1 Statuses} *)

(** Status effects in the MVP. Each one is either a {i stack count} or a
    {i turn duration}:
    - [Strength]: stacks. Added to each Attack/Deal hit the actor makes.
      Persists for the whole fight.
    - [Weak]: duration in turns. The actor's outgoing attack damage is
      multiplied by 0.75 (floored). Decreases by 1 at the end of the
      affected actor's turn.
    - [Vulnerable]: duration in turns. Incoming attack damage is multiplied
      by 1.5 (floored). Decreases by 1 at the end of the affected actor's
      turn.
    - [Poison]: stacks. After the affected actor acts, it loses HP equal to
      the stacks (ignoring block), then loses one stack. *)
type status =
  | Strength
  | Weak
  | Vulnerable
  | Poison

(** An actor's current statuses. Invariant (maintained by [Status]): each
    status appears at most once and every count is positive; a status that
    reaches 0 is removed. Order carries no meaning. *)
type status_map = (status * int) list

(** {1 Cards} *)

(** Who a card effect hits. *)
type target =
  | Self  (** The player. No enemy number is typed. *)
  | Selected_enemy
      (** The one living enemy the player names with [play <card> <enemy>].
          A card with any [Selected_enemy] effect needs a target before its
          energy is spent. *)
  | All_enemies  (** Each living enemy once, in displayed order. *)

(** One step of a card. A card's effects run in list order. *)
type card_effect =
  | Deal of target * int
      (** Attack the target for this much base damage, before Strength,
          Weak, Vulnerable and block. [Deal (Self, _)] is invalid content. *)
  | Gain_block of int  (** The player gains this much block. *)
  | Apply_status of target * status * int
      (** Add this many stacks/turns of the status to the target. *)
  | Draw of int  (** The player draws this many cards. *)
  | Gain_energy of int
      (** The player gains this much energy this turn. Energy may go above
          the turn's starting energy; it is not carried to the next turn. *)

(** A card definition, loaded from [data/cards.json]. *)
type card_def = {
  card_id : string;  (** Stable lowercase ID, e.g. ["strike"]. *)
  card_name : string;  (** Display name, e.g. ["Strike"]. *)
  card_cost : int;  (** Energy needed to play the card, >= 0. *)
  card_description : string;
      (** Player-facing text, e.g. ["Deal 6 to one enemy"]. *)
  card_effects : card_effect list;  (** Non-empty; run in this order. *)
}

(** {1 Enemies} *)

(** One step of an enemy's turn. *)
type enemy_action =
  | Attack of int
      (** Hit the player for this much base damage, before statuses and
          block. *)
  | Defend of int  (** The enemy gains this much block. *)
  | Inflict of status * int
      (** Give the {i player} this many stacks/turns of the status. *)
  | Buff of status * int
      (** Give the {i acting enemy itself} this many stacks/turns of the
          status, e.g. [Buff (Strength, 2)] for a boss powering up. *)

(** What an enemy will do on its next turn, shown to the player before it
    happens. *)
type intent = {
  intent_label : string;
      (** Player-facing summary, e.g. ["Attack 5"]. Never empty. *)
  intent_actions : enemy_action list;
      (** Run in this order on the enemy's turn. *)
}

(** How an enemy chooses its next intent. [Enemy_ai] interprets this; HP
    thresholds are whole-number percentages of max HP (0 to 100). *)
type behavior =
  | Cycle of intent list
      (** Repeat the list in order: the intent for enemy turn [n] is element
          [n mod length]. *)
  | Defend_below of int * intent * intent list
      (** [Defend_below (pct, defend, normal)]: while HP is below [pct]% of
          max HP, choose [defend]; otherwise [Cycle normal]. *)
  | Phase_at of int * intent list * intent list
      (** [Phase_at (pct, high, low)]: cycle [high] while HP is at least
          [pct]% of max HP, and cycle [low] once it drops below. *)
  | Random_choice of intent list
      (** Pick one uniformly using the supplied [Random.State.t]. *)

(** An enemy definition, loaded from [data/enemies.json]. *)
type enemy_def = {
  enemy_id : string;  (** Stable lowercase ID, e.g. ["training_slime"]. *)
  enemy_name : string;  (** Display name, e.g. ["Training Slime"]. *)
  enemy_max_hp : int;  (** Starting and maximum HP, > 0. *)
  enemy_gold : int;  (** Gold awarded once when the fight is won, >= 0. *)
  enemy_behavior : behavior;
      (** How it picks intents; must be able to yield an intent. *)
}

(** The live facts about one enemy that [Enemy_ai] may use to choose an
    intent. Combat builds this; the AI never sees Combat's private state. *)
type enemy_view = {
  ev_hp : int;  (** Current HP, 0 to [ev_max_hp]. *)
  ev_max_hp : int;  (** Maximum HP (same as the definition's). *)
  ev_block : int;  (** Current block. *)
  ev_turn : int;
      (** Number of turns this enemy has already taken in this fight. It is
          0 when its first intent is chosen at the start of the fight. *)
  ev_statuses : status_map;  (** The enemy's current statuses. *)
}

(** {1 Combat views and results} *)

(** One enemy as the combat screen shows it. *)
type combat_enemy_view = {
  ce_number : int;
      (** 1-based number the player types to target this enemy. Only living
          enemies are listed, numbered 1, 2, ... in display order. *)
  ce_name : string;  (** Display name. *)
  ce_hp : int;  (** Current HP. *)
  ce_max_hp : int;  (** Maximum HP. *)
  ce_block : int;  (** Current block. *)
  ce_statuses : status_map;  (** Current statuses. *)
  ce_intent : intent;  (** What it will do when the player ends the turn. *)
}

(** Everything the UI needs to draw one combat screen. This is render data
    only; it is a snapshot, not Combat's state. The cards in the piles are
    not listed here; [Combat.fight_cards] returns them for the [deck]
    command. *)
type combat_view = {
  cv_player_hp : int;  (** Current player HP. *)
  cv_player_max_hp : int;  (** Player max HP. *)
  cv_player_block : int;  (** Current player block. *)
  cv_player_statuses : status_map;  (** Current player statuses. *)
  cv_energy : int;  (** Energy left this turn (may exceed [cv_max_energy]). *)
  cv_max_energy : int;  (** Energy at the start of each turn (3 in the MVP). *)
  cv_turn : int;  (** Player turn number, 1 on the first turn. *)
  cv_hand : (int * card_def) list;
      (** The hand in order, paired with 1-based hand numbers. *)
  cv_draw_count : int;  (** Cards in the draw pile. *)
  cv_discard_count : int;  (** Cards in the discard pile. *)
  cv_enemies : combat_enemy_view list;  (** Living enemies in display order. *)
}

(** How a finished fight ended. *)
type combat_result = {
  res_won : bool;  (** [true] if every enemy reached 0 HP. *)
  res_hp_left : int;  (** Player HP at the end (0 on a loss). *)
  res_gold : int;  (** Gold earned in this fight (0 on a loss). *)
}

(** {1 Commands} *)

(** A parsed player command. Which commands are legal depends on the
    current screen; [Main] decides and reports an error otherwise. *)
type command =
  | New of int option  (** [new [seed]]: start a run, optionally seeded. *)
  | Load of string  (** [load <file>]: load a save (arrives with saves). *)
  | Play of int * int option
      (** [play <card> [enemy]]: 1-based hand number, optional 1-based enemy
          number. *)
  | End_turn  (** [end]: end the player's turn. *)
  | Choose of int
      (** [choose <n>]: 1-based choice; the screen decides whether it is a
          map node or a reward card. *)
  | Show_deck  (** [deck]: run deck on the map; the fight's cards in combat. *)
  | Help  (** [help]: list commands valid on this screen. *)
  | Quit  (** [quit]: leave the game. *)

(** {1 Map and run} *)

(** What happens at a map node. The string is an enemy ID in [content]. *)
type node_kind =
  | Fight of string  (** An ordinary fight against this enemy. *)
  | Elite of string  (** An optional harder fight against this enemy. *)
  | Rest  (** Heal ceil(30% of max HP), capped at max HP. *)
  | Boss of string  (** The final fight; winning it wins the run. *)

(** One node on the map. *)
type map_node = {
  node_id : int;  (** Unique node ID within this map. *)
  node_kind : node_kind;  (** What happens here. *)
  node_row : int;  (** Row on the map, 1 = first row. Edges go to higher rows. *)
  node_next : int list;  (** IDs of nodes reachable from this one. *)
}

(** Where the run is between screens. Typical flow:
    [On_map] -> (enter a Fight/Elite/Boss node) [Fighting id] ->
    win: [Reward_pending ids] -> (choose a card) [On_map];
    boss win: [Won]; loss: [Lost]. Entering a Rest node heals and stays
    [On_map]. *)
type run_phase =
  | On_map  (** Waiting for the player to choose a reachable node. *)
  | Fighting of string
      (** A fight against this enemy ID is in progress at [run_current_node].
          [Run.after_combat] is legal only here. Saves are refused here. *)
  | Reward_pending of string list
      (** After a non-boss win: the offered card IDs, stored so a save here
          restores the exact same offer. *)
  | Won  (** The boss was defeated. *)
  | Lost  (** The player reached 0 HP. *)

(** Everything needed to continue (and save) a run outside of combat. *)
type run_state = {
  run_seed : int;  (** The run's seed; all randomness derives from it. *)
  run_map : map_node list;  (** The whole map. *)
  run_current_node : int option;
      (** ID of the last node entered, or [None] before the first choice. *)
  run_visited : int list;  (** IDs of nodes entered so far, oldest first. *)
  run_deck : string list;
      (** The permanent run deck as card IDs, with repeats, e.g. five
          ["strike"]s. *)
  run_hp : int;  (** Current player HP. *)
  run_max_hp : int;  (** Player max HP. *)
  run_gold : int;  (** Gold held. *)
  run_next_encounter : int;
      (** Progression counter: how many nodes have been entered. Combined
          with [run_seed] to create each node's random stream, so a reloaded
          run makes the same future choices. *)
  run_phase : run_phase;  (** What the run is waiting for. *)
}

(** {1 Content} *)

(** All loaded definitions. [Loader] builds this from JSON; other modules
    receive it as an argument and never read files themselves. *)
type content = {
  content_cards : card_def list;  (** Every card, with unique IDs. *)
  content_enemies : enemy_def list;  (** Every enemy, with unique IDs. *)
  content_reward_pool : string list; (** Card IDs eligible for rewards. *)
}
