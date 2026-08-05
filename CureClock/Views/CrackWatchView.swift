//
//  CrackWatchView.swift
//  CureClock
//
//  Feature 08: log cracks / shrinkage with a photo, cause and dimensions so the
//  pattern (e.g. fast drying) is captured. iOS 14 safe.
//

import SwiftUI

struct CrackWatchView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: CrackLog?

    var body: some View {
        ScreenScaffold("Crack Watch", subtitle: "Catch shrinkage & overload cracks early") {
            if store.crackLogs.isEmpty {
                CardView {
                    EmptyStateView(systemImage: "checkmark.shield.fill", title: "No cracks logged",
                                   message: "Log any crack with a photo and a likely cause.")
                }
            } else {
                ForEach(store.crackLogs) { log in
                    crackCard(log)
                }
            }
            ActionButton(title: "Log Crack", systemImage: "plus") {
                editing = CrackLog(pourID: store.primaryPour?.id)
            }
        }
        .navigationBarTitle("Cracks", displayMode: .inline)
        .sheet(item: $editing) { log in
            CrackEditorView(log: log) { store.saveCrack($0) }
                .environmentObject(store)
        }
    }

    private func crackCard(_ log: CrackLog) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TagChip(text: log.cause.displayName, color: Theme.danger, filled: true)
                    Spacer()
                    Text(Formatters.date(log.createdAt)).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
                if let img = PhotoStore.shared.loadImage(named: log.imageFileName) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(height: 150).frame(maxWidth: .infinity)
                        .clipped().cornerRadius(Theme.Radius.s)
                }
                HStack(spacing: 16) {
                    miniReadout("Width", "\(Formatters.decimal(log.widthMm, digits: 1)) mm")
                    miniReadout("Length", "\(Formatters.decimal(log.lengthCm, digits: 0)) cm")
                    if !log.location.isEmpty { miniReadout("Where", log.location) }
                }
                if !log.note.isEmpty {
                    Text(log.note).font(Theme.caption(13)).foregroundColor(Theme.textPrimary)
                }
                Text(log.cause.hint).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                HStack {
                    if let p = store.pour(log.pourID) {
                        Text(p.name).font(Theme.caption(11)).foregroundColor(Theme.accent)
                    }
                    Spacer()
                    Button(action: { editing = log }) {
                        Image(systemName: "pencil").foregroundColor(Theme.accent)
                    }
                    Button(action: { store.deleteCrack(log) }) {
                        Image(systemName: "trash").foregroundColor(Theme.danger)
                    }
                }
            }
        }
    }

    private func miniReadout(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
            Text(value).font(Theme.mono(13)).foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - Editor

struct CrackEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode

    let log: CrackLog
    let onSave: (CrackLog) -> Void

    @State private var pourID: UUID?
    @State private var cause: CrackCause
    @State private var width: Double
    @State private var length: Double
    @State private var location: String
    @State private var note: String
    @State private var imageFileName: String?
    @State private var pickedImage: UIImage?

    @State private var showSourceDialog = false
    @State private var imageSource: ImageSource?

    init(log: CrackLog, onSave: @escaping (CrackLog) -> Void) {
        self.log = log; self.onSave = onSave
        _pourID = State(initialValue: log.pourID)
        _cause = State(initialValue: log.cause)
        _width = State(initialValue: log.widthMm)
        _length = State(initialValue: log.lengthCm)
        _location = State(initialValue: log.location)
        _note = State(initialValue: log.note)
        _imageFileName = State(initialValue: log.imageFileName)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    PourSelector(pourID: $pourID)

                    Text("CAUSE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CrackCause.allCases) { c in
                                Button(action: { cause = c }) {
                                    Text(c.displayName).font(Theme.caption(12))
                                        .foregroundColor(cause == c ? Theme.textOnAccent : Theme.textPrimary)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Capsule().fill(cause == c ? Theme.danger : Theme.surfaceAlt))
                                        .overlay(Capsule().stroke(Theme.stroke, lineWidth: cause == c ? 0 : 1))
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        LabeledNumberField(label: "Width", value: $width, suffix: "mm")
                        LabeledNumberField(label: "Length", value: $length, suffix: "cm", digits: 0)
                    }
                    LabeledField(label: "Location", text: $location, placeholder: "e.g. NE corner")
                    LabeledField(label: "Note", text: $note, placeholder: "What you observed")

                    photoSection

                    ActionButton(title: "Save Crack Log", systemImage: "checkmark") { save() }
                }
                .padding(Theme.Space.m)
            }
            .cureScreen()
            .navigationBarTitle("Crack", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(Theme.textSecondary),
                trailing: Button(action: { store.dummyKeyboardDismiss() }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .foregroundColor(Theme.accent))
            .actionSheet(isPresented: $showSourceDialog) {
                ActionSheet(title: Text("Add Photo"), buttons: [
                    .default(Text("Camera")) { selectImageSource(.camera, into: $imageSource) },
                    .default(Text("Photo Library")) { selectImageSource(.library, into: $imageSource) },
                    .cancel()
                ])
            }
            .sheet(item: $imageSource) { source in
                imageSourcePicker(source) { img in pickedImage = img }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTO").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            if let img = pickedImage ?? PhotoStore.shared.loadImage(named: imageFileName) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(height: 160).frame(maxWidth: .infinity).clipped().cornerRadius(Theme.Radius.s)
            }
            ActionButton(title: pickedImage == nil && imageFileName == nil ? "Add Photo" : "Replace Photo",
                         systemImage: "camera.fill", kind: .secondary) {
                store.dummyKeyboardDismiss()
                showSourceDialog = true
            }
        }
    }

    private func save() {
        var copy = log
        copy.pourID = pourID
        copy.cause = cause
        copy.widthMm = max(width, 0)
        copy.lengthCm = max(length, 0)
        copy.location = location
        copy.note = note
        if let newImage = pickedImage {
            PhotoStore.shared.delete(named: copy.imageFileName)
            copy.imageFileName = PhotoStore.shared.save(newImage)
        } else {
            copy.imageFileName = imageFileName
        }
        onSave(copy)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Reusable pour selector (chips)

struct PourSelector: View {
    @EnvironmentObject var store: AppStore
    @Binding var pourID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POUR").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            if store.pours.isEmpty {
                Text("No pours yet").font(Theme.caption(12)).foregroundColor(Theme.textDisabled)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.pours) { p in
                            Button(action: { pourID = p.id }) {
                                Text(p.name).font(Theme.caption(12))
                                    .foregroundColor(pourID == p.id ? Theme.textOnAccent : Theme.textPrimary)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Capsule().fill(pourID == p.id ? Theme.accent : Theme.surfaceAlt))
                                    .overlay(Capsule().stroke(Theme.stroke, lineWidth: pourID == p.id ? 0 : 1))
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
}
