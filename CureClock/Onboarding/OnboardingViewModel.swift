//
//  OnboardingViewModel.swift
//  CureClock
//
//  Holds what onboarding teaches and what it collects, and creates the user's first
//  real pour on completion. iOS 14 safe.
//

import SwiftUI

final class OnboardingViewModel: ObservableObject {
    // Page 5 — the mix
    @Published var goal: MixGoal = .slab
    @Published var strengthClass: StrengthClass = .m200
    @Published var cureTempC: Double = 18

    // Page 6 — the pour itself
    @Published var pourName: String = ""
    @Published var pourDate: Date = Date()
    @Published var width: Double = 0          // in the user's display unit
    @Published var length: Double = 0
    @Published var thickness: Double = 0      // mm / in
    @Published var wastePercent: Double = 5

    var hasUsableSection: Bool { width > 0 && length > 0 && thickness > 0 }

    func volumeM3(unit: VolumeUnit) -> Double {
        let w = max(width, 0) * unit.lengthToMeters
        let l = max(length, 0) * unit.lengthToMeters
        let t = max(thickness, 0) * unit.thicknessToMeters
        return w * l * t * (1 + max(wastePercent, 0) / 100)
    }

    /// Persist the chosen defaults and create the first pour.
    ///
    /// This used to be guarded by `if store.pours.isEmpty`, which was never true
    /// because first launch seeded a demo pour — so every answer the user gave was
    /// silently discarded and they landed on someone else's garage slab. There is no
    /// seed any more, and the pour is created unconditionally.
    func apply(to store: AppStore, unit: VolumeUnit) {
        var settings = store.settings
        settings.defaultGoal = goal
        settings.defaultStrengthClass = strengthClass
        settings.cureTempC = cureTempC
        store.updateSettings(settings)

        var pour = Pour.make(goal: goal, strengthClass: strengthClass, tempC: cureTempC, date: pourDate)
        pour.name = pourName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "\(goal.displayName) Pour"
            : pourName
        pour.sections = [PourSection(label: "Section 1",
                                     widthM: max(width, 0) * unit.lengthToMeters,
                                     lengthM: max(length, 0) * unit.lengthToMeters,
                                     thicknessM: max(thickness, 0) * unit.thicknessToMeters,
                                     wastePercent: max(wastePercent, 0))]
        store.savePour(pour)
    }
}
