//
//  SampleData.swift
//  CureClock
//
//  The built-in catalogue of mix presets. Deliberately *not* a demo dataset: a
//  first launch starts with no pours at all, so the pour the user configures in
//  onboarding is the one they land on. iOS 14 safe.
//

import Foundation

enum SampleData {

    /// The built-in catalogue of mix presets (also used when resetting).
    static func defaultPresets() -> [MixPreset] {
        [
            MixPreset(name: "M150 (C16)", strengthClass: .m150,
                      ratioCement: 1, ratioSand: 3, ratioAggregate: 5,
                      wcRatio: 0.60, isScreed: false, characteristicMPa: 15),
            MixPreset(name: "M200 (C20)", strengthClass: .m200,
                      ratioCement: 1, ratioSand: 2.5, ratioAggregate: 4,
                      wcRatio: 0.55, isScreed: false, characteristicMPa: 20),
            MixPreset(name: "M300 (C25)", strengthClass: .m300,
                      ratioCement: 1, ratioSand: 2, ratioAggregate: 3.5,
                      wcRatio: 0.50, isScreed: false, characteristicMPa: 25),
            MixPreset(name: "Screed 1:4", strengthClass: .m200,
                      ratioCement: 1, ratioSand: 4, ratioAggregate: 0,
                      wcRatio: 0.50, isScreed: true, characteristicMPa: 20),
            MixPreset(name: "Screed 1:3", strengthClass: .m300,
                      ratioCement: 1, ratioSand: 3, ratioAggregate: 0,
                      wcRatio: 0.48, isScreed: true, characteristicMPa: 25)
        ]
    }

    /// A clean document: presets only, no pours, no logs.
    static func empty() -> AppData {
        var data = AppData()
        data.mixPresets = defaultPresets()
        return data
    }
}
