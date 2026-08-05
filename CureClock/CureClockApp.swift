//
//  CureClockApp.swift
//  CureClock
//
//  App entry point. Injects the global AppStore + NotificationManager, applies
//  the persisted theme (light/dark/system) and flushes data to disk on
//  backgrounding. No login/welcome/auth screens. iOS 14 safe.
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@main
struct CureClockApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var notifications = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .dark }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(notifications)
                .preferredColorScheme(appearance.colorScheme)
                .onAppear { configureGlobalAppearance() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.flush() }
            if phase == .active { notifications.refreshStatus() }
        }
    }

    /// List/Form are UITableView-backed on iOS 14; clear their background so the
    /// concrete backdrop shows through, and make navigation bars transparent.
    private func configureGlobalAppearance() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear

        // The bar background is transparent, so the title has to follow the theme —
        // a fixed near-white title vanished against the light backdrop.
        let title = UIColor.dynamic(light: 0x16232B, dark: 0xECF2F5)
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: title]
        nav.largeTitleTextAttributes = [.foregroundColor: title]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor.dynamic(light: 0x0891B2, dark: 0x22D3EE)
    }
}
