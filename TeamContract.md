# Team Contract

## What we want from the project

We want to build an enjoyable OCaml game while practicing functional programming, testing, and collaboration. Each person will own a substantive part of the game, share progress early, and ask for help before a delay blocks someone else.

## Communication and meetings

- We use the team text chat for brief or urgent messages and Slack for design discussions, code, decisions, and task updates. We keep project decisions in Slack so everyone can find them. The `#to-do` canvas is our task tracker.
- Each teammate checks Slack at least twice each day. A teammate acknowledges a question within 12 hours while awake; a message sent overnight receives a reply by noon Eastern time the next day. A blocker or likely missed deadline goes to the text chat as soon as it is known.
- We meet once a week. By Thursday at 8 p.m. Eastern, we choose the following week's meeting time in the shared calendar. The invitation includes a video link; we meet in person only if all attendees agree on a location. If no time is chosen by Thursday, the default is Sunday at 7 p.m. Eastern by video. A teammate who cannot attend gives at least 12 hours notice in the text chat, or as soon as possible in an emergency. Meeting notes and decisions go in Slack within 24 hours.

## Decisions

- Before a major project or interface decision, each teammate can post ideas in Slack. We discuss options respectfully and try a workable compromise first. A teammate may ask for a short discussion before a vote.
- If the group cannot agree, a decision requires a majority of the five teammates. We allow 24 hours for input when the schedule permits; a deadline-sensitive decision can be made at a meeting or after a shorter window announced to everyone. The decision and its reason are recorded in Slack. If a disagreement involves only some teammates, the uninvolved teammates help evaluate the options before the vote.

## Commitments and problems

- Every task in the `#to-do` canvas names a primary owner, a backup, a specific deliverable, a due date, and a status (`not started`, `in progress`, `blocked`, or `done`). Owners update status when it changes and post a short progress note at least twice a week.
- Someone who is stuck or may miss a commitment tells the text group promptly, including what is blocked, what they tried, what help they need, and a revised estimate. The backup acknowledges a blocker within 12 waking hours. Within 24 hours, the owner and backup agree on a next step and tell the team.
- If work is missed, we assign a new owner or helper and a new due date in the task tracker. Blocking work takes priority over nonblocking work. The original owner later takes a comparable task from the person who helped. We check the recovery plan at the next team meeting or within 48 hours, whichever comes first. If the recovery plan is not followed, we ask the professor for team coaching immediately.

## Review and integration

- Code changes use descriptive commits and include tests for the behavior changed. For code after MS1, the contributor opens a pull request. A different teammate, preferably the backup owner, reviews the code and tests; the author does not approve their own change. We merge only after the review is addressed and `dune build` and `dune runtest` pass, or the team records why a check cannot run yet. We review integration and open pull requests at the weekly meeting.
- Backup owners read the component interface, review at least one relevant test or change, and discuss progress with the primary owner weekly. The owner documents important behavior so a backup can help with a handoff.
- Before changing a shared `.mli`, type, JSON format, or other interface, the owner posts an `INTERFACE CHANGE` note in Slack `#general` with the proposed change and affected modules. Affected owners and backups review it before merge. We update callers in the same integration pass.

## AI use

- We follow the course's AI and academic-integrity rules. AI assistance does not replace each contributor's own understanding. The person using AI inspects every generated line, checks it against the intended behavior, and personally runs relevant tests before committing; they are responsible for the result.
- The contributor discloses AI-assisted code in the pull request and in a brief comment or acknowledgement in the affected file. They describe what AI helped with and how they verified it. The reviewer checks the code and tests independently and can ask the contributor to explain any part. We do not merge code that the contributor cannot explain or that has not been checked.
- If teammates disagree about AI use, we pause the affected change, discuss the concern in Slack or at a meeting, and decide under the process above within 24 hours when feasible. Course rules take precedence over any team vote.

## Revisiting the agreement

We review this contract at our third meeting and at each project milestone. Anyone may propose a change in Slack; all teammates have at least 24 hours to comment when timing permits. A change takes effect after a majority of the five teammates approve it, and the approved wording is committed to this file. We can also revisit a rule promptly when it is causing a problem.
