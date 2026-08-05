//
//  SplashView.swift
//  CureClock
//
//  Thematic launch animation, three simultaneously-animated layers:
//   1. background — slow shifting concrete/cyan gradient (infinite loop)
//   2. midground  — a curing dial that "fills like fresh concrete", a sweeping
//                   clock hand and a pulsing water drop (infinite loops)
//   3. foreground — logo + title + tagline with a spring entrance
//  A single coordinator Timer drives the staged sequence (≥2.5s) and the
//  designed scale-up + fade exit. All looping animation state is reset in
//  .onDisappear so nothing leaks into the main app. iOS 14 safe.
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    // Layer 1 — background loop
    @State private var gradientShift = false
    // Layer 2 — midground loops + staged fill
    @State private var fillLevel: CGFloat = 0
    @State private var sweep = false
    @State private var dropPulse = false
    @State private var ringTrim: CGFloat = 0
    // Layer 3 — foreground entrance
    @State private var logoShown = false
    // Exit
    @State private var exiting = false

    // Coordinator
    @State private var isVisible = true
    @State private var timer: Timer?
    @State private var elapsed: Double = 0
    @State private var didFill = false
    @State private var didReveal = false
    @State private var didExit = false
    @State private var didFinish = false

    var body: some View {
        ZStack {
            // Layer 1: animated background gradient
            LinearGradient(colors: [Color(hex: 0x0D1012), Color(hex: 0x14171A), Color(hex: 0x0B2C33)],
                           startPoint: gradientShift ? .topLeading : .bottomTrailing,
                           endPoint: gradientShift ? .bottomTrailing : .topLeading)
                .ignoresSafeArea()

            RadialGradient(colors: [Theme.cureGlow, .clear],
                           center: .center, startRadius: 10,
                           endRadius: gradientShift ? 360 : 280)
                .ignoresSafeArea()

            VStack(spacing: Theme.Space.xl) {
                // Layer 2: the curing dial
                curingDial
                    .frame(width: 170, height: 170)

                // Layer 3: logo text + tagline
                VStack(spacing: 8) {
                    Text("Builder Clock")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("Mix it right. Let it cure.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.accentHi)
                }
                .opacity(logoShown ? 1 : 0)
                .offset(y: logoShown ? 0 : 18)
            }
            .scaleEffect(exiting ? 1.25 : 1.0)
            .opacity(exiting ? 0 : 1)
        }
        .onAppear { start() }
        .onDisappear { teardown() }
    }

    // MARK: - Dial

    private var curingDial: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // outer ring drawing in
                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.accent.opacity(0.6), radius: 8)

                // tick marks
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(Theme.concrete.opacity(0.5))
                        .frame(width: 2, height: i % 3 == 0 ? 12 : 7)
                        .offset(y: -s / 2 + 12)
                        .rotationEffect(.degrees(Double(i) / 12 * 360))
                }

                // concrete fill rising inside the dial
                Circle()
                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.35), Theme.water.opacity(0.55)],
                                         startPoint: .bottom, endPoint: .top))
                    .mask(
                        GeometryReader { g in
                            Rectangle()
                                .frame(height: g.size.height * fillLevel)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    )
                    .padding(14)

                // sweeping clock hand
                Capsule()
                    .fill(Theme.accentHi)
                    .frame(width: 3, height: s * 0.34)
                    .offset(y: -s * 0.17)
                    .rotationEffect(.degrees(sweep ? 360 : 0))

                // center water drop
                Image(systemName: "drop.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.water)
                    .scaleEffect(dropPulse ? 1.18 : 0.82)
                    .shadow(color: Theme.water.opacity(0.7), radius: dropPulse ? 10 : 4)
            }
            .frame(width: s, height: s)
        }
    }

    // MARK: - Coordinator

    private func start() {
        isVisible = true

        // Start the infinite loops immediately (layers 1 & 2).
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { gradientShift = true }
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { sweep = true }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dropPulse = true }
        withAnimation(.easeOut(duration: 1.0)) { ringTrim = 1 }

        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            elapsed += 0.1

            // Phase 2 (0.6s): the dial fills like concrete.
            if elapsed >= 0.6 && !didFill {
                didFill = true
                withAnimation(.easeInOut(duration: 0.9)) { fillLevel = 1 }
            }
            // Phase 3 (1.4s): logo + tagline spring in.
            if elapsed >= 1.4 && !didReveal {
                didReveal = true
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { logoShown = true }
            }
            // Phase 4 (2.2s): designed scale-up + fade exit.
            if elapsed >= 2.2 && !didExit {
                didExit = true
                withAnimation(.easeIn(duration: 0.45)) { exiting = true }
            }
            // Hand off after the exit completes (≈2.65s total).
            if elapsed >= 2.65 && !didFinish {
                didFinish = true
                t.invalidate()
                onFinish()
            }
        }
    }

    private func teardown() {
        timer?.invalidate()
        timer = nil
        // Reset every looping/animation flag so nothing animates in the background.
        isVisible = false
        gradientShift = false
        sweep = false
        dropPulse = false
        fillLevel = 0
        ringTrim = 0
        logoShown = false
        exiting = false
    }
}
