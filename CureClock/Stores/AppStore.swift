//
//  AppStore.swift
//  CureClock
//
//  The single source of truth (@EnvironmentObject). Holds AppData, exposes
//  uniform CRUD for every entity and all cross-screen derived calculations
//  (mix, strength %, milestones, cost) so numbers stay identical everywhere.
//  iOS 14 safe.
//

import SwiftUI

final class AppStore: ObservableObject {
    @Published private(set) var data: AppData { didSet { revision &+= 1 } }

    /// Bumped on every mutation; derived caches key off it.
    private var revision = 0

    // Display preferences. These used to be read straight out of UserDefaults on every
    // access, so nothing observed them and Settings had to poke `objectWillChange`
    // by hand to get the rest of the app to redraw.
    @Published var volumeUnit: VolumeUnit {
        didSet { UserDefaults.standard.set(volumeUnit.rawValue, forKey: Keys.volumeUnit) }
    }
    @Published var bagSize: BagSize {
        didSet { UserDefaults.standard.set(bagSize.rawValue, forKey: Keys.bagSize) }
    }
    @Published var currency: CurrencyCode {
        didSet { UserDefaults.standard.set(currency.rawValue, forKey: Keys.currency) }
    }

    private enum Keys {
        static let volumeUnit = "volumeUnit"
        static let bagSize = "bagSizeKg"
        static let currency = "currencyCode"
    }

    private let persistence = PersistenceManager.shared
    private let photos = PhotoStore.shared

    init() {
        let defaults = UserDefaults.standard
        volumeUnit = VolumeUnit(rawValue: defaults.string(forKey: Keys.volumeUnit) ?? "") ?? .cubicMeters
        bagSize = BagSize(rawValue: defaults.object(forKey: Keys.bagSize) as? Int ?? 50) ?? .kg50
        currency = CurrencyCode(rawValue: defaults.string(forKey: Keys.currency) ?? "") ?? .usd
        self.data = persistence.load()
    }

    // MARK: - Generic CRUD helpers

    private func upsert<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>) where T.ID == UUID {
        if let i = data[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
            data[keyPath: keyPath][i] = item
        } else {
            data[keyPath: keyPath].append(item)
        }
        save()
    }

    private func remove<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>) where T.ID == UUID {
        data[keyPath: keyPath].removeAll { $0.id == item.id }
        save()
    }

    // MARK: - Settings / preferences (read back from @AppStorage)

    var settings: AppSettings { data.settings }
    func updateSettings(_ s: AppSettings) { data.settings = s; save() }

    var bagSizeKg: Double { bagSize.kg }
    func money(_ value: Double) -> String { Formatters.currency(value, code: currency) }
    /// Format a volume (stored in m³) in the user's chosen unit.
    func volume(_ m3: Double) -> String {
        "\(Formatters.decimal(m3 * volumeUnit.fromM3, digits: 2)) \(volumeUnit.symbol)"
    }

    // MARK: - Collections

    var pours: [Pour] { data.pours.sorted { $0.createdAt > $1.createdAt } }
    var mixPresets: [MixPreset] { data.mixPresets }
    var inventory: [InventoryItem] { data.inventory }
    var crackLogs: [CrackLog] { data.crackLogs.sorted { $0.createdAt > $1.createdAt } }
    var weatherNotes: [WeatherNote] { data.weatherNotes.sorted { $0.date > $1.date } }
    var photoLogs: [PhotoItem] { data.photoLogs.sorted { $0.createdAt > $1.createdAt } }
    var costInputs: CostInputs { data.costInputs }

    /// The pour most screens default to (the newest one).
    var primaryPour: Pour? { pours.first }
    func pour(_ id: UUID?) -> Pour? { guard let id = id else { return nil }; return data.pours.first { $0.id == id } }
    func pourName(_ id: UUID?) -> String { pour(id)?.name ?? "—" }

    // MARK: - CRUD per entity

    func savePour(_ p: Pour) {
        let isNew = !data.pours.contains { $0.id == p.id }
        upsert(p, \.pours)
        if isNew {
            let mix = mixResult(for: p)
            addHistory(HistoryEvent(pourID: p.id, kind: "poured", title: "\(p.name) poured",
                                    detail: "\(volume(p.totalVolumeM3)) · \(p.strengthClass.displayName)",
                                    date: p.pourDate, icon: "drop.fill"))
            _ = mix
        }
    }
    func deletePour(_ p: Pour) {
        // Drop the image blobs too. `deletePhoto`/`deleteCrack` do this; deleting the
        // whole pour only removed the records, orphaning every JPEG in Documents
        // (and in the user's iCloud backup) forever.
        for photo in data.photoLogs where photo.pourID == p.id { photos.delete(named: photo.imageFileName) }
        for crack in data.crackLogs where crack.pourID == p.id { photos.delete(named: crack.imageFileName) }

        data.weatherNotes.removeAll { $0.pourID == p.id }
        data.crackLogs.removeAll { $0.pourID == p.id }
        data.photoLogs.removeAll { $0.pourID == p.id }
        data.historyEvents.removeAll { $0.pourID == p.id }
        remove(p, \.pours)
    }

    func saveMixPreset(_ m: MixPreset) { upsert(m, \.mixPresets) }
    func deleteMixPreset(_ m: MixPreset) { remove(m, \.mixPresets) }
    func resetPresets() { data.mixPresets = SampleData.defaultPresets(); save() }

    func saveInventory(_ i: InventoryItem) { upsert(i, \.inventory) }
    func deleteInventory(_ i: InventoryItem) { remove(i, \.inventory) }

    func saveCrack(_ c: CrackLog) { upsert(c, \.crackLogs) }
    func deleteCrack(_ c: CrackLog) {
        photos.delete(named: c.imageFileName)
        remove(c, \.crackLogs)
    }

    func saveWeather(_ w: WeatherNote) { upsert(w, \.weatherNotes) }
    func deleteWeather(_ w: WeatherNote) { remove(w, \.weatherNotes) }

    func savePhoto(_ p: PhotoItem) { upsert(p, \.photoLogs) }
    func deletePhoto(_ p: PhotoItem) {
        photos.delete(named: p.imageFileName)
        remove(p, \.photoLogs)
    }

    func updateCostInputs(_ c: CostInputs) { data.costInputs = c; save() }

    private func addHistory(_ e: HistoryEvent) { upsert(e, \.historyEvents) }

    // MARK: - Mix derivations

    func mixResult(for pour: Pour) -> MixResult {
        StrengthEngine.mixResult(volumeM3: pour.totalVolumeM3, ratio: pour.ratioTuple, wc: pour.wcRatio)
    }
    func mixResult(volumeM3: Double, ratio: (c: Double, s: Double, a: Double), wc: Double) -> MixResult {
        StrengthEngine.mixResult(volumeM3: volumeM3, ratio: ratio, wc: wc)
    }
    func waterQuality(for pour: Pour) -> WaterQuality { WaterQuality.classify(pour.wcRatio) }

    // MARK: - Strength derivations

    /// Cure temperature for each elapsed day of a pour: the logged weather note for
    /// that day where there is one, otherwise the pour's nominal cure temperature.
    /// Day 0 is the first 24 h after the pour.
    private func loggedTemps(for pour: Pour) -> [Int: Double] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: pour.pourDate)
        var tempByDay: [Int: Double] = [:]
        for n in data.weatherNotes where n.pourID == pour.id {
            let d = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: n.date)).day ?? 0
            if d >= 0 { tempByDay[d] = n.tempC }
        }
        return tempByDay
    }

    /// Equivalent age (days at 20°C) elapsed for a pour, weather-aware when notes exist.
    /// This is *the* measure of progress — the ring, the curve, the milestone dates and
    /// the allowed-now list are all derived from it, so they cannot disagree.
    func equivalentDaysElapsed(for pour: Pour, on date: Date = Date()) -> Double {
        let elapsed = max(date.timeIntervalSince(pour.pourDate) / 86_400, 0)
        let tempByDay = loggedTemps(for: pour)
        guard !tempByDay.isEmpty else {
            return StrengthEngine.equivalentDays(calendarDays: elapsed, tempC: pour.cureTempC)
        }
        let wholeDays = Int(elapsed)
        var equiv = 0.0
        if wholeDays > 0 {
            for day in 0..<wholeDays { equiv += StrengthEngine.tempFactor(tempByDay[day] ?? pour.cureTempC) }
        }
        let frac = elapsed - Double(wholeDays)
        equiv += frac * StrengthEngine.tempFactor(tempByDay[wholeDays] ?? pour.cureTempC)
        return equiv
    }

    /// The calendar moment at which a pour reaches `target` equivalent days, walking
    /// forward day by day through the same logged/nominal temperatures used above.
    /// `nil` when the cure is frozen and the target is never reached.
    func date(forEquivalentDays target: Double, pour: Pour) -> Date? {
        guard target > 0 else { return pour.pourDate }
        let tempByDay = loggedTemps(for: pour)
        let horizon = MixConstants.designAgeDays * 12          // ≈ a year, then give up
        var equiv = 0.0
        for day in 0..<horizon {
            let factor = StrengthEngine.tempFactor(tempByDay[day] ?? pour.cureTempC)
            guard factor > 0 else { continue }
            if target - equiv <= factor {
                let frac = (target - equiv) / factor
                return pour.pourDate.addingTimeInterval((Double(day) + frac) * 86_400)
            }
            equiv += factor
        }
        return nil
    }

    func currentStrengthPercent(for pour: Pour, on date: Date = Date()) -> Double {
        StrengthEngine.fraction(equivDays: equivalentDaysElapsed(for: pour, on: date)) * 100
    }

    func daysSincePour(_ pour: Pour, on date: Date = Date()) -> Double {
        max(date.timeIntervalSince(pour.pourDate) / 86_400, 0)
    }

    /// Strength % per calendar day (index 0…maxDay) — weather-aware for days already
    /// logged, projected at the pour's temperature after that. Plotting this against
    /// the same equivalent-age model means the "today" point sits exactly on the ring.
    func curveSeries(for pour: Pour, days: Int = MixConstants.designAgeDays) -> [Double] {
        (0...days).map { d in
            let at = pour.pourDate.addingTimeInterval(Double(d) * 86_400)
            return StrengthEngine.fraction(equivDays: equivalentDaysElapsed(for: pour, on: at)) * 100
        }
    }

    func milestones(for pour: Pour, on date: Date = Date()) -> [MilestoneStatus] {
        let elapsedEquiv = equivalentDaysElapsed(for: pour, on: date)
        return CureMilestoneType.allCases.map { type in
            let required = StrengthEngine.requiredEquivDays(forGate: type)
            let est = self.date(forEquivalentDays: required, pour: pour)
            return MilestoneStatus(type: type,
                                   estDate: est,
                                   daysFromPour: est.map { $0.timeIntervalSince(pour.pourDate) / 86_400 },
                                   reached: elapsedEquiv >= required)
        }
    }

    func curveMarkers(for pour: Pour, on date: Date = Date()) -> [StrengthMarker] {
        milestones(for: pour, on: date).compactMap { status in
            guard let days = status.daysFromPour else { return nil }
            return StrengthMarker(type: status.type,
                                  day: min(days, Double(MixConstants.designAgeDays)),
                                  percent: status.type.gatePercent,
                                  symbol: status.type.icon, color: status.type.color,
                                  reached: status.reached)
        }
    }

    func allowedNow(for pour: Pour, on date: Date = Date()) -> [CureMilestoneType] {
        let equiv = equivalentDaysElapsed(for: pour, on: date)
        return CureMilestoneType.allCases.filter { equiv >= StrengthEngine.requiredEquivDays(forGate: $0) }
    }

    func nextMilestone(for pour: Pour, on date: Date = Date()) -> MilestoneStatus? {
        milestones(for: pour, on: date).first { !$0.reached }
    }

    /// True while any part of the cure is stalled by cold — either the pour's nominal
    /// temperature or a logged weather day is at or below freezing.
    func isCureStalled(for pour: Pour) -> Bool {
        if StrengthEngine.isFrozen(pour.cureTempC) { return true }
        return data.weatherNotes.contains { $0.pourID == pour.id && StrengthEngine.isFrozen($0.tempC) }
    }

    // MARK: - Inventory sufficiency

    var cementStockKg: Double {
        data.inventory.reduce(0) { $0 + Double($1.bagsInStock) * $1.bagSizeKg }
    }
    var totalCementNeededKg: Double {
        data.pours.reduce(0) { $0 + mixResult(for: $1).cementKg }
    }
    /// Bags (at the user's bag size) still to buy to cover all pours.
    var bagsShortAll: Int {
        let deficit = max(totalCementNeededKg - cementStockKg, 0)
        return Int((deficit / bagSizeKg).rounded(.up))
    }

    /// Cement in stock is one shared pile, not a private allowance per pour. It is
    /// handed out oldest pour first, so three pours no longer each subtract the whole
    /// stock and under-report both the shortfall and the cost.
    private var allocationCache: (revision: Int, map: [UUID: (needKg: Double, coveredKg: Double)])?

    private func cementAllocation() -> [UUID: (needKg: Double, coveredKg: Double)] {
        if let cached = allocationCache, cached.revision == revision { return cached.map }
        var remaining = cementStockKg
        var map: [UUID: (needKg: Double, coveredKg: Double)] = [:]
        for p in data.pours.sorted(by: { $0.pourDate < $1.pourDate }) {
            let need = mixResult(for: p).cementKg
            let covered = min(need, max(remaining, 0))
            remaining -= covered
            map[p.id] = (need, covered)
        }
        allocationCache = (revision, map)
        return map
    }

    /// Cement this pour still has to be bought for, after its share of stock.
    func cementDeficitKg(for pour: Pour) -> Double {
        guard let a = cementAllocation()[pour.id] else {
            return max(mixResult(for: pour).cementKg - cementStockKg, 0)
        }
        return max(a.needKg - a.coveredKg, 0)
    }

    func bagsShort(for pour: Pour) -> Int {
        Int((cementDeficitKg(for: pour) / bagSizeKg).rounded(.up))
    }

    // MARK: - Cost

    func cost(for pour: Pour) -> CostResult {
        let c = data.costInputs
        let mix = mixResult(for: pour)
        let vol = pour.totalVolumeM3

        let bagsNeeded = mix.bags(ofSizeKg: bagSizeKg)
        let bagsToBuy = bagsShort(for: pour)
        let bagsCovered = max(bagsNeeded - bagsToBuy, 0)

        var r = CostResult()
        r.cementCost          = Double(bagsNeeded) * c.cementPricePerBag
        r.cementFromStockCost = Double(bagsCovered) * c.cementPricePerBag
        r.sandCost   = mix.sandVolumeM3 * c.sandPricePerM3
        r.aggCost    = mix.aggVolumeM3 * c.aggPricePerM3
        r.waterCost  = (mix.waterL / 1000) * c.waterPricePerM3
        r.mixerCost  = c.mixerRentalPerDay * Double(c.mixerDays)
        r.pumpCost   = c.pumpRentalPerM3 * vol
        r.laborCost  = c.laborPerM3 * vol
        return r
    }
    func costPerM3(for pour: Pour) -> Double {
        let vol = pour.totalVolumeM3
        return vol > 0 ? cost(for: pour).total / vol : 0
    }

    // MARK: - Report snapshot

    /// Immutable copy of everything a PDF export needs. Built on the main thread so
    /// the renderer never touches `@Published` state from its background queue.
    func reportSnapshot(for pour: Pour) -> ReportSnapshot {
        ReportSnapshot(pour: pour,
                       mix: mixResult(for: pour),
                       cost: cost(for: pour),
                       costPerM3: costPerM3(for: pour),
                       milestones: milestones(for: pour),
                       curve: curveSeries(for: pour),
                       waterQuality: waterQuality(for: pour),
                       bagSizeKg: bagSizeKg,
                       volumeUnit: volumeUnit,
                       currency: currency)
    }

    // MARK: - History timeline (derived)

    /// Recomputing this walks every pour's milestones, and `HistoryView` asks for it
    /// from `body`. Cached against the data revision and the calendar day (milestones
    /// only become "reached" as time passes) so a re-render is free.
    private var timelineCache: (revision: Int, day: Date, events: [HistoryEvent])?

    func timeline() -> [HistoryEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        if let cached = timelineCache, cached.revision == revision, cached.day == today {
            return cached.events
        }
        var events = data.historyEvents
        for p in data.pours {
            for m in milestones(for: p) where m.reached {
                guard let est = m.estDate else { continue }
                events.append(HistoryEvent(pourID: p.id, kind: "reached",
                                           title: "\(p.name): \(m.type.displayName)",
                                           detail: "≥\(Int(m.type.gatePercent))% strength reached",
                                           date: est, icon: m.type.icon))
            }
        }
        let sorted = events.sorted { $0.date > $1.date }
        timelineCache = (revision, today, sorted)
        return sorted
    }

    // MARK: - Dashboard signals

    /// A pour is still curing until it clears the full-load gate (28 equivalent days),
    /// the same test the timeline and the allowed-now list use.
    var activeCuringCount: Int {
        let fullLoad = StrengthEngine.requiredEquivDays(forGate: .fullLoad)
        return data.pours.filter { equivalentDaysElapsed(for: $0) < fullLoad }.count
    }
    var openCrackCount: Int { data.crackLogs.count }
    var attentionCount: Int { activeCuringCount + data.crackLogs.count }

    // MARK: - Lifecycle

    private func save() { persistence.save(data) }
    func flush() { persistence.flush(data) }

    func replace(with newData: AppData) {
        data = newData
        persistence.saveNow(data)
        objectWillChange.send()
    }

    func wipeAll() {
        photos.clearAll()
        data = SampleData.empty()
        persistence.saveNow(data)
        objectWillChange.send()
    }
}
