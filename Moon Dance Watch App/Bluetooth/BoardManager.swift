import CoreBluetooth
import Foundation
import Observation

/// An LED box (or, with "show all devices" on, any device) seen during a scan.
struct DiscoveredBoard: Identifiable, Hashable {
    enum Signal: String { case near = "Near", medium = "OK", far = "Far" }

    let id: UUID
    var name: String
    var rssi: Int
    var looksLikeBoard: Bool

    var signal: Signal {
        if rssi >= -65 { return .near }
        if rssi >= -80 { return .medium }
        return .far
    }
}

/// Talks to the MoonBoard LED box over Bluetooth (Core Bluetooth, central role).
///
/// Every job is: connect → find the UART RX characteristic → write the packets →
/// disconnect right away, so other climbers' phones can reach the board.
/// Every step and error goes to `log`.
@Observable
final class BoardManager: NSObject {
    enum Status: Equatable {
        case idle
        case connecting
        case sending
        case lit
        case cleared
        case failed(String)
    }

    enum JobKind: String {
        case light = "Light it"
        case clear = "Clear"
    }

    /// How long a whole job may take before we give up.
    static let jobTimeout: Duration = .seconds(15)
    /// Pause after the last write before disconnecting, so the box has the data.
    static let disconnectDelay: Duration = .milliseconds(400)

    private(set) var status: Status = .idle
    private(set) var lastJob: JobKind?
    private(set) var discovered: [DiscoveredBoard] = []
    private(set) var isScanning = false
    private(set) var bluetoothState: CBManagerState = .unknown

    let log: BluetoothLog
    let settings: AppSettings

    private struct Job {
        let id = UUID()
        let kind: JobKind
        let packets: [Data]
        var next = 0
    }

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var job: Job?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var rxCharacteristic: CBCharacteristic?
    @ObservationIgnored private var writeType: CBCharacteristicWriteType = .withResponse
    @ObservationIgnored private var searchingForJob = false
    @ObservationIgnored private var wantsDiscovery = false
    @ObservationIgnored private var loggedDevices: Set<UUID> = []
    /// Core Bluetooth needs strong references to peripherals we may connect to.
    @ObservationIgnored private var knownPeripherals: [UUID: CBPeripheral] = [:]

    private var uartService: CBUUID { CBUUID(string: BoardProtocol.uartServiceUUID) }
    private var rxUUID: CBUUID { CBUUID(string: BoardProtocol.rxCharacteristicUUID) }

    init(settings: AppSettings, log: BluetoothLog = BluetoothLog()) {
        self.settings = settings
        self.log = log
        super.init()
    }

    var isBusy: Bool { job != nil }

    // MARK: - Public actions

    /// Lights a problem on the board.
    func light(_ holds: [Hold]) {
        let message = BoardProtocol.message(for: holds)
        start(.light, message: message)
    }

    /// Turns all the lights off.
    func clearBoard() {
        start(.clear, message: BoardProtocol.clearMessage)
    }

    /// Back to idle (for example after moving to another problem).
    func resetStatus() {
        guard job == nil else { return }
        status = .idle
    }

    /// Starts listing nearby LED boxes for Find board.
    func startScan() {
        wantsDiscovery = true
        discovered = []
        loggedDevices = []
        let central = ensureCentral()
        if central.state == .poweredOn {
            beginScan()
        } else {
            log.add("Scan requested; waiting for Bluetooth (\(Self.describe(central.state)))")
        }
    }

    func stopScan() {
        wantsDiscovery = false
        if !searchingForJob {
            endScan()
        }
    }

    /// Saves a box so later sessions connect to it automatically.
    func save(_ board: DiscoveredBoard) {
        settings.boardID = board.id.uuidString
        settings.boardName = board.name
        log.add("Saved board \(board.name) (\(board.id.uuidString))")
    }

    // MARK: - Jobs

    private func start(_ kind: JobKind, message: String) {
        if let job {
            log.error("\(kind.rawValue) ignored: still busy with \(job.kind.rawValue)")
            return
        }
        let packets = BoardProtocol.packets(problem: message, flags: settings.bleFlags)
        job = Job(kind: kind, packets: packets)
        lastJob = kind
        status = .connecting
        log.add("\(kind.rawValue): message \(message)")
        if !settings.bleFlags.isEmpty {
            log.add("Flags packet first: ~\(settings.bleFlags)*")
        }
        log.add("Split into \(packets.count) packet(s) of ≤\(BoardProtocol.defaultPacketLength) bytes")
        startTimeout()

        let central = ensureCentral()
        if central.state == .poweredOn {
            connectForJob()
        } else {
            log.add("Waiting for Bluetooth (\(Self.describe(central.state)))")
            failIfUnusable(central.state)
        }
    }

    private func connectForJob() {
        guard job != nil, peripheral == nil, let central else { return }
        if let idString = settings.boardID, let id = UUID(uuidString: idString) {
            if let known = central.retrievePeripherals(withIdentifiers: [id]).first {
                log.add("Saved board found by the system")
                connect(known)
                return
            }
            log.add("Saved board not known yet; scanning for it")
        } else {
            log.add("No saved board; scanning for the first LED box")
        }
        searchingForJob = true
        beginScan()
    }

    private func connect(_ target: CBPeripheral) {
        guard let central else { return }
        peripheral = target
        knownPeripherals[target.identifier] = target
        target.delegate = self
        log.add("Connecting to \(target.name ?? "unnamed") (\(target.identifier.uuidString))")
        central.connect(target, options: nil)
    }

    private func writeNext() {
        guard var job, let peripheral, let rxCharacteristic else { return }
        while job.next < job.packets.count {
            if writeType == .withoutResponse && !peripheral.canSendWriteWithoutResponse {
                // Wait for peripheralIsReady(toSendWriteWithoutResponse:).
                self.job = job
                return
            }
            let packet = job.packets[job.next]
            let text = String(decoding: packet, as: UTF8.self)
            log.add("Write \(job.next + 1)/\(job.packets.count): \"\(text)\"")
            peripheral.writeValue(packet, for: rxCharacteristic, type: writeType)
            if writeType == .withResponse {
                // Wait for didWriteValueFor before sending the next packet.
                self.job = job
                return
            }
            job.next += 1
        }
        self.job = job
        finishWrites()
    }

    private func finishWrites() {
        guard let job else { return }
        log.add("All \(job.packets.count) packet(s) written")
        let jobID = job.id
        Task { [weak self] in
            try? await Task.sleep(for: Self.disconnectDelay)
            guard let self, self.job?.id == jobID else { return }
            self.complete()
        }
    }

    private func complete() {
        guard let job else { return }
        status = job.kind == .light ? .lit : .cleared
        log.add("\(job.kind.rawValue) done; disconnecting so others can use the board")
        endJob()
    }

    private func fail(_ message: String) {
        guard job != nil else { return }
        log.error(message)
        status = .failed(message)
        endJob()
    }

    private func endJob() {
        job = nil
        rxCharacteristic = nil
        if searchingForJob {
            searchingForJob = false
            if !wantsDiscovery { endScan() }
        }
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
    }

    private func startTimeout() {
        guard let jobID = job?.id else { return }
        Task { [weak self] in
            try? await Task.sleep(for: Self.jobTimeout)
            guard let self, self.job?.id == jobID else { return }
            self.fail("Timed out: the board didn't answer within \(Self.jobTimeout.components.seconds) s")
        }
    }

    private func failIfUnusable(_ state: CBManagerState) {
        switch state {
        case .unsupported:
            fail("Bluetooth isn't supported here (the simulator has no Bluetooth)")
        case .unauthorized:
            fail("Bluetooth permission is off: Settings › Privacy › Bluetooth › Moondance")
        case .poweredOff:
            fail("Bluetooth is turned off")
        default:
            break
        }
    }

    // MARK: - Scanning

    private func ensureCentral() -> CBCentralManager {
        if let central { return central }
        log.add("Starting Bluetooth")
        let created = CBCentralManager(delegate: self, queue: nil)
        central = created
        return created
    }

    private func beginScan() {
        guard let central, central.state == .poweredOn else { return }
        if central.isScanning { return }
        // No service filter: newer boxes might not advertise the UART service.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
        log.add("Scanning…")
    }

    private func endScan() {
        guard let central, isScanning else { return }
        central.stopScan()
        isScanning = false
        log.add("Scan stopped")
    }

    private func handleDiscovery(_ found: CBPeripheral, advertisement: [String: Any], rssi: Int) {
        let name = advertisement[CBAdvertisementDataLocalNameKey] as? String ?? found.name ?? "Unnamed device"
        let services = advertisement[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let looksLikeBoard = services.contains(uartService) || name.localizedCaseInsensitiveContains("moon")

        if looksLikeBoard || settings.showAllDevices {
            knownPeripherals[found.identifier] = found
            if !loggedDevices.contains(found.identifier) {
                loggedDevices.insert(found.identifier)
                var details = "Found \"\(name)\" rssi \(rssi) id \(found.identifier.uuidString)"
                if !services.isEmpty {
                    details += " services \(services.map(\.uuidString).joined(separator: ","))"
                }
                if let maker = advertisement[CBAdvertisementDataManufacturerDataKey] as? Data {
                    details += " maker data \(maker.map { String(format: "%02x", $0) }.joined())"
                }
                log.add(details)
            }
            let board = DiscoveredBoard(id: found.identifier, name: name, rssi: rssi, looksLikeBoard: looksLikeBoard)
            if let index = discovered.firstIndex(where: { $0.id == board.id }) {
                discovered[index] = board
            } else {
                discovered.append(board)
            }
            discovered.sort { ($0.looksLikeBoard ? 1 : 0, $0.rssi) > ($1.looksLikeBoard ? 1 : 0, $1.rssi) }
        }

        guard searchingForJob, job != nil, peripheral == nil else { return }
        let matches: Bool
        if let saved = settings.boardID {
            matches = found.identifier.uuidString == saved
        } else {
            matches = looksLikeBoard
        }
        if matches {
            searchingForJob = false
            if !wantsDiscovery { endScan() }
            connect(found)
        }
    }

    static func describe(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: "unknown"
        case .resetting: "resetting"
        case .unsupported: "unsupported"
        case .unauthorized: "not allowed"
        case .poweredOff: "off"
        case .poweredOn: "on"
        @unknown default: "state \(state.rawValue)"
        }
    }

    static func describe(_ properties: CBCharacteristicProperties) -> String {
        var names: [String] = []
        if properties.contains(.read) { names.append("read") }
        if properties.contains(.write) { names.append("write") }
        if properties.contains(.writeWithoutResponse) { names.append("writeNoResponse") }
        if properties.contains(.notify) { names.append("notify") }
        if properties.contains(.indicate) { names.append("indicate") }
        return names.isEmpty ? "none" : names.joined(separator: "+")
    }
}

// MARK: - CBCentralManagerDelegate

extension BoardManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            let state = central.state
            bluetoothState = state
            log.add("Bluetooth is \(Self.describe(state))", isError: state != .poweredOn && state != .unknown && state != .resetting)
            if state == .poweredOn {
                if job != nil { connectForJob() }
                if wantsDiscovery { beginScan() }
            } else {
                isScanning = false
                failIfUnusable(state)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            handleDiscovery(peripheral, advertisement: advertisementData, rssi: rssi)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            guard peripheral === self.peripheral else { return }
            log.add("Connected; discovering services")
            status = .sending
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral === self.peripheral else { return }
            fail("Couldn't connect: \(error?.localizedDescription ?? "no reason given")")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        MainActor.assumeIsolated {
            if let error {
                log.add("Disconnected: \(error.localizedDescription)")
            } else {
                log.add("Disconnected")
            }
            if peripheral === self.peripheral {
                fail("The board disconnected before the problem was sent")
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BoardManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral === self.peripheral else { return }
            if let error {
                fail("Service discovery failed: \(error.localizedDescription)")
                return
            }
            let services = peripheral.services ?? []
            log.add("Services: \(services.map(\.uuid.uuidString).joined(separator: ", "))")
            guard let uart = services.first(where: { $0.uuid == uartService }) else {
                fail("The board has no UART service (\(BoardProtocol.uartServiceUUID))")
                return
            }
            peripheral.discoverCharacteristics(nil, for: uart)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral === self.peripheral else { return }
            if let error {
                fail("Characteristic discovery failed: \(error.localizedDescription)")
                return
            }
            let characteristics = service.characteristics ?? []
            for characteristic in characteristics {
                log.add("Characteristic \(characteristic.uuid.uuidString): \(Self.describe(characteristic.properties))")
            }
            guard let rx = characteristics.first(where: { $0.uuid == rxUUID }) else {
                fail("No RX characteristic (\(BoardProtocol.rxCharacteristicUUID))")
                return
            }
            if rx.properties.contains(.write) {
                writeType = .withResponse
            } else if rx.properties.contains(.writeWithoutResponse) {
                writeType = .withoutResponse
            } else {
                fail("The RX characteristic can't be written to")
                return
            }
            rxCharacteristic = rx
            let maxLength = peripheral.maximumWriteValueLength(for: writeType)
            log.add("Writing \(writeType == .withResponse ? "with" : "without") response; max write \(maxLength) bytes")
            writeNext()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral === self.peripheral, var job else { return }
            if let error {
                fail("Write \(job.next + 1) failed: \(error.localizedDescription)")
                return
            }
            job.next += 1
            self.job = job
            writeNext()
        }
    }

    nonisolated func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            guard peripheral === self.peripheral else { return }
            writeNext()
        }
    }
}
