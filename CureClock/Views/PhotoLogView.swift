//
//  PhotoLogView.swift
//  CureClock
//
//  Feature 10: a photo diary of the pour — formwork, the pour itself, the
//  surface and the finished result, tagged by stage. iOS 14 safe.
//

import SwiftUI

struct PhotoLogView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: PhotoItem?
    @State private var filter: PhotoStage?

    private var items: [PhotoItem] {
        guard let f = filter else { return store.photoLogs }
        return store.photoLogs.filter { $0.stage == f }
    }

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScreenScaffold("Photo Log", subtitle: "Document every stage") {
            filterBar
            if items.isEmpty {
                CardView {
                    EmptyStateView(systemImage: "photo.on.rectangle.angled", title: "No photos",
                                   message: "Capture or import a photo of this pour.")
                }
            } else {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(items) { item in
                        photoTile(item)
                    }
                }
            }
            ActionButton(title: "Add Photo", systemImage: "plus") {
                editing = PhotoItem(pourID: store.primaryPour?.id, stage: filter ?? .surface)
            }
        }
        .navigationBarTitle("Photos", displayMode: .inline)
        .sheet(item: $editing) { item in
            PhotoEditorView(item: item) { store.savePhoto($0) }
                .environmentObject(store)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", active: filter == nil) { filter = nil }
                ForEach(PhotoStage.allCases) { s in
                    chip(s.displayName, active: filter == s, color: s.color) { filter = s }
                }
            }
        }
    }

    private func chip(_ text: String, active: Bool, color: Color = Theme.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(Theme.caption(12))
                .foregroundColor(active ? Theme.textOnAccent : Theme.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(active ? color : Theme.surface))
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: active ? 0 : 1))
        }.buttonStyle(PlainButtonStyle())
    }

    private func photoTile(_ item: PhotoItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if let img = PhotoStore.shared.loadImage(named: item.imageFileName) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(height: 130).frame(maxWidth: .infinity).clipped()
                } else {
                    Rectangle().fill(Theme.surfaceAlt).frame(height: 130)
                        .overlay(Image(systemName: "photo").foregroundColor(Theme.textDisabled))
                }
                TagChip(text: item.stage.displayName, color: item.stage.color, filled: true).padding(6)
            }
            .cornerRadius(Theme.Radius.s)
            if !item.caption.isEmpty {
                Text(item.caption).font(Theme.caption(11)).foregroundColor(Theme.textSecondary).lineLimit(2)
            }
            HStack {
                Text(Formatters.dayMonth(item.createdAt)).font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
                Spacer()
                Button(action: { editing = item }) { Image(systemName: "pencil").foregroundColor(Theme.accent) }
                Button(action: { store.deletePhoto(item) }) { Image(systemName: "trash").foregroundColor(Theme.danger) }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
    }
}

// MARK: - Editor

struct PhotoEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode

    let item: PhotoItem
    let onSave: (PhotoItem) -> Void

    @State private var pourID: UUID?
    @State private var stage: PhotoStage
    @State private var caption: String
    @State private var imageFileName: String?
    @State private var pickedImage: UIImage?

    @State private var showSourceDialog = false
    @State private var imageSource: ImageSource?

    init(item: PhotoItem, onSave: @escaping (PhotoItem) -> Void) {
        self.item = item; self.onSave = onSave
        _pourID = State(initialValue: item.pourID)
        _stage = State(initialValue: item.stage)
        _caption = State(initialValue: item.caption)
        _imageFileName = State(initialValue: item.imageFileName)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    PourSelector(pourID: $pourID)

                    Text("STAGE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(PhotoStage.allCases) { s in
                            Button(action: { stage = s }) {
                                VStack(spacing: 4) {
                                    Image(systemName: s.icon)
                                    Text(s.displayName).font(Theme.caption(11))
                                }
                                .foregroundColor(stage == s ? Theme.textOnAccent : Theme.textPrimary)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(stage == s ? s.color : Theme.surfaceAlt))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke, lineWidth: stage == s ? 0 : 1))
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }

                    if let img = pickedImage ?? PhotoStore.shared.loadImage(named: imageFileName) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 200).frame(maxWidth: .infinity).clipped().cornerRadius(Theme.Radius.s)
                    }
                    ActionButton(title: pickedImage == nil && imageFileName == nil ? "Add Photo" : "Replace Photo",
                                 systemImage: "camera.fill", kind: .secondary) {
                        store.dummyKeyboardDismiss(); showSourceDialog = true
                    }

                    LabeledField(label: "Caption", text: $caption, placeholder: "e.g. Mesh laid, ready to pour")

                    ActionButton(title: "Save Photo", systemImage: "checkmark") { save() }
                }
                .padding(Theme.Space.m)
            }
            .cureScreen()
            .navigationBarTitle("Photo", displayMode: .inline)
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

    private func save() {
        var copy = item
        copy.pourID = pourID
        copy.stage = stage
        copy.caption = caption
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
