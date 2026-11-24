# Slay the Caml: team plan

Team 20 Caml Slayers · CS 3110

This is the team's plan and division of labor: the game we are building, the
rules we agreed on, who owns each module, and the MS2 work breakdown. It
describes the work; it doesn't claim that any of it is finished. For what
actually works, see the MS2 report and `AUTHORS.md`.

**Sources of truth, in order:** the code (`lib/types.ml`, `lib/sigs.ml`, then
each owner's `.mli`), then `README.md` (rules, controls, content format,
agreed decisions), then this plan. If this plan and the code disagree, the code
wins. Tell the team about the mismatch so this file can be fixed.

## Contract status

`lib/types.ml` and `lib/sigs.ml` are **frozen** as of 2026-11-23, with all
five owners' approval. To change either file:

1. Write a proposal: the exact type or function change, every caller it
   affects, and one updated example.
2. All five owners review it.
3. Every caller is updated in the same integration pass.

## The game

Slay the Caml is a terminal deck builder in OCaml, in the style of *Slay the
Spire*. The player picks a route on a branching map, fights enemies with a
hand of cards while seeing each enemy's next move (its *intent*), improves the
deck after fights, rests, and beats a boss. It has one player, one or more
enemies per fight, cards and enemies defined in JSON, and saves between map
nodes. Libraries: Yojson for JSON and OUnit2 for tests, built with dune.

The repository is <https://github.com/gracejinsotrue/cs3110-final-project>.
Each person works on their own branch and opens a pull request against
`master` for team review.

## Team and ownership

| Person | NetID | Primary area | Backup owner |
| --- | --- | --- | --- |
| Nicholas (Nick) Lennon | ncl46 | Combat engine | Yuan |
| Yuan Gao | yg626 | Status rules and enemy AI | Nick |
| Carter Chamberlain | cjc423 | Content, loading, validation, README | Grace |
| Kiyam Merali | km942 | Map, rewards, run progression, saves | Carter |
| Grace Jin | gsj33 | UI, input, integration (`bin/main.ml`), dune build, merging | Kiyam |

A backup owner learns the interface, reviews or contributes a test, and can
help connect the module. Being a backup doesn't transfer ownership.

## Ground rules

1. **Errors are values.** Expected bad input and illegal moves return
   `('a, string) result` and never raise. Parse and validation errors name
   the bad field or command.
2. **Numbering is 1-based for the player.** Every hand position, enemy
   number and menu choice the player sees or types starts at 1. Internal
   lists may count from 0; the conversion happens once, where the UI meets
   Combat.
3. **Randomness is explicit.** Any function that shuffles, generates a map
   or reward, or picks an AI move takes a `Random.State.t`. There is no
   global `Random.self_init`. A saved run stores the seed and enough
   progression state to rebuild the next node's random stream.
4. **IDs are stable.** Content IDs are lowercase (`"strike"`,
   `"training_slime"`) and never change, even if display names do. Saved
   data stores IDs and resolves them against loaded content.
5. **Field prefixes.** Every record field starts with its record's prefix,
   so no two records share a field name (see the table under "Shared
   contract").
6. **Comments.** Every variant and record field in a shared type has a
   short comment giving its meaning and units.
7. **Pure libraries; I/O only in Main.** Renderers return strings and never
   print, read input or change game state. Only `bin/main.ml` does I/O.
8. **Stay in your own files.** Helper types and functions stay out of the
   `.mli` unless another owner needs them.
9. **Original content.** Use our own names, art and text. Don't copy assets
   from the real game.
10. **Acknowledge AI use.** Follow the AI rules in `TeamContract.md`:
    disclose AI help in the pull request, in a comment in each affected file,
    and in `AUTHORS.md`.

## What the player sees and does

The first release is a text interface. Grace owns the rendering, and the
other modules supply the data. Every screen starts with a one-line location
and ends with the commands available there. The game never asks the player
to type an internal card or enemy ID.

```
TITLE:   new [seed] | help | quit        (load <file> arrives with saves)
  -> MAP: HP / max HP, gold, numbered reachable nodes, visited route, deck
       choose <node>  -> FIGHT / ELITE / BOSS
                      -> REST: heal, then back to MAP
  -> FIGHT: enemies and their next intents; player HP, block, statuses,
       energy, draw/discard counts, numbered hand
       play <card> [enemy] | end | deck | help
       win (non-boss) -> REWARD: numbered card offers, choose <n>, then MAP
       boss win -> VICTORY          player HP <= 0 -> DEFEAT
```

Example combat screen (illustrative numbers; the real screen is drawn from a
`combat_view`):

```
FIGHT - Turn 2                HP 63/80 | Block 8 | Energy 2/3
Statuses: Strength 1          Draw 4 | Discard 6

Enemies
 1. Training Slime   HP 18/30   Block 0   Intent: Attack 5
 2. Guard            HP 22/22   Block 3   Intent: Defend 4

Hand
 1. Strike   [1]  Deal 6 to one enemy
 2. Defend   [1]  Gain 5 block
 3. Bash     [2]  Deal 8; apply 2 Vulnerable to one enemy

Commands: play 1 2 | play 2 | end | deck | help
```

- `play 1 2` means hand card 1 on enemy 2. Both numbers are positions, not IDs.
- `play 2` is valid only for a card with no single-enemy effect. Combat
  enforces this.
- An invalid command leaves the screen and all game state unchanged and
  explains what was wrong.
- `choose N` picks a map node or a reward card, depending on the screen.
- `deck` shows the permanent run deck on the map and the current fight's
  cards in combat.
- `help` lists only the commands valid on the current screen.

## MVP rules

These are the agreed rules. `README.md` records them for players, along with
the decisions settled during MS2.

| Rule | MVP choice |
| --- | --- |
| Start | 80/80 HP, 0 gold, and a deck of 5 Strike, 4 Defend and 1 Bash. Cards are defined in JSON; the run deck stores their IDs, repeats included. |
| Turn | At the start of each player turn, the player's old block is removed, energy is set to 3, and the player draws up to 5 cards. The deck is shuffled before the first hand. Playing a card spends its cost and applies its effects in the order listed. |
| Piles | Played cards go to the discard pile after all their effects resolve. At the end of the turn, the rest of the hand is discarded. If a draw needs cards and the draw pile is empty, the discard pile is shuffled into a new draw pile. Cards still in hand or already drawn are never shuffled. No card is ever lost or duplicated. |
| Targets | `Selected_enemy` needs a living, numbered enemy. `Self` takes no enemy number. `All_enemies` hits each living enemy once, in display order. A card with any selected-enemy effect needs its target checked **before** energy is spent. |
| Damage | Add the attacker's Strength, apply Weak as `floor(dmg * 0.75)`, then the defender's Vulnerable as `floor(dmg * 1.5)`. Clamp at 0, let block absorb what it can, and take the rest from HP. Poison ignores block. |
| Statuses | Strength and Poison are **stacks**; Weak and Vulnerable are **turn durations**. Strength lasts the whole fight. Poison: after the affected actor acts, it loses HP equal to its stacks, then loses one stack. Weak and Vulnerable drop by 1 at the end of the affected actor's turn. Entries that reach zero are removed. Stacking is additive. |
| Enemy round | After the player ends the turn, each living enemy carries out its **shown** intent, in display order. Each enemy's old block is cleared just before it acts, and its statuses tick right after. Processing stops as soon as the player's HP hits 0. Next intents are computed and shown only after the whole round. |
| Victory | The fight ends as soon as every enemy is at 0 HP. The player keeps their current HP and gets the encounter's gold once. At 0 player HP the run is lost, with no reward. A boss win ends the run as won. |
| Map (full MVP) | Five rows of forward-only nodes: ordinary fights early, an optional elite in the middle, a rest node in row 4 that is always reachable, and one boss in row 5. Only the current node's outgoing edges can be chosen. |
| Rewards and rest | After a non-boss win, offer up to three distinct cards from the reward pool; `choose N` adds one to the run deck. If the pool has fewer than three cards, offer them all. Rest heals `ceil(max_hp * 0.30)`, capped at max HP, and returns to the map. |
| Save | Save only on the map and reward screens, never in combat. A loaded save must reproduce the same reward offer and the same later seeded choices. |

The displayed max energy stays 3, even when a card grants extra energy for
the turn. Shops, relics, potions, events, card upgrades and map graphics are
out of scope for the first content set.

## Content

Starter content, the first JSON fixture every owner builds against:

- `strike`: cost 1, `Deal (Selected_enemy, 6)`
- `defend`: cost 1, `Gain_block 5`
- `bash`: cost 2, `Deal (Selected_enemy, 8)`, then
  `Apply_status (Selected_enemy, Vulnerable, 2)`
- `training_slime`: 30 HP, 5 gold, `Cycle [Attack 5; Defend 3]`
- a top-level `reward_pool` listing several **non-starter** cards, so the
  MS2 reward is a real choice.

For the full MVP: at least 8 player cards, 3 ordinary enemy patterns, 1 elite
and 1 boss. Yuan designs the enemy patterns and their counterplay, and Carter
stores them in JSON. The boss should telegraph a strong turn and have a
readable defensive or recovery turn.

## Project layout

```
TEAM_PLAN.md                 this plan and the MS2 work breakdown
README.md                    build and run, rules, controls, content format, agreed decisions
AUTHORS.md                   team members, plus source and AI acknowledgements
TeamContract.md              communication, review and AI-use agreement
dune-project, */dune         build configuration
lib/types.ml  lib/sigs.ml    shared contract, agreed by all five (frozen)
lib/combat.*                 Nick
lib/status.*  lib/enemy_ai.* Yuan
lib/loader.*  lib/validate.* Carter
lib/map.*  lib/rewards.*     Kiyam
lib/run.*  lib/save.*        Kiyam (save arrives in MS3)
lib/ui.*                     Grace
bin/main.ml                  Grace: the only module that wires everything together and does I/O
data/cards.json              Carter: card definitions and reward pool
data/enemies.json            Carter: enemy definitions
test/*_test.ml, test/fixtures/   tests next to each owner's area
```

A module that isn't built yet may be left out, as long as its interface is
described here or in a real `.mli`. Don't add empty placeholder modules.

## Shared contract

`lib/types.ml` holds only data types that more than one owner needs to build
or inspect. `lib/sigs.ml` holds only the two module types Combat is
parameterized by. Compile order: `Types`, then `Sigs`, then the owner
modules, then `bin/main.ml`, which instantiates
`Combat.Make (Status) (Enemy_ai)`. Read the files themselves for every field
and its comment.

| Type | Contents | Used by |
| --- | --- | --- |
| `status`, `status_map` | Strength, Weak, Vulnerable, Poison; `(status * int) list` with unique statuses and positive counts | Combat, Status, AI, Loader, UI |
| `target`, `card_effect`, `card_def` | Self / selected enemy / all enemies; deal, block, apply status, draw, energy; stable ID, name, cost, description, ordered effects | Combat, Loader, Rewards, UI |
| `enemy_action`, `intent`, `behavior`, `enemy_def`, `enemy_view` | Attack, defend, inflict (on the player), buff (on itself); a labeled intent; cycle, defend-below, phase-at, random choice; stable ID, name, max HP, gold, behavior; HP, block, turn and statuses as the AI sees them | Combat, AI, Loader, UI |
| `combat_enemy_view`, `combat_view`, `combat_result` | Render-ready player and enemy state, numbered hand, pile counts and intents; won/lost, HP left, gold earned | Combat, UI, Run |
| `command` | `New`, `Load`, `Play`, `End_turn`, `Choose`, `Show_deck`, `Help`, `Quit` | UI, Main |
| `node_kind`, `map_node` | Fight / Elite / Rest / Boss (with enemy IDs); ID, kind, row, outgoing node IDs | Map, Run, Save, UI |
| `run_phase`, `run_state` | On map / fighting / reward pending / won / lost; seed, map, position, visited nodes, deck IDs, HP, gold, encounter counter, phase | Run, Save, Main, UI |
| `content` | Loaded cards, enemies and reward pool IDs | Loader, Validate, Main |

**Field prefixes:**

| Record | Prefix | Record | Prefix |
| --- | --- | --- | --- |
| `card_def` | `card_` | `enemy_def` | `enemy_` |
| `intent` | `intent_` | `enemy_view` | `ev_` |
| `combat_enemy_view` | `ce_` | `combat_view` | `cv_` |
| `combat_result` | `res_` | `map_node` | `node_` |
| `run_state` | `run_` | `content` | `content_` |

**Run phases:** `On_map` → enter a Fight, Elite or Boss node → `Fighting
enemy_id` → a win moves to `Reward_pending ids` → `choose` → back to `On_map`.
A boss win moves to `Won`, and a loss to `Lost`, with no gold. Entering a Rest
node heals and stays `On_map`. `Run.after_combat` is legal only in
`Fighting`, and saving is refused in `Fighting`. For MS2 every node holds one
enemy; multi-enemy encounters need an agreed encounter definition, through
the change process above.

**Status and AI semantics** (written out in `lib/sigs.ml`):

- `apply s n m` adds `n` (additive for every status) and ignores `n <= 0`.
  The result stays normalized.
- `tick m` returns `(m', poison_damage)`. `poison_damage` is the Poison
  stacks from before the tick (0 if none). `m'` has Poison, Weak and
  Vulnerable each lowered by 1, zero entries removed, and Strength
  unchanged.
- `outgoing` adds Strength, then applies Weak. `incoming` applies Vulnerable.
  Both results are at least 0. Combat subtracts block afterwards.
- `next_intent rng def view` uses only its three arguments. Only
  `Random_choice` draws from `rng`. `ev_turn` counts turns already taken, so
  the first intent is chosen with `ev_turn = 0`. If a behavior can't produce
  an intent, it returns `{ intent_label = "Wait"; intent_actions = [] }`
  instead of raising.
- `Defend_below (pct, defend, normal)`: while HP is below `pct`% of max HP,
  always use `defend`; otherwise cycle through `normal`.
- **Timing:** Combat owns the order, and Status owns the arithmetic. Each
  hit goes base damage → `outgoing` → `incoming` → clamp → block → HP. After
  an actor finishes acting (the player on `end`; each enemy right after its
  own intent), Combat calls `tick` and takes the poison damage straight
  from HP. `Inflict` and `Buff` go through `apply`, not the damage pipeline.

### Changes from the plan's first type sketch

The first sketch of `types.ml` used unprefixed fields such as `id`, `hp` and
`gold`. These changes went in before the freeze:

1. **Field prefixes on every record** (table above). Without them, OCaml can
   pick the wrong record for a shared field name.
2. **`cv_max_energy`** on `combat_view`, so the UI can show "Energy 2/3".
3. **`Fighting of string`**, a run phase holding the enemy ID.
   `Run.after_combat` is legal only there, and saving is refused there.
4. **`Buff of status * int`**, an enemy action that gives the status to the
   acting enemy itself. (`Inflict` targets the player.)
5. **`content_reward_pool : string list`**, read from a top-level
   `reward_pool` array in `cards.json`: the card IDs that may be offered as
   rewards.
6. **`Combat.fight_cards`** (in `combat.mli`) lists every card in the current
   fight, for the in-combat `deck` command, instead of adding the piles to
   `combat_view`.
7. **Semantics settled in comments:**
   - `ev_turn` counts turns already taken.
   - `cv_turn` starts at 1.
   - `cv_enemies` holds only living enemies, numbered 1 to n.
   - `tick` reports the Poison from before it lowers the count.
   - `apply` is additive and ignores `n <= 0`.
   - `next_intent` returns "Wait" instead of raising.

## Responsibilities

Each owner's `.mli` is the authoritative interface. The signatures below are
the ones the plan asked for.

### Nick: Combat engine (backup: Yuan)

- **Owns:** `lib/combat.ml`, `lib/combat.mli`, `test/combat_test.ml`.
- **Depends on:** only Types and Sigs.
- **Delivers:** `Combat.Make (Status : Sigs.STATUS) (AI : Sigs.ENEMY_AI)`
  with an abstract `type t`. Only `view` exposes a `Types.combat_view`.
  - An initializer that takes a `Random.State.t`, the player deck
    (`card_def list`), player HP, max HP and the enemy definitions. It builds
    the piles, shuffles, draws the first hand, sets energy and picks the
    first intents.
  - `play_card : t -> hand_index:int -> target_index:int option -> (t, string) result`
  - `end_turn : t -> (t, string) result`
  - `view : t -> Types.combat_view`
  - `result : t -> Types.combat_result option` (`None` while the fight goes on)
  - `fight_cards : t -> Types.card_def list` (hand, draw and discard piles)
- **Effect interpreter:** check the target and cost before changing any
  state, pay the cost, run the effects in order (damage, block, statuses,
  draw, energy), then move the played card to discard. Never lose or
  duplicate a card when reshuffling.
- **Turn cycle:** player actions → player end-of-turn tick → enemies act in
  display order (clear that enemy's block, act, tick) → new intents → block
  reset, energy refresh, draw. Check for the end of the fight throughout,
  and stop once it's over.
- **Tests:** a no-op STATUS and an ENEMY_AI that always attacks for 5.
  Cover:
  - Strike against 3 block deals 3;
  - unaffordable cards;
  - invalid hand and target numbers;
  - draw-pile exhaustion and reshuffle;
  - end-turn order;
  - victory and defeat.

  Assert only on `view` and `result`, never on private fields.
- **Order of work:** (1) the `.mli`, plus an init and view showing a hand and
  one enemy; (2) target and cost checks that return `Error` before changing
  state; (3) Strike and Defend, then Bash's ordered effects; (4)
  discard, reshuffle and the end-turn phases; (5) end-of-fight results and
  black-box tests. Send Grace a compiling `.mli` and one example
  `combat_view` early.

### Yuan: Status rules and enemy AI (backup: Nick)

- **Owns:** `lib/status.ml(i)`, `lib/enemy_ai.ml(i)`,
  `test/status_ai_test.ml`, and the enemy patterns and boss design (stored
  in JSON by Carter).
- **Depends on:** Types; implements Sigs.
- **Delivers:**
  - `Status : Sigs.STATUS`, which keeps maps normalized and documents the
    Strength/Weak/Vulnerable/Poison order.
  - `Enemy_ai : Sigs.ENEMY_AI`. Fixed patterns cycle by `ev_turn`.
    Conditional behavior uses only `enemy_def`, `enemy_view` and the given
    random state. Every intent has a player-facing label.
  - A README behavior table listing each enemy ID, its pattern or trigger,
    and the intended counterplay.
- **Tests:**
  - 10 damage into Vulnerable becomes 15;
  - the Strength and Weak order;
  - Poison damage and expiry;
  - a three-step pattern repeats;
  - an enemy at 40% HP picks Defend under "defend below 50%";
  - the same seed gives the same random intent sequence.
- **Order of work:** (1) the status formulas and durations in the README;
  (2) `apply`, `outgoing`, `incoming` and `tick` with hand-computed
  examples; (3) `Cycle` for the first enemy; (4) test the first three intents
  and connect with Nick; (5) conditional and random behaviors once the
  connected fight works.

### Carter: content, loading, validation, documentation (backup: Grace)

- **Owns:** `lib/loader.ml(i)`, `lib/validate.ml(i)`, `data/cards.json`,
  `data/enemies.json`, `README.md`, `test/content_test.ml`,
  `test/fixtures/`.
- **Depends on:** Types and Yojson.
- **Delivers:**
  - `Loader.load : string -> (Types.content, string list) result`. Each
    error gives the file plus the path to the bad field. It parses the
    top-level `reward_pool` into `content_reward_pool`.
  - `Validate.content : Types.content -> (unit, string list) result` and
    `Validate.warnings : Types.content -> string list`. Parsing and
    validation stay separate, so tests can build `content` directly.
  - **Hard errors:**
    - duplicate IDs, and missing IDs or names;
    - unknown status or behavior tags;
    - negative cost, damage or HP;
    - empty required patterns;
    - invalid target and effect combinations, such as `Deal (Self, _)`;
    - references to missing IDs, including `reward_pool` IDs that name no card;
    - enemies whose behavior can't produce a valid intent.
  - **Warnings**, which don't block launch:
    - a 0-cost card dealing more than 6 damage;
    - an enemy with no attack;
    - unusually high damage or reward values;
    - unused definitions;
    - a reward pool with fewer than 3 cards, or one that includes starter
      cards.
  - A small but complete playable content set, plus README instructions:
    build, tests, controls, rules, content format, and how to add a card or
    enemy.
- **Tests:**
  - minimal valid and invalid JSON fixtures;
  - exact, useful errors for an unknown status, a duplicate ID and a
    negative cost;
  - every real content file parses and passes validation;
  - a tiny fixture with one card and one enemy, for the other owners' tests.
- **Order of work:** (1) agree on the JSON tags with Yuan and publish a tiny
  valid fixture; (2) parse each field, with file and field errors; (3)
  validate IDs, values, patterns and references; (4) the first real cards and
  enemy, plus a malformed fixture; (5) the README, and only then more content.

### Kiyam: map, rewards, run progression, saves (backup: Carter)

- **Owns:** `lib/map.ml(i)`, `lib/rewards.ml(i)`, `lib/run.ml(i)`,
  `lib/save.ml(i)`, `test/run_test.ml`.
- **Depends on:** Types.
- **Delivers:**
  - `Map.generate : Random.State.t -> ... -> map_node list` and
    `Map.validate : map_node list -> (unit, string list) result`. The
    validator checks for reachable paths, legal edges, no early elites, and a
    rest before the boss.
  - `Rewards.generate : Random.State.t -> card_def list -> card_def list`.
    The pool is an argument, and the module never reads JSON. Main builds the
    pool from `content_reward_pool`. Offers are distinct, and a pool of fewer
    than three cards is offered in full.
  - `Run.new_run`, `Run.available_nodes`, `Run.enter_node`,
    `Run.after_combat`, `Run.choose_reward`, and end-of-run helpers.
    - `enter_node` rejects unreachable nodes. Fight, Elite and Boss nodes
      move to `Fighting enemy_id`. Rest heals `ceil(30% of max HP)`, capped,
      and stays `On_map`. It updates the current node, the visited list and
      the encounter counter.
    - `after_combat : run_state -> combat_result -> reward_ids:string list -> (run_state, string) result`
      is legal only in `Fighting` and never calls Combat. A normal win moves
      to `Reward_pending reward_ids`, a boss win to `Won`, and a loss to
      `Lost` with no gold.
    - `choose_reward` checks that the choice is legal, adds the card ID to
      the run deck, and returns to `On_map`.
  - `Save.write` / `Save.read` (MS3): a versioned, human-readable format.
    Saving is allowed only in `On_map` or `Reward_pending`. A version
    mismatch or unknown card ID is rejected with a clear error. The save
    keeps the seed and progression state, so a reload gives the same future
    map and rewards.
- **Tests:**
  - the same seed gives the same map, and many seeds pass `Map.validate`;
  - rewards work with a 4-card pool written in the test;
  - invalid node moves and reward choices fail cleanly;
  - `after_combat` handles a win and a loss from hand-written results, and
    rejects calls outside `Fighting`;
  - a save and read round-trips the whole run state and future random
    choices.
- **Order of work:** (1) the start state and a one-fight map fixture; (2)
  `available_nodes` and `enter_node`, rejecting unreachable choices; (3)
  reward IDs from an explicit pool and seed; (4) `after_combat` and
  `choose_reward`; (5) generated routes and saves, once the MS2 path is
  playable. Give Grace a before-and-after example for every phase change.

### Grace: UI, input, integration (backup: Kiyam)

- **Owns:** `lib/ui.ml(i)`, `bin/main.ml`, `test/ui_test.ml`, the
  end-to-end smoke test, the dune build, and merging pull requests.
- **Depends on:** Types.
- **Delivers:**
  - `Ui.parse : string -> (Types.command, string) result`. It trims
    whitespace, and its errors show valid syntax: `play 2 1` gives
    `Play (2, Some 1)`, and `play x` is an error.
  - `Ui.render_combat` plus small renderers for the map, rewards, help,
    victory and defeat. One card-list renderer serves `deck` both on the map
    and in combat. Renderers return strings and never print, read input or
    change state.
  - `bin/main.ml`:
    - loads and validates content, and creates or loads a run;
    - builds the reward pool from `content_reward_pool`;
    - creates the combat for the chosen encounter;
    - loops render → read → parse → dispatch;
    - applies `Run.after_combat`, offers rewards, and saves at the agreed
      checkpoints.
  - A scripted smoke test: load real content, start a seeded run, enter a
    fight, play or end turns, resolve the result, choose a reward, and (from
    MS3) save and reload. It uses a scripted input source, not interactive
    stdin.
- **Tests:**
  - parsing valid and invalid commands (`play 2 1`, `play x`, missing or
    extra arguments);
  - a hand-written `combat_view` renders the enemy intent, numbered hand,
    energy and HP;
  - a hand-written map or reward view renders the choices;
  - one full seeded smoke path completes without exceptions.
- **Order of work:** (1) command examples for each screen, and pure renderers
  from hand-written views; (2) parse valid and invalid commands, with no
  state changes; (3) connect Main to the real JSON and show the map; (4)
  connect map choice, the fight loop, and the result and reward choice; (5)
  run a scripted path and a manual path, and keep the exact commands and
  output for the MS2 report.

### Everyone

- Pair agreements, recorded in the README:
  - Nick and Grace: hand and target numbering;
  - Yuan and Nick: turn numbering and status timing;
  - Carter and Yuan: JSON behavior tags;
  - Kiyam and Grace: phase transitions.
- Keep a short contribution log with the real code, test and doc paths and
  the results you saw, for the reports.

## Integration rhythm

| Checkpoint | Shared result |
| --- | --- |
| Day 1 | Rules, `types.ml`, `sigs.ml`, one tiny JSON fixture, and `dune build` all compile. |
| First handoff | Each owner provides a `.mli`, one sample value or fixture, and passing local tests. Main compiles against each handoff. |
| Midpoint | One fight with the real Status and AI and real loaded content; seeded map and rewards work; the UI renders the fight. |
| Final integration | The full path (start, map, combat, reward, save and load, boss win or defeat) works from the README commands. `dune build`, `dune test` and content validation all pass. |

Connect the pieces in this order: real JSON → combat with Status and AI → UI
fight loop → Run map and reward transitions → scripted smoke test. Run
`dune build` after each connection, and fix interface mismatches before
adding more content.

## MS2 target: one connected, playable slice

From a fresh checkout, the real terminal program supports this path:

1. Start a seeded run and show a tiny map with a reachable fight node. The
   map may be fixed, but the choice goes through `Run.enter_node`.
2. Enter the `training_slime` fight loaded from JSON. Show current HP,
   energy, the hand, enemy HP and the enemy's **visible next intent**.
3. `play 1 1` to attack, or `play 2` for a self-target card, when those cards
   are in those positions. An invalid hand number, target or cost leaves
   combat unchanged.
4. `end`: the shown intent happens, HP and block change, and a new hand and
   intent appear. Continue until victory or defeat.
5. On victory, show a deterministic card offer. Choosing one adds its ID to
   the run deck and returns to the map or a simple end-of-slice screen. On
   defeat, show a defeat screen.

The scripted smoke test uses the same dispatch functions and real content.
It may use a fixed seed, but it **must not assume a specific card is hand
number 1**: it reads the hand from the view and picks a legal command. One
fight and one reward are enough for MS2. The branching campaign, all the
content and a polished save system are MS3 work.

### Who builds what by MS2

| Owner (backup) | MS2 goal | Check and handoff |
| --- | --- | --- |
| Nick (Yuan) | Combat state with init, view, `play_card`, `end_turn`, result. Strike, Defend, Bash, energy, one selected target, draw/discard/reshuffle, block, status calls, the shown intent, win and loss. | `test/combat_test.ml`: a play changes HP, block and energy; a bad target or cost changes nothing; end turn runs the shown attack and draws again; victory and defeat. Yuan reviews the status timing and contributes or reviews an end-turn test. |
| Yuan (Nick) | Strength, Weak, Vulnerable and Poison arithmetic, and a `Cycle` AI for `training_slime` labeled `Attack 5` and `Defend 3`. | `test/status_ai_test.ml`: the hand-calculated 10 → 15 Vulnerable damage, poison, and the intent labels for turns 0, 1 and 2. Nick reviews one test and checks the AI in combat. |
| Carter (Grace) | The real JSON set (Strike, Defend, Bash, Training Slime, reward cards); `Loader.load` and enough `Validate.content` to reject malformed IDs, missing fields, unknown tags, negative values and empty patterns; README commands, rules and a JSON example. | `test/content_test.ml` loads the real files and checks IDs and effects; malformed fixtures give field-specific errors. Grace runs the loader through Main and checks that load errors are readable. |
| Kiyam (Carter) | A tiny valid route with one reachable fight; `Run.new_run`, `available_nodes`, `enter_node`, `after_combat`, `choose_reward`, and seeded `Rewards.generate`. Map generation and saves wait until the playable path works. | `test/run_test.ml`: a legal and an illegal node choice, win → offer → deck update, loss → `Lost` with no reward, and repeatable rewards for one seed. Carter checks that offered IDs exist in the card pool. |
| Grace (Kiyam) | Parsing and pure renderers for the MS2 screens; Main wired to the real loader, run, combat, AI and rewards; `new`, `choose`, `play`, `end`, `deck`, `help`, `quit`; a scripted smoke path. | `test/ui_test.ml` checks parsing and the key combat text; the smoke test loads JSON, enters the node, plays and ends turns, resolves the fight and chooses a reward. Kiyam contributes a transition test or scripted path and checks that the reward returns to the right phase. |

## MS2 report and submission

The report is about six pages, `MS2Report.pdf`, using the course template.
It starts with the team name, all members and NetIDs, the project title and
a clickable repository URL. Every section is written from **observed** work:

1. **What works so far:** one exact command sequence and what changed on
   screen; the connected modules; code and test paths in the ZIP; what's
   left for MS3.
2. **Design:** the screen and data flow, module responsibilities, short
   implemented signatures and clearly labeled proposed interfaces, lessons
   from integration, open questions.
3. **Responsibilities and contributions:** for every member, their primary
   and backup area, actual contribution, supporting paths, how they learned
   their backup area, and their next task. Missed or reassigned work is
   stated plainly.
4. **Remaining work:** the dependency order for generated maps, more
   content, rest, save and load, the boss and full-run checks, with an owner
   for each.
5. **Validation:** for each built behavior, the test name and path, the
   expected result worked out independently, the actual result, and any
   failure and fix. Future checks are labeled *planned*. Includes a manual
   playthrough. `dune test` is the automated command.
6. **AI use and review:** the actual AI assistance, a concrete example of
   human review, each owner's review responsibility, and the
   acknowledgements in `AUTHORS.md`.

`source.zip` holds the source, tests, build files, data, `README.md`,
`AUTHORS.md` and any file the report cites. It leaves out `_build`, local
opam switches and `.git`. One person uploads both files to Gradescope and adds
every member. Each member fills in the peer-evaluation form for every
teammate, themselves included, within 48 hours of submitting.

---

*Converted to Markdown from the team's plan document, with the type-sketch
changes and the contract freeze added, with AI assistance (Claude Code). See
`AUTHORS.md`.*
