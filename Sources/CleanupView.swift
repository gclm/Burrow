//
//  CleanupView.swift
//  Burrow
//
//  Wraps `mo clean` in a SwiftUI surface. The interaction is:
//    1. View opens → automatically runs `mo clean --dry-run`,
//       streams stdout to a scrollable text area.
//    2. When the dry run finishes, the "Clean for real" button
//       activates. Until then, only quit/close is possible.
//    3. The real run streams to the same text area; output and exit
//       code stay visible after it ends.
//
//  Why not bind to `mo`'s JSON mode here: `mo clean` doesn't currently
//  emit JSON the way `mo status` does, and the human output is the
//  signal users want to read anyway ("freed X GB" with the path
//  breakdown). The view embeds it verbatim.
//
//  Long-running aspect: `mo clean` can take minutes on a fresh-from-
//  the-airport machine. The Process runs on a utility queue and pipes
//  stdout in chunks back to the view via a published string so we get
//  live progress, not a blocking final dump.
//

import SwiftUI
import AppKit

@MainActor
final class CleanupModel: ObservableObject {
    enum Phase: Equatable {
        case dryRunning, dryReady, running, done(Int32), failed(String)
    }

    @Published var phase: Phase = .dryRunning
    @Published var output: String = ""

    private var task: Process?

    init() {
        self.start(args: ["clean", "--dry-run"], onExit: { [weak self] code in
            self?.phase = code == 0 ? .dryReady : .failed("dry-run exited \(code)")
        })
    }

    func runForReal() {
        // Only kick off the real clean from the post-dry-run state. The
        // earlier draft tried to accept `.done` too so users could
        // "clean again" without reopening the window, but that's
        // brittle: between dry-run and real-run the cache state has
        // changed, and a confirmation from a stale preview is exactly
        // what we want to prevent. Re-opening the window re-runs the
        // dry-run — a clean confirmation each time.
        guard case .dryReady = phase else { return }
        self.output = ""
        self.phase = .running
        self.start(args: ["clean"], onExit: { [weak self] code in
            self?.phase = code == 0 ? .done(code) : .failed("clean exited \(code)")
        })
    }

    func cancel() {
        if let task, task.isRunning { task.terminate() }
    }

    private func start(args: [String], onExit: @escaping (Int32) -> Void) {
        guard let mo = MoleCLI.findExecutable() else {
            self.phase = .failed("mo not found")
            return
        }

        let t = Process()
        t.executableURL = URL(fileURLWithPath: mo)
        t.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        t.standardOutput = outPipe
        t.standardError = errPipe

        // Stream stdout in 4 KB chunks. readabilityHandler fires on the
        // pipe's IO queue, so we hop back to main before mutating the
        // @Published `output`. Stripping ANSI escapes makes the text
        // sane in a SwiftUI Text — `mo` uses lipgloss colour codes
        // which would otherwise show as garbage.
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty, let s = String(data: chunk, encoding: .utf8) else { return }
            let stripped = CleanupModel.stripAnsi(s)
            DispatchQueue.main.async {
                self.output.append(stripped)
            }
        }
        // Merge stderr into the same buffer — `mo`'s diagnostic output
        // is informative ("skipping IN_USE: …") and the user wants it.
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty, let s = String(data: chunk, encoding: .utf8) else { return }
            let stripped = CleanupModel.stripAnsi(s)
            DispatchQueue.main.async {
                self.output.append(stripped)
            }
        }

        t.terminationHandler = { proc in
            // Drain remaining buffered output before reporting exit.
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                onExit(proc.terminationStatus)
            }
        }

        do {
            try t.run()
            self.task = t
        } catch {
            self.phase = .failed("spawn: \(error.localizedDescription)")
        }
    }

    /// Strip CSI escape sequences (`ESC [ ... letter`) so colour codes
    /// from lipgloss don't pollute the SwiftUI Text. We don't try to
    /// render colour — just clean text.
    ///
    /// `nonisolated` because the readability handlers above run on the
    /// pipe's IO queue, not the main actor. The function is pure (no
    /// `self`, no shared mutable state) so being callable from any
    /// isolation domain is safe.
    nonisolated private static func stripAnsi(_ s: String) -> String {
        guard s.contains("\u{1B}") else { return s }
        var out = String()
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "\u{1B}", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "[" {
                // Skip the CSI parameters + final byte.
                var j = s.index(i, offsetBy: 2)
                while j < s.endIndex {
                    let cc = s[j]
                    if cc.asciiValue.map({ $0 >= 0x40 && $0 <= 0x7E }) ?? false {
                        j = s.index(after: j); break
                    }
                    j = s.index(after: j)
                }
                i = j
                continue
            }
            out.append(c); i = s.index(after: i)
        }
        return out
    }
}

@available(macOS 14.0, *)
struct CleanupView: View {
    @StateObject private var model = CleanupModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            Divider()
            ScrollView {
                ScrollViewReader { proxy in
                    Text(model.output.isEmpty ? "Waiting for output…" : model.output)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .id("body")
                        .onChange(of: model.output) { _, _ in
                            // Tail-follow the output as it streams in.
                            proxy.scrollTo("body", anchor: .bottom)
                        }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cleanup").font(.title2.weight(.semibold))
                Text(self.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            actionButtons
        }
    }

    private var subtitle: String {
        switch model.phase {
        case .dryRunning: return "Previewing what `mo clean` would free…"
        case .dryReady:   return "Dry run complete — review then choose Clean for real."
        case .running:    return "Cleaning… do not quit."
        case .done(let c): return "Done (exit \(c))."
        case .failed(let m): return "Failed: \(m)"
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if case .dryRunning = model.phase {
                ProgressView().controlSize(.small)
            } else if case .running = model.phase {
                ProgressView().controlSize(.small)
            }

            Button("Clean for real") { model.runForReal() }
                .keyboardShortcut(.defaultAction)
                .disabled({
                    switch model.phase {
                    case .dryReady: return false
                    default: return true
                    }
                }())
        }
    }
}
