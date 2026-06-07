//
//  InstallerView.swift
//  Burrow
//
//  The Installers tool — pick which leftover installers to remove, with
//  MOLE doing the deletion. Mole's `installer` is an interactive selection
//  TUI (no flags/JSON for targeted removal), so Burrow runs it in a
//  pseudo-terminal (MoInteractiveRunner), shows Mole's own list as a native
//  checklist, and replays the user's choices as keystrokes — then verifies
//  the on-screen selection before letting Mole confirm. Nothing is removed
//  by Burrow itself.
//

import SwiftUI
import AppKit

// MARK: - Runner (drives Mole's selection TUI)

@MainActor
final class MoInteractiveRunner: ObservableObject {
    enum Phase: Equatable { case scanning, choosing, applying, done(Int32), failed(String) }

    @Published var phase: Phase = .scanning
    @Published var items: [MoTUIItem] = []
    @Published var resultText: String = ""

    let title: String
    private let subcommand: String
    private var pty = PTYTask()
    private var screen = ""        // raw TUI output, pre-confirm
    private var result = ""        // output after Enter (Mole's removal results)
    private var confirmed = false
    private var listReady = false

    init(subcommand: String, title: String) { self.subcommand = subcommand; self.title = title }

    func start() {
        guard let mo = MoleCLI.findExecutable() else { phase = .failed("mo not found"); return }
        pty.onExit = { [weak self] in Task { @MainActor in self?.handleExit() } }
        do { try pty.launch(mo, [subcommand]) }
        catch { phase = .failed("Couldn't start `mo \(subcommand)`."); return }
        pty.master?.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return }
            Task { @MainActor in self?.ingest(s) }
        }
    }

    func rescan() {
        pty.master?.readabilityHandler = nil
        pty.terminate()
        pty = PTYTask()
        screen = ""; result = ""; confirmed = false; listReady = false
        items = []; resultText = ""; phase = .scanning
        start()
    }

    /// Apply selection: toggle the wanted rows, RE-READ the screen, and only
    /// press Enter if the on-screen checks match exactly — otherwise bail
    /// without removing anything.
    func confirm(_ wanted: Set<Int>) {
        guard phase == .choosing, !wanted.isEmpty else { return }
        phase = .applying
        pty.send(MoTUI.keystrokesToSelect(wanted, count: items.count, confirm: false))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.phase == .applying else { return }
            let onScreen = MoTUI.selectedIndices(MoTUI.parse(self.screen))
            if onScreen == wanted {
                self.confirmed = true
                self.pty.send([0x0d])   // Enter → Mole removes exactly these
            } else {
                self.pty.send(MoTUI.quit)
                self.phase = .failed("Couldn't confirm the selection safely (\(onScreen.count)/\(wanted.count) toggled). Nothing was removed — please try again.")
            }
        }
    }

    func cancel() {
        pty.master?.readabilityHandler = nil
        pty.send(MoTUI.quit)
        pty.terminate()
        switch phase { case .done, .failed: break; default: phase = .done(130) }
    }

    private func ingest(_ s: String) {
        if confirmed { result += s; return }
        screen += s
        if !listReady, screen.contains("Enter"), screen.contains("Confirm") {
            let parsed = MoTUI.parse(screen)
            if !parsed.items.isEmpty {
                listReady = true
                items = parsed.items
                phase = .choosing
            }
        }
    }

    private func handleExit() {
        pty.master?.readabilityHandler = nil
        let status = pty.terminationStatus
        if confirmed {
            resultText = MoTUI.stripANSI(result).trimmingCharacters(in: .whitespacesAndNewlines)
            if resultText.isEmpty { resultText = "Done — selected installers moved out by Mole." }
            phase = .done(status)
        } else if !listReady {
            // Exited before a list rendered — usually "nothing to remove".
            phase = .done(status)
        }
        // listReady && !confirmed → we're already in .failed; leave it.
    }
}

// MARK: - View

struct InstallerView: View {
    @StateObject private var runner = MoInteractiveRunner(subcommand: "installer", title: "Installers")
    var isActive: Bool = true
    @State private var selected: Set<Int> = []
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if isActive { startOnce() } }
        .onChange(of: isActive) { _, now in if now { startOnce() } }
    }
    private func startOnce() { guard !started else { return }; started = true; runner.start() }

    @ViewBuilder
    private var content: some View {
        switch runner.phase {
        case .scanning:
            centered { ProgressView("Scanning for installers via Mole…").controlSize(.large)
                .tint(Tool.installer.accent).font(Brand.mono(11)) }
        case .choosing:
            chooser
        case .applying:
            centered { ProgressView("Removing…").controlSize(.large)
                .tint(Tool.installer.accent).font(Brand.mono(11)) }
        case .done(let code):
            doneView(code)
        case .failed(let m):
            messageView(icon: "exclamationmark.triangle", color: Brand.orange, text: m)
        }
    }

    private var chooser: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Installers").font(Brand.serif(18, .medium)).foregroundStyle(Brand.textPrimary)
                Text("\(runner.items.count) found").font(Brand.mono(11)).foregroundStyle(Brand.textTertiary)
                Spacer()
                Button { runner.cancel(); runner.rescan(); selected = [] } label: {
                    Label("Rescan", systemImage: "arrow.clockwise").font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
            Rectangle().fill(Brand.hairline).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(runner.items.enumerated()), id: \.offset) { i, item in
                        MoItemRow(item: item, accent: Tool.installer.accent, selected: selected.contains(i)) {
                            if selected.contains(i) { selected.remove(i) } else { selected.insert(i) }
                        }
                        Rectangle().fill(Brand.hairline).frame(height: 1).padding(.leading, 48)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
            }
            .scrollIndicators(.visible)

            Rectangle().fill(Brand.hairline).frame(height: 1)
            HStack {
                Text(selectionLabel).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                Spacer()
                Button { selected = (selected.count == runner.items.count) ? [] : Set(runner.items.indices) } label: {
                    Text(selected.count == runner.items.count ? "select none" : "select all")
                        .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                }.buttonStyle(.plain).padding(.trailing, 8)
                Button { confirmRemoval() } label: {
                    Text("Remove\(selected.isEmpty ? "" : " (\(selected.count))")")
                        .font(Brand.sans(12, .semibold)).foregroundStyle(selected.isEmpty ? Brand.textTertiary : .white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(selected.isEmpty ? Color.white.opacity(0.06) : Tool.installer.accent))
                }.buttonStyle(.plain).disabled(selected.isEmpty)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
    }

    private var selectionLabel: String {
        selected.isEmpty ? "\(runner.items.count) installers" : "\(selected.count) selected"
    }

    private func confirmRemoval() {
        let targets = selected.sorted().compactMap { runner.items.indices.contains($0) ? runner.items[$0] : nil }
        guard !targets.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \(targets.count) installer\(targets.count == 1 ? "" : "s")?"
        alert.informativeText = "Mole will remove these:\n\n"
            + targets.prefix(12).map { "• \($0.name)" }.joined(separator: "\n")
            + (targets.count > 12 ? "\n… and \(targets.count - 12) more" : "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runner.confirm(selected)
    }

    private func doneView(_ code: Int32) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: code == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle")
                    .foregroundStyle(code == 0 ? Tool.installer.accent : Brand.orange)
                Text(runner.items.isEmpty && runner.resultText.isEmpty ? "No leftover installers found." : "Done.")
                    .font(Brand.sans(14, .semibold)).foregroundStyle(Brand.textPrimary)
                Spacer()
                Button { runner.rescan(); selected = [] } label: {
                    Label("Scan again", systemImage: "arrow.clockwise").font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            Rectangle().fill(Brand.hairline).frame(height: 1)
            if !runner.resultText.isEmpty {
                ScrollView {
                    Text(runner.resultText).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16).textSelection(.enabled)
                }
            } else { Spacer() }
        }
    }

    private func messageView(icon: String, color: Color, text: String) -> some View {
        VStack(spacing: 12) { Spacer()
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(color)
            Text(text).font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            Button { runner.rescan(); selected = [] } label: {
                Label("Try again", systemImage: "arrow.clockwise").font(Brand.mono(11)).foregroundStyle(Tool.installer.accent)
            }.buttonStyle(.plain)
            Spacer(); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func centered<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack { Spacer(); c(); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A selectable row backed by a parsed Mole TUI item.
struct MoItemRow: View {
    let item: MoTUIItem
    let accent: Color
    let selected: Bool
    let onToggle: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox").font(.system(size: 15)).foregroundStyle(Brand.textTertiary).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(Brand.sans(13, .medium)).foregroundStyle(Brand.textPrimary).lineLimit(1)
                Text("\(item.size)\(item.location.isEmpty ? "" : " · \(item.location)")")
                    .font(Brand.mono(10)).foregroundStyle(Brand.textTertiary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17)).foregroundStyle(selected ? accent : Brand.textTertiary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(hover ? Brand.cardFillHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { onToggle() }
    }
}
