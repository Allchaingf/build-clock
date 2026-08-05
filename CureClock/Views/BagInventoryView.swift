//
//  BagInventoryView.swift
//  CureClock
//
//  Feature 06: cement / mix bags in stock vs. what the pours need, with a clear
//  enough / short-by-N badge. Add, edit and adjust stock. iOS 14 safe.
//

import SwiftUI

struct BagInventoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: InventoryItem?

    var body: some View {
        ScreenScaffold("Bag Inventory", subtitle: "Will your stock cover the pours?") {
            sufficiencyCard
            listCard
            ActionButton(title: "Add Item", systemImage: "plus") {
                editing = InventoryItem(name: "", bagSizeKg: store.bagSizeKg, bagsInStock: 0)
            }
        }
        .navigationBarTitle("Inventory", displayMode: .inline)
        .sheet(item: $editing) { item in
            InventoryEditorView(item: item) { store.saveInventory($0) }
                .environmentObject(store)
        }
    }

    private var sufficiencyCard: some View {
        let neededKg = store.totalCementNeededKg
        let stockKg = store.cementStockKg
        let short = store.bagsShortAll
        let enough = short == 0
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Cement check", systemImage: "shippingbox.fill")
                    Spacer()
                    TagChip(text: enough ? "Enough" : "Short \(short)",
                            color: enough ? Theme.success : Theme.warning, filled: true)
                }
                HStack {
                    metric("Needed", "\(Formatters.decimal(neededKg, digits: 0)) kg",
                           "\(Int((neededKg / store.bagSizeKg).rounded(.up))) bags")
                    Divider().frame(height: 40).background(Theme.stroke)
                    metric("In stock", "\(Formatters.decimal(stockKg, digits: 0)) kg",
                           "\(Int((stockKg / store.bagSizeKg).rounded(.down))) bags")
                }
                ProgressBar(progress: neededKg > 0 ? min(stockKg / neededKg * 100, 100) : 100,
                            tint: enough ? Theme.success : Theme.warning)
                if !enough {
                    InfoBanner(text: "Buy \(short) more \(Int(store.bagSizeKg)) kg bag(s) to cover all current pours.",
                               systemImage: "cart.fill.badge.plus", tint: Theme.warning)
                } else {
                    InfoBanner(text: "Stock covers the cement for every saved pour.",
                               systemImage: "checkmark.seal.fill", tint: Theme.success)
                }
            }
        }
    }

    private func metric(_ label: String, _ big: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            Text(big).font(Theme.monoBold(18)).foregroundColor(Theme.accentHi)
            Text(sub).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Stock items", systemImage: "tray.full.fill")
                if store.inventory.isEmpty {
                    EmptyStateView(systemImage: "shippingbox", title: "No stock",
                                   message: "Add cement or ready-mix bags you have on site.")
                } else {
                    ForEach(store.inventory) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name.isEmpty ? "Item" : item.name)
                                    .font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                                Text("\(Int(item.bagSizeKg)) kg bags\(item.note.isEmpty ? "" : " · \(item.note)")")
                                    .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            stepper(item)
                            // Visible delete, rather than a long press nobody discovers.
                            Button(action: { withAnimation { store.deleteInventory(item) } }) {
                                Image(systemName: "trash").foregroundColor(Theme.danger)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 6)
                        .overlay(Divider().background(Theme.stroke), alignment: .bottom)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = item }
                    }
                }
            }
        }
    }

    private func stepper(_ item: InventoryItem) -> some View {
        HStack(spacing: 10) {
            Button(action: { adjust(item, -1) }) {
                Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundColor(Theme.concrete)
            }.buttonStyle(PlainButtonStyle())
            Text("\(item.bagsInStock)").font(Theme.monoBold(18)).foregroundColor(Theme.textPrimary)
                .frame(minWidth: 34)
            Button(action: { adjust(item, 1) }) {
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(Theme.accent)
            }.buttonStyle(PlainButtonStyle())
        }
    }

    private func adjust(_ item: InventoryItem, _ delta: Int) {
        var copy = item
        copy.bagsInStock = max(copy.bagsInStock + delta, 0)
        store.saveInventory(copy)
    }
}

// MARK: - Editor sheet

struct InventoryEditorView: View {
    @Environment(\.presentationMode) private var presentationMode
    let item: InventoryItem
    let onSave: (InventoryItem) -> Void

    @State private var name: String
    @State private var bagSize: Double
    @State private var stock: Double
    @State private var note: String

    init(item: InventoryItem, onSave: @escaping (InventoryItem) -> Void) {
        self.item = item; self.onSave = onSave
        _name = State(initialValue: item.name)
        _bagSize = State(initialValue: item.bagSizeKg)
        _stock = State(initialValue: Double(item.bagsInStock))
        _note = State(initialValue: item.note)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    LabeledField(label: "Name", text: $name, placeholder: "e.g. Cement (OPC)")
                    HStack(spacing: 12) {
                        LabeledNumberField(label: "Bag size", value: $bagSize, suffix: "kg", digits: 0)
                        LabeledNumberField(label: "Bags in stock", value: $stock, suffix: "bags", digits: 0)
                    }
                    LabeledField(label: "Note", text: $note, placeholder: "Where it's stored")
                    ActionButton(title: "Save", systemImage: "checkmark") { save() }
                }
                .padding(Theme.Space.m)
            }
            .cureScreen()
            .navigationBarTitle("Stock Item", displayMode: .inline)
            // Every field here is a .decimalPad with no Return key, and "Save" sits
            // under the keyboard — without this there is no way to put it away.
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
        var copy = item
        copy.name = name.isEmpty ? "Item" : name
        copy.bagSizeKg = max(bagSize, 1)
        copy.bagsInStock = Int(max(stock, 0))
        copy.note = note
        onSave(copy)
        presentationMode.wrappedValue.dismiss()
    }
}
