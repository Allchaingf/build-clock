//
//  StrengthEngine.swift
//  CureClock
//
//  Pure, stateless concrete math: mix proportioning, the ACI hyperbolic
//  strength-gain curve and the Nurse–Saul temperature (maturity) adjustment.
//  Kept free of UI/state so it is trivially testable. iOS 14 safe.
//

import Foundation

enum StrengthEngine {

    // MARK: - Mix proportioning

    static func mixResult(volumeM3 volume: Double,
                          ratio: (c: Double, s: Double, a: Double),
                          wc: Double) -> MixResult {
        let sum = ratio.c + ratio.s + ratio.a
        guard sum > 0, volume > 0 else { return MixResult() }

        let dry = volume * MixConstants.dryVolumeFactor
        let cementVol = dry * ratio.c / sum
        let sandVol   = dry * ratio.s / sum
        let aggVol    = dry * ratio.a / sum

        let cementKg = cementVol * MixConstants.cementDensity
        let sandKg   = sandVol   * MixConstants.sandDensity
        let aggKg    = aggVol    * MixConstants.aggregateDensity
        let waterL   = max(wc, 0) * cementKg

        return MixResult(wetVolumeM3: volume, dryVolumeM3: dry,
                         cementVolumeM3: cementVol, sandVolumeM3: sandVol, aggVolumeM3: aggVol,
                         cementKg: cementKg, sandKg: sandKg, aggKg: aggKg, waterL: waterL)
    }

    /// Cement content (kg per m³ of finished concrete) implied by a nominal volumetric
    /// ratio. This is the single source of the kg/m³ figure the app shows — a separately
    /// stored design value would drift from what the calculator actually proportions.
    static func cementContentKgPerM3(ratio: (c: Double, s: Double, a: Double)) -> Double {
        let sum = ratio.c + ratio.s + ratio.a
        guard sum > 0 else { return 0 }
        return MixConstants.dryVolumeFactor * ratio.c / sum * MixConstants.cementDensity
    }

    // MARK: - Temperature factor (maturity)

    /// Multiplier converting one calendar day at `tempC` into equivalent days at 20°C.
    /// (T + 10) / 30 — but hard-stopped at 0°C: at or below freezing the cure does
    /// not advance (and fresh concrete may be permanently damaged), so crediting a
    /// sixth of a day the way the raw Nurse–Saul datum does would be optimistic.
    static func tempFactor(_ tempC: Double) -> Double {
        guard tempC > MixConstants.freezingTempC else { return 0 }
        return max(tempC - MixConstants.datumTempC, 0) / MixConstants.referenceRate
    }

    /// True when the cure is stopped at this temperature — no milestone can be dated.
    static func isFrozen(_ tempC: Double) -> Bool { tempFactor(tempC) <= 0 }

    static func equivalentDays(calendarDays days: Double, tempC: Double) -> Double {
        max(days, 0) * tempFactor(tempC)
    }

    // MARK: - Strength-gain curve

    /// Fraction (0…1) of the 28-day strength at equivalent age `te` (days).
    static func fraction(equivDays te: Double) -> Double {
        guard te > 0 else { return 0 }
        let f = te / (MixConstants.curveA + MixConstants.curveB * te)
        return min(max(f, 0), 1)
    }

    // MARK: - Inverse: days to reach a target fraction

    /// Equivalent days needed to reach fraction `p` (0…1). Capped near the asymptote.
    static func equivDaysForFraction(_ p: Double) -> Double {
        let pp = min(max(p, 0), 0.98)             // curve asymptotes at 1/b
        let denom = 1 - MixConstants.curveB * pp
        guard denom > 0.0001 else { return Double(MixConstants.designAgeDays) }
        return MixConstants.curveA * pp / denom
    }

    /// Calendar days after the pour to reach fraction `p` at `tempC`.
    /// `nil` when the cure is frozen and the fraction is never reached.
    static func calendarDaysForFraction(_ p: Double, tempC: Double) -> Double? {
        let factor = tempFactor(tempC)
        guard factor > 0 else { return nil }
        return equivDaysForFraction(p) / factor
    }

    // MARK: - Milestone gates

    /// Every gate is expressed as a required *equivalent age* (days at 20°C) — one
    /// currency for "how far along is this pour", so the timeline, the ring and the
    /// allowed-now list can never disagree.
    ///
    /// Full load is the 28-day design age rather than "100% of the curve": the
    /// hyperbola only asymptotes to 100%, so a percentage gate would unlock the most
    /// load-critical milestone several days early in cold weather.
    static func requiredEquivDays(forGate gate: CureMilestoneType) -> Double {
        switch gate {
        case .walkOn:              return equivDaysForFraction(0.30)
        case .removeFormworkSides: return equivDaysForFraction(0.50)
        case .tileFinish:          return equivDaysForFraction(0.60)
        case .removeProps:         return max(equivDaysForFraction(0.70),
                                              MixConstants.minPropRemovalEquivDays)
        case .fullLoad:            return Double(MixConstants.designAgeDays)
        }
    }

    /// Strength % of the 28-day value implied by a gate's required equivalent age.
    static func gatePercent(forGate gate: CureMilestoneType) -> Double {
        (fraction(equivDays: requiredEquivDays(forGate: gate)) * 100).rounded()
    }

    /// Calendar days to reach a milestone gate at a constant `tempC`.
    /// `nil` when the cure is frozen at that temperature.
    static func calendarDays(forGate gate: CureMilestoneType, tempC: Double) -> Double? {
        let factor = tempFactor(tempC)
        guard factor > 0 else { return nil }
        return requiredEquivDays(forGate: gate) / factor
    }
}
