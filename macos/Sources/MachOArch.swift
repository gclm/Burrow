//
//  MachOArch.swift
//  Burrow
//
//  Reads the architecture slices of a Mach-O executable for the process
//  inspector's "Format" line (PRD §α 55: native-vs-Rosetta / universal). Pure
//  header parsing — feed the first bytes of the file; the file read is the seam.
//

import Foundation

enum MachOArch {
    // cputype values (cpu.h): high bit 0x01000000 = 64-bit ABI.
    private static let names: [UInt32: String] = [
        0x0100_000C: "arm64",     // CPU_TYPE_ARM64
        0x0100_0007: "x86_64",    // CPU_TYPE_X86_64
        0x0000_0007: "i386",
        0x0000_000C: "arm",
    ]

    /// Arch slice names from a Mach-O / fat header. Empty if not a Mach-O.
    /// Handles thin (MH_MAGIC[_64], both endians) and fat (FAT_MAGIC[_64]).
    static func archs(fromHeader b: [UInt8]) -> [String] {
        guard b.count >= 8 else { return [] }
        let m = be32(b, 0)
        switch m {
        case 0xFEED_FACE, 0xFEED_FACF:                 // thin, big-endian fields
            return names[be32(b, 4)].map { [$0] } ?? ["unknown"]
        case 0xCEFA_EDFE, 0xCFFA_EDFE:                 // thin, little-endian fields
            return names[le32(b, 4)].map { [$0] } ?? ["unknown"]
        case 0xCAFE_BABE, 0xCAFE_BABF:                 // fat (big-endian count + entries)
            let count = Int(be32(b, 4))
            let is64 = m == 0xCAFE_BABF
            let stride = is64 ? 32 : 20
            var out: [String] = []
            for i in 0..<min(count, 16) {
                let off = 8 + i * stride
                guard off + 4 <= b.count else { break }
                out.append(names[be32(b, off)] ?? "unknown")
            }
            return out
        default:
            return []
        }
    }

    /// "arm64" · "x86_64" · "Universal (arm64, x86_64)" · "" — the inspector label.
    static func label(_ archs: [String]) -> String {
        let known = archs.filter { $0 != "unknown" }
        if known.isEmpty { return "" }
        return known.count == 1 ? known[0] : "Universal (\(known.joined(separator: ", ")))"
    }

    /// Read the leading bytes of the executable and resolve its arch label.
    /// The file read is the seam; returns "" when unreadable.
    static func label(path: String) -> String {
        guard let h = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? h.close() }
        let data = (try? h.read(upToCount: 4096)) ?? Data()
        return label(archs(fromHeader: [UInt8](data)))
    }

    private static func be32(_ b: [UInt8], _ o: Int) -> UInt32 {
        guard o + 4 <= b.count else { return 0 }
        return UInt32(b[o]) << 24 | UInt32(b[o+1]) << 16 | UInt32(b[o+2]) << 8 | UInt32(b[o+3])
    }
    private static func le32(_ b: [UInt8], _ o: Int) -> UInt32 {
        guard o + 4 <= b.count else { return 0 }
        return UInt32(b[o+3]) << 24 | UInt32(b[o+2]) << 16 | UInt32(b[o+1]) << 8 | UInt32(b[o])
    }
}
