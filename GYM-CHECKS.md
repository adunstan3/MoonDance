# Things to check at Rocky Top

Only the real watch at the board can answer these. If something fails, open
Settings › Bluetooth log, use **Share log** (or take a photo), and note the box's
name/ID.

## Bluetooth protocol (milestone 1)

Source: the community emulator github.com/e-sr/moonboard (`ble/moonboard_app_protocol.py`,
`ble/moonboard_BLE_service.py`). Unsure points, most likely to bite first:

1. **Position numbers start at 0 or 1?** The emulator's code (`position_trans`) is
   0-based: A1 = 0, A18 = 17, B18 = 18 … K18 = 197. Its README says "1 to 198".
   We follow the code. If every light is off by one row, this is why.
   Check: Test send should light D5 + F4 green, E8 H10 G13 D15 blue, F18 red.
2. **Clear.** The emulator has no clear command. We send an empty problem `l##`.
   Checked: everything goes off except A1 (bottom-left), which stays lit. Accepted.
3. **Newer box (V3/V4, 12-digit ID).** It may not advertise the Nordic UART
   service (6E400001-…) or may name itself differently. The scan therefore has no
   service filter and lists anything named "moon…" or offering UART. If nothing
   shows up, turn on **Show all devices** in the Bluetooth log and scan again; the
   log lists each device's name, services and maker data.
4. **Write type.** The box's RX characteristic (6E400002-…) is written *with*
   response if it allows it, otherwise without. The log shows which, and the
   max write size.
5. **Flags packet.** Newer versions of the official app may send `~D*` before the
   problem (D = light the hold LEDs above as well on the emulator). Off by default;
   if problems don't light, try Bluetooth log › Flags packet › `~D*`.
6. **Disconnect timing.** We disconnect 0.4 s after the last write so phones can
   connect. If only part of a problem lights, the box may need longer.

## Find board and auto-connect (milestone 4)

7. **Find board** lists boxes named "moon…" or advertising the UART service, with
   the 12-digit ID if the box's name contains one (otherwise the first 8 characters
   of the watch's identifier for it). Check the ID shown matches the box's label.
8. **Auto-connect.** The saved box is remembered by Core Bluetooth's identifier on
   this watch. Light it listens for that box advertising (log: "Listening for the
   saved board"), then connects. It should hear it in well under a second.
9. **Sharing the board.** After Light it, check someone's phone can connect with
   the official app straight away. While someone else is connected, Light it should
   fail within about 3 s with "Someone else has the board. Retry in a moment", and
   their phone should keep the board: the box stops advertising while connected, so
   Moondance doesn't connect at all. (The first gym visit, with a waiting
   connection request, fought with other climbers' phones.)

## Action Button (milestone 5)

Logging is on screen only: tap the tries count for +1 attempt, touch and hold it
for Sent, tap the star for a project. (watchOS doesn't let an app read the Action
Button or use its long press, and the attempt/sent shortcuts were removed.)

10. Optional: Watch › Settings › Action Button › Shortcut › **Light It** lights the
    problem on the Session screen. If Light It isn't listed there, it can still be
    run by Siri ("Light it in Moondance").

## Export (milestone 6)

11. Settings › Export logs › **Mail or Messages** opens the watch share sheet. Send
    it to yourself by Mail and check the attachment opens as a spreadsheet. The
    sheet offers a `.csv` file, and plain text where a file isn't accepted (Messages
    may take the text). This can be tested at home over cellular.
12. "Last export" in Settings is the last time the share sheet was opened; watchOS
    doesn't tell the app whether you actually sent it.

## Connection states and errors (milestone 7)

13. The bottom button shows the state: **Light it** (idle), a blue dot while
    connecting/sending, **● Lit** in green with **Clear**, or **● Retry** in red.
    A failure also shows a red banner saying what to do (move closer, turn on
    Bluetooth, board busy…) and the full reason goes to the Bluetooth log.
14. Walk out of range and tap Light it: after about 3 s it should say "Someone else
    has the board. Retry in a moment" (out of range and busy look the same: no
    advertising heard).

## After the review fixes (build 3)

15. Settings › Stay open › **Start climbing session**. Allow Health when asked
    (turn on Workouts, then Done). The card should read "On since …". Lower your
    wrist for a few minutes, then raise it: Moondance should be on screen, not
    the clock. **End climbing session** stops it; a workout icon in the status bar
    should disappear.
16. In the hold pictures, tap a hold and use the pen to add beta (try dictation
    and Scribble). Check the keyboard no longer offers suggestions like "Doing
    good". Check the white marks, and that Show beta's bubbles and lines are readable and
    easy to pan to.
17. Hold **Sent** on a sent problem: only the latest send should turn back into an
    attempt. In History, swipe a row left › **Edit** and fix an entry.
18. Export logs and check the CSV now has problem_id, star, high_point and beta
    rows. Mark a high point and check it shows in History.

## After the security fixes (build 4)

19. Settings › **Forget board**, then Bluetooth log › **Test send**: it should fail at
    once with "Pick your board first: Settings › Find board" and connect to nothing.
    Then **Find board**, pick "Moonboard A", and check Light it still works as before.20. Bluetooth log › turn on **Show all devices** and **Scan**: the box's line should
    still show its ID, services and maker data; other devices only "Found other
    device "name" rssi -NN".
