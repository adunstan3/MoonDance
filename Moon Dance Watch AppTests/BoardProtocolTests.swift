import Foundation
import Testing
@testable import Moon_Dance_Watch_App

struct GridPositionTests {
    @Test func parsesNames() {
        #expect(GridPosition("A1")?.column == 0)
        #expect(GridPosition("A1")?.row == 1)
        #expect(GridPosition("k18")?.column == 10)
        #expect(GridPosition("K18")?.row == 18)
        #expect(GridPosition("D15")?.name == "D15")
    }

    @Test func rejectsOffGridNames() {
        #expect(GridPosition("L1") == nil)
        #expect(GridPosition("A0") == nil)
        #expect(GridPosition("A19") == nil)
        #expect(GridPosition("") == nil)
        #expect(GridPosition("5A") == nil)
    }
}

struct BoardProtocolTests {
    @Test func ledNumbersSnakeThroughColumns() throws {
        func number(_ name: String) throws -> Int {
            BoardProtocol.ledNumber(for: try #require(GridPosition(name)))
        }
        #expect(try number("A1") == 0)
        #expect(try number("A18") == 17)
        #expect(try number("B18") == 18)
        #expect(try number("B1") == 35)
        #expect(try number("C1") == 36)
        #expect(try number("K1") == 180)
        #expect(try number("K18") == 197)
    }

    /// Every one of the 198 positions round-trips through the emulator's maths.
    @Test func matchesEmulatorPositionTrans() throws {
        var seen = Set<Int>()
        for column in 0..<GridPosition.columns {
            for row in 1...GridPosition.rows {
                let position = try #require(GridPosition(column: column, row: row))
                let number = BoardProtocol.ledNumber(for: position)
                #expect(BoardProtocol.position(forLedNumber: number) == position)
                seen.insert(number)
            }
        }
        #expect(seen == Set(0..<198))
    }

    @Test func testProblemMessage() {
        // D5=67, F4=104, E8=79, H10=134, G13=120, D15=57, F18=90
        #expect(BoardProtocol.message(for: BoardProtocol.testProblem) == "l#S67,S104,P79,P134,P120,P57,E90#")
    }

    @Test func skipsUnreadableHolds() {
        let holds = [Hold(position: "A1", role: .start), Hold(position: "Z99", role: .hand)]
        #expect(BoardProtocol.message(for: holds) == "l#S0#")
    }

    @Test func packetsAreAtMost20BytesAndRejoin() {
        let message = BoardProtocol.message(for: BoardProtocol.testProblem)
        let packets = BoardProtocol.packets(for: message)
        #expect(packets.allSatisfy { $0.count <= 20 })
        #expect(packets.count == 2)
        let joined = packets.reduce(Data(), +)
        #expect(String(decoding: joined, as: UTF8.self) == message)
    }

    @Test func shortMessageIsOnePacket() {
        #expect(BoardProtocol.packets(for: BoardProtocol.clearMessage).count == 1)
    }

    @Test func flagsPacketComesFirst() {
        let packets = BoardProtocol.packets(problem: "l#S0#", flags: "D")
        #expect(packets.map { String(decoding: $0, as: UTF8.self) } == ["~D*", "l#S0#"])
        #expect(BoardProtocol.packets(problem: "l#S0#", flags: "").count == 1)
    }
}
