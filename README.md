# Caml Slayers

**Project:** Slay the Caml, a terminal-based deck-building game written in OCaml. Players choose a route, fight with cards while seeing enemy intents, and improve their deck after encounters. The first MS2 goal is one complete playable fight and card reward.

## Team members

- Nicholas Lennon (ncl46)
- Carter Chamberlain (cjc423)
- Grace Jin (gsj33)
- Kiyam Merali (km942)
- Yuan Gao (yg626)

## Team agreement

Our communication, review, and contribution rules are in [TeamContract.md](TeamContract.md).

## Install, build and test

You need OCaml 5 and opam (the CS 3110 switch works). Install the libraries once:

```bash
opam install dune yojson ounit2 ansiterminal
```

Then, from the repository root:

```bash
dune build
```

```bash
dune test
```

The game's entry point (`bin/main.ml`) is still being written. When it lands, `dune exec bin/main.exe` will start the game.

## Controls

Every number you type is the one shown on screen, counting from 1.

| Command | Where | Meaning |
| --- | --- | --- |
| `new [seed]` | title | Start a run, optionally with a fixed seed |
| `choose <n>` | map, reward | Pick map node `n` or reward card `n` |
| `play <card> [enemy]` | fight | Play hand card `card`; give `enemy` if the card hits one enemy |
| `end` | fight | End your turn; enemies do what their intent said |
| `deck` | map, fight | Show your run deck (map) or this fight's cards (fight) |
| `help` | anywhere | List the commands valid on this screen |
| `quit` | anywhere | Leave the game |

## Rules (MVP)

- **Start:** 80/80 HP, 0 gold. Deck: 5 Strike, 4 Defend, 1 Bash.
- **Your turn:** your old block is removed, energy is set to 3, and you draw up to 5 cards. A card costs its energy and its effects happen in the order listed.
- **Piles:** played cards and the rest of your hand go to the discard pile. When you must draw from an empty draw pile, the discard pile is shuffled into a new draw pile.
- **Damage:** base damage, then the attacker's Strength is added, then Weak multiplies by 0.75, then the defender's Vulnerable multiplies by 1.5 (rounding down each time). Block absorbs what is left, and the remainder comes off HP. Poison ignores block.
- **Statuses:** Strength is a stack that lasts the fight. Weak and Vulnerable last a number of turns and drop by 1 at the end of the affected actor's turn. Poison: after the actor acts, it loses HP equal to its Poison, then Poison drops by 1.
- **Enemy turn:** each living enemy, in order, loses its old block and does its shown intent. The next intents are shown after all enemies have acted.
- **End of a fight:** you win when every enemy is at 0 HP (you keep your HP and get the enemy's gold), and you lose at 0 HP. After a normal win you pick 1 of up to 3 cards to add to your deck.
- **Rest:** heal 30% of max HP (rounded up).

## Content format

Cards and enemies live in `data/cards.json` and `data/enemies.json`. The game loads them with `Loader.load "data"` and checks them with `Validate.content` before playing.

`cards.json` may include a top-level `reward_pool` array of card IDs. Every ID must name a loaded card; the run offers up to three distinct cards from this pool.

**IDs** are lowercase letters, digits and `_`, start with a letter, and never change once used. Saves and the starter deck refer to cards by ID. Display names can change freely.

### Cards

```json
{
  "reward_pool": ["twin_jab", "venom_dart", "war_cry"],
  "cards": [
    {
      "id": "bash",
      "name": "Bash",
      "cost": 2,
      "description": "Deal 8; apply 2 Vulnerable to one enemy",
      "effects": [
        { "type": "deal", "target": "selected_enemy", "amount": 8 },
        { "type": "apply_status", "target": "selected_enemy", "status": "vulnerable", "amount": 2 }
      ]
    }
  ]
}
```

| Effect `type` | Other fields | Meaning |
| --- | --- | --- |
| `deal` | `target`, `amount` | Attack for `amount` base damage. Target cannot be `self`. |
| `gain_block` | `amount` | You gain block. |
| `apply_status` | `target`, `status`, `amount` | Add stacks/turns of a status (`amount` ≥ 1). |
| `draw` | `amount` | Draw cards. |
| `gain_energy` | `amount` | Gain energy this turn. |

- **Targets:** `self`, `selected_enemy` (the player types an enemy number), `all_enemies`
- **Statuses:** `strength`, `weak`, `vulnerable`, `poison`

### Enemies

```json
{
  "enemies": [
    {
      "id": "training_slime",
      "name": "Training Slime",
      "max_hp": 30,
      "gold": 5,
      "behavior": {
        "type": "cycle",
        "intents": [
          { "label": "Attack 5", "actions": [{ "type": "attack", "amount": 5 }] },
          { "label": "Defend 3", "actions": [{ "type": "defend", "amount": 3 }] }
        ]
      }
    }
  ]
}
```

An **intent** is a player-facing `label` plus a list of `actions`, which run in order:

| Action `type` | Other fields | Meaning |
| --- | --- | --- |
| `attack` | `amount` | Hit the player. |
| `defend` | `amount` | The enemy gains block. |
| `inflict` | `status`, `amount` | Give the player a status. |
| `buff` | `status`, `amount` | Give this enemy a status. |

| Behavior `type` | Other fields | Meaning |
| --- | --- | --- |
| `cycle` | `intents` | Repeat the intents in order. |
| `defend_below` | `pct`, `defend`, `normal` | Use the `defend` intent while HP is below `pct`% of max; otherwise cycle `normal`. |
| `phase_at` | `pct`, `high`, `low` | Cycle `high` while HP ≥ `pct`%, then `low` once HP drops below. |
| `random_choice` | `intents` | Pick one at random (seeded) each turn. |

### Enemy behaviors

| Enemy | Pattern | Counterplay |
| --- | --- | --- |
| `training_slime` | Attack 5, Defend 3, repeat | Block on attack turns, and hit hard on defend turns |

### Adding a card or enemy

1. Add an object to `data/cards.json` or `data/enemies.json` using the format above, with a new unique ID.
2. Run `dune test`. One test loads the real `data/` files and fails with a message naming the file, entry and field if anything is malformed or invalid. A second test lists balance warnings, such as a 0-cost card dealing more than 6 damage, a card costing more than 3 energy, or an enemy that never attacks.
3. A misspelled field (e.g. `"cots"`), an unknown tag (e.g. status `"stun"`), a duplicate ID or a negative cost all produce errors such as:

   ```
   data/cards.json: cards[2] ("bash").effects[1].status: unknown status "stun" (expected one of: strength, weak, vulnerable, poison)
   card "cheap": cost is -1; must be 0 or more
   ```

### Fixtures for tests

`test/fixtures/tiny/` holds the smallest valid content (one card, `strike`, and one enemy, `training_slime`). Other modules' tests can use it, or build `Types.content` values by hand.
