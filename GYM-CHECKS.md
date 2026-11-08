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
