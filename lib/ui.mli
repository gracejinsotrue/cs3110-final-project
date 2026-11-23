(** Text in and text out for the terminal game.

    [Ui] turns a typed line into a [Types.command] and turns game values into
    the text shown on screen. Nothing here reads input or prints: every function
    returns a string, so [Main] owns the I/O and tests can inspect the output
    directly.

    Every number shown to the player (hand cards, enemies, map choices, reward
    choices) is 1-based and is exactly the number the player types back.

    Written with AI assistance (Claude Code); see the PR description. *)

(** Which screen the player is on. [Main] uses it to pick the help text and to
    decide which commands are legal. *)
type screen =
  | Title  (** No run yet: start one or quit. *)
  | Map  (** Choosing the next node. *)
  | Combat  (** A fight is in progress. *)
  | Reward  (** Choosing a card after winning a fight. *)
  | Game_over  (** The run ended; the player may start another. *)

(** {1 Input} *)

val parse : string -> (Types.command, string) result
(** [parse line] reads one command. The command word is case-insensitive and any
    amount of space may separate words. Numbers must be plain digits, so
    ["play -1"] and ["play x"] are errors, but ["play 0"] parses and is left to
    [Combat] to reject with the valid range.

    Accepted forms: [new], [new <seed>], [load <file>], [play <card>],
    [play <card> <enemy>], [end], [choose <n>], [deck], [help], [quit]. For
    [load], everything after the command word (trimmed, case kept) is the file
    name.

    [Error msg] says what was wrong and shows the form to type instead. *)

val command_name : Types.command -> string
(** [command_name c] is the word the player types for [c], e.g. ["play"] for
    [Play _] and ["end"] for [End_turn]. *)

val not_available : screen -> Types.command -> string
(** [not_available s c] is the message shown when [c] parsed but is not legal on
    screen [s]. It names the command and points to [help]. *)

(** {1 Output} *)

val title : string
(** The banner and first prompt shown at startup. *)

val help : screen -> string
(** [help s] lists the commands legal on screen [s], one per line. *)

val render_statuses : Types.status_map -> string
(** [render_statuses m] is e.g. ["Strength 2, Vulnerable 1"], always in the
    order Strength, Weak, Vulnerable, Poison regardless of the order in [m]. The
    empty map is ["none"]. *)

val render_card : int -> Types.card_def -> string
(** [render_card n c] is one numbered line such as
    ["2. Bash (2 energy): Deal 8; apply 2 Vulnerable to one enemy"]. *)

val render_combat : Types.combat_view -> string
(** [render_combat v] is the whole combat screen: the turn number, each living
    enemy with its number, HP, block, statuses and intent, then the player's HP,
    block, energy and statuses, the numbered hand, and the pile sizes. *)

val render_enemy_turn :
  before:Types.combat_view -> after:Types.combat_view -> string
(** [render_enemy_turn ~before ~after] summarizes an [end] command: which intent
    each enemy in [before] carried out and how much HP the player lost between
    the two views. *)

val render_result : Types.combat_result -> string
(** [render_result r] announces a finished fight: victory with the gold earned,
    or defeat. *)

val render_run_over : Types.run_state -> string
(** [render_run_over r] closes a run that cannot continue: a win if [r] is
    [Won], a loss if it is [Lost], and otherwise a cleared map (no reachable
    node left). It shows the final HP, gold and deck size and offers a new run.
*)

val render_map :
  Types.content -> Types.run_state -> Types.map_node list -> string
(** [render_map c r choices] is the map screen: the player's HP, gold and deck
    size, every row of [r.run_map] (marking visited nodes and the current one),
    and [choices] numbered from 1. [choices] is normally
    [Run.available_nodes r]; [choose n] means its [n]th element. Enemy IDs are
    shown by their names in [c], or by ID if [c] does not have them. *)

val render_rewards : Types.card_def list -> string
(** [render_rewards cards] lists the offered cards numbered from 1 and tells the
    player to type [choose <n>]. *)

val render_deck : Types.card_def list -> string
(** [render_deck cards] lists a deck with copies grouped, e.g.
    ["5x Strike (1 energy): Deal 6 to one enemy"], in order of each card's first
    appearance, under a header giving the total count. *)
