//
//  MoreView.swift
//  CureClock
//
//  Hub for tools and settings: inventory, cost, reports, reminders, settings.
//  iOS 14 safe.
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScreenScaffold("More", subtitle: "Tools, planning & settings") {
            VStack(spacing: 12) {
                NavRow("Bag Inventory", subtitle: store.bagsShortAll > 0 ? "Short \(store.bagsShortAll) bags for current pours" : "Stock covers your pours",
                       systemImage: "shippingbox.fill", tint: store.bagsShortAll > 0 ? Theme.warning : Theme.success) {
                    BagInventoryView()
                }
                NavRow("Cost Estimate", subtitle: "Materials + mixer / pump rental",
                       systemImage: "dollarsign.circle.fill", tint: Theme.accent) {
                    CostEstimateView()
                }
                NavRow("Reports", subtitle: "Export a PDF: volumes, mix, curve, cost",
                       systemImage: "doc.richtext.fill", tint: Theme.water) {
                    ReportsView()
                }
                NavRow("Reminders", subtitle: store.attentionCount > 0 ? "\(store.activeCuringCount) pour(s) still curing" : "Cure & milestone alerts",
                       systemImage: "bell.badge.fill", tint: Theme.accentHi) {
                    RemindersView()
                }
                NavRow("Strength Today", subtitle: "What's safe to do right now",
                       systemImage: "gauge.with.needle.fill", tint: Theme.success) {
                    StrengthTodayView()
                }
                NavRow("Settings", subtitle: "Units, currency, theme, presets, backup",
                       systemImage: "gearshape.fill", tint: Theme.concrete) {
                    SettingsView()
                }
            }
        }
        .navigationBarTitle("More", displayMode: .inline)
    }
}

// MARK: - Logs tab hub

struct LogsHubView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScreenScaffold("Logs", subtitle: "Document the pour & its cure") {
            VStack(spacing: 12) {
                NavRow("Photo Log", subtitle: "\(store.photoLogs.count) photo(s) — pour, formwork, surface",
                       systemImage: "photo.stack.fill", tint: Theme.accent) {
                    PhotoLogView()
                }
                NavRow("Crack Watch", subtitle: store.openCrackCount > 0 ? "\(store.openCrackCount) logged" : "No cracks logged",
                       systemImage: "exclamationmark.triangle.fill",
                       tint: store.openCrackCount > 0 ? Theme.danger : Theme.success) {
                    CrackWatchView()
                }
                NavRow("Weather Note", subtitle: "\(store.weatherNotes.count) day(s) recorded",
                       systemImage: "cloud.sun.fill", tint: Theme.water) {
                    WeatherNoteView()
                }
                NavRow("History", subtitle: "Poured, milestones reached, loaded",
                       systemImage: "clock.arrow.circlepath", tint: Theme.concrete) {
                    HistoryView()
                }
            }
        }
        .navigationBarTitle("Logs", displayMode: .inline)
    }
}
