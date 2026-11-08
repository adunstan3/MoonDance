import Foundation

/// Why talking to the LED box failed: a detailed line for the Bluetooth log, and
/// a short message for the climber on the Session screen.
nonisolated enum BoardFailure: Equatable, Sendable {
    case bluetoothUnavailable
    case bluetoothNotAllowed
    case bluetoothOff
    case timedOut(seconds: Int64)
    case connectFailed(String)
    case disconnected
    case discoveryFailed(String)
    case serviceMissing
    case characteristicMissing
    case notWritable
    case writeFailed(packet: Int, reason: String)

    /// For the Bluetooth log.
    var logText: String {
        switch self {
        case .bluetoothUnavailable: "Bluetooth isn't supported here (the simulator has no Bluetooth)"
        case .bluetoothNotAllowed: "Bluetooth permission is off: Settings › Privacy › Bluetooth › Moondance"
        case .bluetoothOff: "Bluetooth is turned off"
        case .timedOut(let seconds): "Timed out: the board didn't answer within \(seconds) s"
        case .connectFailed(let reason): "Couldn't connect: \(reason)"
        case .disconnected: "The board disconnected before the problem was sent"
        case .discoveryFailed(let reason): "Discovery failed: \(reason)"
        case .serviceMissing: "The board has no UART service (\(BoardProtocol.uartServiceUUID))"
        case .characteristicMissing: "No RX characteristic (\(BoardProtocol.rxCharacteristicUUID))"
        case .notWritable: "The RX characteristic can't be written to"
        case .writeFailed(let packet, let reason): "Write \(packet) failed: \(reason)"
        }
    }

    /// For the Session screen: what happened and what to do.
    var message: String {
        switch self {
        case .bluetoothUnavailable: "Bluetooth isn't available"
        case .bluetoothNotAllowed: "Allow Bluetooth for Moondance in Settings"
        case .bluetoothOff: "Turn Bluetooth on, then retry"
        case .timedOut: "Board didn't answer. Move closer and retry"
        case .connectFailed, .disconnected: "Board busy or out of range. Retry"
        case .discoveryFailed, .writeFailed: "Sending failed. Retry"
        case .serviceMissing, .characteristicMissing, .notWritable: "That box didn't accept problems. See Bluetooth log"
        }
    }
}
