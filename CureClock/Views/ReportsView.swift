//
//  ReportsView.swift
//  CureClock
//
//  Feature 11: choose what to include and export a PDF report of a pour
//  (volumes, mix, strength curve, milestones, cost). iOS 14 safe.
//

import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var vm = ReportViewModel()

    @State private var selectedPourID: UUID?
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var generating = false

    private var pour: Pour? {
        if let id = selectedPourID, let p = store.pour(id) { return p }
        return store.primaryPour
    }

    var body: some View {
        ScreenScaffold("Reports", subtitle: "Export a PDF for the file or client") {
            if let pour = pour {
                PourPickerBar(selectedPourID: $selectedPourID)
                includeCard
                previewCard(pour)
                ActionButton(title: generating ? "Generating…" : "Export PDF",
                             systemImage: "square.and.arrow.up") {
                    export(pour)
                }
                .disabled(generating)
            } else {
                CardView {
                    EmptyStateView(systemImage: "doc.richtext", title: "No pour yet",
                                   message: "Save a pour to build a report.")
                }
            }
        }
        .navigationBarTitle("Reports", displayMode: .inline)
        .onAppear { if selectedPourID == nil { selectedPourID = store.primaryPour?.id } }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
    }

    private var includeCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Include", systemImage: "checklist")
                toggle("Mix & materials", $vm.includeMix)
                toggle("Strength curve", $vm.includeCurve)
                toggle("Milestone schedule", $vm.includeMilestones)
                toggle("Cost estimate", $vm.includeCost)
            }
        }
    }

    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title).font(Theme.body(15)).foregroundColor(Theme.textPrimary)
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
        .padding(.vertical, 2)
    }

    private func previewCard(_ pour: Pour) -> some View {
        let m = store.mixResult(for: pour)
        let c = store.cost(for: pour)
        return CardView {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: pour.name, subtitle: "Report preview", systemImage: "doc.text.magnifyingglass")
                ReadoutRow(label: "Total volume", value: store.volume(pour.totalVolumeM3), mono: true)
                if vm.includeMix {
                    ReadoutRow(label: "Cement", value: "\(m.bags(ofSizeKg: store.bagSizeKg)) × \(Int(store.bagSizeKg)) kg bags", mono: true)
                    ReadoutRow(label: "Water", value: "\(Formatters.decimal(m.waterL, digits: 0)) L", mono: true)
                }
                if vm.includeCurve {
                    ReadoutRow(label: "Strength today", value: Formatters.percent(store.currentStrengthPercent(for: pour)), mono: true)
                }
                if vm.includeCost {
                    ReadoutRow(label: "Total cost", value: store.money(c.total), tint: Theme.accentHi)
                }
            }
        }
    }

    private func export(_ pour: Pour) {
        store.dummyKeyboardDismiss()
        generating = true
        // Read the store here, on the main thread, and hand the renderer a value type.
        let snapshot = store.reportSnapshot(for: pour)
        DispatchQueue.global(qos: .userInitiated).async {
            let url = vm.generate(snapshot)
            DispatchQueue.main.async {
                generating = false
                if let url = url { shareURL = url; showShare = true }
            }
        }
    }
}
