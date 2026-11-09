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
   If Clear does nothing, the official app's way of clearing is different; note it.
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
   this watch. After a relaunch, Light it should connect without scanning; the log
   says "Saved board found by the system".
9. **Sharing the board.** After Light it, check someone's phone can connect with
   the official app straight away.

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
14. Walk out of range and tap Light it: after 15 s it should say "Board didn't
    answer. Move closer and retry".
