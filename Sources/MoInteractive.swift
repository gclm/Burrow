//
//  MoInteractive.swift
//  Burrow
//
//  Drives Mole's INTERACTIVE selection TUIs (`mo installer`, `mo purge`)
//  from the GUI so the user can pick WHICH items to remove — and Mole
//  itself does the deletion. Mole exposes no flags/JSON for targeted
//  removal; its only selection is the on-screen checklist. So Burrow runs
//  `mo` in a pseudo-terminal, parses that checklist into a native list,
//  and replays the user's choices as keystrokes (↓ / Space / Enter).
//
//  The pure parts here — parsing a screen and planning keystrokes — are
//  unit-tested. The PTY plumbing (PTYTask / MoInteractiveRunner) is the
//  thin impure seam. Crucially, after sending the toggles we RE-READ the
//  screen and verify the selection matches before pressing Enter, so a
//  parsing/cursor bug can never make Mole delete the wrong thing.
//

import Foundation
import Darwin    // openpty, winsize
import Security  // AuthorizationExecuteWithPrivileges (root scan)

// MARK: - Parsed TUI model

struct MoTUIItem: Equatable {
    let name: String
    let size: String        // as Mole prints it, e.g. "1.26GB"
    let location: String    // e.g. "Desktop"
    let selected: Bool      // ● vs ○
}

struct MoTUIScreen: Equatable {
    let items: [MoTUIItem]
    let cursor: Int          // index with the ➤ marker
    let selectedCount: Int?  // from the "N selected" header, if present
}

enum MoTUI {
    // Glyphs Mole's TUI uses.
    private static let unchecked: Character = "\u{25CB}"  // ○
    private static let checked: Character = "\u{25CF}"    // ●
    private static let cursorMark: Character = "\u{27A4}" // ➤

    /// Parse the LAST rendered frame of a Mole selection TUI. The TUI
    /// redraws the whole list each keystroke; each frame begins with a
    /// "… N selected" header, so resetting on every header leaves us with
    /// the most recent frame's state.
    static func parse(_ raw: String) -> MoTUIScreen {
        let text = stripANSI(raw)
        var items: [MoTUIItem] = []
        var cursor = 0
        var selectedCount: Int?

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.replacingOccurrences(of: "\r", with: "")
            if let n = selectedCountIn(line) {       // header → start a fresh frame
                selectedCount = n
                items = []
                cursor = 0
                continue
            }
            guard let (item, isCursor) = parseItem(line) else { continue }
            if isCursor { cursor = items.count }
            items.append(item)
        }
        return MoTUIScreen(items: items, cursor: cursor, selectedCount: selectedCount)
    }

    /// The indices currently checked (●) in a screen.
    static func selectedIndices(_ screen: MoTUIScreen) -> Set<Int> {
        Set(screen.items.enumerated().filter { $0.element.selected }.map { $0.offset })
    }

    /// Keystrokes to take a FRESH list (cursor at item 0, everything ○) to
    /// exactly `wanted` checked. Walks every item top-to-bottom once,
    /// pressing Space only on wanted ones — deterministic, no cursor math.
    /// `confirm` appends Enter. Does NOT confirm an empty selection.
    static func keystrokesToSelect(_ wanted: Set<Int>, count: Int, confirm: Bool) -> [UInt8] {
        let down: [UInt8] = [0x1b, 0x5b, 0x42]   // ESC [ B
        let space: UInt8 = 0x20
        let enter: UInt8 = 0x0d
        var out: [UInt8] = []
        guard count > 0 else { return out }
        for i in 0..<count {
            if wanted.contains(i) { out.append(space) }
            if i < count - 1 { out.append(contentsOf: down) }
        }
        if confirm && !wanted.isEmpty { out.append(enter) }
        return out
    }

    static let quit: [UInt8] = [0x71]  // 'q'

    /// Total item count from a "[current/total]" header. Mole caps how many
    /// rows it renders (≈50), so on a long list the header total exceeds the
    /// number we can parse — the UI uses this to say "showing N of M".
    static func totalCount(_ raw: String) -> Int? {
        let text = stripANSI(raw)
        guard let r = text.range(of: #"\[\d+/(\d+)\]"#, options: .regularExpression) else { return nil }
        let inside = text[r].dropFirst().dropLast()      // "1/53"
        return Int(inside.split(separator: "/").last.map(String.init) ?? "")
    }

    /// The N from Mole's final confirm screen ("Remove 3 artifacts, 1.2GB" /
    /// "Remove 1 installer"). Used to verify the count before the second Enter.
    static func removalCount(_ raw: String) -> Int? {
        let text = stripANSI(raw)
        guard let r = text.range(of: #"Remove\s+\d+"#, options: .regularExpression) else { return nil }
        return Int(text[r].filter(\.isNumber))
    }

    // MARK: - Parsing helpers

    private static func selectedCountIn(_ line: String) -> Int? {
        guard let r = line.range(of: #"(\d+)\s+selected"#, options: .regularExpression) else { return nil }
        return Int(line[r].split(separator: " ").first ?? "")
    }

    /// Parse one item row → (item, isCursorLine). Returns nil for non-item
    /// lines (header, footer, blanks).
    private static func parseItem(_ line: String) -> (MoTUIItem, Bool)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let markerIdx = trimmed.firstIndex(where: { $0 == checked || $0 == unchecked }) else { return nil }
        let isCursor = trimmed.first == cursorMark
        let selected = trimmed[markerIdx] == checked
        let rest = trimmed[trimmed.index(after: markerIdx)...].trimmingCharacters(in: .whitespaces)
        // rest: "Inkling-0.0.1.dmg                 771KB | Desktop"
        let pipeParts = rest.components(separatedBy: "|")
        let location = pipeParts.count > 1 ? pipeParts[1].trimmingCharacters(in: .whitespaces) : ""
        let left = pipeParts[0].split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard left.count >= 2 else { return nil }
        let size = left.last!
        let name = left.dropLast().joined(separator: " ")
        guard !name.isEmpty else { return nil }
        return (MoTUIItem(name: name, size: size, location: location, selected: selected), isCursor)
    }

    /// Strip CSI escape sequences so the TUI's redraw control codes don't
    /// pollute parsing. (Mirror of CommandRunner.stripAnsi, kept local so
    /// this file is self-contained + testable.)
    static func stripANSI(_ s: String) -> String {
        guard s.contains("\u{1B}") else { return s }
        var out = String(); out.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "\u{1B}", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "[" {
                var j = s.index(i, offsetBy: 2)
                while j < s.endIndex {
                    if let a = s[j].asciiValue, a >= 0x40, a <= 0x7E { j = s.index(after: j); break }
                    j = s.index(after: j)
                }
                i = j; continue
            }
            out.append(s[i]); i = s.index(after: i)
        }
        return out
    }
}

// MARK: - Transport (bridges mo's terminal; as the user, or as root)

/// What `MoInteractiveRunner` needs from whatever is bridging mo's terminal:
/// streamed output (`onData`, on a background queue), an exit signal
/// (`onExit`), and a way to type (`send`) / stop reading / kill it. Two
/// implementations:
///   • `PTYTask`           — runs mo as the user in a pty.
///   • `PrivilegedSession` — runs mo as ROOT via the system auth dialog, so it
///     sits OUTSIDE Burrow's TCC responsibility chain (no per-folder flood).
protocol MoTransport: AnyObject {
    var onData: ((String) -> Void)? { get set }
    var onExit: (@Sendable () -> Void)? { get set }
    var terminationStatus: Int32 { get }
    func send(_ bytes: [UInt8])
    func stopReading()
    func terminate()
}

/// A child process attached to a pseudo-terminal, so a TUI program (Mole's
/// selection screen) believes it's interactive.
final class PTYTask: MoTransport {
    private let proc = Process()
    private var master: FileHandle?

    var onData: ((String) -> Void)?
    var onExit: (@Sendable () -> Void)?
    var terminationStatus: Int32 { proc.terminationStatus }

    func launch(_ executable: String, _ args: [String], cols: UInt16 = 120, rows: UInt16 = 60) throws {
        var amaster: Int32 = 0
        var aslave: Int32 = 0
        var ws = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&amaster, &aslave, nil, nil, &ws) == 0 else {
            throw NSError(domain: "burrow.pty", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "openpty failed"])
        }
        let slave = FileHandle(fileDescriptor: aslave, closeOnDealloc: false)
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = args
        proc.standardInput = slave
        proc.standardOutput = slave
        proc.standardError = slave
        var env = Foundation.ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        proc.environment = env
        proc.terminationHandler = { [weak self] _ in self?.onExit?() }
        let mh = FileHandle(fileDescriptor: amaster, closeOnDealloc: true)
        master = mh
        mh.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty else { return }
            self?.onData?(String(decoding: d, as: UTF8.self))
        }
        // Close the parent's slave fd whether or not the launch succeeds — on a
        // throw the child never starts, so nothing else would ever close it.
        do { try proc.run() }
        catch { close(aslave); throw error }
        close(aslave)   // parent doesn't use the slave end
    }

    func send(_ bytes: [UInt8]) { try? master?.write(contentsOf: Data(bytes)) }
    func stopReading() { master?.readabilityHandler = nil }
    func terminate() { master?.readabilityHandler = nil; if proc.isRunning { proc.terminate() } }
}

/// Runs `mo` as ROOT via AuthorizationServices — the SAME system-auth Clean
/// uses (native dialog, Touch ID; the tool is launched outside Burrow's
/// responsibility chain, so TCC doesn't prompt per folder). `/usr/bin/script`
/// gives mo a real pty so its checklist still renders, and we set `HOME` so it
/// scans the user's dirs, not root's.
///
/// `AuthorizationExecuteWithPrivileges` is long-"deprecated" but functional and
/// needs no code-signing; there's no non-deprecated API that returns a live
/// bidirectional pipe to a root child. `launch` BLOCKS on the auth dialog — run
/// it off the main thread.
final class PrivilegedSession: MoTransport {
    var onData: ((String) -> Void)?
    var onExit: (@Sendable () -> Void)?
    private(set) var terminationStatus: Int32 = 0

    private var authRef: AuthorizationRef?
    private var file: UnsafeMutablePointer<FILE>?
    private var master: FileHandle?

    func launch(mo: String, subcommand: String, home: String) throws {
        var auth: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &auth) == errAuthorizationSuccess, let auth else {
            throw NSError(domain: "burrow.priv", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't start authorization."])
        }
        authRef = auth

        // script -q /dev/null /bin/sh -c "HOME='…' exec '…/mo' <sub>"
        func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let inner = "HOME=\(q(home)) exec \(q(mo)) \(subcommand)"
        let argStrings = ["-q", "/dev/null", "/bin/sh", "-c", inner]
        var cArgs: [UnsafeMutablePointer<CChar>?] = argStrings.map { strdup($0) }
        cArgs.append(nil)
        defer { for p in cArgs { free(p) } }   // AEWP exec'd a copy; safe to free after

        // AuthorizationExecuteWithPrivileges is marked UNAVAILABLE to Swift but is
        // still a live symbol in Security.framework — fetch it via dlsym. It's the
        // only API that returns a live bidirectional pipe to a root child without
        // a code-signed helper.
        typealias AEWP = @convention(c) (
            AuthorizationRef, UnsafePointer<CChar>, AuthorizationFlags,
            UnsafePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
        ) -> OSStatus
        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), "AuthorizationExecuteWithPrivileges") else {
            AuthorizationFree(auth, []); authRef = nil
            throw NSError(domain: "burrow.priv", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Privileged execution isn't available on this system."])
        }
        let aewp = unsafeBitCast(sym, to: AEWP.self)

        var pipe: UnsafeMutablePointer<FILE>?
        let rc = "/usr/bin/script".withCString { tool -> OSStatus in
            cArgs.withUnsafeMutableBufferPointer { buf -> OSStatus in
                aewp(auth, tool, [], buf.baseAddress, &pipe)
            }
        }
        guard rc == errAuthorizationSuccess, let pipe else {
            AuthorizationFree(auth, []); authRef = nil
            throw NSError(domain: "burrow.priv", code: Int(rc),
                          userInfo: [NSLocalizedDescriptionKey: "Administrator access was declined."])
        }
        file = pipe
        let mh = FileHandle(fileDescriptor: fileno(pipe), closeOnDealloc: false)
        master = mh
        mh.readabilityHandler = { [weak self] h in
            let d = h.availableData
            if d.isEmpty {                       // EOF → the root tool exited
                h.readabilityHandler = nil
                self?.onExit?()
                return
            }
            self?.onData?(String(decoding: d, as: UTF8.self))
        }
    }

    func send(_ bytes: [UInt8]) { try? master?.write(contentsOf: Data(bytes)) }
    func stopReading() { master?.readabilityHandler = nil }
    func terminate() {
        master?.readabilityHandler = nil
        if let file { fclose(file); self.file = nil }   // closing the pipe → root tool gets EOF
        if let authRef { AuthorizationFree(authRef, []); self.authRef = nil }
    }
}
