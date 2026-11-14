# Moondance — Spec

Nov 7, 2026 · @Andrew Dunstan · updated Nov 14, 2026 to match the app as built

## Overview

Moondance is a standalone Apple Watch Ultra app that lights up MoonBoard problems on the board at Rocky Top Climbing, logs attempts and sends, and tracks projects, with no iPhone nearby.

- **Device:** Apple Watch Ultra (1st gen), watchOS 26.6, built with Claude Code and Xcode on the Mac.
- **No phone or internet needed:** the watch talks to the board's LED box directly over Bluetooth, and all problems ship inside the app.
- **v1 scope:** light up problems, switch hold sets, log attempts and sends, mark projects, export logs. Added since: hold pictures with a high point, beta pinned to holds, log editing, a random problem, and a climbing session that keeps the app on screen.
- **Personal use only:** the bundled problems are MoonBoard's content, so the app is installed through the paid developer account and never published.

## Board and Bluetooth

Rocky Top has one 40° MoonBoard with one LED box, and the gym swaps it between the 2016 and 2024 hold sets.

- **Grid:** 11 columns (A–K) × 18 rows, 198 positions, the same for both hold sets. Only the problem list changes between them.
- **Hold set setting:** Settings has a 2016 / 2024 40° choice. The problem list, logs and projects all follow it.
- **Connection:** Core Bluetooth in the central role. The first scan finds the LED box, shows its ID, and saves it; later sessions connect to that box automatically. The app only ever connects to the saved box: with none saved, Light it opens Find board, and any other job (the Bluetooth log's Test send or Clear) fails with "Pick your board first". Many unrelated devices offer the same UART service, so a board-like device is never picked automatically.
- **Sending a problem:** connect, write the hold list in the box's format, then disconnect right away so other climbers' phones can reach the board.
- **Protocol source:** the community Raspberry Pi emulator of the LED box ([e-sr/moonboard](https://github.com/e-sr/moonboard)). Claude Code reads its code for the exact message format rather than guessing.
- **Box version risk:** newer V3/V4 boxes show a 12-digit ID and may differ from the older box the emulator copies. The first milestone tests this at the gym.
- **Clear:** a button that turns all lights off.

## Problem data

The app ships a JSON snapshot of problems for both hold sets, loaded on first launch.

| Included | 2016 (40°) | 2024 40° |
| --- | --- | --- |
| Benchmarks, every grade | All | All |
| Extra V4 (6B, 6B+) | Most-repeated \~300 | Most-repeated \~300 |
| Extra V5 (6C, 6C+) | Most-repeated \~300 | Most-repeated \~300 |

- **Grades:** MoonBoard uses Font grades. The app shows the V grade first with Font beside it ("V5 · 6C+").
- **Source:** community-scraped MoonBoard datasets on GitHub, filtered by a one-time script on the Mac. Pick the newest dataset that includes the 2024 set. Extras are capped at 300 per grade per hold set.
- **Fields per problem:** id, hold set, name, setter, Font grade, V grade, benchmark flag, repeat count, holds.
- **Holds:** a list of grid positions with a role each: start, hand or finish (for example `S A5`, `P D9`, `E F18`).
- **Updating:** v1 never downloads. A newer snapshot means rerunning the script and rebuilding the app.

## Screens and navigation

The app opens on a Session screen built for standing at the wall: the hold grid fills the left side, and the Digital Crown steps through problems without going back to a list. History and Settings are a swipe left.

1. **Session (home):** the hold grid in MoonBoard's colors (green start, blue hand, red finish; dots only where the hold set has a hold) on the left. The problem name sits top left on the clock's line; tapping it opens the Problem list. The side column has the grade with a B badge, the tries count (tap: +1 attempt; touch and hold: Sent, or on a sent problem, Unsend), the project star ("Proj"), a "Beta" mark when the problem has beta (it opens Hold pictures with Show beta on), and Light it at the bottom. Turning the Crown moves to the next or previous problem in the list. Tapping the grid opens Hold pictures.
2. **Hold pictures:** the problem drawn with pictures of the real holds, start and finish outlined, A–K and 1–18 around the edge. The Crown zooms, drag pans, and double-tap resets. Tapping one of the problem's holds opens a callout beside it: its coordinates, your beta for that hold, and a pen to write or change it (empty grid points do nothing). The editor saves as you type and has a back button; its red button is Cancel the first time and Remove after that. Holds with beta carry a small white mark here and on Session's grid. "Show beta" beside Back (gray when there's none) lays every note out in bubbles left and right of the board, level with their holds and joined to them by lines, without overlaps or crossing lines; you pan sideways to read them. Long-pressing a hand hold marks it as your high point (gold; one per problem); long-pressing the finish logs a send.
3. **Problem list:** a list for the current hold set and grade. The header has a hold set chip (opens Settings), a grade chip (opens the grade picker) and a dice chip (jumps to a random problem in the list). Starred problems are pinned to the top, newest star first, then the rest by repeats. Each row: name, grade, a B badge for benchmarks, a pen if it has beta, a star for projects, and a green check if sent or the attempt count. Tapping a row opens it in Session.
4. **Grade picker:** a Digital Crown picker from V4 to V14 (the dataset starts at V4), plus Benchmarks only on or off. Opens on the last grade picked; V5 on first launch.
5. **Light it:** after Light it, the button reads Lit with a green dot (blue while connecting, red with Retry if it failed, plus a red banner saying what to do), and Clear appears.
6. **History:** sessions grouped by day: problems tried, attempts and sends, and any high point marked that day. Tapping a problem opens it in Session. A pen on the right of each row opens that problem's log for the day (tap an entry to switch attempt and send, swipe to delete, Delete all after a confirmation). Rows have no swipe actions, since a sideways swipe on History changes page.
7. **Settings:** hold set, V or Font grades, Stay open (start or end a climbing session), the saved board with Forget board, the Bluetooth log, and Export logs with the last export date.

There is no separate Projects page: starred problems are pinned to the top of the list instead.

**Action Button:** watchOS doesn't let a third-party app read the Action Button or its long press, so logging is on screen only. The Light It App Shortcut can be assigned to the button or run with Siri.

**Look:** near-black screens using only the board's LED colors: green for start and sent, blue for hand holds and actions, red for finish and destructive actions, white for projects, gold for your high point. Every color is paired with an icon so it reads in glare, and the system clock stays visible.

## Logging, projects and export

Everything is stored on the watch and works offline; export is the backup.

- **Attempts:** each tap on the tries count saves one attempt with the time. An **Undo** appears for 5 seconds after each tap.
- **Sends:** touch and hold saves a send (which also counts as an attempt). A problem can be sent more than once; the list shows a check after the first.
- **Unsend:** touch and hold on a sent problem turns its latest send back into an attempt. Earlier tries and sends stay, and Undo restores the send.
- **Editing:** History's Edit and Delete fix anything older (for example, test logging during beta testing).
- **Projects:** the star toggles a problem as a project. Sending a project keeps the star until it's removed by hand.
- **High point:** one per problem, set from Hold pictures. Every marking is also recorded and shows in History.
- **Beta:** short notes pinned to holds ("heel hook", "match"), written in Hold pictures.
- **Sessions:** History groups logs by calendar day, so no start or stop button is needed.
- **Climbing session:** Settings › Stay open starts an indoor-climbing workout session (HealthKit) so raising the wrist shows the app instead of the clock. Nothing is saved to Health. It ends from Settings, or by itself after 3 hours.
- **Export:** Settings → **Export logs** builds a CSV and opens the watch share sheet, so it can go out by Mail or Messages over cellular. Columns: date, time, hold set, problem id, problem, grade, type (attempt, send, star, high_point or beta), hold (the high point's position) and note (the beta text). A problem name or note starting with =, +, -, @, a tab or a carriage return gets a leading apostrophe and quotes, so a spreadsheet can't run it as a formula.
- **Backup reminder:** Settings shows the date of the last export.
- **Failures:** a failed save shows a red banner and goes in the Bluetooth log. If the store can't be opened, the app shows an error screen instead of crashing; it can carry on without saving or start a new log, keeping the old files on the watch.

## Data model

SwiftData on the watch, with the bundled problems kept read-only and the user's logs kept separately so a new snapshot never wipes them.

| Model | Fields | Notes |
| --- | --- | --- |
| Problem | id, holdSet, name, setter, fontGrade, vGrade, isBenchmark, repeats, holds | From the bundled JSON; read-only |
| Hold | position (e.g. "D9"), role (start, hand, finish) | Stored inside Problem |
| LogEntry | id, problemId, holdSet, date, isSend | One row per attempt or send |
| Project | problemId, holdSet, dateAdded | One row per starred problem |
| HighPoint | problemId, holdSet, position, date | The current one, per problem and hold set |
| HighPointMark | problemId, holdSet, position, date | Every high point marked, for History |
| BetaNote | problemId, holdSet, position, text, updated | One per hold of a problem |
| Settings | holdSet, boardID, boardName, lastExport, lastGrade, benchmarksOnly, gradeScale | Stored in UserDefaults |

Logs, projects, high points and beta refer to problems by the dataset's problem id, so they still match after the snapshot is replaced.

## Build plan

One Claude Code prompt per milestone, each built in the simulator and committed before the next. The whole app is built first, then uploaded once through TestFlight and tested at Rocky Top.

1. **Bluetooth proof:** a Bluetooth manager that scans, connects, sends and clears, plus a Bluetooth log screen with a Test send of one hardcoded 2024 problem for the gym visit.
2. **Snapshot:** the Mac script that filters a dataset into the bundled JSON, plus loading it on first launch.
3. **Browse:** **the Session screen with Crown stepping and Light it, then the Problem list and grade picker**.
4. **Hold sets:** the Settings toggle, with the list switching between 2016 and 2024.
5. **Logging and projects:** attempts, sends, undo, stars, the Action Button, the Projects and History pages.
6. **Export:** CSV and the share sheet.
7. **Polish:** connection dot states, Clear board, app icon.

The repo gets SPEC.md (this doc, exported) and a CLAUDE.md saying to read the spec first and target the Ultra on watchOS 26.

All seven milestones are built. Version 1.0 build 2 went to TestFlight on Nov 10, 2026, after the first gym visit. Since then: hold pictures and high points, then the Nov 13 review fixes (safer unsend, log editing, fuller export, no silent save failures, no crash on a bad store, faster launch and Crown stepping, random problem, climbing session). Nov 14: beta pinned to holds, high points in History, "Proj" label (a climber-for-scale figure and a separate beta window were tried and removed); build 3 uploaded. Later on Nov 14, security fixes: jobs only connect to the saved board, formula-safe CSV text, a more private Bluetooth log, and a pre-commit secret check. Releases go through `scripts/release.sh`, which bumps the build number, tests, uploads and tags `build-N`.

## Later versions and open questions

Later: setting your own problems, a Smart Stack widget for the current project, a session timer, and "unsent only" / "starred only" list filters.

- [x] Which LED box version does Rocky Top have? It works with the emulator's protocol (checked Nov 2026); Clear leaves A1 lit.
- [x] Which community dataset includes the 2024 set? boardhang/boardsesh (see tools/build_problems.py).
- [x] Name and icon decided: Moondance, with the Crescent Problem icon (a moon with a green, blue and red problem inside its curve).
- [ ] Does a climbing session bring the app back on wrist raise on the real watch?
