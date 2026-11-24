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
  files went through Loader,
  Validate, Run, Combat, Rewards and back to the map, ending in both wins and
  losses. A scripted playthrough of `bin/main.ml` also worked.

**Other sources:** none.

## Carter Chamberlain (cjc423)

**Area:**

**Files:**

**AI assistance:**

**Review and checks:**

**Other sources:**

## Grace Jin (gsj33)

**Area:**

**Files:**

**AI assistance:**

**Review and checks:**

**Other sources:**

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
