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

**Area:** Map, rewards, and run progression; backup for UI/integration and
content/loading.

**Files:** `lib/map.ml(i)`, `lib/rewards.ml(i)`, `lib/run.ml(i)`,
`lib/types.ml`, reward-pool loading and validation in `lib/loader.ml(i)` and
`lib/validate.ml(i)`, `test/run_test.ml`, and related content tests (PR #7 and
the follow-up branch).

**AI assistance:** OpenAI Codex assisted with the map, rewards, and run
implementation, reward-pool changes, and follow-up tests. It drafted the fixed
route, seeded reward selection, run transitions, loader/validation changes,
and rejection/phase-transition tests.

**Review and checks:** The follow-up adds tests for unreachable nodes, invalid
reward choices, `after_combat` outside a fight, and the map → fight → reward →
map transition. On the refreshed `origin/master`, Codex ran
`dune test --profile release`; all 205 tests passed. Standard `dune test`
currently stops because warning 8 in upstream `lib/loader.ml` is treated as an
error; that file was left untouched. Kiyam should personally review the
AI-assisted changes and rerun the checks before submission, as required by the
team contract. As Carter's backup, Kiyam read the Loader and Validate
interfaces/tests and coordinated the reward-pool field so reward IDs are
checked against loaded card definitions.

**Other sources:** Team plan, README, shared type contract, and MS1Report.pdf;
no external sources.

## Yuan Gao (yg626)

**Area:**

**Files:**

**AI assistance:**

**Review and checks:**

**Other sources:**
