//
//  Enums.swift
//  CureClock
//
//  All domain enums: strength classes, mix goals, water quality, cure milestones,
//  crack causes, photo stages, weather risk, plus unit/currency/appearance prefs.
//  Each is Codable + display metadata. iOS 14 safe.
//

import SwiftUI

// MARK: - Strength class (M-grade ≈ C-grade)

enum StrengthClass: String, Codable, CaseIterable, Identifiable {
    case m150, m200, m300
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .m150: return "M150"
        case .m200: return "M200"
        case .m300: return "M300"
        }
    }
    var cEquivalent: String {
        switch self {
        case .m150: return "C16"
        case .m200: return "C20"
        case .m300: return "C25"
        }
    }
    var characteristicMPa: Double {
        switch self {
        case .m150: return 15
        case .m200: return 20
        case .m300: return 25
        }
    }
    /// Nominal ratio cement : sand : aggregate (by volume).
    var ratio: (c: Double, s: Double, a: Double) {
        switch self {
        case .m150: return (1, 3, 5)
        case .m200: return (1, 2.5, 4)
        case .m300: return (1, 2, 3.5)
        }
    }
    var defaultWC: Double {
        switch self {
        case .m150: return 0.60
        case .m200: return 0.55
        case .m300: return 0.50
        }
    }
    /// Derived from this class's nominal ratio, so the figure quoted here is exactly
    /// what the mix calculator will proportion.
    var cementKgPerM3: Double { StrengthEngine.cementContentKgPerM3(ratio: ratio) }
    var blurb: String {
        switch self {
        case .m150: return "Mass / non-structural fill, low load."
        case .m200: return "General slabs, paths, light structures."
        case .m300: return "Structural slabs, footings, heavier load."
        }
    }
}

// MARK: - Mix goal (drives default class & whether it's a screed)

enum MixGoal: String, Codable, CaseIterable, Identifiable {
    case foundation, screed, slab, repair
    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .foundation: return "Footings & mass concrete"
        case .screed:     return "Sand-cement floor topping"
        case .slab:       return "Floors, paths, driveways"
        case .repair:     return "Patches & small fixes"
        }
    }
    var icon: String {
        switch self {
        case .foundation: return "square.3.layers.3d.down.right"
        case .screed:     return "rectangle.compress.vertical"
        case .slab:       return "square.split.bottomrightquarter"
        case .repair:     return "bandage.fill"
        }
    }
    var color: Color {
        switch self {
        case .foundation: return Theme.concrete
        case .screed:     return Theme.water
        case .slab:       return Theme.accent
        case .repair:     return Theme.warning
        }
    }
    var defaultStrengthClass: StrengthClass {
        switch self {
        case .foundation: return .m200
        case .screed:     return .m200
        case .slab:       return .m200
        case .repair:     return .m300
        }
    }
    var isScreed: Bool { self == .screed }
}

// MARK: - Water/cement quality band

enum WaterQuality: String {
    case tooDry, strong, ideal, acceptable, tooWet

    static func classify(_ wc: Double) -> WaterQuality {
        switch wc {
        case ..<0.40:        return .tooDry
        case 0.40..<0.45:    return .strong
        case 0.45..<0.55:    return .ideal
        case 0.55..<0.65:    return .acceptable
        default:             return .tooWet
        }
    }

    var title: String {
        switch self {
        case .tooDry:     return "Very stiff"
        case .strong:     return "Strong"
        case .ideal:      return "Ideal"
        case .acceptable: return "Acceptable"
        case .tooWet:     return "Too wet"
        }
    }
    var message: String {
        switch self {
        case .tooDry:     return "Low workability — hard to place. Consider a plasticiser rather than more water."
        case .strong:     return "Strong & durable, but stiff. Good for structural pours."
        case .ideal:      return "Ideal balance of strength and workability."
        case .acceptable: return "Workable but slightly weaker. Don't add more water."
        case .tooWet:     return "Too much water → markedly weaker, more shrinkage and a real cracking risk."
        }
    }
    var color: Color {
        switch self {
        case .tooDry:     return Theme.warning
        case .strong:     return Theme.success
        case .ideal:      return Theme.success
        case .acceptable: return Theme.warning
        case .tooWet:     return Theme.danger
        }
    }
    var icon: String {
        switch self {
        case .ideal, .strong: return "checkmark.seal.fill"
        case .tooWet:         return "drop.triangle.fill"
        default:             return "exclamationmark.triangle.fill"
        }
    }
    var isWarning: Bool { self == .tooWet || self == .acceptable || self == .tooDry }
}

// MARK: - Cure milestones (strength gates)

enum CureMilestoneType: String, Codable, CaseIterable, Identifiable {
    case walkOn, removeFormworkSides, tileFinish, removeProps, fullLoad
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .walkOn:              return "Walk on"
        case .removeFormworkSides: return "Strip side formwork"
        case .tileFinish:          return "Tile / finish"
        case .removeProps:         return "Remove props"
        case .fullLoad:            return "Full load (cured)"
        }
    }
    var detail: String {
        switch self {
        case .walkOn:              return "Light foot traffic is OK."
        case .removeFormworkSides: return "Vertical shutters can come off."
        case .tileFinish:          return "Surface finishing & tiling, partial load."
        case .removeProps:         return "Soffit props out — only with the designer's agreement."
        case .fullLoad:            return "Full design load — vehicles, structure."
        }
    }
    /// Strength % of the 28-day value this gate corresponds to. Derived from the
    /// gate's required equivalent age so the percentage shown and the date shown
    /// always come from the same number.
    var gatePercent: Double { StrengthEngine.gatePercent(forGate: self) }

    /// Milestones that carry structural risk and need a professional sign-off
    /// rather than an app estimate.
    var needsEngineerSignOff: Bool { self == .removeProps || self == .fullLoad }
    var icon: String {
        switch self {
        case .walkOn:              return "figure.walk"
        case .removeFormworkSides: return "square.dashed"
        case .tileFinish:          return "square.grid.3x3.fill"
        case .removeProps:         return "arrow.up.and.down.square"
        case .fullLoad:            return "checkmark.seal.fill"
        }
    }
    var color: Color {
        switch self {
        case .walkOn:              return Theme.water
        case .removeFormworkSides: return Theme.accent
        case .tileFinish:          return Theme.accentHi
        case .removeProps:         return Theme.warning
        case .fullLoad:            return Theme.success
        }
    }
}

// MARK: - Crack causes

enum CrackCause: String, Codable, CaseIterable, Identifiable {
    case shrinkage, thermal, settlement, overload, plastic
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shrinkage:  return "Drying shrinkage"
        case .thermal:    return "Thermal"
        case .settlement: return "Settlement"
        case .overload:   return "Early overload"
        case .plastic:    return "Plastic (fresh)"
        }
    }
    var hint: String {
        switch self {
        case .shrinkage:  return "Often from drying too fast — keep it damp."
        case .thermal:    return "Large temperature swings during cure."
        case .settlement: return "Ground or formwork moved under load."
        case .overload:   return "Loaded before enough strength was gained."
        case .plastic:    return "Surface dried before it set — recur the surface."
        }
    }
    var icon: String { "scribble.variable" }
    var color: Color { Theme.danger }
}

// MARK: - Photo stages

enum PhotoStage: String, Codable, CaseIterable, Identifiable {
    case pour, formwork, surface, finished
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .pour:     return "drop.fill"
        case .formwork: return "square.dashed"
        case .surface:  return "square.on.square"
        case .finished: return "checkmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .pour:     return Theme.water
        case .formwork: return Theme.concrete
        case .surface:  return Theme.accent
        case .finished: return Theme.success
        }
    }
}

// MARK: - Weather risk

enum WeatherRisk: String, Codable, CaseIterable, Identifiable {
    case ok, frost, hot, rain
    var id: String { rawValue }

    static func assess(tempC: Double, precipitationMm: Double) -> WeatherRisk {
        if tempC < 5 { return .frost }
        if tempC > 32 { return .hot }
        if precipitationMm > 2 { return .rain }
        return .ok
    }
    var displayName: String {
        switch self {
        case .ok:    return "Good"
        case .frost: return "Frost risk"
        case .hot:   return "Hot — dries fast"
        case .rain:  return "Rain"
        }
    }
    var advice: String {
        switch self {
        case .ok:    return "Conditions are fine for curing."
        case .frost: return "Below 5°C: strength gain stalls. Protect with insulation."
        case .hot:   return "Above 32°C: cure too fast → shrinkage. Keep damp & shaded."
        case .rain:  return "Protect fresh surfaces from washout and pitting."
        }
    }
    var icon: String {
        switch self {
        case .ok:    return "sun.max.fill"
        case .frost: return "snowflake"
        case .hot:   return "thermometer.sun.fill"
        case .rain:  return "cloud.rain.fill"
        }
    }
    var color: Color {
        switch self {
        case .ok:    return Theme.success
        case .frost: return Theme.water
        case .hot:   return Theme.warning
        case .rain:  return Theme.info
        }
    }
}

// MARK: - Units

enum VolumeUnit: String, Codable, CaseIterable, Identifiable {
    case cubicMeters, cubicFeet
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cubicMeters: return "Cubic metres (m³)"
        case .cubicFeet:   return "Cubic feet (ft³)"
        }
    }
    var symbol: String { self == .cubicMeters ? "m³" : "ft³" }
    /// Multiply an m³ value by this to display in the chosen unit.
    var fromM3: Double { self == .cubicMeters ? 1 : 35.3147 }
    /// Linear (length) symbol & conversion for dimension entry.
    var lengthSymbol: String { self == .cubicMeters ? "m" : "ft" }
    var lengthToMeters: Double { self == .cubicMeters ? 1 : 0.3048 }
    var thicknessSymbol: String { self == .cubicMeters ? "mm" : "in" }
    var thicknessToMeters: Double { self == .cubicMeters ? 0.001 : 0.0254 }
}

enum BagSize: Int, Codable, CaseIterable, Identifiable {
    case kg25 = 25, kg50 = 50
    var id: Int { rawValue }
    var displayName: String { "\(rawValue) kg" }
    var kg: Double { Double(rawValue) }
}

// MARK: - Currency

enum CurrencyCode: String, Codable, CaseIterable, Identifiable {
    case usd, eur, gbp, rub, inr, aed
    var id: String { rawValue }
    var code: String { rawValue.uppercased() }
    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .rub: return "₽"
        case .inr: return "₹"
        case .aed: return "AED "
        }
    }
    var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "Pound"
        case .rub: return "Ruble"
        case .inr: return "Rupee"
        case .aed: return "Dirham"
        }
    }
    /// Where the symbol goes, by the currency's own convention rather than the
    /// device locale's — the user picked this currency explicitly.
    var symbolLeading: Bool {
        switch self {
        case .eur, .rub: return false
        case .usd, .gbp, .inr, .aed: return true
        }
    }
}
