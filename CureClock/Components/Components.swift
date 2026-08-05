//
//  Components.swift
//  CureClock
//
//  Reusable UI kit: action buttons, cards, chips, stat tiles, progress ring,
//  styled inputs, warning banners and the screen scaffold. iOS 14 safe
//  (custom ButtonStyles instead of .bordered; value-form overlays/backgrounds).
//

import SwiftUI

// MARK: - Button styles

struct ActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(15))
            .foregroundColor(textColor)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background(for: configuration))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(kind == .secondary ? Theme.stroke : Color.clear, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary: return Theme.textOnAccent
        case .secondary: return Theme.accent
        case .danger: return .white
        }
    }

    @ViewBuilder
    private func background(for configuration: Configuration) -> some View {
        switch kind {
        case .primary: Theme.actionGradient
        case .secondary: Theme.surfaceHi
        case .danger: LinearGradient(colors: [Theme.danger, Theme.danger.opacity(0.82)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Convenience button with optional SF Symbol.
struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: ActionButtonStyle.Kind = .primary
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let img = systemImage { Image(systemName: img) }
                Text(title)
            }
        }
        .buttonStyle(ActionButtonStyle(kind: kind, fullWidth: fullWidth))
    }
}

/// A label that looks like an ActionButton, for use inside NavigationLink
/// (NavigationLink is not a Button, so a ButtonStyle can't be applied to it).
struct ActionLabel: View {
    let title: String
    var systemImage: String? = nil
    var kind: ActionButtonStyle.Kind = .primary
    var fullWidth: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if let img = systemImage { Image(systemName: img) }
            Text(title)
        }
        .font(Theme.heading(15))
        .foregroundColor(kind == .secondary ? Theme.accent : Theme.textOnAccent)
        .padding(.vertical, 13).padding(.horizontal, 18)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(kind == .secondary ? AnyView(Theme.surfaceHi) : AnyView(Theme.actionGradient))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
            .stroke(kind == .secondary ? Theme.stroke : Color.clear, lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
    }
}

// MARK: - Card container

struct CardView<Content: View>: View {
    var padding: CGFloat = Theme.Space.m
    let content: () -> Content
    init(padding: CGFloat = Theme.Space.m, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding; self.content = content
    }
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let img = systemImage {
                Image(systemName: img).foregroundColor(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.heading(17)).foregroundColor(Theme.textPrimary)
                if let s = subtitle {
                    Text(s).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Status chip

struct TagChip: View {
    let text: String
    var color: Color = Theme.accent
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.caption(11))
            .foregroundColor(filled ? Theme.textOnAccent : color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(filled ? color : color.opacity(0.18))
            )
    }
}

// MARK: - Stat tile (dashboard metrics)

struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String
    var tint: Color = Theme.accent
    var mono: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tint)
                Spacer()
            }
            Text(value)
                .font(mono ? Theme.monoBold(22) : Theme.title(22))
                .foregroundColor(mono ? Theme.mono : Theme.textPrimary)
            Text(label).font(Theme.caption()).foregroundColor(Theme.textSecondary)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

// MARK: - Progress ring (mono percentage)

struct ProgressRing: View {
    var progress: Double           // 0...100
    var size: CGFloat = 64
    var lineWidth: CGFloat = 8
    var tint: Color = Theme.accent
    var caption: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(Theme.stroke, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 100) / 100))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.5), radius: 5)
            VStack(spacing: 0) {
                Text("\(Int(progress.rounded()))%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.mono)
                if let c = caption {
                    Text(c).font(.system(size: size * 0.085, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Linear progress bar

struct ProgressBar: View {
    var progress: Double           // 0...100
    var tint: Color = Theme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.stroke)
                Capsule().fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 100) / 100))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Styled inputs

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .font(Theme.body())
                .foregroundColor(Theme.textPrimary)
                .keyboardType(keyboard)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

/// Numeric entry that keeps its own text.
///
/// Deriving the displayed text from the value on every keystroke round-trips it
/// through a formatter, and a grouping separator then makes the round trip lossy:
/// 1500 renders as "1,500" (or "1.500" in a European locale) and parses back as 1.5.
/// Here the text is the user's, the value follows it, and the text is only
/// re-rendered from the value when the field is not being edited.
struct LabeledNumberField: View {
    let label: String
    @Binding var value: Double
    var suffix: String = ""
    var digits: Int = 2

    @State private var text: String = ""
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            HStack {
                TextField("0", text: $text, onEditingChanged: { began in
                    isEditing = began
                    if !began { text = Self.display(value, digits: digits) }
                })
                .keyboardType(.decimalPad)
                .font(Theme.body())
                .foregroundColor(Theme.textPrimary)
                if !suffix.isEmpty {
                    Text(suffix).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
        .onAppear { text = Self.display(value, digits: digits) }
        .onChange(of: text) { newText in
            let parsed = Self.parse(newText)
            if parsed != value { value = parsed }
        }
        .onChange(of: value) { newValue in
            // Reflect changes made elsewhere (applying a preset, switching units)
            // without overwriting what the user is part-way through typing.
            if !isEditing && Self.parse(text) != newValue {
                text = Self.display(newValue, digits: digits)
            }
        }
    }

    private static func display(_ value: Double, digits: Int) -> String {
        value == 0 ? "" : Formatters.plain(value, digits: digits)
    }

    /// Accepts either decimal mark and ignores anything a stray paste might bring in.
    private static func parse(_ string: String) -> Double {
        let cleaned = string
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(cleaned) ?? 0
    }
}

// MARK: - Inline banner (warnings / info)

struct InfoBanner: View {
    let text: String
    var systemImage: String = "exclamationmark.triangle.fill"
    var tint: Color = Theme.warning

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(tint)
                .font(.system(size: 15, weight: .bold))
            Text(text)
                .font(Theme.caption(13))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(tint.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(tint.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Standing safety notice

/// Shown wherever the app makes a structural recommendation (strength today, the
/// cure timeline, onboarding, the PDF). The numbers are a temperature-adjusted
/// model, not a test of the user's concrete, and stripping formwork or loading a
/// slab on the strength of them is a structural decision.
struct EngineeringDisclaimer: View {
    var compact: Bool = false

    static let text = "Estimates only — from a temperature model, not from tests on your concrete. Striking formwork, removing props or loading the structure must be confirmed by cube/cylinder tests and the designer's instructions."

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(Theme.warning)
                .font(.system(size: compact ? 12 : 14, weight: .bold))
            Text(Self.text)
                .font(Theme.caption(compact ? 11 : 12))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.warning.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.warning.opacity(0.32), lineWidth: 1))
    }
}

/// Cold-weather notice: below 5°C the cure crawls, at or below freezing it stops
/// and fresh concrete can be permanently damaged.
struct ColdCureBanner: View {
    let tempC: Double

    var body: some View {
        Group {
            if StrengthEngine.isFrozen(tempC) {
                InfoBanner(text: "At \(Int(tempC))°C the cure is stopped — no strength is being gained and fresh concrete can be permanently damaged by freezing. Milestone dates can't be estimated until it's protected or warmer.",
                           systemImage: "snowflake", tint: Theme.danger)
            } else if tempC < MixConstants.coldWarningTempC {
                InfoBanner(text: "Below \(Int(MixConstants.coldWarningTempC))°C strength gain nearly stalls. Treat these dates as optimistic and protect the pour with insulation.",
                           systemImage: "thermometer.snowflake", tint: Theme.warning)
            }
        }
    }
}

// MARK: - Key/value row

struct ReadoutRow: View {
    let label: String
    let value: String
    var tint: Color = Theme.textPrimary
    var mono: Bool = false

    var body: some View {
        HStack {
            Text(label).font(Theme.body(14)).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(mono ? Theme.mono(14) : Theme.heading(15))
                .foregroundColor(tint)
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    var systemImage: String = "tray"
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.accent.opacity(0.75))
            Text(title).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
            Text(message).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Screen scaffold (title + scroll content on concrete backdrop)

struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let content: () -> Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle; self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.title(27)).foregroundColor(Theme.textPrimary)
                    if let s = subtitle {
                        Text(s).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.top, 4)
                content()
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 120)   // clear the custom tab bar
        }
        .cureScreen()
    }
}
