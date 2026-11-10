import Foundation

/// The message format the MoonBoard app sends to the LED box, taken from the
/// community emulator at github.com/e-sr/moonboard (ble/moonboard_app_protocol.py
/// and ble/moonboard_BLE_service.py).
///
/// - The box offers the Nordic UART service; the app writes to its RX characteristic.
/// - A problem is one ASCII string: `l#` + comma-separated holds + `#`,
///   for example `l#S67,P79,E90#`.
/// - Each hold is a role letter (S start, P hand/"move", E end/finish) and a
///   position number on the LED strip path.
/// - The string is split into BLE-sized packets (20 bytes with the default MTU);
///   the box glues them back together between `l#` and `#`.
/// - An optional flags packet `~<flags>*` may come first (D = "both lights"
///   on the emulator, M = mini board).
nonisolated enum BoardProtocol {
    static let uartServiceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    static let rxCharacteristicUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let txCharacteristicUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    /// Bytes per BLE write when the MTU is the default 23 (23 − 3 header bytes).
    static let defaultPacketLength = 20

    /// The emulator has no "clear" command. An empty problem turns the lights off.
    /// Checked at the gym (Rocky Top box): everything goes off except A1 (LED 0),
    /// probably the firmware reading the empty hold as position 0. Kept as is.
    static let clearMessage = "l##"

    /// The position number the box expects for a grid position.
    ///
    /// The emulator's `position_trans` turns a number `p` back into a grid name with
    /// `col = p / 18`, `row = p % 18 + 1`, and the row flipped on odd columns,
    /// so the numbers snake up column A, down column B, and so on:
    /// A1 = 0 … A18 = 17, B18 = 18 … B1 = 35, C1 = 36 …
    static func ledNumber(for position: GridPosition) -> Int {
        let rows = GridPosition.rows
        let offset = position.column.isMultiple(of: 2) ? position.row - 1 : rows - position.row
        return position.column * rows + offset
    }

    /// Inverse of `ledNumber(for:)`, the same maths as the emulator's `position_trans`.
    static func position(forLedNumber number: Int) -> GridPosition? {
        let rows = GridPosition.rows
        let column = number / rows
        var row = number % rows + 1
        if !column.isMultiple(of: 2) { row = rows + 1 - row }
        return GridPosition(column: column, row: row)
    }

    static func roleLetter(_ role: HoldRole) -> String {
        switch role {
        case .start: "S"
        case .hand: "P"
        case .finish: "E"
        }
    }

    /// The full problem string, e.g. `l#S67,S104,P79,E90#`. Holds with an
    /// unreadable position are skipped.
    static func message(for holds: [Hold]) -> String {
        let codes = holds.compactMap { hold -> String? in
            guard let position = GridPosition(hold.position) else { return nil }
            return roleLetter(hold.role) + String(ledNumber(for: position))
        }
        return "l#" + codes.joined(separator: ",") + "#"
    }

    /// The optional flags packet, e.g. `~D*`. Empty flags mean no packet.
    static func flagsMessage(_ flags: String) -> String? {
        flags.isEmpty ? nil : "~\(flags)*"
    }

    /// Splits a message into ASCII packets of at most `maxLength` bytes.
    static func packets(for message: String, maxLength: Int = defaultPacketLength) -> [Data] {
        let bytes = Array(message.utf8)
        let size = max(1, maxLength)
        return stride(from: 0, to: bytes.count, by: size).map { start in
            Data(bytes[start..<min(start + size, bytes.count)])
        }
    }

    /// Every packet to write for one job, flags first.
    static func packets(problem message: String, flags: String, maxLength: Int = defaultPacketLength) -> [Data] {
        var result: [Data] = []
        if let flagsMessage = flagsMessage(flags) {
            result += packets(for: flagsMessage, maxLength: maxLength)
        }
        result += packets(for: message, maxLength: maxLength)
        return result
    }

    /// The hardcoded 2024 problem used by Test send in the Bluetooth log:
    /// start D5 and F4; hands E8, H10, G13, D15; finish F18.
    static let testProblem: [Hold] = [
        Hold(position: "D5", role: .start),
        Hold(position: "F4", role: .start),
        Hold(position: "E8", role: .hand),
        Hold(position: "H10", role: .hand),
        Hold(position: "G13", role: .hand),
        Hold(position: "D15", role: .hand),
        Hold(position: "F18", role: .finish),
    ]
}
