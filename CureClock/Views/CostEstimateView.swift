//
//  CostEstimateView.swift
//  CureClock
//
//  Feature 07: materials + mixer/pump rental cost for a pour, with a donut
//  breakdown and cost per m³. Inputs persist to the shared CostInputs.
//  iOS 14 safe.
//

import SwiftUI

struct CostEstimateView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedPourID: UUID?
    @State private var inputs = CostInputs()
    @State private var loaded = false

    private var pour: Pour? {
        if let id = selectedPourID, let p = store.pour(id) { return p }
        return store.primaryPour
    }

    var body: some View {
        ScreenScaffold("Cost Estimate", subtitle: "Materials + mixer / pump rental") {
            if let pour = pour {
                PourPickerBar(selectedPourID: $selectedPourID)
                breakdownCard(pour)
                materialsInputCard
                rentalInputCard
            } else {
                CardView {
                    EmptyStateView(systemImage: "dollarsign.circle",
                                   title: "No pour yet",
                                   message: "Save a pour to estimate its cost.")
                }
            }
        }
        .navigationBarTitle("Cost", displayMode: .inline)
        .onAppear {
            if !loaded { inputs = store.costInputs; loaded = true }
            if selectedPourID == nil { selectedPourID = store.primaryPour?.id }
        }
        .onChange(of: inputs) { newValue in store.updateCostInputs(newValue) }
    }

    private func breakdownCard(_ pour: Pour) -> some View {
        let c = store.cost(for: pour)
        let data: [ChartDatum] = [
            ChartDatum(label: "Cement", value: c.cementCost, color: Theme.accent),
            ChartDatum(label: "Sand", value: c.sandCost, color: Theme.concrete),
            ChartDatum(label: "Aggregate", value: c.aggCost, color: Theme.water),
            ChartDatum(label: "Rental", value: c.rental, color: Theme.warning),
            ChartDatum(label: "Labour", value: c.laborCost, color: Theme.accentHi)
        ].filter { $0.value > 0 }
        return CardView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(title: "Total cost", systemImage: "chart.pie.fill")
                HStack(alignment: .center, spacing: Theme.Space.m) {
                    DonutChartView(data: data, size: 130, lineWidth: 22,
                                   centerTitle: store.money(c.total))
                    ChartLegend(items: data) { store.money($0) }
                }
                Divider().background(Theme.stroke)
                ReadoutRow(label: "Total", value: store.money(c.total), tint: Theme.accentHi)
                ReadoutRow(label: "Per \(store.volumeUnit.symbol)",
                           value: store.money(store.costPerM3(for: pour) / store.volumeUnit.fromM3), mono: true)
                if c.cementFromStockCost > 0 {
                    Divider().background(Theme.stroke)
                    ReadoutRow(label: "Already in stock", value: "− \(store.money(c.cementFromStockCost))",
                               tint: Theme.success, mono: true)
                    ReadoutRow(label: "Still to buy", value: store.money(c.stillToBuy), tint: Theme.warning)
                }
            }
        }
    }

    private var materialsInputCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Material prices",
                              subtitle: "Cement priced per \(Int(store.bagSizeKg)) kg bag",
                              systemImage: "tag.fill")
                HStack(spacing: 12) {
                    LabeledNumberField(label: "Cement / bag", value: $inputs.cementPricePerBag, suffix: store.currency.symbol)
                    LabeledNumberField(label: "Sand / \(unit)", value: perVolume(\.sandPricePerM3), suffix: store.currency.symbol)
                }
                HStack(spacing: 12) {
                    LabeledNumberField(label: "Aggregate / \(unit)", value: perVolume(\.aggPricePerM3), suffix: store.currency.symbol)
                    LabeledNumberField(label: "Water / \(unit)", value: perVolume(\.waterPricePerM3), suffix: store.currency.symbol)
                }
            }
        }
    }

    private var rentalInputCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Rental & labour", systemImage: "wrench.and.screwdriver.fill")
                HStack(spacing: 12) {
                    LabeledNumberField(label: "Mixer / day", value: $inputs.mixerRentalPerDay, suffix: store.currency.symbol)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MIXER DAYS").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        Stepper("\(inputs.mixerDays)", value: $inputs.mixerDays, in: 0...60)
                            .font(Theme.body(14)).foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                    }
                }
                HStack(spacing: 12) {
                    LabeledNumberField(label: "Pump / \(unit)", value: perVolume(\.pumpRentalPerM3), suffix: store.currency.symbol)
                    LabeledNumberField(label: "Labour / \(unit)", value: perVolume(\.laborPerM3), suffix: store.currency.symbol)
                }
            }
        }
    }

    private var unit: String { store.volumeUnit.symbol }

    /// Per-volume prices are stored per m³ but entered in the user's chosen unit —
    /// otherwise an imperial user types a per-ft³ price into a per-m³ field.
    private func perVolume(_ keyPath: WritableKeyPath<CostInputs, Double>) -> Binding<Double> {
        let factor = store.volumeUnit.fromM3
        return Binding(get: { inputs[keyPath: keyPath] / factor },
                       set: { inputs[keyPath: keyPath] = $0 * factor })
    }
}
