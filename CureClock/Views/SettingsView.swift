//
//  SettingsView.swift
//  CureClock
//
//  Feature 14: units, currency, theme, mix presets, backup and data reset.
//  Every control is fully wired and persists via @AppStorage / the store.
//  iOS 14 safe.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showImport = false
    @State private var showWipeConfirm = false
    @State private var pendingImport: PendingImport?

    /// Identifiable wrapper so the confirmation alert can be driven by the decoded
    /// backup itself.
    private struct PendingImport: Identifiable {
        let id = UUID()
        let data: AppData
    }

    var body: some View {
        ScreenScaffold("Settings", subtitle: "Units, theme, presets & backup") {
            appearanceCard
            unitsCard
            presetsCard
            backupCard
            dataCard
            aboutCard
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $showImport) {
            // Read the file, but don't commit it yet — importing silently replaced
            // every pour, log and photo with no way back.
            DocumentPicker { url in
                if let decoded = PersistenceManager.shared.decodeBackup(from: url) {
                    pendingImport = PendingImport(data: decoded)
                }
            }
        }
        .alert(item: $pendingImport) { imported in
            Alert(title: Text("Replace all data?"),
                  message: Text("This backup has \(imported.data.pours.count) pour(s). Importing replaces everything currently in the app — pours, logs and settings. This cannot be undone."),
                  primaryButton: .destructive(Text("Replace")) {
                      PersistenceManager.shared.commitBackup(imported.data)
                      store.replace(with: imported.data)
                  },
                  secondaryButton: .cancel())
        }
        .actionSheet(isPresented: $showWipeConfirm) {
            ActionSheet(title: Text("Erase all data?"),
                        message: Text("Deletes every pour, log and photo. This cannot be undone."),
                        buttons: [.destructive(Text("Erase everything")) { store.wipeAll() }, .cancel()])
        }
    }

    // MARK: Appearance

    private var appearanceCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Theme", subtitle: "Applies instantly across the app",
                              systemImage: "paintbrush.fill")
                HStack(spacing: 8) {
                    ForEach(AppAppearance.allCases) { mode in
                        Button(action: { appearanceRaw = mode.rawValue }) {
                            VStack(spacing: 6) {
                                Image(systemName: mode.icon).font(.system(size: 18, weight: .semibold))
                                Text(mode.displayName).font(Theme.caption(12))
                            }
                            .foregroundColor(appearanceRaw == mode.rawValue ? Theme.textOnAccent : Theme.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(appearanceRaw == mode.rawValue ? Theme.accent : Theme.surfaceAlt))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.stroke, lineWidth: appearanceRaw == mode.rawValue ? 0 : 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: Units & currency

    private var unitsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Units & currency", systemImage: "ruler.fill")

                settingMenu(title: "Volume unit", value: store.volumeUnit.symbol) {
                    ForEach(VolumeUnit.allCases) { u in
                        Button(u.displayName) { store.volumeUnit = u }
                    }
                }
                Divider().background(Theme.stroke)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CEMENT BAG SIZE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    Picker("", selection: Binding(get: { store.bagSize.rawValue },
                                                  set: { store.bagSize = BagSize(rawValue: $0) ?? .kg50 })) {
                        ForEach(BagSize.allCases) { b in Text(b.displayName).tag(b.rawValue) }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Divider().background(Theme.stroke)
                settingMenu(title: "Currency", value: store.currency.code) {
                    ForEach(CurrencyCode.allCases) { c in
                        Button("\(c.code) — \(c.displayName)") { store.currency = c }
                    }
                }
            }
        }
    }

    private func settingMenu<Content: View>(title: String, value: String, @ViewBuilder menu: () -> Content) -> some View {
        HStack {
            Text(title).font(Theme.body(15)).foregroundColor(Theme.textPrimary)
            Spacer()
            Menu {
                menu()
            } label: {
                HStack(spacing: 4) {
                    Text(value).font(Theme.mono(14)).foregroundColor(Theme.accent)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)).foregroundColor(Theme.accent)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Theme.surfaceAlt))
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
            }
        }
    }

    // MARK: Presets

    private var presetsCard: some View {
        CardView {
            VStack(spacing: 4) {
                NavigationLink(destination: MixPresetsView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.16)).frame(width: 44, height: 44)
                            Image(systemName: "slider.horizontal.3").foregroundColor(Theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mix Presets").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                            Text("\(store.mixPresets.count) recipes — edit ratios & W/C")
                                .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Theme.textDisabled)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: Backup

    private var backupCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Backup", subtitle: "Export or restore your data as JSON",
                              systemImage: "externaldrive.fill")
                HStack(spacing: 12) {
                    ActionButton(title: "Export", systemImage: "square.and.arrow.up", kind: .secondary) {
                        if let url = PersistenceManager.shared.exportBackup(store.data) {
                            shareURL = url; showShare = true
                        }
                    }
                    ActionButton(title: "Import", systemImage: "square.and.arrow.down", kind: .secondary) {
                        showImport = true
                    }
                }
            }
        }
    }

    // MARK: Data

    private var dataCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Data", systemImage: "trash.fill")
                ActionButton(title: "Erase All Data", systemImage: "trash", kind: .danger) {
                    showWipeConfirm = true
                }
            }
        }
    }

    private var aboutCard: some View {
        CardView {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill").foregroundColor(Theme.accentHi)
                    Text("Builder Clock").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                }
                Text("Mix it right. Let it cure.").font(Theme.caption(12)).foregroundColor(Theme.accentHi)
                Text("All data stays on this device. v1.0").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Mix presets editor

struct MixPresetsView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: MixPreset?

    var body: some View {
        ScreenScaffold("Mix Presets", subtitle: "Your reusable recipes") {
            ForEach(store.mixPresets) { preset in
                CardView {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(preset.name).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                                if preset.isScreed { TagChip(text: "Screed", color: Theme.water) }
                            }
                            Text("\(preset.ratioText) · W/C \(Formatters.decimal(preset.wcRatio, digits: 2)) · \(Int(preset.characteristicMPa)) MPa · ≈\(Int(preset.cementKgPerM3.rounded())) kg/m³ cement")
                                .font(Theme.mono(11)).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Button(action: { editing = preset }) { Image(systemName: "pencil").foregroundColor(Theme.accent) }
                        Button(action: { store.deleteMixPreset(preset) }) { Image(systemName: "trash").foregroundColor(Theme.danger) }
                    }
                }
            }
            ActionButton(title: "Add Preset", systemImage: "plus") {
                editing = MixPreset(name: "", strengthClass: .m200, ratioCement: 1, ratioSand: 2.5,
                                    ratioAggregate: 4, wcRatio: 0.55,
                                    isScreed: false, characteristicMPa: 20)
            }
            ActionButton(title: "Reset to Defaults", systemImage: "arrow.counterclockwise", kind: .secondary) {
                store.resetPresets()
            }
        }
        .navigationBarTitle("Presets", displayMode: .inline)
        .sheet(item: $editing) { preset in
            PresetEditorView(preset: preset) { store.saveMixPreset($0) }
                .environmentObject(store)
        }
    }
}

struct PresetEditorView: View {
    @Environment(\.presentationMode) private var presentationMode
    let preset: MixPreset
    let onSave: (MixPreset) -> Void

    @State private var name: String
    @State private var strengthClass: StrengthClass
    @State private var isScreed: Bool
    @State private var sand: Double
    @State private var aggregate: Double
    @State private var wc: Double
    @State private var mpa: Double

    init(preset: MixPreset, onSave: @escaping (MixPreset) -> Void) {
        self.preset = preset; self.onSave = onSave
        _name = State(initialValue: preset.name)
        _strengthClass = State(initialValue: preset.strengthClass)
        _isScreed = State(initialValue: preset.isScreed)
        _sand = State(initialValue: preset.ratioSand)
        _aggregate = State(initialValue: preset.ratioAggregate)
        _wc = State(initialValue: preset.wcRatio)
        _mpa = State(initialValue: preset.characteristicMPa)
    }

    /// Live cement content for the ratio being edited — the same number the mix
    /// calculator will use, rather than a separate figure the user could set to
    /// anything without it changing a single result.
    private var cementPerM3: Double {
        StrengthEngine.cementContentKgPerM3(ratio: (1, max(sand, 0.1), isScreed ? 0 : max(aggregate, 0)))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    LabeledField(label: "Name", text: $name, placeholder: "e.g. M250 custom")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("STRENGTH CLASS").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        Picker("", selection: $strengthClass) {
                            ForEach(StrengthClass.allCases) { c in Text(c.displayName).tag(c) }
                        }.pickerStyle(SegmentedPickerStyle())
                    }

                    Toggle(isOn: $isScreed) {
                        Text("Screed (no coarse aggregate)").font(Theme.body(14)).foregroundColor(Theme.textPrimary)
                    }.toggleStyle(SwitchToggleStyle(tint: Theme.accent))

                    HStack(spacing: 12) {
                        LabeledNumberField(label: "Sand part", value: $sand, suffix: ": 1c", digits: 1)
                        if !isScreed { LabeledNumberField(label: "Aggregate part", value: $aggregate, suffix: ": 1c", digits: 1) }
                    }
                    HStack(spacing: 12) {
                        LabeledNumberField(label: "W/C ratio", value: $wc, suffix: "", digits: 2)
                        LabeledNumberField(label: "28-day strength", value: $mpa, suffix: "MPa", digits: 0)
                    }

                    CardView {
                        ReadoutRow(label: "Cement content (derived)",
                                   value: "≈ \(Int(cementPerM3.rounded())) kg/m³", mono: true)
                    }

                    ActionButton(title: "Save Preset", systemImage: "checkmark") { save() }
                }
                .padding(Theme.Space.m)
            }
            .cureScreen()
            .navigationBarTitle("Preset", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(Theme.textSecondary),
                trailing: Button(action: { UIApplication.shared.dismissKeyboard() }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .foregroundColor(Theme.accent))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func save() {
        var copy = preset
        copy.name = name.isEmpty ? "Custom" : name
        copy.strengthClass = strengthClass
        copy.isScreed = isScreed
        copy.ratioCement = 1
        copy.ratioSand = max(sand, 0.1)
        copy.ratioAggregate = isScreed ? 0 : max(aggregate, 0)
        copy.wcRatio = min(max(wc, 0.3), 0.9)
        copy.characteristicMPa = max(mpa, 1)
        onSave(copy)
        presentationMode.wrappedValue.dismiss()
    }
}
