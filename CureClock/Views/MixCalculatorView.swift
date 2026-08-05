//
//  MixCalculatorView.swift
//  CureClock
//
//  Feature 01/02/03: volume from W×L×Thickness across multiple sections →
//  cement/sand/aggregate/water + bag count by mix preset, with a W/C quality
//  warning. Calc / Add Section / Save Pour. iOS 14 safe.
//

import SwiftUI

struct MixCalculatorView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager

    @StateObject private var vm = MixCalculatorViewModel(
        seed: { var p = Pour.make(goal: .slab, strengthClass: .m200, tempC: 18, date: Date())
                p.name = "New Pour"
                p.sections = [PourSection(label: "Section 1", thicknessM: 0.1, wastePercent: 5)]
                return p }())

    @AppStorage("remindersEnabled") private var remindersEnabled = false

    @State private var seeded = false
    @State private var editingSection: PourSection?
    @State private var savedFlash = false
    @State private var savedWasUpdate = false
    @State private var pendingDelete: DeleteTarget?

    private struct DeleteTarget: Identifiable {
        let pour: Pour
        var id: UUID { pour.id }
    }

    /// True when the draft is a pour that already exists — saving will update it
    /// rather than create another one.
    private var isEditingSaved: Bool { store.pour(vm.pour.id) != nil }

    var body: some View {
        ScreenScaffold("Mix Calculator", subtitle: "Volume → materials, bags & water") {
            draftCard
            mixCard
            sectionsCard
            totalCard
            ActionButton(title: "Calc", systemImage: "function") {
                store.dummyKeyboardDismiss()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { vm.showResults = true }
            }
            if vm.showResults { resultsCard; waterCard; saveBar }
        }
        .navigationBarTitle("Mix", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            withAnimation { vm.startNewPour(from: store) }
        }) { Image(systemName: "plus.circle").foregroundColor(Theme.accent) })
        .onAppear {
            if !seeded { if let p = store.primaryPour { vm.pour = p }; seeded = true }
        }
        .sheet(item: $editingSection) { sec in
            PourSectionEditorView(section: sec, unit: store.volumeUnit) { saved in
                vm.upsertSection(saved)
            }
            .environmentObject(store)
        }
        .overlay(savedToast, alignment: .top)
        .alert(item: $pendingDelete) { target in
            Alert(title: Text("Delete \(target.pour.name)?"),
                  message: Text("Removes the pour and its photos, cracks and weather notes. This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) {
                      store.deletePour(target.pour)
                      vm.startNewPour(from: store)
                  },
                  secondaryButton: .cancel())
        }
    }

    // MARK: Which pour am I editing?

    /// Saving used to `upsert` whatever was seeded from the newest pour, so pressing
    /// "Save Pour" quietly overwrote it while the toast said a new clock had started.
    /// The draft is now explicit: you can see which pour you are editing, start a new
    /// one, or delete the one you are on.
    private var draftCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: isEditingSaved ? "Editing saved pour" : "New pour",
                              subtitle: isEditingSaved
                                ? "Saving updates this pour"
                                : "Saving creates a pour — your existing ones aren't touched",
                              systemImage: "square.and.pencil")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        draftChip(title: "＋ New", active: !isEditingSaved) {
                            withAnimation { vm.startNewPour(from: store) }
                        }
                        ForEach(store.pours) { p in
                            draftChip(title: p.name, active: vm.pour.id == p.id) {
                                withAnimation { vm.pour = p; vm.showResults = false }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                if isEditingSaved, let saved = store.pour(vm.pour.id) {
                    Button(action: { pendingDelete = DeleteTarget(pour: saved) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete this pour").font(Theme.caption(12))
                        }
                        .foregroundColor(Theme.danger)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func draftChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.caption(12))
                .foregroundColor(active ? Theme.textOnAccent : Theme.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(active ? Theme.accent : Theme.surfaceAlt))
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: active ? 0 : 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Mix recipe

    private var mixCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Mix & pour", systemImage: "cube.box.fill")
                LabeledField(label: "Pour name", text: $vm.pour.name, placeholder: "e.g. Garage slab")

                Text("PRESET").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.mixPresets) { preset in
                            let active = preset.strengthClass == vm.pour.strengthClass && preset.isScreed == vm.pour.isScreed
                            Button(action: { withAnimation { vm.applyPreset(preset) } }) {
                                VStack(spacing: 2) {
                                    Text(preset.name).font(Theme.caption(12))
                                    Text(preset.ratioText).font(Theme.mono(10))
                                }
                                .foregroundColor(active ? Theme.textOnAccent : Theme.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(active ? Theme.accent : Theme.surfaceAlt))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke, lineWidth: active ? 0 : 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                Divider().background(Theme.stroke)

                ReadoutRow(label: "Strength class",
                           value: "\(vm.pour.strengthClass.displayName) · \(vm.pour.strengthClass.cEquivalent)", mono: true)
                ReadoutRow(label: "Ratio (C:S:A)",
                           value: vm.pour.isScreed
                                ? "1 : \(Formatters.decimal(vm.pour.ratioSand, digits: 1))"
                                : "1 : \(Formatters.decimal(vm.pour.ratioSand, digits: 1)) : \(Formatters.decimal(vm.pour.ratioAggregate, digits: 1))",
                           mono: true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("WATER / CEMENT").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(Formatters.decimal(vm.pour.wcRatio, digits: 2))
                            .font(Theme.mono(13)).foregroundColor(vm.waterQuality.color)
                    }
                    Slider(value: $vm.pour.wcRatio, in: 0.30...0.80, step: 0.01).accentColor(vm.waterQuality.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CURE TEMPERATURE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(vm.pour.cureTempC))°C").font(Theme.mono(13)).foregroundColor(Theme.accentHi)
                    }
                    Slider(value: $vm.pour.cureTempC, in: -5...40, step: 1).accentColor(Theme.accent)
                }

                DatePicker("Pour date", selection: $vm.pour.pourDate, in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .font(Theme.body(14))
                    .accentColor(Theme.accent)
            }
        }
    }

    // MARK: Sections

    private var sectionsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sections", subtitle: "Add each area to sum the volume",
                              systemImage: "square.split.2x2.fill")

                if vm.pour.sections.isEmpty {
                    EmptyStateView(systemImage: "square.dashed", title: "No sections",
                                   message: "Add a section to start the calculation.")
                } else {
                    // A visible trash button, not a long-press-only context menu —
                    // an action nobody can find is an action that isn't there.
                    ForEach(vm.pour.sections) { sec in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sec.label).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                                Text(dimsSummary(sec)).font(Theme.mono(11)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Text(store.volume(sec.volumeM3))
                                .font(Theme.mono(13)).foregroundColor(Theme.accentHi)
                            Image(systemName: "pencil.circle").foregroundColor(Theme.textDisabled)
                            Button(action: { withAnimation { vm.removeSection(sec) } }) {
                                Image(systemName: "trash").foregroundColor(Theme.danger)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture { editingSection = sec }
                        .overlay(Divider().background(Theme.stroke), alignment: .bottom)
                    }
                }

                ActionButton(title: "Add Section", systemImage: "plus", kind: .secondary) {
                    editingSection = PourSection(label: "Section \(vm.pour.sections.count + 1)",
                                                 thicknessM: 0.1, wastePercent: 5)
                }
            }
        }
    }

    private func dimsSummary(_ s: PourSection) -> String {
        let u = store.volumeUnit
        return "\(Formatters.decimal(s.widthM / u.lengthToMeters, digits: 2))×\(Formatters.decimal(s.lengthM / u.lengthToMeters, digits: 2)) \(u.lengthSymbol) · \(Formatters.decimal(s.thicknessM / u.thicknessToMeters, digits: 0)) \(u.thicknessSymbol) · +\(Int(s.wastePercent))%"
    }

    // MARK: Total

    private var totalCard: some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL VOLUME").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    Text("\(vm.pour.sections.count) section(s)").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Text("\(Formatters.decimal(vm.totalVolumeM3 * store.volumeUnit.fromM3, digits: 2)) \(store.volumeUnit.symbol)")
                    .font(Theme.monoBold(26)).foregroundColor(Theme.accentHi)
            }
        }
    }

    // MARK: Results

    private var resultsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Materials", subtitle: "Dry-volume method (×1.54)",
                              systemImage: "scalemass.fill")
                let m = vm.mix
                materialRow("Cement", kg: m.cementKg,
                            sub: "\(m.bags(ofSizeKg: store.bagSizeKg)) × \(Int(store.bagSizeKg)) kg bags · ≈\(Int(m.cementKgPerM3.rounded())) kg/m³",
                            tint: Theme.accent)
                materialRow("Sand", kg: m.sandKg, sub: store.volume(m.sandVolumeM3), tint: Theme.concrete)
                if !vm.pour.isScreed {
                    materialRow("Aggregate", kg: m.aggKg, sub: store.volume(m.aggVolumeM3), tint: Theme.concrete)
                }
                Divider().background(Theme.stroke)
                HStack {
                    Image(systemName: "drop.fill").foregroundColor(Theme.water)
                    Text("Water").font(Theme.body(14)).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(Formatters.decimal(m.waterL, digits: 0)) L").font(Theme.mono(14)).foregroundColor(Theme.water)
                }
            }
        }
    }

    private func materialRow(_ name: String, kg: Double, sub: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Theme.body(15)).foregroundColor(Theme.textPrimary)
                Text(sub).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Text("\(Formatters.decimal(kg, digits: 0)) kg").font(Theme.mono(15)).foregroundColor(tint)
        }
    }

    private var waterCard: some View {
        InfoBanner(text: "\(vm.waterQuality.title) — \(vm.waterQuality.message)",
                   systemImage: vm.waterQuality.icon, tint: vm.waterQuality.color)
    }

    // MARK: Save

    private var saveBar: some View {
        ActionButton(title: isEditingSaved ? "Update Pour" : "Save Pour",
                     systemImage: "tray.and.arrow.down.fill") {
            store.dummyKeyboardDismiss()
            savedWasUpdate = isEditingSaved
            store.savePour(vm.pour)
            // Respect the Reminders switch: scheduling purely on "notifications are
            // allowed" turned reminders back on for every pour the user saved after
            // deliberately switching them off.
            if remindersEnabled && notifications.isAuthorized {
                notifications.scheduleCureReminders(for: vm.pour,
                                                    milestones: store.milestones(for: vm.pour),
                                                    keepWetDays: store.settings.keepWetDays)
            }
            withAnimation { savedFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { savedFlash = false }
            }
        }
    }

    private var savedToast: some View {
        Group {
            if savedFlash {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(savedWasUpdate ? "Pour updated" : "Pour saved — cure clock started")
                }
                .font(Theme.caption(13)).foregroundColor(Theme.textOnAccent)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(Theme.success))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
