//
//  MixCalculatorViewModel.swift
//  CureClock
//
//  Transient editing state for the Mix Calculator: a draft Pour with its
//  sections and recipe, plus the live mix/volume/water-quality derivations.
//  Committed to the store only on "Save Pour". iOS 14 safe.
//

import SwiftUI

final class MixCalculatorViewModel: ObservableObject {
    @Published var pour: Pour
    @Published var showResults = false

    init(seed: Pour) { self.pour = seed }

    // Derived
    var totalVolumeM3: Double { pour.totalVolumeM3 }
    var mix: MixResult { StrengthEngine.mixResult(volumeM3: totalVolumeM3, ratio: pour.ratioTuple, wc: pour.wcRatio) }
    var waterQuality: WaterQuality { WaterQuality.classify(pour.wcRatio) }

    // Mutations
    func applyPreset(_ p: MixPreset) {
        pour.strengthClass = p.strengthClass
        pour.isScreed = p.isScreed
        pour.ratioCement = p.ratioCement
        pour.ratioSand = p.ratioSand
        pour.ratioAggregate = p.ratioAggregate
        pour.wcRatio = p.wcRatio
        pour.characteristicMPa = p.characteristicMPa
    }

    func addSection() {
        pour.sections.append(PourSection(label: "Section \(pour.sections.count + 1)",
                                         thicknessM: 0.1, wastePercent: 5))
    }
    func upsertSection(_ s: PourSection) {
        if let i = pour.sections.firstIndex(where: { $0.id == s.id }) { pour.sections[i] = s }
        else { pour.sections.append(s) }
    }
    func removeSection(_ s: PourSection) {
        pour.sections.removeAll { $0.id == s.id }
    }

    func startNewPour(from store: AppStore) {
        let s = store.settings
        var p = Pour.make(goal: s.defaultGoal, strengthClass: s.defaultStrengthClass,
                          tempC: s.cureTempC, date: Date())
        p.name = "New Pour"
        p.sections = [PourSection(label: "Section 1", thicknessM: 0.1, wastePercent: 5)]
        pour = p
        showResults = false
    }
}
