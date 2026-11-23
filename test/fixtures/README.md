# Content test fixtures

- `tiny/` is the smallest valid content: one card (`strike`) and one enemy
  (`training_slime`). Other owners can load it with `Loader.load "fixtures/tiny"`.
- `bad_*.json` and `warn_*.json` files each break (or stretch) one rule. They
  are read by `test/content_test.ml`, and each file is named after the check it
  exercises.
