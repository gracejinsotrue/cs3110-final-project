# Authors

- Nicholas Lennon (ncl46)
- Carter Chamberlain (cjc423)
- Grace Jin (gsj33)
- Kiyam Merali (km942)
- Yuan Gao (yg626)

Each member lists their own sources and AI use below. Add your section under your name.

Carter Chamberlain ---------------------------------------
I used Claude Code (Anthropic’s coding assistant, Claude Opus 5.5) during the project. I personally wrote lib/loader.ml, lib/loader.mli, lib/validate.ml, lib/validate.mli, test/content_test.ml, the fixtures in test/fixtures/, data/cards.json, data/enemies.json (the MS2 set), and the README sections on build commands, rules, content format, and agreed decisions. I also made the Yojson 3 build fix and wrote the reward-offer tests.

I built PR #10 (UI and Main) with the fix, ran its tests, and played scripted games through victory and a reward choice. I recorded the results in my MS2 report section.
- **How I reviewed it:** I reviewed it by checking the information that gets passed between modules and the types that Claude was using. It was mainly used for debugging though, so I didn't need to review a ton.
