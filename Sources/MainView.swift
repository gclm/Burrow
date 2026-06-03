//
//  MainView.swift
//  Burrow
//
//  Single-window shell that replaces the per-feature windows from
//  v0.2 (History / DiskMap / Cleanup / Settings each had its own
//  NSWindow). One main window + sidebar = one cohesive app instead of
//  four floating utilities.
//
//  Sidebar selection drives the content area through a small enum so
//  the popover can also navigate by setting `selection` directly
//  ("Open Burrow → History" deep-link works without a separate API).
//
//  NavigationSplitView's `.sidebar` column gets the system vibrancy
//  treatment for free; we just style the rows. Content area is a
//  switch on `selection`, no further routing layer.
//

import SwiftUI

enum BurrowSection: Hashable, CaseIterable, Identifiable {
    case overview, history, diskMap, cleanup, settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .history:  return "History"
        case .diskMap:  return "Disk Map"
        case .cleanup:  return "Cleanup"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .history:  return "chart.line.uptrend.xyaxis"
        case .diskMap:  return "square.grid.3x3.fill"
        case .cleanup:  return "trash"
        case .settings: return "gearshape"
        }
    }

    /// One-line purpose statement under the sidebar label. Helps a
    /// first-time user understand what each tab does without
    /// committing to a click.
    var subtitle: String {
        switch self {
        case .overview: return "Current snapshot at a glance"
        case .history:  return "Charts + top processes over time"
        case .diskMap:  return "Treemap of disk usage"
        case .cleanup:  return "Free space, safely"
        case .settings: return "Retention, sampling, MCP"
        }
    }
}

@available(macOS 14.0, *)
struct MainView: View {
    let db: DB
    let sampler: Sampler
    weak var delegate: AppDelegate?
    var initialSelection: BurrowSection = .overview

    @State private var selection: BurrowSection

    init(db: DB, sampler: Sampler, delegate: AppDelegate?,
         initialSelection: BurrowSection = .overview) {
        self.db = db
        self.sampler = sampler
        self.delegate = delegate
        self.initialSelection = initialSelection
        // @State initial value via _selection — the parameter is the
        // tab to land on when the window opens (overview by default,
        // overridden when popover deep-links).
        self._selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 196, ideal: 220, max: 260)
        } detail: {
            content
                .frame(minWidth: 720)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(BurrowSection.allCases, selection: $selection) { section in
            sidebarRow(for: section)
                .tag(section)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            // Branded header — small, doesn't compete with the row
            // labels but anchors the sidebar visually.
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.Colour.accent)
                Text("Burrow").font(Theme.Font.cardTitle)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private func sidebarRow(for section: BurrowSection) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: section.icon)
                .frame(width: 18, alignment: .center)
                .foregroundStyle(self.selection == section ? Theme.Colour.accent : Theme.Colour.textSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(Theme.Font.body)
                Text(section.subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colour.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch self.selection {
        case .overview:
            OverviewView(db: db, sampler: sampler) {
                self.selection = $0
            }
        case .history:
            HistoryView(db: db)
        case .diskMap:
            DiskMapView()
        case .cleanup:
            CleanupView()
        case .settings:
            SettingsView(onRunMaintenance: { [weak delegate] in
                delegate?.maintenance?.runNow()
            })
        }
    }
}
