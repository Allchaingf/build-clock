//
//  Models.swift
//  CureClock
//
//  Codable value types and the AppData root aggregate (the single persisted
//  document). Plus the lightweight derived result types (MixResult, CostResult,
//  MilestoneStatus) returned by the store. iOS 14 safe.
//

import Foundation

// MARK: - Onboarding-captured defaults

struct AppSettings: Codable, Equatable {
    var defaultGoal: MixGoal = .slab
    var defaultStrengthClass: StrengthClass = .m200
    var cureTempC: Double = MixConstants.defaultCureTempC
    var keepWetDays: Int = MixConstants.defaultKeepWetDays
}

// MARK: - Pour & sections

struct PourSection: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String = "Section"
    var widthM: Double = 0
    var lengthM: Double = 0
    var thicknessM: Double = 0          // stored in metres (entered as mm/in)
    var wastePercent: Double = 5

    var volumeM3: Double {
        max(widthM, 0) * max(lengthM, 0) * max(thicknessM, 0) * (1 + max(wastePercent, 0) / 100)
    }
}

struct Pour: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "Pour"
    var goal: MixGoal = .slab
    var strengthClass: StrengthClass = .m200
    var isScreed: Bool = false

    // Snapshot of the mix recipe so later preset edits don't retro-change a pour.
    var ratioCement: Double = 1
    var ratioSand: Double = 2.5
    var ratioAggregate: Double = 4
    var wcRatio: Double = 0.55
    var characteristicMPa: Double = 20

    var sections: [PourSection] = []
    var cureTempC: Double = MixConstants.defaultCureTempC
    var pourDate: Date = Date()
    var notes: String = ""
    var createdAt: Date = Date()

    var totalVolumeM3: Double { sections.reduce(0) { $0 + $1.volumeM3 } }
    var ratioTuple: (c: Double, s: Double, a: Double) { (ratioCement, ratioSand, ratioAggregate) }

    /// Builds a pour seeded from a goal + class (used by calculator/onboarding).
    static func make(goal: MixGoal, strengthClass: StrengthClass, tempC: Double, date: Date) -> Pour {
        var p = Pour()
        p.name = goal.displayName
        p.goal = goal
        p.strengthClass = strengthClass
        p.isScreed = goal.isScreed
        if goal.isScreed {
            p.ratioCement = 1; p.ratioSand = 4; p.ratioAggregate = 0
            p.wcRatio = 0.50
        } else {
            let r = strengthClass.ratio
            p.ratioCement = r.c; p.ratioSand = r.s; p.ratioAggregate = r.a
            p.wcRatio = strengthClass.defaultWC
        }
        p.characteristicMPa = strengthClass.characteristicMPa
        p.cureTempC = tempC
        p.pourDate = date
        return p
    }
}

// MARK: - Mix preset (editable in Settings)

struct MixPreset: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var strengthClass: StrengthClass
    var ratioCement: Double
    var ratioSand: Double
    var ratioAggregate: Double           // 0 for screed
    var wcRatio: Double
    var isScreed: Bool = false
    var characteristicMPa: Double

    /// Cement content implied by this recipe — derived, never stored, so it can't
    /// disagree with what the calculator proportions.
    var cementKgPerM3: Double {
        StrengthEngine.cementContentKgPerM3(ratio: (ratioCement, ratioSand, ratioAggregate))
    }

    var ratioText: String {
        if isScreed { return "1 : \(Formatters.decimal(ratioSand, digits: 1))" }
        return "\(Formatters.decimal(ratioCement, digits: 0)) : \(Formatters.decimal(ratioSand, digits: 1)) : \(Formatters.decimal(ratioAggregate, digits: 1))"
    }
}

// MARK: - Inventory

struct InventoryItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "Cement"
    var bagSizeKg: Double = 50
    var bagsInStock: Int = 0
    var note: String = ""
}

// MARK: - Cost inputs

struct CostInputs: Codable, Equatable {
    var cementPricePerBag: Double = 8
    var sandPricePerM3: Double = 30
    var aggPricePerM3: Double = 35
    var waterPricePerM3: Double = 0
    var mixerRentalPerDay: Double = 0
    var mixerDays: Int = 1
    var pumpRentalPerM3: Double = 0
    var laborPerM3: Double = 0
}

// MARK: - Logs

struct CrackLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var pourID: UUID?
    var cause: CrackCause = .shrinkage
    var widthMm: Double = 0
    var lengthCm: Double = 0
    var location: String = ""
    var imageFileName: String?
    var note: String = ""
    var createdAt: Date = Date()
}

struct WeatherNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var pourID: UUID?
    var date: Date = Date()
    var tempC: Double = 20
    var precipitationMm: Double = 0
    var note: String = ""

    var risk: WeatherRisk { WeatherRisk.assess(tempC: tempC, precipitationMm: precipitationMm) }
}

struct PhotoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var pourID: UUID?
    var stage: PhotoStage = .surface
    var caption: String = ""
    var imageFileName: String?
    var createdAt: Date = Date()
}

struct HistoryEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var pourID: UUID?
    var kind: String          // "poured" / "reached" / "loaded" / "log"
    var title: String
    var detail: String = ""
    var date: Date = Date()
    var icon: String = "circle.fill"

    /// Milestone events are synthesised fresh on every timeline build, so their `id`
    /// changes each time. Lists key off this instead, which depends only on content.
    var stableKey: String {
        "\(kind)|\(pourID?.uuidString ?? "-")|\(title)|\(date.timeIntervalSince1970)"
    }
}

// MARK: - Root document

struct AppData: Codable {
    var schemaVersion = 1
    var settings = AppSettings()
    var pours: [Pour] = []
    var mixPresets: [MixPreset] = []
    var inventory: [InventoryItem] = []
    var crackLogs: [CrackLog] = []
    var weatherNotes: [WeatherNote] = []
    var photoLogs: [PhotoItem] = []
    var historyEvents: [HistoryEvent] = []
    var costInputs = CostInputs()
}

// MARK: - Derived result types (not persisted)

struct MixResult: Equatable {
    var wetVolumeM3: Double = 0
    var dryVolumeM3: Double = 0
    var cementVolumeM3: Double = 0
    var sandVolumeM3: Double = 0
    var aggVolumeM3: Double = 0
    var cementKg: Double = 0
    var sandKg: Double = 0
    var aggKg: Double = 0
    var waterL: Double = 0
    /// Bag count for the currently-selected bag size.
    func bags(ofSizeKg size: Double) -> Int { size <= 0 ? 0 : Int((cementKg / size).rounded(.up)) }
    /// Cement content actually proportioned, per m³ of finished concrete.
    var cementKgPerM3: Double { wetVolumeM3 > 0 ? cementKg / wetVolumeM3 : 0 }
}

struct CostResult: Equatable {
    /// Full cement requirement priced in whole bags — not just the shortfall, so
    /// "Total" really is the cost of the pour rather than the top-up shopping list.
    var cementCost: Double = 0
    /// The part of `cementCost` already covered by bags on site.
    var cementFromStockCost: Double = 0
    var sandCost: Double = 0
    var aggCost: Double = 0
    var waterCost: Double = 0
    var mixerCost: Double = 0
    var pumpCost: Double = 0
    var laborCost: Double = 0

    var materials: Double { cementCost + sandCost + aggCost + waterCost }
    var rental: Double { mixerCost + pumpCost }
    var total: Double { materials + rental + laborCost }
    /// What still has to be bought, i.e. the total less what stock already covers.
    var stillToBuy: Double { max(total - cementFromStockCost, 0) }
}

/// One milestone's live state. `estDate`/`daysFromPour` are nil when the cure is
/// frozen and the gate is never reached at the recorded temperature.
/// The id is the milestone type, not a fresh UUID — these are rebuilt on every
/// render and a new identity each time would tear down and rebuild every row.
struct MilestoneStatus: Identifiable {
    var id: String { type.rawValue }
    let type: CureMilestoneType
    let estDate: Date?
    let daysFromPour: Double?
    let reached: Bool
    var percentAtGate: Double { type.gatePercent }
}
