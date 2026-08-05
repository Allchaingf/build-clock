//
//  StrengthTodayView.swift
//  CureClock
//
//  Feature 05: the current estimated strength % and exactly what's safe to do
//  right now (walk / strip formwork / tile / load). iOS 14 safe.
//

import SwiftUI

struct StrengthTodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedPourID: UUID?

    private var pour: Pour? {
        if let id = selectedPourID, let p = store.pour(id) { return p }
        return store.primaryPour
    }

    var body: some View {
        ScreenScaffold("Strength Today", subtitle: "What's safe right now") {
            if let pour = pour {
                PourPickerBar(selectedPourID: $selectedPourID)
                gaugeCard(pour)
                ColdCureBanner(tempC: pour.cureTempC)
                allowedCard(pour)
                nextCard(pour)
                EngineeringDisclaimer()
            } else {
                CardView {
                    EmptyStateView(systemImage: "gauge.with.dots.needle.bottom.50percent",
                                   title: "No pour yet",
                                   message: "Save a pour to see its live strength.")
                }
            }
        }
        .navigationBarTitle("Strength", displayMode: .inline)
        .onAppear { if selectedPourID == nil { selectedPourID = store.primaryPour?.id } }
    }

    private func gaugeCard(_ pour: Pour) -> some View {
        let pct = store.currentStrengthPercent(for: pour)
        let day = store.daysSincePour(pour)
        return CardView {
            VStack(spacing: 12) {
                ProgressRing(progress: pct, size: 150, lineWidth: 14, tint: tint(pct), caption: "of 28-day")
                Text(pour.name).font(Theme.heading(17)).foregroundColor(Theme.textPrimary)
                HStack(spacing: 18) {
                    miniStat("Day", "\(Int(day))")
                    miniStat("Class", pour.strengthClass.displayName)
                    miniStat("MPa (est.)", "\(Int(pour.characteristicMPa * pct / 100))")
                }
                Text("Estimated from the cure model — not a cube-test result.")
                    .font(Theme.caption(11)).foregroundColor(Theme.textDisabled)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.monoBold(18)).foregroundColor(Theme.accentHi)
            Text(label).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
        }
    }

    private func allowedCard(_ pour: Pour) -> some View {
        let allowed = Set(store.allowedNow(for: pour).map { $0.rawValue })
        return CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Allowed now", systemImage: "checklist")
                ForEach(CureMilestoneType.allCases) { type in
                    let ok = allowed.contains(type.rawValue)
                    HStack(spacing: 12) {
                        Image(systemName: ok ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundColor(ok ? Theme.success : Theme.textDisabled)
                            .font(.system(size: 17))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.displayName).font(Theme.body(15))
                                .foregroundColor(ok ? Theme.textPrimary : Theme.textSecondary)
                            Text(type.detail).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        TagChip(text: "\(Int(type.gatePercent))%", color: ok ? Theme.success : Theme.concrete, filled: ok)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func nextCard(_ pour: Pour) -> some View {
        Group {
            if let next = store.nextMilestone(for: pour) {
                if let est = next.estDate {
                    InfoBanner(text: "Next: \(next.type.displayName) — est. \(Formatters.date(est)) (\(Formatters.relativeDays(to: est))).",
                               systemImage: next.type.icon, tint: Theme.accent)
                } else {
                    InfoBanner(text: "Next: \(next.type.displayName) — no date while the cure is stalled by cold.",
                               systemImage: "snowflake", tint: Theme.water)
                }
            } else {
                InfoBanner(text: "Fully cured — all milestones reached.",
                           systemImage: "checkmark.seal.fill", tint: Theme.success)
            }
        }
    }

    private func tint(_ pct: Double) -> Color {
        if pct >= 100 { return Theme.success }
        if pct >= 60 { return Theme.accentHi }
        return Theme.curing
    }
}
