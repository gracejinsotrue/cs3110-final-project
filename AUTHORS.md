# Authors

**Slay the Caml** · Team 20 Caml Slayers · CS 3110

Each member fills in their own entry: what they built, any AI assistance and
how they reviewed and checked it, and any other sources used. The MS2 report
draws on these entries, so keep them factual and point to files and PRs.

## Nicholas (Nick) Lennon (ncl46)

**Area:** Combat engine (primary owner); backup owner for Status rules and
enemy AI.

**Files:** `lib/combat.ml`, `lib/combat.mli`, `test/combat_test.ml`, and the
`combat_test` stanza in `test/dune` (PRs #9 and #11).

**AI assistance:** Claude Code (Anthropic) wrote the first versions of the
files above from the team plan:
- the `Combat.Make (Status) (Enemy_ai)` interface and implementation;
- the black-box test suite and its fake Status and AI modules.

It also wrote throwaway scripts that played seeded fights through Loader, Run,
Rewards and Grace's game (not committed). It drafted the descriptions for PRs
#9 and #11 and the acknowledgement comments at the top of each Combat file.

**Review and checks:**
- **Code review:** I reviewed every line of the Combat code and tests. As
  backup owner, I also reviewed Yuan's `lib/status.ml` and `lib/enemy_ai.ml`.
- **Decisions after review** (made in PR #11):
  - the target is checked before the energy cost;
  - errors when there is only one choice read "the only enemy is 1";
  - setup errors are returned as values;
  - a leftover hit on a dead target is never moved to another enemy;
  - all of a fight's randomness comes from the seed Main passes in.
- **`dune test`:** all 51 Combat tests pass. The expected values come from the
  rules in `README.md`, worked out before the code was run, not copied from its
  output.
- **Planted bugs (run by Claude Code):** deliberate bugs went into `combat.ml`
  (for example, discarding a card before its effects, or applying Vulnerable
  before Strength and Weak). The tests had to catch each one. One bug was
  missed at first, so that test was strengthened.
- **Integration (Claude Code's scripts):** seeded runs on the real `data/`
  files went through Loader, Validate, Run, Combat, Rewards and back to the
  map, ending in both wins and losses. A scripted playthrough of `bin/main.ml`
  also worked.

**Other sources:** none.

## Carter Chamberlain (cjc423)

**Area:**

**Files:**

**AI assistance:**

**Review and checks:**

**Other sources:**

## Grace Jin (gsj33)

**Area:** UI, input and integration (primary owner); the dune build and merging.

**Files:** `lib/ui.ml`, `lib/ui.mli`, `bin/main.ml`, `bin/dune`,
`test/ui_test.ml`, the `ui_test` stanza in `test/dune`, and the run
instructions in `README.md` (PR #10).

**AI assistance:** Claude Code (Anthropic) wrote the first versions of the
files above from the team plan, plus the PR #10 description and the
acknowledgement comment at the top of each file.

**Review and checks:**
- **Code review:** I reviewed the Ui and Main code and the 55 UI tests.
- **`dune test`:** all tests pass.
- **Playthroughs (run by Claude Code):** seeded games of `bin/main.exe` on the
  real `data/`: a win through the reward pick, a loss, invalid commands, and a
  missing data folder.

**Other sources:** none.

## Kiyam Merali (km942)

**Area:**

**Files:**

**AI assistance:**

**Review and checks:**

**Other sources:**

## Yuan Gao (yg626)

**Area:** Status rules and enemy AI (primary owner); backup owner for the
Combat engine.

**Files:** `lib/status.ml`, `lib/status.mli`, `lib/enemy_ai.ml`,
`lib/enemy_ai.mli`, `test/status_ai_test.ml`, the `status_ai_test` stanza in
`test/dune`, and the `camel_king` boss in `data/enemies.json` (PR #8). Also
the `camel_king` row in the README's behavior table, and the test "Vulnerable
2 on an enemy boosts hits for two player turns" in `test/combat_test.ml`.

**AI assistance:** Claude Code (Anthropic) wrote the first versions of the
files above from `types.ml`, `sigs.ml` and the team plan. That covers the
Status and Enemy_ai implementations, the 35 tests, the boss design, the extra
Combat test and the PR #8 description.

**Review and checks:**
- **Code review:** I reviewed `status.ml` and `enemy_ai.ml` against the
  contracts in `sigs.ml`. Each `.mli` is `include Sigs.STATUS` or
  `include Sigs.ENEMY_AI`, so the build fails if either module stops matching.
- **`dune test`:** all 35 Status and Enemy AI tests pass. The expected values
  come from the rules in `README.md` and `sigs.ml`. For example, Vulnerable
  turns 10 into 15, and Strength 4 then Weak turns 6 into 7 (8 if Weak were
  applied first). One test checked the wrong thing at first: it couldn't tell
  whether Strength or Weak came first. It was replaced with a case where the
  order changes the result.
- **Boss:** `camel_king` passes `Validate` with no warnings. A test checks that
  it switches to its low-HP pattern below 50% HP.
- **Combat backup:** I reviewed when `lib/combat.ml` calls Status (outgoing,
  then incoming, then block; the player ticks at the end of their turn; each
  enemy ticks right after its own action; poison ignores block). It matches
  `sigs.ml`. I added one end-of-turn test for the case no test covered: how
  long a Vulnerable that the player puts on an enemy lasts.

**Other sources:** none.
