//
//  MilestoneTimelineRow.swift
//  CureClock
//
//  Reusable vertical timeline row for a single cure milestone (walk-on, tile,
//  remove formwork, full load). Shows the strength gate %, the estimated date
//  and a reached/pending state. iOS 14 safe.
//

import SwiftUI

struct MilestoneTimelineRow: View {
    let status: MilestoneStatus
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // rail + node
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(status.reached ? status.type.color : Theme.surface)
                        .frame(width: 30, height: 30)
                    Circle()
                        .stroke(status.type.color, lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image(systemName: status.type.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(status.reached ? .white : status.type.color)
                }
                if !isLast {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(minHeight: 56)

            // detail
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(status.type.displayName)
                        .font(Theme.heading(15))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    TagChip(text: "\(Int(status.type.gatePercent))%",
                            color: status.type.color, filled: status.reached)
                }
                Text(status.type.detail)
                    .font(Theme.caption(12))
                    .foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(tint)
                    Text(scheduleText)
                        .font(Theme.mono(11))
                        .foregroundColor(tint)
                }
            }
            .padding(.bottom, 14)
        }
    }

    /// No estimated date means the cure is stalled by cold — say so instead of
    /// quietly showing a date that will never arrive.
    private var scheduleText: String {
        guard let est = status.estDate else { return "Stalled — too cold to date" }
        if status.reached { return "Reached \(Formatters.dayMonth(est))" }
        return "Est. \(Formatters.dayMonth(est)) · \(Formatters.relativeDays(to: est))"
    }

    private var icon: String {
        if status.estDate == nil { return "snowflake" }
        return status.reached ? "checkmark.seal.fill" : "calendar"
    }

    private var tint: Color {
        if status.estDate == nil { return Theme.water }
        return status.reached ? Theme.success : Theme.textSecondary
    }
}
