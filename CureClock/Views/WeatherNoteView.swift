//
//  WeatherNoteView.swift
//  CureClock
//
//  Feature 09: record temperature / rainfall per cure day with a risk badge.
//  These feed the weather-aware maturity calculation on the timeline.
//  iOS 14 safe.
//

import SwiftUI

struct WeatherNoteView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: WeatherNote?

    var body: some View {
        ScreenScaffold("Weather Note", subtitle: "Temp & rain shape the cure") {
            CardView {
                InfoBanner(text: "Recorded days refine the strength curve: warm days speed it up, frost stalls it.",
                           systemImage: "info.circle.fill", tint: Theme.accent)
            }
            if store.weatherNotes.isEmpty {
                CardView {
                    EmptyStateView(systemImage: "cloud.sun", title: "No weather logged",
                                   message: "Add a day's temperature and rainfall.")
                }
            } else {
                ForEach(store.weatherNotes) { note in
                    weatherCard(note)
                }
            }
            ActionButton(title: "Add Weather Day", systemImage: "plus") {
                editing = WeatherNote(pourID: store.primaryPour?.id, tempC: store.settings.cureTempC)
            }
        }
        .navigationBarTitle("Weather", displayMode: .inline)
        .sheet(item: $editing) { note in
            WeatherEditorView(note: note) { store.saveWeather($0) }
                .environmentObject(store)
        }
    }

    private func weatherCard(_ note: WeatherNote) -> some View {
        CardView {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(note.risk.color.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: note.risk.icon).foregroundColor(note.risk.color).font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(Formatters.date(note.date)).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        TagChip(text: note.risk.displayName, color: note.risk.color)
                    }
                    Text("\(Int(note.tempC))°C · \(Formatters.decimal(note.precipitationMm, digits: 0)) mm rain")
                        .font(Theme.mono(12)).foregroundColor(Theme.textSecondary)
                    if !note.note.isEmpty {
                        Text(note.note).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                VStack(spacing: 10) {
                    Button(action: { editing = note }) { Image(systemName: "pencil").foregroundColor(Theme.accent) }
                    Button(action: { store.deleteWeather(note) }) { Image(systemName: "trash").foregroundColor(Theme.danger) }
                }
            }
        }
    }
}

// MARK: - Editor

struct WeatherEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode

    let note: WeatherNote
    let onSave: (WeatherNote) -> Void

    @State private var pourID: UUID?
    @State private var date: Date
    @State private var tempC: Double
    @State private var precip: Double
    @State private var text: String

    init(note: WeatherNote, onSave: @escaping (WeatherNote) -> Void) {
        self.note = note; self.onSave = onSave
        _pourID = State(initialValue: note.pourID)
        _date = State(initialValue: note.date)
        _tempC = State(initialValue: note.tempC)
        _precip = State(initialValue: note.precipitationMm)
        _text = State(initialValue: note.note)
    }

    private var risk: WeatherRisk { WeatherRisk.assess(tempC: tempC, precipitationMm: precip) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    PourSelector(pourID: $pourID)

                    CardView {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("TEMPERATURE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Int(tempC))°C").font(Theme.mono(14)).foregroundColor(risk.color)
                            }
                            Slider(value: $tempC, in: -10...45, step: 1).accentColor(risk.color)
                        }
                    }

                    LabeledNumberField(label: "Rainfall", value: $precip, suffix: "mm", digits: 0)

                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date])
                        .font(Theme.body(14)).accentColor(Theme.accent)
                        .padding(.vertical, 4)

                    LabeledField(label: "Note", text: $text, placeholder: "e.g. covered with hessian")

                    InfoBanner(text: "\(risk.displayName): \(risk.advice)", systemImage: risk.icon, tint: risk.color)

                    ActionButton(title: "Save Weather Day", systemImage: "checkmark") { save() }
                }
                .padding(Theme.Space.m)
            }
            .cureScreen()
            .navigationBarTitle("Weather", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(Theme.textSecondary),
                trailing: Button(action: { store.dummyKeyboardDismiss() }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .foregroundColor(Theme.accent))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func save() {
        var copy = note
        copy.pourID = pourID
        copy.date = date
        copy.tempC = tempC
        copy.precipitationMm = max(precip, 0)
        copy.note = text
        onSave(copy)
        presentationMode.wrappedValue.dismiss()
    }
}
