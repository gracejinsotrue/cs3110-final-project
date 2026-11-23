(** Checking loaded content before the game uses it.

    [Loader] guarantees the content has the right shape; [Validate] checks
    that it makes sense. Every function is pure and works on
    [Types.content] values, so tests can build content by hand.

    Messages name the definition and the part of it that is wrong, e.g.
    [card "bash": cost is -1; must be 0 or more]. Paths inside a
    definition (such as [effects[1]]) count from 0, matching the JSON. *)

val content : Types.content -> (unit, string list) result
(** [content c] is [Ok ()] if [c] is safe to play, or [Error msgs] with
    one message per problem. Hard errors are:
    - an ID that is empty, not lowercase [a-z0-9_] starting with a
      letter, or used by two cards (or two enemies);
    - an empty name, card description or intent label;
    - a negative card cost, damage, block, draw, energy, enemy HP change
      or gold; a status amount of 0 or less; enemy max HP of 0 or less;
    - a card with no effects, or a [Deal (Self, _)] effect;
    - an enemy behavior with an empty intent list (it could not produce
      an intent), or an HP percentage outside 0 to 100. *)

val warnings : Types.content -> string list
(** [warnings c] lists balance and design problems that do not stop the
    game, e.g. a 0-cost card that deals more than 6 damage, a card that
    costs more than the 3 energy a turn gives, a card that weakens the
    player or strengthens an enemy, an enemy with no attack anywhere in
    its behavior, or unusually large damage or gold. It assumes [c]
    passed [content]; on invalid content the result is still defined but
    may be incomplete. *)

val card_ids_known : Types.content -> string list -> (unit, string list) result
(** [card_ids_known c ids] checks that every ID in [ids] is a card in [c].
    Use it for the starter deck, reward offers and saved decks. *)

val enemy_ids_known : Types.content -> string list -> (unit, string list) result
(** [enemy_ids_known c ids] checks that every ID in [ids] is an enemy in
    [c]. Use it for the enemies named by map nodes. *)
