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
///
/// The box takes one connection at a time and stops advertising while someone is
/// connected. So a job first listens for the box's advertising and only connects
/// once it hears it. If it doesn't hear it, someone else has the board and we give
/// up instead of leaving a connection request waiting, which would grab the board
/// the moment they let go.
@Observable
final class BoardManager: NSObject {
    enum Status: Equatable {
        case idle
        case connecting
        case sending
        case lit
        case cleared
        case failed(BoardFailure)
    }

    enum JobKind: String {
        case light = "Light it"
        case clear = "Clear"
    }

    /// How long a whole job may take before we give up.
    static let jobTimeout: Duration = .seconds(15)
    /// How long to listen for the box advertising before deciding it's busy.
    static let advertisingWindow: Duration = .seconds(3)
    /// How long a connection attempt may wait before we cancel it, so it can't
    /// take the board from someone later.
    static let connectTimeout: Duration = .seconds(4)
    /// Pause after the last write before disconnecting, so the box has the data.
    static let disconnectDelay: Duration = .milliseconds(400)

    private(set) var status: Status = .idle
    private(set) var lastJob: JobKind?
    private(set) var discovered: [DiscoveredBoard] = []
    private(set) var isScanning = false
    private(set) var bluetoothState: CBManagerState = .unknown

    let log: BluetoothLog
    let settings: AppSettings
    /// Called when a job ends (lit, cleared or failed), for banners and haptics.
    @ObservationIgnored var onJobEnded: ((Status) -> Void)?

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

    #if DEBUG
    /// Screenshots and tests only: pretend a job ended this way.
    func debugSetStatus(_ status: Status, lastJob: JobKind = .light) {
        self.status = status
        self.lastJob = lastJob
    }

    /// Screenshots only: two fake boxes in the Find board list.
    func debugAddDemoBoards() {
        discovered = [
            DiscoveredBoard(id: UUID(), name: "MoonBoard 482910375561", rssi: -58, looksLikeBoard: true),
            DiscoveredBoard(id: UUID(), name: "MoonBoard 120394857712", rssi: -86, looksLikeBoard: true),
        ]
    }
    #endif

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

    /// Listens for the box's advertising, then connects (see the type comment).
    private func connectForJob() {
        guard let jobID = job?.id, peripheral == nil, central != nil, !searchingForJob else { return }
        if settings.boardID != nil {
            log.add("Listening for the saved board")
        } else {
            log.add("No saved board; listening for the first LED box")
        }
        searchingForJob = true
        beginScan()
        Task { [weak self] in
            try? await Task.sleep(for: Self.advertisingWindow)
            guard let self, self.job?.id == jobID, self.searchingForJob, self.peripheral == nil else { return }
            self.fail(.notAdvertising(seconds: Self.advertisingWindow.components.seconds))
        }
    }

    private func connect(_ target: CBPeripheral) {
        guard let central, let jobID = job?.id else { return }
        peripheral = target
        knownPeripherals[target.identifier] = target
        target.delegate = self
        log.add("Connecting to \(target.name ?? "unnamed") (\(target.identifier.uuidString))")
        central.connect(target, options: nil)
        Task { [weak self] in
            try? await Task.sleep(for: Self.connectTimeout)
            guard let self, self.job?.id == jobID, self.status == .connecting else { return }
            self.fail(.connectTimedOut(seconds: Self.connectTimeout.components.seconds))
        }
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
        onJobEnded?(status)
    }

    private func fail(_ failure: BoardFailure) {
        guard job != nil else { return }
        log.error(failure.logText)
        status = .failed(failure)
        endJob()
        onJobEnded?(status)
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
            self.fail(.timedOut(seconds: Self.jobTimeout.components.seconds))
        }
    }

    private func failIfUnusable(_ state: CBManagerState) {
        switch state {
        case .unsupported:
            fail(.bluetoothUnavailable)
        case .unauthorized:
            fail(.bluetoothNotAllowed)
        case .poweredOff:
            fail(.bluetoothOff)
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
            fail(.connectFailed(error?.localizedDescription ?? "no reason given"))
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
                fail(.disconnected)
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
                fail(.discoveryFailed("services: \(error.localizedDescription)"))
                return
            }
            let services = peripheral.services ?? []
            log.add("Services: \(services.map(\.uuid.uuidString).joined(separator: ", "))")
            guard let uart = services.first(where: { $0.uuid == uartService }) else {
                fail(.serviceMissing)
                return
            }
            peripheral.discoverCharacteristics(nil, for: uart)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral === self.peripheral else { return }
            if let error {
                fail(.discoveryFailed("characteristics: \(error.localizedDescription)"))
                return
            }
            let characteristics = service.characteristics ?? []
            for characteristic in characteristics {
                log.add("Characteristic \(characteristic.uuid.uuidString): \(Self.describe(characteristic.properties))")
            }
            guard let rx = characteristics.first(where: { $0.uuid == rxUUID }) else {
                fail(.characteristicMissing)
                return
            }
            if rx.properties.contains(.write) {
                writeType = .withResponse
            } else if rx.properties.contains(.writeWithoutResponse) {
                writeType = .withoutResponse
            } else {
                fail(.notWritable)
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
                fail(.writeFailed(packet: job.next + 1, reason: error.localizedDescription))
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
