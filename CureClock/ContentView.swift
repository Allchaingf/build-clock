//
//  ContentView.swift
//  CureClock
//
//  RootView: the Splash -> Onboarding (first launch only) -> Main app state
//  machine. No login/welcome/auth screens of any kind. iOS 14 safe.
//

import SwiftUI

enum AppPhase { case splash, onboarding, main }

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var phase: AppPhase = .splash

    /// Theme's fonts are scaled through UIFontMetrics rather than being SwiftUI text
    /// styles, so nothing below would notice a change of text size on its own.
    /// Observing it at the root rebuilds the tree when the user changes the setting.
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        phase = hasCompletedOnboarding ? .main : .onboarding
                    }
                }
                .transition(.opacity)

            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    withAnimation(.easeInOut(duration: 0.5)) { phase = .main }
                }
                .transition(.opacity)

            case .main:
                RootTabView()
                    .transition(.opacity)
            }
        }
    }
}
