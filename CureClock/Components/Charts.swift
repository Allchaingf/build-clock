//
//  Charts.swift
//  CureClock
//
//  Hand-drawn charts (Swift Charts is iOS 16+). Line, donut, bar and the
//  bespoke StrengthCurveChart, all built with Shape/Path/GeometryReader.
//  iOS 14 safe.
//

import SwiftUI

/// Identified by its label: these are rebuilt inside `body` on every render, so a
/// fresh UUID each time would make every ForEach rebuild its whole list.
struct ChartDatum: Identifiable {
    var id: String { label }
    let label: String
    let value: Double
    var color: Color = Theme.accent
}

// MARK: - Generic line chart

struct LineChartView: View {
    let values: [Double]
    var tint: Color = Theme.accent
    var height: CGFloat = 150
    var maxOverride: Double? = nil

    private var maxValue: Double { max(maxOverride ?? (values.max() ?? 1), 0.0001) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = values.count > 1 ? w / CGFloat(values.count - 1) : w
            ZStack {
                Path { p in
                    for i in 0...4 {
                        let y = h * CGFloat(i) / 4
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Theme.stroke.opacity(0.5), lineWidth: 0.5)

                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v / maxValue) * h))
                    }
                    p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * step, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))

                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: h - CGFloat(values[0] / maxValue) * h))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v / maxValue) * h))
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Strength-gain curve (with milestone markers + "today" rule)

struct StrengthMarker: Identifiable {
    var id: String { type.rawValue }
    let type: CureMilestoneType
    let day: Double          // x position in days
    let percent: Double      // y position 0...100
    let symbol: String
    let color: Color
    let reached: Bool
}

struct StrengthCurveChart: View {
    let values: [Double]            // percent per day index (0...maxDay)
    var markers: [StrengthMarker] = []
    var todayDay: Double? = nil
    var height: CGFloat = 200

    private var maxDay: CGFloat { CGFloat(max(values.count - 1, 1)) }

    private func x(_ day: Double, _ w: CGFloat) -> CGFloat { CGFloat(day) / maxDay * w }
    private func y(_ pct: Double, _ h: CGFloat) -> CGFloat { h - CGFloat(min(max(pct, 0), 100) / 100) * h }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // horizontal grid + % labels
                ForEach(0...4, id: \.self) { i in
                    let pct = Double(4 - i) * 25
                    let yy = h * CGFloat(i) / 4
                    Path { p in p.move(to: CGPoint(x: 0, y: yy)); p.addLine(to: CGPoint(x: w, y: yy)) }
                        .stroke(Theme.stroke.opacity(0.45), lineWidth: 0.5)
                    Text("\(Int(pct))")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.textDisabled)
                        // keep the top ("100") and bottom ("0") labels inside the plot
                        .position(x: 10, y: min(max(yy - 6, 6), h - 6))
                }

                // area fill
                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: x(Double(i), w), y: y(v, h)))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.32), Theme.accent.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))

                // curve stroke
                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: y(values[0], h)))
                    for (i, v) in values.enumerated() {
                        p.addLine(to: CGPoint(x: x(Double(i), w), y: y(v, h)))
                    }
                }
                .stroke(Theme.accentHi, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: Theme.accent.opacity(0.5), radius: 4)

                // "today" vertical rule
                if let td = todayDay, td >= 0, td <= Double(maxDay) {
                    let tx = x(td, w)
                    Path { p in p.move(to: CGPoint(x: tx, y: 0)); p.addLine(to: CGPoint(x: tx, y: h)) }
                        .stroke(Theme.water, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    Text("today")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.water)
                        .position(x: min(max(tx, 18), w - 18), y: 8)
                }

                // milestone markers
                ForEach(markers) { m in
                    let mx = x(m.day, w)
                    let my = y(m.percent, h)
                    ZStack {
                        Circle()
                            .fill(m.reached ? m.color : Theme.surface)
                            .frame(width: 16, height: 16)
                        Circle()
                            .stroke(m.color, lineWidth: 2)
                            .frame(width: 16, height: 16)
                        Image(systemName: m.symbol)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(m.reached ? .white : m.color)
                    }
                    .position(x: min(max(mx, 8), w - 8), y: my)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Bar chart (vertical)

struct BarChartView: View {
    let data: [ChartDatum]
    var height: CGFloat = 150

    private var maxValue: Double { max(data.map { $0.value }.max() ?? 1, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(data) { d in
                VStack(spacing: 6) {
                    Text(Formatters.decimal(d.value, digits: 0))
                        .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [d.color, d.color.opacity(0.55)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(CGFloat(d.value / maxValue) * height, 3))
                    Text(d.label)
                        .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 36)
    }
}

// MARK: - Donut chart

struct DonutChartView: View {
    let data: [ChartDatum]
    var size: CGFloat = 150
    var lineWidth: CGFloat = 26
    var centerTitle: String? = nil

    private var total: Double { max(data.reduce(0) { $0 + $1.value }, 0.0001) }

    var body: some View {
        ZStack {
            if data.isEmpty || data.allSatisfy({ $0.value == 0 }) {
                Circle().stroke(Theme.stroke, lineWidth: lineWidth)
            } else {
                ForEach(Array(segments().enumerated()), id: \.offset) { _, seg in
                    Circle()
                        .trim(from: seg.start, to: seg.end)
                        .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            VStack(spacing: 0) {
                Text(centerTitle ?? Formatters.decimal(total, digits: 0))
                    .font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 6)
                Text("total").font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func segments() -> [(start: CGFloat, end: CGFloat, color: Color)] {
        var result: [(CGFloat, CGFloat, Color)] = []
        var running: Double = 0
        for d in data where d.value > 0 {
            let start = running / total
            running += d.value
            let end = running / total
            result.append((CGFloat(start), CGFloat(end), d.color))
        }
        return result
    }
}

// MARK: - Legend

struct ChartLegend: View {
    let items: [ChartDatum]
    var valueFormatter: (Double) -> String = { Formatters.decimal($0, digits: 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(item.color).frame(width: 11, height: 11)
                    Text(item.label).font(Theme.caption()).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(valueFormatter(item.value))
                        .font(Theme.mono(12)).foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
