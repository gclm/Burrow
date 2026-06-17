//
//  PortsView.swift
//  Burrow
//
//  Port / connection inspector pane (roadmap C.10, extended): a native
//  `lsof -i`-style table. Lists listening sockets AND established connections
//  (with their remote endpoint), labels well-known ports with their service,
//  flags port conflicts, and offers a confirm-gated Quit (SIGTERM) on the
//  user's own processes only — root/other-user sockets stay read-only.
//
//  NOTE (hand-test): native enumeration + a real kill — verify the list +
//  remote endpoints vs `lsof -i -P` and that Quit only targets your own procs.
//

import SwiftUI
import Darwin

struct PortsView: View {
    var isActive: Bool = true

    @State private var conns: [ListeningPort] = []
    @State private var filter: PortInspector.Filter = .all
    @State private var query = ""
    @State private var killTarget: ListeningPort?
    @State private var loaded = false
    private let uid = Int(getuid())

    private var conflicts: Set<Int> { PortInspector.conflicts(conns) }
    private var rows: [ListeningPort] { PortInspector.filter(conns, filter, query: query) }

    var body: some View {
        VStack(spacing: 0) {
            toolbar.padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
            Rectangle().fill(Brand.hairline).frame(height: 1)
            columnHeader.padding(.horizontal, 18).padding(.vertical, 7)
            Rectangle().fill(Brand.hairline).frame(height: 1)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row($0) }
                    if loaded, rows.isEmpty {
                        Text(NSLocalizedString("No matching ports.", comment: ""))
                            .font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { if isActive { reload() } }
        .onChange(of: isActive) { _, now in if now { reload() } }
        .confirmationDialog(
            NSLocalizedString("Quit this process?", comment: ""),
            isPresented: Binding(get: { killTarget != nil }, set: { if !$0 { killTarget = nil } }),
            presenting: killTarget
        ) { p in
            Button(NSLocalizedString("Quit", comment: ""), role: .destructive) {
                _ = kill(pid_t(p.pid), SIGTERM); reload()
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: { p in
            Text("\(p.process) (pid \(p.pid)) — port \(p.port)")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(PortInspector.Filter.allCases, id: \.self) { f in
                    seg(f)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.black.opacity(0.22)))
            .overlay(Capsule().strokeBorder(Brand.hairline, lineWidth: 1))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(Brand.textTertiary)
                TextField(NSLocalizedString("port, process, service…", comment: ""), text: $query)
                    .textFieldStyle(.plain).font(Brand.sans(12)).frame(width: 160)
            }
            Button { reload() } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Brand.textSecondary)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Refresh", comment: ""))
        }
    }

    private func seg(_ f: PortInspector.Filter) -> some View {
        let on = filter == f
        let label: String = {
            switch f {
            case .all: return NSLocalizedString("All", comment: "")
            case .listening: return NSLocalizedString("Listening", comment: "")
            case .established: return NSLocalizedString("Established", comment: "")
            }
        }()
        return Button { filter = f } label: {
            Text(label).font(Brand.mono(11, on ? .semibold : .regular))
                .foregroundStyle(on ? .black : Brand.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background { if on { Capsule().fill(.white) } }
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("PORT", comment: "")).frame(width: 96, alignment: .leading)
            Text(NSLocalizedString("PROCESS", comment: "")).frame(maxWidth: .infinity, alignment: .leading)
            Text(NSLocalizedString("PEER", comment: "")).frame(width: 200, alignment: .leading)
            Spacer().frame(width: 56)
        }
        .font(Brand.mono(9, .bold)).tracking(0.6).foregroundStyle(Brand.textTertiary)
    }

    @ViewBuilder private func row(_ p: ListeningPort) -> some View {
        let conflicted = p.state == .listen && conflicts.contains(p.port)
        HStack(spacing: 12) {
            // Port + proto + service
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(p.port)").font(Brand.mono(13, .bold)).foregroundStyle(Brand.textPrimary)
                    Text(p.proto).font(Brand.mono(9)).foregroundStyle(Brand.textTertiary)
                }
                if let svc = PortLookup.service(for: p.port) {
                    Text(svc).font(Brand.mono(9)).foregroundStyle(Brand.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 96, alignment: .leading)

            // Process + pid (+ conflict badge)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(p.process).font(Brand.sans(13, .medium)).foregroundStyle(Brand.textPrimary)
                        .lineLimit(1).truncationMode(.middle)
                    if conflicted {
                        Text(NSLocalizedString("conflict", comment: ""))
                            .font(Brand.mono(9, .medium)).foregroundStyle(Brand.amber)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Capsule().fill(Brand.amber.opacity(0.16)))
                    }
                }
                Text("pid \(p.pid)").font(Brand.mono(10)).foregroundStyle(Brand.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Peer: remote endpoint for established, state chip for listen
            Group {
                if let remote = p.remoteDisplay {
                    Text(remote).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                } else {
                    Chip(text: "listening", color: Brand.green)
                }
            }
            .frame(width: 200, alignment: .leading)

            // Quit (owned listeners/connections only)
            Group {
                if PortInspector.isKillable(p, currentUID: uid) {
                    Button(NSLocalizedString("Quit", comment: "")) { killTarget = p }
                        .buttonStyle(.plain)
                        .font(Brand.sans(11, .semibold)).foregroundStyle(Brand.red)
                }
            }
            .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.hairline).frame(height: 1) }
    }

    private func reload() {
        Task.detached(priority: .userInitiated) {
            let found = PortEnumerator.connections(includeEstablished: true)
            await MainActor.run { conns = found; loaded = true }
        }
    }
}
