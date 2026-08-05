//
//  PourSectionEditorView.swift
//  CureClock
//
//  Sheet for adding / editing one pour section. Width × Length × Thickness are
//  entered in the user's chosen units and converted to metres on save.
//  iOS 14 safe.
//

import SwiftUI

struct PourSectionEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode

    let original: PourSection
    let onSave: (PourSection) -> Void

    @State private var label: String
    @State private var width: Double      // display units
    @State private var length: Double     // display units
    @State private var thickness: Double  // display units (mm / in)
    @State private var waste: Double

    init(section: PourSection, unit: VolumeUnit, onSave: @escaping (PourSection) -> Void) {
        self.original = section
        self.onSave = onSave
        _label = State(initialValue: section.label)
        _width = State(initialValue: section.widthM / unit.lengthToMeters)
        _length = State(initialValue: section.lengthM / unit.lengthToMeters)
        _thickness = State(initialValue: section.thicknessM / unit.thicknessToMeters)
        _waste = State(initialValue: section.wastePercent)
    }

    private var unit: VolumeUnit { store.volumeUnit }

    private var liveVolumeM3: Double {
        max(width, 0) * unit.lengthToMeters
        * max(length, 0) * unit.lengthToMeters
        * max(thickness, 0) * unit.thicknessToMeters
        * (1 + max(waste, 0) / 100)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    LabeledField(label: "Section name", text: $label, placeholder: "e.g. Main bay")

                    HStack(spacing: 12) {
                        LabeledNumberField(label: "Width", value: $width, suffix: unit.lengthSymbol)
                        LabeledNumberField(label: "Length", value: $length, suffix: unit.lengthSymbol)
                    }
                    HStack(spacing: 12) {
                        LabeledNumberField(label: "Thickness", value: $thickness, suffix: unit.thicknessSymbol)
                        LabeledNumberField(label: "Waste", value: $waste, suffix: "%", digits: 0)
                    }

                    CardView {
                        HStack {
                            Text("Section volume").font(Theme.body(14)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(Formatters.decimal(liveVolumeM3 * unit.fromM3, digits: 2)) \(unit.symbol)")
                                .font(Theme.monoBold(20)).foregroundColor(Theme.accentHi)
                        }
                    }

                    ActionButton(title: "Save Section", systemImage: "checkmark") { save() }
                }
                .padding(Theme.Space.m)
            }
            .cureScreen()
            .navigationBarTitle("Section", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(Theme.textSecondary),
                trailing: Button(action: { store.dummyKeyboardDismiss() }) { Image(systemName: "keyboard.chevron.compact.down") }
                    .foregroundColor(Theme.accent)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func save() {
        var s = original
        s.label = label.isEmpty ? "Section" : label
        s.widthM = max(width, 0) * unit.lengthToMeters
        s.lengthM = max(length, 0) * unit.lengthToMeters
        s.thicknessM = max(thickness, 0) * unit.thicknessToMeters
        s.wastePercent = max(waste, 0)
        onSave(s)
        presentationMode.wrappedValue.dismiss()
    }
}

extension AppStore {
    /// Small convenience so views can dismiss the keyboard without importing UIKit.
    func dummyKeyboardDismiss() { UIApplication.shared.dismissKeyboard() }
}
