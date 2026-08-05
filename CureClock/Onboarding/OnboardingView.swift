//
//  OnboardingView.swift
//  CureClock
//
//  Six pages: four that explain the model the whole app rests on, then two that
//  collect the user's first real pour.
//
//   O1 Class & ratio  — what M150/M200/M300 and 1 : 2.5 : 4 actually mean
//   O2 Water          — why the W/C ratio decides the strength you get
//   O3 Temperature    — equivalent days, and what cold does to them
//   O4 Milestones     — the strength gates, and the standing safety notice
//   O5 Your mix       — goal, class, cure temperature
//   O6 Your pour      — name, dimensions, pour date → starts the clock
//
//  No Skip: the pour created here is the one the user lands on, so skipping would
//  drop them into an empty app. iOS 14 safe.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @EnvironmentObject var store: AppStore
    @StateObject private var vm = OnboardingViewModel()

    @State private var page = 0
    private let pageCount = 6

    private var isLast: Bool { page == pageCount - 1 }

    private var primaryTitle: String {
        switch page {
        case 0...3: return "Next"
        case 4:     return "Set the mix"
        default:    return "Start the Clock"
        }
    }

    /// The final page is the only one that gates: it creates the pour, and a pour
    /// with no dimensions has nothing to calculate.
    private var canAdvance: Bool { !isLast || vm.hasUsableSection }

    var body: some View {
        ZStack {
            ConcreteBackground()

            VStack(spacing: 0) {
                header

                TabView(selection: $page) {
                    ExplainRatioPage().tag(0)
                    ExplainWaterPage().tag(1)
                    ExplainTemperaturePage().tag(2)
                    ExplainMilestonesPage().tag(3)
                    MixSetupPage(vm: vm).tag(4)
                    PourSetupPage(vm: vm, unit: store.volumeUnit).tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                dots

                VStack(spacing: 6) {
                    ActionButton(title: primaryTitle,
                                 systemImage: isLast ? "clock.fill" : "arrow.right") {
                        advance()
                    }
                    .opacity(canAdvance ? 1 : 0.45)
                    .disabled(!canAdvance)

                    if isLast && !vm.hasUsableSection {
                        Text("Enter a width, length and thickness to start the clock.")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, Theme.Space.m)
                .padding(.bottom, Theme.Space.l)
            }
        }
    }

    private var header: some View {
        HStack {
            if page > 0 {
                Button(action: { withAnimation(.easeInOut) { page -= 1 } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(Theme.caption(14)).foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
            Spacer()
            Text("\(page + 1) / \(pageCount)")
                .font(Theme.mono(12)).foregroundColor(Theme.textDisabled)
                .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.top, 8)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.accentHi : Theme.stroke)
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
            }
        }
        .padding(.vertical, Theme.Space.m)
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation(.easeInOut) { page += 1 }
        } else {
            UIApplication.shared.dismissKeyboard()
            vm.apply(to: store, unit: store.volumeUnit)
            onFinish()
        }
    }
}

// MARK: - Shared page furniture

private struct OnboardHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.16)).frame(width: 64, height: 64)
                Image(systemName: icon).font(.system(size: 28, weight: .bold)).foregroundColor(Theme.accentHi)
            }
            Text(title).font(Theme.title(24)).foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.l)
        }
    }
}

/// A page body: scrolls so long copy and large Dynamic Type sizes still fit.
private struct OnboardPage<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Space.l) {
                content()
            }
            .padding(.top, Theme.Space.l)
            .padding(.horizontal, Theme.Space.m)
            .padding(.bottom, Theme.Space.m)
        }
    }
}

private struct Point: View {
    let icon: String
    let text: String
    var tint: Color = Theme.accentHi

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 20)
            Text(text)
                .font(Theme.body(14)).foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - O1  Class & ratio

private struct ExplainRatioPage: View {
    var body: some View {
        OnboardPage {
            OnboardHeader(icon: "chart.bar.fill", title: "Class and ratio",
                          subtitle: "The two numbers every mix is described by.")

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Strength class", systemImage: "seal.fill")
                    Point(icon: "number", text: "M150, M200, M300 is the strength the concrete is expected to reach in 28 days — 15, 20 and 25 MPa. Roughly C16, C20 and C25.")
                    Point(icon: "arrow.up.right", text: "Higher class means more cement and less water: stronger and denser, but stiffer to place.")
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Mix ratio", systemImage: "cube.box.fill")
                    Text("1 : 2.5 : 4")
                        .font(Theme.monoBold(26)).foregroundColor(Theme.accentHi)
                    RatioBars()
                    Point(icon: "scalemass.fill", text: "Cement : sand : aggregate, measured by volume. One bucket of cement, two and a half of sand, four of stone.")
                    Point(icon: "function", text: "Builder Clock turns your dimensions into these three piles, plus the water, and tells you how many bags that is.")
                }
            }
        }
    }
}

private struct RatioBars: View {
    private let parts: [(String, Double, Color)] = [
        ("Cement", 1, Theme.accent), ("Sand", 2.5, Theme.concrete), ("Aggregate", 4, Theme.water)
    ]
    private var total: Double { parts.reduce(0) { $0 + $1.1 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(parts, id: \.0) { part in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(part.2)
                            .frame(width: max((geo.size.width - 6) * CGFloat(part.1 / total), 2))
                    }
                }
            }
            .frame(height: 16)
            HStack(spacing: 12) {
                ForEach(parts, id: \.0) { part in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(part.2).frame(width: 9, height: 9)
                        Text(part.0).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - O2  Water

private struct ExplainWaterPage: View {
    var body: some View {
        OnboardPage {
            OnboardHeader(icon: "drop.fill", title: "Water is the trade-off",
                          subtitle: "The one thing on site that quietly costs you strength.")

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Water / cement ratio", systemImage: "drop.triangle.fill")
                    WaterBandBar()
                    Point(icon: "checkmark.seal.fill",
                          text: "0.45–0.55 is the useful band: strong enough, still placeable.",
                          tint: Theme.success)
                    Point(icon: "exclamationmark.triangle.fill",
                          text: "Above 0.55 the mix flows more easily and loses strength fast — and the extra water leaves pores and shrinkage cracks behind as it dries.",
                          tint: Theme.warning)
                    Point(icon: "hand.raised.fill",
                          text: "If it is too stiff to place, the answer is a plasticiser or better compaction, not another bucket of water.",
                          tint: Theme.danger)
                }
            }

            CardView {
                Point(icon: "sparkles",
                      text: "The calculator scores your W/C as you move the slider, so you can see what a splash more water costs before you add it.")
            }
        }
    }
}

private struct WaterBandBar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                bar(Theme.warning, "0.30")
                bar(Theme.success, "0.45")
                bar(Theme.warning, "0.55")
                bar(Theme.danger, "0.65+")
            }
            Text("stiff  →  ideal  →  workable  →  weak")
                .font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
        }
    }

    private func bar(_ color: Color, _ label: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(height: 14)
            Text(label).font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - O3  Temperature

private struct ExplainTemperaturePage: View {
    private let samples: [Double] = [5, 20, 30]

    var body: some View {
        OnboardPage {
            OnboardHeader(icon: "thermometer.medium", title: "Temperature sets the pace",
                          subtitle: "Concrete cures on warmth, not on the calendar.")

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Equivalent days", systemImage: "calendar.badge.clock")
                    HStack(spacing: 10) {
                        ForEach(samples, id: \.self) { t in
                            VStack(spacing: 3) {
                                Text("\(Int(t))°C").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                                Text("×\(Formatters.decimal(StrengthEngine.tempFactor(t), digits: 2))")
                                    .font(Theme.mono(13)).foregroundColor(Theme.accentHi)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surfaceAlt))
                        }
                    }
                    Point(icon: "clock.arrow.circlepath", text: "A warm day advances the cure further than a cold one. The app counts progress in equivalent days at 20°C, not in days on the calendar.")
                    Point(icon: "cloud.sun.fill", text: "Log the weather as you go and the curve follows the real days you had, not the temperature you guessed at the start.")
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    Point(icon: "thermometer.snowflake",
                          text: "Below 5°C strength gain nearly stalls — dates get long and unreliable.",
                          tint: Theme.warning)
                    Point(icon: "snowflake",
                          text: "At or below freezing the clock stops entirely, and fresh concrete that freezes is damaged for good. Protect it.",
                          tint: Theme.danger)
                }
            }
        }
    }
}

// MARK: - O4  Milestones

private struct ExplainMilestonesPage: View {
    var body: some View {
        OnboardPage {
            OnboardHeader(icon: "flag.checkered", title: "Why you wait",
                          subtitle: "Every job on a fresh slab has a strength gate.")

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(CureMilestoneType.allCases) { type in
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(type.color)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(type.displayName).font(Theme.body(15)).foregroundColor(Theme.textPrimary)
                                Text(type.detail).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            TagChip(text: "\(Int(type.gatePercent))%", color: type.color)
                        }
                    }
                }
            }

            CardView {
                Point(icon: "exclamationmark.triangle.fill",
                      text: "Loading concrete before it has the strength is how slabs crack and structures fail. Builder Clock estimates each gate's date so you know what you are waiting for.",
                      tint: Theme.warning)
            }

            EngineeringDisclaimer()
        }
    }
}

// MARK: - O5  Your mix

private struct MixSetupPage: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var burstTrigger = 0

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let classes = StrengthClass.allCases

    var body: some View {
        OnboardPage {
            OnboardHeader(icon: "cube.box.fill", title: "Your mix",
                          subtitle: "What are you pouring, and how warm is it?")

            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(MixGoal.allCases) { goal in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            vm.goal = goal
                            vm.strengthClass = goal.defaultStrengthClass
                        }
                        burstTrigger += 1
                    }) {
                        ZStack {
                            VStack(spacing: 6) {
                                Image(systemName: goal.icon)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(vm.goal == goal ? Theme.textOnAccent : goal.color)
                                Text(goal.displayName)
                                    .font(Theme.heading(15))
                                    .foregroundColor(vm.goal == goal ? Theme.textOnAccent : Theme.textPrimary)
                                Text(goal.subtitle)
                                    .font(Theme.caption(11))
                                    .foregroundColor(vm.goal == goal ? Theme.textOnAccent.opacity(0.85) : Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Group {
                                    if vm.goal == goal {
                                        RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.accentGradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface)
                                    }
                                }
                            )
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                                .stroke(vm.goal == goal ? Color.clear : Theme.stroke, lineWidth: 1))

                            if vm.goal == goal { BurstEmitter(trigger: burstTrigger) }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("STRENGTH CLASS").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    Picker("", selection: $vm.strengthClass) {
                        ForEach(classes) { c in Text(c.displayName).tag(c) }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Text(vm.strengthClass.blurb).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                    Divider().background(Theme.stroke)
                    let r = vm.strengthClass.ratio
                    ReadoutRow(label: "Cement : Sand : Aggregate",
                               value: "\(Int(r.c)) : \(Formatters.decimal(r.s, digits: 1)) : \(Formatters.decimal(r.a, digits: 1))", mono: true)
                    ReadoutRow(label: "Target W/C", value: Formatters.decimal(vm.strengthClass.defaultWC, digits: 2), mono: true)
                    ReadoutRow(label: "Cement", value: "≈ \(Int(vm.strengthClass.cementKgPerM3.rounded())) kg/m³", mono: true)
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CURE TEMPERATURE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(vm.cureTempC))°C · ×\(Formatters.decimal(StrengthEngine.tempFactor(vm.cureTempC), digits: 2))")
                            .font(Theme.mono(13)).foregroundColor(Theme.accentHi)
                    }
                    Slider(value: $vm.cureTempC, in: -5...40, step: 1).accentColor(Theme.accent)
                    ReadoutRow(label: "Est. walk-on",
                               value: StrengthEngine.calendarDays(forGate: .walkOn, tempC: vm.cureTempC)
                                   .map { "≈ \(Formatters.decimal($0, digits: 1)) days" } ?? "cure stalled",
                               mono: true)
                    ColdCureBanner(tempC: vm.cureTempC)
                }
            }
        }
    }
}

// MARK: - O6  Your pour

private struct PourSetupPage: View {
    @ObservedObject var vm: OnboardingViewModel
    let unit: VolumeUnit

    var body: some View {
        OnboardPage {
            OnboardHeader(icon: "calendar.badge.clock", title: "Your pour",
                          subtitle: "Real numbers — this becomes your first pour and starts the clock.")

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledField(label: "Pour name", text: $vm.pourName, placeholder: "e.g. Garage slab")
                    HStack(spacing: 12) {
                        LabeledNumberField(label: "Width", value: $vm.width, suffix: unit.lengthSymbol)
                        LabeledNumberField(label: "Length", value: $vm.length, suffix: unit.lengthSymbol)
                    }
                    HStack(spacing: 12) {
                        LabeledNumberField(label: "Thickness", value: $vm.thickness, suffix: unit.thicknessSymbol)
                        LabeledNumberField(label: "Waste", value: $vm.wastePercent, suffix: "%", digits: 0)
                    }
                    Divider().background(Theme.stroke)
                    HStack {
                        Text("Volume").font(Theme.body(14)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Formatters.decimal(vm.volumeM3(unit: unit) * unit.fromM3, digits: 2)) \(unit.symbol)")
                            .font(Theme.monoBold(20)).foregroundColor(Theme.accentHi)
                    }
                    Text("You can add more sections later in the Mix tab.")
                        .font(Theme.caption(11)).foregroundColor(Theme.textDisabled)
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("POUR DATE & TIME").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    DatePicker("", selection: $vm.pourDate, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .accentColor(Theme.accent)
                    ReadoutRow(label: "Clock starts", value: Formatters.dayTime(vm.pourDate), mono: true)
                }
            }
        }
        .onAppear {
            // Sensible default slab thickness in whichever unit is in use.
            if vm.thickness == 0 { vm.thickness = unit == .cubicMeters ? 100 : 4 }
        }
    }
}

// MARK: - Particle burst

private struct BurstEmitter: View {
    let trigger: Int
    @State private var fire = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let angle = Double(i) / 10 * 2 * Double.pi
                Circle()
                    .fill(Theme.accentHi)
                    .frame(width: 6, height: 6)
                    .offset(x: fire ? CGFloat(cos(angle)) * 46 : 0,
                            y: fire ? CGFloat(sin(angle)) * 46 : 0)
                    .opacity(fire ? 0 : 1)
            }
        }
        .onChange(of: trigger) { _ in
            fire = false
            withAnimation(.easeOut(duration: 0.6)) { fire = true }
        }
    }
}
