//
//  Theme.swift
//  CureClock
//
//  Central design system: concrete-grey + cyan-cure palette (adaptive light/dark),
//  gradients, typography, spacing tokens and cached formatters.
//  All APIs used here are iOS 14.0 safe.
//

import SwiftUI
import UIKit

// MARK: - Dynamic color helper

extension Color {
    /// Builds a color that adapts to the active interface style.
    /// `preferredColorScheme` (set from Settings) flips these automatically.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(hex: UInt, alpha: Double = 1.0) {
        self = Color(UIColor(hex: hex, alpha: alpha))
    }
}

extension UIColor {
    /// UIKit twin of `Color.dynamic` — needed for the appearance proxies (nav bar),
    /// which can't take a SwiftUI Color.
    static func dynamic(light: UInt, dark: UInt) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }

    convenience init(hex: UInt, alpha: Double = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }
}

// MARK: - Theme namespace

enum Theme {

    // Backgrounds (dark = spec primary; light = a calm concrete-paper counterpart)
    static let bgTop      = Color.dynamic(light: 0xEEF2F4, dark: 0x14171A)
    static let bgBottom   = Color.dynamic(light: 0xDDE5E9, dark: 0x0D1012)
    static let surface    = Color.dynamic(light: 0xFFFFFF, dark: 0x21272C)
    static let surfaceAlt = Color.dynamic(light: 0xF1F5F7, dark: 0x1C2125)
    static let surfaceHi  = Color.dynamic(light: 0xE7EDF1, dark: 0x2A3137)
    static let stroke     = Color.dynamic(light: 0xCBD7DE, dark: 0x38424A)

    // Grid line color for the concrete backdrop (semi transparent in use)
    static let gridLine   = Color.dynamic(light: 0x6E7E88, dark: 0x57C7F5)

    // Text
    static let textPrimary   = Color.dynamic(light: 0x16232B, dark: 0xECF2F5)
    static let textSecondary = Color.dynamic(light: 0x5A6E78, dark: 0xA8B6BE)
    static let textDisabled  = Color.dynamic(light: 0x9AAAB2, dark: 0x67747C)
    static let textOnAccent  = Color(hex: 0x08252B)   // dark teal-black, reads on cyan
    static let mono          = Color.dynamic(light: 0x0C1418, dark: 0xFFFFFF)

    // Brand / accents
    static let accent      = Color.dynamic(light: 0x0891B2, dark: 0x06B6D4) // cyan-cure
    static let accentDeep  = Color.dynamic(light: 0x0E7490, dark: 0x0891B2)
    static let accentHi    = Color.dynamic(light: 0x06B6D4, dark: 0x22D3EE) // highlight
    static let water       = Color.dynamic(light: 0x0EA5E9, dark: 0x38BDF8) // second accent (water)
    static let concrete    = Color.dynamic(light: 0x64748B, dark: 0x94A3B8) // neutral

    // Semantic statuses
    static let success = Color.dynamic(light: 0x16A34A, dark: 0x22C55E) // gained strength
    static let curing  = Color.dynamic(light: 0x0891B2, dark: 0x06B6D4) // curing
    static let warning = Color.dynamic(light: 0xD97706, dark: 0xF59E0B) // attention
    static let danger  = Color.dynamic(light: 0xDC2626, dark: 0xEF4444) // crack / weak
    static let info    = water

    // Gradients
    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, water],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var actionGradient: LinearGradient {
        LinearGradient(colors: [accentHi, accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var cureGlow: Color { Color(hex: 0x06B6D4, alpha: 0.32) }

    // Spacing scale
    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let xl: CGFloat = 32
    }

    // Corner radii
    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let pill: CGFloat = 100
    }

    // MARK: Typography
    //
    // `Font.system(size:)` is a fixed point size and ignores the user's text-size
    // setting entirely. Running the size through UIFontMetrics makes every label
    // built from these helpers respond to Dynamic Type. Growth is capped at 1.5×
    // because the charts, rings and tab bar are laid out to fixed heights and a
    // 3× accessibility size would push them apart.
    private static let maxScale: CGFloat = 1.5

    static func scaled(_ size: CGFloat) -> CGFloat {
        min(UIFontMetrics(forTextStyle: .body).scaledValue(for: size), size * maxScale)
    }

    static func title(_ size: CGFloat = 26) -> Font { .system(size: scaled(size), weight: .bold, design: .rounded) }
    static func heading(_ size: CGFloat = 19) -> Font { .system(size: scaled(size), weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: scaled(size), weight: .regular, design: .rounded) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: scaled(size), weight: .semibold, design: .monospaced) }
    static func monoBold(_ size: CGFloat = 20) -> Font { .system(size: scaled(size), weight: .bold, design: .monospaced) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: scaled(size), weight: .medium, design: .rounded) }
}

// MARK: - Formatters (cached; .formatted() is iOS 15+, so we use these everywhere)

enum Formatters {

    // NumberFormatter is expensive to build and these run hundreds of times per
    // render, so the whole set is built once. They are never mutated after
    // construction, which is what makes sharing them across threads safe.
    private static func makeDecimal(digits: Int, grouping: Bool) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        f.usesGroupingSeparator = grouping
        return f
    }
    private static let maxDigits = 4
    private static let grouped: [NumberFormatter] = (0...maxDigits).map { makeDecimal(digits: $0, grouping: true) }
    private static let ungrouped: [NumberFormatter] = (0...maxDigits).map { makeDecimal(digits: $0, grouping: false) }
    private static let money: [NumberFormatter] = [0, 2].map { d -> NumberFormatter in
        let f = makeDecimal(digits: d, grouping: true)
        f.minimumFractionDigits = d
        return f
    }

    /// Display formatting — groups thousands ("1,500").
    static func decimal(_ value: Double, digits: Int = 1) -> String {
        grouped[min(max(digits, 0), maxDigits)].string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Formatting for *editable* text. No grouping separator: a field that renders
    /// 1500 as "1,500" (or "1.500" in a European locale) parses back as 1.5 the next
    /// time it is touched, silently destroying every value of a thousand or more.
    static func plain(_ value: Double, digits: Int = 2) -> String {
        ungrouped[min(max(digits, 0), maxDigits)].string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Money in the user's chosen currency. The amount is formatted with the device
    /// locale's separators and the symbol is placed by the currency's own convention —
    /// setting both `currencyCode` and `currencySymbol` on a `.currency` formatter
    /// leaves the layout to the device locale and produces things like "$ 1 500,00".
    static func currency(_ value: Double, code: CurrencyCode) -> String {
        let f = value.rounded() == value ? money[0] : money[1]
        let amount = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return code.symbolLeading ? "\(code.symbol)\(amount)" : "\(amount)\u{00A0}\(code.symbol)"
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static let medium: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let shortDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let dayTime: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, HH:mm"; return f
    }()

    static func date(_ d: Date) -> String { medium.string(from: d) }
    static func dayMonth(_ d: Date) -> String { shortDay.string(from: d) }
    static func dayTime(_ d: Date) -> String { dayTime.string(from: d) }

    static func relativeDays(to date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days > 0 { return "in \(days)d" }
        return "\(-days)d ago"
    }
}

// MARK: - Keyboard dismissal (no @FocusState on iOS 14)

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
