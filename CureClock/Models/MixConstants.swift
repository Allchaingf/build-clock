//
//  MixConstants.swift
//  CureClock
//
//  Centralised, tunable domain constants for the mix proportioning and the
//  temperature-adjusted strength-gain model. Keeping them in one place makes the
//  math testable and easy to reason about. iOS 14 safe (pure values).
//

import Foundation

enum MixConstants {

    // MARK: Proportioning
    /// Wet → dry bulking / void factor (IS 10262 / ACI rule of thumb ≈ 1.52–1.57).
    static let dryVolumeFactor: Double = 1.54

    /// Bulk densities (kg/m³).
    static let cementDensity: Double = 1440
    static let sandDensity: Double = 1600
    static let aggregateDensity: Double = 1500
    static let waterDensity: Double = 1000   // 1 L ≈ 1 kg

    // MARK: Strength-gain curve  fraction(tₑ) = tₑ / (a + b·tₑ)  (ACI 209 hyperbolic)
    static let curveA: Double = 4.0
    static let curveB: Double = 0.85

    // MARK: Maturity (Nurse–Saul equivalent age)
    /// Datum temperature below which no strength is gained (°C).
    static let datumTempC: Double = -10
    /// Reference cure temperature the baseline curve is defined at (°C).
    static let referenceTempC: Double = 20
    /// referenceTempC − datumTempC, precomputed.
    static var referenceRate: Double { referenceTempC - datumTempC }   // 30

    /// At or below this temperature fresh concrete gains no usable strength (and
    /// can be damaged by freezing), so the maturity clock is stopped entirely.
    static let freezingTempC: Double = 0
    /// Below this the cure is badly slowed and the user is warned everywhere.
    static let coldWarningTempC: Double = 5

    // MARK: Defaults
    static let defaultCureTempC: Double = 20
    static let defaultKeepWetDays: Int = 7
    static let designAgeDays: Int = 28

    /// Soffit props / shoring stay in for at least this equivalent age no matter
    /// what the strength fraction says — the strength gate alone (≈7 days) is far
    /// below normal practice (14–28 days, or per the designer's calculation).
    static let minPropRemovalEquivDays: Double = 14
}
