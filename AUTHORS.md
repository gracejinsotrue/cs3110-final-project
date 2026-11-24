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

**Area:** Content, loading and validation (primary owner), and the README.
Backup owner for UI and Main (Grace) and for checking reward IDs (Kiyam).

**Files:** `lib/loader.ml`, `lib/loader.mli`, `lib/validate.ml`,
`lib/validate.mli`, `data/cards.json`, `data/enemies.json`,
`test/content_test.ml`, `test/fixtures/`, the first `dune-project`,
`lib/dune` and `test/dune`, and the README's build, rules, content-format and
agreed-decisions sections (PRs #6 and #13).

**AI assistance:** Claude Code (Anthropic) wrote the first versions of the
files above from the team plan:
- the JSON format and the MS2 card and enemy set;
- the Loader, with error messages that name the file and field;
- Validate's errors, balance warnings and ID checks;
- the content tests and the bad-input fixtures.

In PR #13 it also wrote:
- the Yojson 3 build fix in `lib/loader.ml`;
- the reward-offer tests;
- the README decisions section.

It drafted my MS2 report section.

**Review and checks:**
- **Code review:** I reviewed the code, focusing on the types used in the JSON
  format and the data passed between modules (`Types.content`, the reward pool,
  and the IDs Main checks at startup).
- **`dune test`:** all 55 content tests pass. These include one fixture per
  kind of bad input, each of which must give an error naming the field and the
  bad value.
- **Build fix:** `master` failed to compile on the course's Yojson 3.0.0. A
  fresh clone with the fix applied builds and passes every suite.
- **Backup checks (run by Claude Code):**
  - **For Kiyam:** reward offers over 500 seeds contain only known cards from
    the reward pool.
  - **For Grace:** PR #10 was built with the fix and played through a seeded
    game to victory and a reward pick, with invalid commands rejected.

**Other sources:** Yojson and OUnit2 documentation. The game's genre and the
starter card names Strike, Defend and Bash come from *Slay the Spire* (Mega
Crit). All other card and enemy names, values and text are our own.

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

**Area:**

**Files:**

**AI assistance:**

**Review and checks:**

**Other sources:**
