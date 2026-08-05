//
//  ConcreteBackground.swift
//  CureClock
//
//  The shared dark concrete backdrop: a soft poured-slab gradient with a faint
//  grout grid and a watermark trowel/dial glyph. Applied via `.cureScreen()`.
//  Built entirely from Shapes — iOS 14 safe, no assets required.
//

import SwiftUI

// MARK: - Faint grout / form grid

private struct GroutGrid: Shape {
    var spacing: CGFloat = 34
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = 0
        while x <= rect.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height)); x += spacing }
        var y: CGFloat = 0
        while y <= rect.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: rect.width, y: y)); y += spacing }
        return p
    }
}

// MARK: - Watermark dial (a curing clock face)

private struct DialGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        // tick marks
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * Double.pi
            let outer = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            let inner = CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.86, y: c.y + CGFloat(sin(a)) * r * 0.86)
            p.move(to: inner); p.addLine(to: outer)
        }
        return p
    }
}

struct ConcreteBackground: View {
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            // pooled cure glow toward the top
            RadialGradient(colors: [Theme.cureGlow, Color.clear],
                           center: .topTrailing, startRadius: 8, endRadius: 420)
                .ignoresSafeArea()

            GroutGrid()
                .stroke(Theme.gridLine.opacity(0.06), lineWidth: 0.6)
                .ignoresSafeArea()

            DialGlyph()
                .stroke(Theme.accent.opacity(0.05), lineWidth: 2)
                .frame(width: 280, height: 280)
                .offset(x: 120, y: -180)
        }
    }
}

// MARK: - Screen modifier

extension View {
    /// Places content on the shared concrete backdrop.
    func cureScreen() -> some View {
        ZStack {
            ConcreteBackground()
            self
        }
    }
}
