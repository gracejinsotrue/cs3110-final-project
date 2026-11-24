(** The combat engine: one fight between the player and one or more enemies.

    [Combat.Make (Status) (Enemy_ai)] builds the engine from the status
    arithmetic and the enemy AI (see [Sigs]). Combat owns the {i order} of
    events; [S] owns the arithmetic and [AI] chooses intents.

    {2 Numbering}
    Hand numbers and enemy numbers are the 1-based numbers the player types and
    sees in {!view}. Main passes [Play (card, enemy)] straight through. Enemy
    numbers count {i living} enemies only, in display order, so they shift down
    when an earlier enemy dies.

    {2 Playing a card}
    [play_card] checks, in this order and before changing anything, that: the
    fight is not over; the hand number exists; the target is right; and the card
    is affordable. A card with any [Selected_enemy] effect needs a living enemy
    number. A card with none must {i not} be given one ([play 2 1] for Defend is
    an error, not a silent ignore). On success it removes the card from the
    hand, pays its cost, runs its effects in list order, and only then puts it
    on the discard pile, so a card's own [Draw] can never draw it again. If the
    selected enemy dies partway through a card, the card's remaining effects on
    it do nothing; they never move on to another enemy.

    {2 Ending the turn}
    [end_turn] does, in order:
    + discard the rest of the hand;
    + tick the player's statuses ([S.tick]); poison damage goes straight to HP,
      ignoring block;
    + each living enemy, in display order: clear its block, run its {i shown}
      intent's actions in order, then tick its statuses and take its poison
      damage;
    + choose every living enemy's next intent ([AI.next_intent], with [ev_turn]
      = turns it has taken);
    + start the next player turn: clear the player's block, set energy to 3,
      draw 5 cards, and add 1 to the turn number.

    {2 Damage}
    Every hit (a card's [Deal] or an enemy's [Attack]) is: base damage, then
    [S.outgoing] with the attacker's statuses, then [S.incoming] with the
    defender's statuses, clamped at 0; block absorbs it first, then HP drops
    (never below 0). [Apply_status], [Inflict] and [Buff] go through [S.apply].

    {2 Piles}
    When a draw needs a card and the draw pile is empty, the discard pile is
    shuffled into a new draw pile. The hand is never shuffled back. If both
    piles are empty, the draw stops early. Cards are never lost or duplicated.

    {2 The end of the fight}
    The fight ends the moment every enemy is at 0 HP (a win) or the player is (a
    loss), even partway through a card or an enemy round. Nothing after that
    point runs. From then on {!result} is [Some _] and [play_card] and
    [end_turn] return [Error].

    {2 Randomness}
    [init] uses the given [Random.State.t] for the opening shuffle and first
    intents, and derives a private state from it for later shuffles and random
    intents. Values of [t] are immutable: an operation never changes its
    argument, so the same [t] and the same command always give the same result.
*)

module Make (S : Sigs.STATUS) (AI : Sigs.ENEMY_AI) : sig
  type t
  (** A fight in progress or finished. *)

  val init :
    Random.State.t ->
    deck:Types.card_def list ->
    hp:int ->
    max_hp:int ->
    Types.enemy_def list ->
    (t, string) result
  (** [init rng ~deck ~hp ~max_hp enemies] starts a fight. It shuffles [deck]
      (repeats allowed) into the draw pile, picks each enemy's first intent with
      [ev_turn = 0], and starts player turn 1 (energy 3, block 0, a hand of up
      to 5 cards). Enemies start at full HP with no block or statuses, in the
      given display order. [Error] if [enemies] is empty, [max_hp <= 0], or [hp]
      is not in [1 .. max_hp]. *)

  val play_card :
    t -> hand_index:int -> target_index:int option -> (t, string) result
  (** [play_card t ~hand_index ~target_index] plays hand card [hand_index]
      (1-based) at living enemy [target_index] (1-based), if it needs one.
      [Error msg] leaves the fight unchanged, and [msg] says what was wrong and
      what to type instead. *)

  val end_turn : t -> (t, string) result
  (** [end_turn t] ends the player's turn and runs the enemy round, as described
      above. [Error] only if the fight is already over. *)

  val view : t -> Types.combat_view
  (** [view t] is everything the UI needs to draw the combat screen. Only living
      enemies are listed, numbered from 1. *)

  val result : t -> Types.combat_result option
  (** [result t] is [None] while the fight continues. On a win it is
      [Some { res_won = true; res_hp_left; res_gold }] where [res_gold] is the
      sum of every enemy's gold. On a loss it is
      [Some { res_won = false; res_hp_left = 0; res_gold = 0 }]. *)

  val fight_cards : t -> Types.card_def list
  (** [fight_cards t] is every card in this fight (hand, draw and discard
      piles), for the in-combat [deck] command. It is sorted by name so it does
      not reveal the draw order. *)
end
