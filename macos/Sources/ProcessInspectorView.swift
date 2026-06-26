//
//  ProcessInspectorView.swift
//  Burrow
//
//  Per-process inspector (PRD §α Process Inspector): where the process was
//  launched from (ProcessOrigin — a pure parent-chain walk), its executable
//  path, and whether that binary still exists on disk (a "deleted/replaced
//  since launch" signal — the cheap, honest part of BinaryIntegrity that needs
//  no launch-inode read). Presented as a sheet from the process table's row
//  menu. The classification logic is pure + tested (ProcessOriginTests); this
//  view only renders it.
//

import SwiftUI
import AppKit

/// Identifiable wrapper so `.sheet(item:)` can drive the inspector without
/// making the widely-Codable `ProcessInfo` itself Identifiable.
struct ProcessInspectTarget: Identifiable {
    let proc: ProcessInfo
    var id: Int { proc.pid }
}

struct ProcessInspectorView: View {
    let proc: ProcessInfo
    /// The current process set — the parent-chain map ProcessOrigin walks.
    let processes: [ProcessInfo]
    @Environment(\.dismiss) private var dismiss

    private var table: [Int: ProcessOrigin.Info] {
        Dictionary(processes.map { ($0.pid, ProcessOrigin.Info(name: $0.name, ppid: $0.ppid ?? 0)) },
                   uniquingKeysWith: { a, _ in a })
    }
    private var origin: ProcessOrigin.Origin { ProcessOrigin.classify(pid: proc.pid, table: table) }
    private var path: String? { ProcessActions.executablePath(pid: proc.pid) }
    private var binaryMissing: Bool {
        guard let path else { return false }
        return !FileManager.default.fileExists(atPath: path)
    }
    private var parentName: String? { proc.ppid.flatMap { table[$0]?.name } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                AppIconView(proc: proc).frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(proc.name).font(Brand.sans(15, .semibold)).foregroundStyle(Brand.textPrimary)
                    Text(verbatim: "PID \(proc.pid)").font(Brand.mono(11)).foregroundStyle(Brand.textTertiary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Brand.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("Close", comment: ""))
            }

            VStack(alignment: .leading, spacing: 10) {
                field("ORIGIN", originText, glyph: originGlyph, tint: originTint)
                if let parentName {
                    field("PARENT", "\(parentName) (PID \(proc.ppid ?? 0))",
                          glyph: "arrow.up.right", tint: Brand.textSecondary)
                }
                field("PROGRAM", path ?? NSLocalizedString("Unknown", comment: ""),
                      glyph: binaryMissing ? "exclamationmark.triangle.fill" : "checkmark.seal",
                      tint: binaryMissing ? Brand.red : Brand.green, mono: true)
                if binaryMissing {
                    Text(NSLocalizedString("The program file no longer exists on disk — it was deleted or replaced after this process started.", comment: ""))
                        .font(Brand.mono(10)).foregroundStyle(Brand.red.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                field("CPU", String(format: "%.1f%%", proc.cpu), glyph: "cpu", tint: Brand.textSecondary)
            }

            HStack {
                Spacer()
                if let path {
                    Button(NSLocalizedString("Reveal in Finder", comment: "")) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    .buttonStyle(.plain).font(Brand.sans(12, .semibold)).foregroundStyle(Tool.status.accent)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func field(_ label: String, _ value: String, glyph: String, tint: Color, mono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: glyph).font(.system(size: 12)).foregroundStyle(tint).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString(label, comment: "")).font(Brand.mono(9, .bold)).tracking(0.5)
                    .foregroundStyle(Brand.textTertiary)
                Text(value).font(mono ? Brand.mono(11) : Brand.sans(12)).foregroundStyle(Brand.textPrimary)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private var originText: String {
        switch origin {
        case .login:        return NSLocalizedString("Launched at login / from the Dock", comment: "")
        case .shell(let s): return String(format: NSLocalizedString("Started from a %@ shell", comment: ""), s)
        case .ssh:          return NSLocalizedString("Started over SSH (remote session)", comment: "")
        }
    }
    private var originGlyph: String {
        switch origin {
        case .login: return "person.crop.circle"
        case .shell: return "terminal"
        case .ssh:   return "network"
        }
    }
    private var originTint: Color {
        switch origin {
        case .login: return Brand.green
        case .shell: return Brand.gold
        case .ssh:   return Brand.orange
        }
    }
}
