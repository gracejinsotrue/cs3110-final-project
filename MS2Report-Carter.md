# MS2 report: Carter's sections (draft)

## Design: loading and validation

`Loader.load "data"` parses `cards.json` and `enemies.json` into `Types.content`. It never raises. It reports every error, each with its file, entry and field, e.g. `data/cards.json: cards[0] ("bash").effects[1].status: unknown status "stun"`. `Validate.content` rejects content that parses but is wrong (duplicate IDs, negative costs, empty enemy patterns). `Validate.warnings` flags balance problems, such as a 0-cost card dealing more than 6 damage. Keeping parsing and validation separate means the validator can be tested on content written by hand.

## Contributions: Carter Chamberlain (cjc423)

- **Owner of** `lib/loader.*`, `lib/validate.*`, `data/*.json`, `test/content_test.ml` and the README (PR #6).
- **Fixed the `master` build:** removed a Yojson-2-only pattern that broke compilation on Yojson 3.0.0.
- **Backup for Kiyam:** tests that every offered reward ID is a real card from the reward pool.
- **Backup for Grace:** I learned her area by reviewing PR #10. I read how `bin/main.ml` moves between screens and calls `Ui`, then built it with the fix and played a scripted seeded game through victory and a reward choice.
- **Next (MS3):** more cards and enemies, including an elite and the boss.

## Validation

`test/content_test.ml` has 55 passing tests (`dune test`):
- Valid files parse to the expected records.
- Each of the 11 bad-input fixtures in `test/fixtures/` produces an error that names the field and the bad value.
- The validator's errors and warnings trigger exactly at their limits.
- Reward offers over 500 seeds contain only known pool cards.
