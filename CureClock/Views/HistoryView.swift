//
//  HistoryView.swift
//  CureClock
//
//  Feature 12: a chronological log of pours, strength milestones reached and
//  other events, derived live from the data. iOS 14 safe.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScreenScaffold("History", subtitle: "Poured · reached · loaded") {
            let events = store.timeline()
            if events.isEmpty {
                CardView {
                    EmptyStateView(systemImage: "clock.arrow.circlepath", title: "Nothing yet",
                                   message: "Save a pour and milestones will appear here as they're reached.")
                }
            } else {
                CardView {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.stableKey) { idx, e in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 0) {
                                    ZStack {
                                        Circle().fill(color(e).opacity(0.18)).frame(width: 34, height: 34)
                                        Image(systemName: e.icon).font(.system(size: 14, weight: .bold))
                                            .foregroundColor(color(e))
                                    }
                                    if idx != events.count - 1 {
                                        Rectangle().fill(Theme.stroke).frame(width: 2).frame(maxHeight: .infinity)
                                    }
                                }
                                .frame(minHeight: 52)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                                    if !e.detail.isEmpty {
                                        Text(e.detail).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                                    }
                                    Text(Formatters.date(e.date)).font(Theme.mono(11)).foregroundColor(Theme.textDisabled)
                                }
                                .padding(.bottom, 14)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitle("History", displayMode: .inline)
    }

    private func color(_ e: HistoryEvent) -> Color {
        switch e.kind {
        case "poured": return Theme.water
        case "reached": return Theme.success
        case "loaded": return Theme.warning
        default: return Theme.accent
        }
    }
}
