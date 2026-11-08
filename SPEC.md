# Moondance — Spec

Nov 7, 2026 · @Andrew Dunstan

## Overview

Moondance is a standalone Apple Watch Ultra app that lights up MoonBoard problems on the board at Rocky Top Climbing, logs attempts and sends, and tracks projects, with no iPhone nearby.

- **Device:** Apple Watch Ultra (1st gen), watchOS 26.6, built with Claude Code and Xcode on the Mac.
- **No phone or internet needed:** the watch talks to the board's LED box directly over Bluetooth, and all problems ship inside the app.
- **v1 scope:** light up problems, switch hold sets, log attempts and sends, mark projects, export logs.
- **Personal use only:** the bundled problems are MoonBoard's content, so the app is installed through the paid developer account and never published.

## Board and Bluetooth

Rocky Top has one 40° MoonBoard with one LED box, and the gym swaps it between the 2016 and 2024 hold sets.

- **Grid:** 11 columns (A–K) × 18 rows, 198 positions, the same for both hold sets. Only the problem list changes between them.
- **Hold set setting:** Settings has a 2016 / 2024 40° choice. The problem list, logs and projects all follow it.
- **Connection:** Core Bluetooth in the central role. The first scan finds the LED box, shows its ID, and saves it; later sessions connect to that box automatically.
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

The app opens on a Session screen built for standing at the wall: the hold grid fills the screen, and the Digital Crown steps through problems without going back to a list. Projects and History are a swipe left.

1. **Problem list:** a list for the current hold set and grade. The header shows the hold set and a grade button (opens on the last grade picked; V5 on first launch). Each row: name, grade, a B badge for benchmarks, a star for projects, a green check if sent, and the attempt count. Tapping a row opens it in Session.
2. **Grade picker:** a Digital Crown picker from V0 to V14, plus Benchmarks only on or off.
3. **Session (home): the hold grid in MoonBoard's colors (green start, blue hand, red finish) on the left; a side column with grade, B badge, attempt count, project star and list position ("3 / 42"); a full-width Light it button at the bottom. Turning the Crown moves to the next or previous problem in the list. Tapping the name opens the Problem lis**t.
4. **Action Button: a press logs +1 attempt; a long press marks Sent. Each shows a short banner with Undo. Settings can switch it to Light it instead. After Light it, the button reads Lit with a green dot (gray idle, blue connecting, red failed), and Clear board appears**.
5. **Projects:** starred problems for the current hold set, newest first, with attempts and sent status.
6. **History:** sessions grouped by day: problems tried, attempts and sends. Tapping a problem opens it in Session.
7. **Settings:** hold set, Action Button choice, saved board ID with **Forget board**, and **Export logs**.

**Look:** near-black screens using only the board's LED colors: green for start and sent, blue for hand holds and actions, red for finish and destructive actions, white for projects. Every color is paired with an icon so it reads in glare, and the system clock stays visible.

## Logging, projects and export

Everything is stored on the watch and works offline; export is the backup.

- **Attempts:** each **+1 attempt** tap saves one attempt with the time. An **Undo** appears for 5 seconds after each tap.
- **Sends:** **Sent** saves a send (which also counts as an attempt). A problem can be sent more than once; the list shows a check after the first.
- **Projects:** the star toggles a problem as a project. Sending a project keeps the star until it's removed by hand.
- **Sessions:** History groups logs by calendar day, so no start or stop button is needed.
- **Export:** Settings → **Export logs** builds a CSV (date, time, hold set, problem, grade, attempt or send) and opens the watch share sheet, so it can go out by Mail or Messages over cellular.
- **Backup reminder:** Settings shows the date of the last export.

## Data model

SwiftData on the watch, with the bundled problems kept read-only and the user's logs kept separately so a new snapshot never wipes them.

| Model | Fields | Notes |
| --- | --- | --- |
| Problem | id, holdSet, name, setter, fontGrade, vGrade, isBenchmark, repeats, holds | From the bundled JSON; read-only |
| Hold | position (e.g. "D9"), role (start, hand, finish) | Stored inside Problem |
| LogEntry | id, problemId, holdSet, date, isSend | One row per attempt or send |
| Project | problemId, holdSet, dateAdded | One row per starred problem |
| Settings | holdSet, boardID, lastExport | Stored in UserDefaults |

Logs and projects refer to problems by MoonBoard's problem id, so they still match after the snapshot is replaced.

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

## Later versions and open questions

Later: random problem by grade, setting your own problems, a Smart Stack widget for the current project, and a session timer.

- [ ] Which LED box version does Rocky Top have?
- [ ] Which community dataset includes the 2024 set?
- [ ] Name and icon decided: Moondance, with the Crescent Problem icon (a moon with a green, blue and red problem inside its curve).
