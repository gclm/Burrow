import XCTest
@testable import Burrow

final class MachOArchTests: XCTestCase {
    func testThinArm64BigEndian() {
        let h: [UInt8] = [0xFE, 0xED, 0xFA, 0xCF, 0x01, 0x00, 0x00, 0x0C]
        XCTAssertEqual(MachOArch.archs(fromHeader: h), ["arm64"])
        XCTAssertEqual(MachOArch.label(MachOArch.archs(fromHeader: h)), "arm64")
    }

    func testThinX86LittleEndian() {
        // 0xCFFAEDFE magic → cputype fields are little-endian; x86_64 = 0x01000007.
        let h: [UInt8] = [0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01]
        XCTAssertEqual(MachOArch.archs(fromHeader: h), ["x86_64"])
    }

    func testFatUniversal() {
        var h: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x02]  // FAT_MAGIC, 2 slices
        h += [0x01, 0x00, 0x00, 0x0C] + [UInt8](repeating: 0, count: 16)    // slice 0: arm64 (stride 20)
        h += [0x01, 0x00, 0x00, 0x07] + [UInt8](repeating: 0, count: 16)    // slice 1: x86_64
        XCTAssertEqual(MachOArch.archs(fromHeader: h), ["arm64", "x86_64"])
        XCTAssertEqual(MachOArch.label(MachOArch.archs(fromHeader: h)), "Universal (arm64, x86_64)")
    }

    func testNotMachO() {
        XCTAssertEqual(MachOArch.archs(fromHeader: [0x7F, 0x45, 0x4C, 0x46, 0, 0, 0, 0]), [])  // ELF
        XCTAssertEqual(MachOArch.label([]), "")
    }
}
