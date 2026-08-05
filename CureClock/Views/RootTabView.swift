//
//  RootTabView.swift
//  CureClock
//
//  Main shell: a custom tab bar over four NavigationView stacks. iOS 14 safe
//  (NavigationView with stack style, not NavigationStack).
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .calculator

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .calculator:
                    NavigationView { MixCalculatorView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .timeline:
                    NavigationView { CureTimelineView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .logs:
                    NavigationView { LogsHubView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                case .more:
                    NavigationView { MoreView() }
                        .navigationViewStyle(StackNavigationViewStyle())
                }
            }

            CustomTabBar(selection: $tab, badge: store.attentionCount)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

// MARK: - Navigation row used by the hubs

struct NavRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = Theme.accent
    let destination: () -> Destination

    init(_ title: String, subtitle: String, systemImage: String, tint: Color = Theme.accent,
         @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title; self.subtitle = subtitle; self.systemImage = systemImage
        self.tint = tint; self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: systemImage).font(.system(size: 18, weight: .semibold)).foregroundColor(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    Text(subtitle).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textDisabled)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
