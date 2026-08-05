//
//  CustomTabBar.swift
//  CureClock
//
//  Custom themed tab bar (not the system TabView chrome). iOS 14 safe.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case calculator, timeline, logs, more
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .calculator: return "Mix"
        case .timeline:   return "Cure"
        case .logs:       return "Logs"
        case .more:       return "More"
        }
    }
    var icon: String {
        switch self {
        case .calculator: return "cube.box.fill"
        case .timeline:   return "clock.fill"
        case .logs:       return "square.stack.3d.up.fill"
        case .more:       return "ellipsis.circle.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    var badge: Int = 0   // shown on the More tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = tab }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(selection == tab ? Theme.accentHi : Theme.textSecondary)
                                .scaleEffect(selection == tab ? 1.14 : 1.0)
                                .shadow(color: selection == tab ? Theme.accent.opacity(0.6) : .clear, radius: 6)
                            if tab == .more && badge > 0 {
                                Text("\(badge)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Theme.danger))
                                    .offset(x: 12, y: -10)
                            }
                        }
                        Text(tab.title)
                            .font(.system(size: 10, weight: selection == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == tab ? Theme.accentHi : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 6)
        .background(
            // `.systemThinMaterial` follows the interface style; the *Dark variant is
            // a hard-coded dark slab that sat under light content in the light theme.
            BlurView(style: .systemThinMaterial)
                .overlay(Theme.surface.opacity(0.55))
                .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
}
