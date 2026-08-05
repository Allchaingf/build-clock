//
//  CureTimelineView.swift
//  CureClock
//
//  Feature 04: the strength-gain curve over 28 days (temperature-adjusted) with
//  milestone markers and estimated dates. iOS 14 safe (custom Path chart).
//

import SwiftUI

struct CureTimelineView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedPourID: UUID?

    private var pour: Pour? {
        if let id = selectedPourID, let p = store.pour(id) { return p }
        return store.primaryPour
    }

    var body: some View {
        ScreenScaffold("Cure Timeline", subtitle: "Strength gain & milestone gates") {
            if let pour = pour {
                PourPickerBar(selectedPourID: $selectedPourID)
                curveCard(pour)
                ColdCureBanner(tempC: pour.cureTempC)
                milestonesCard(pour)
                tempCard(pour)
                EngineeringDisclaimer()
            } else {
                CardView {
                    EmptyStateView(systemImage: "clock.badge.questionmark",
                                   title: "No pour yet",
                                   message: "Save a pour in the Mix tab to start the cure clock.")
                }
            }
        }
        .navigationBarTitle("Cure", displayMode: .inline)
        .onAppear { if selectedPourID == nil { selectedPourID = store.primaryPour?.id } }
    }

    private func curveCard(_ pour: Pour) -> some View {
        let pct = store.currentStrengthPercent(for: pour)
        let day = store.daysSincePour(pour)
        return CardView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pour.name).font(Theme.heading(17)).foregroundColor(Theme.textPrimary)
                        Text("Poured \(Formatters.date(pour.pourDate)) · day \(Int(day))")
                            .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    ProgressRing(progress: pct, size: 66, tint: ringTint(pct), caption: "strength")
                }
                StrengthCurveChart(values: store.curveSeries(for: pour),
                                   markers: store.curveMarkers(for: pour),
                                   todayDay: min(day, Double(MixConstants.designAgeDays)))
                Text("≈% of 28-day strength · logged weather so far, then projected at \(Int(pour.cureTempC))°C")
                    .font(Theme.caption(11)).foregroundColor(Theme.textDisabled)
            }
        }
    }

    private func milestonesCard(_ pour: Pour) -> some View {
        let items = store.milestones(for: pour)
        return CardView {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "Milestones", subtitle: "Gated by strength & temperature",
                              systemImage: "flag.checkered")
                    .padding(.bottom, 6)
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, status in
                    MilestoneTimelineRow(status: status, isLast: idx == items.count - 1)
                }
            }
        }
    }

    private func tempCard(_ pour: Pour) -> some View {
        let factor = StrengthEngine.tempFactor(pour.cureTempC)
        return Group {
            if factor > 0 {
                InfoBanner(
                    text: "Curing at \(Int(pour.cureTempC))°C runs ×\(Formatters.decimal(factor, digits: 2)) vs the 20°C baseline. Warmer cures faster, colder slower.",
                    systemImage: "thermometer.medium",
                    tint: pour.cureTempC < MixConstants.coldWarningTempC ? Theme.water : Theme.accent)
            }
        }
    }

    private func ringTint(_ pct: Double) -> Color {
        if pct >= 100 { return Theme.success }
        if pct >= 60 { return Theme.accentHi }
        return Theme.curing
    }
}

// MARK: - Reusable pour picker

struct PourPickerBar: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedPourID: UUID?

    var body: some View {
        // Shown from the first pour onward: appearing out of nowhere when a second
        // pour is added is how people miss that the app is multi-pour at all.
        if !store.pours.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.pours) { p in
                        let active = (selectedPourID ?? store.primaryPour?.id) == p.id
                        Button(action: { withAnimation { selectedPourID = p.id } }) {
                            Text(p.name)
                                .font(Theme.caption(12))
                                .foregroundColor(active ? Theme.textOnAccent : Theme.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(active ? Theme.accent : Theme.surface))
                                .overlay(Capsule().stroke(Theme.stroke, lineWidth: active ? 0 : 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}
