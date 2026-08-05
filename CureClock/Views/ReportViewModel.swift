//
//  ReportViewModel.swift
//  CureClock
//
//  Builds a multi-section PDF (volumes, mix, strength curve, milestones, cost)
//  with UIGraphicsPDFRenderer and Core Graphics — no Swift Charts / iOS 16 APIs.
//  iOS 14 safe.
//

import UIKit

/// Everything the PDF needs, captured from the store on the main thread.
///
/// Rendering used to read `AppStore` (whose state is `@Published`) from a background
/// queue, so a pour saved or a price edited mid-export could be torn across the
/// report. An immutable snapshot removes the shared state entirely.
struct ReportSnapshot {
    let pour: Pour
    let mix: MixResult
    let cost: CostResult
    let costPerM3: Double
    let milestones: [MilestoneStatus]
    let curve: [Double]
    let waterQuality: WaterQuality
    let bagSizeKg: Double
    let volumeUnit: VolumeUnit
    let currency: CurrencyCode

    func money(_ value: Double) -> String { Formatters.currency(value, code: currency) }

    /// Volumes, lengths and thicknesses in the unit the user picked — the report used
    /// to be metric regardless, so an imperial user saw ft³ in the app and m³ in the
    /// document they hand to a client.
    func volume(_ m3: Double, digits: Int = 2) -> String {
        "\(Formatters.decimal(m3 * volumeUnit.fromM3, digits: digits)) \(volumeUnit.symbol)"
    }
    func length(_ metres: Double) -> String {
        Formatters.decimal(metres / volumeUnit.lengthToMeters, digits: 2)
    }
    func thickness(_ metres: Double) -> String {
        "\(Formatters.decimal(metres / volumeUnit.thicknessToMeters, digits: 0)) \(volumeUnit.thicknessSymbol)"
    }
}

final class ReportViewModel: ObservableObject {
    @Published var includeMix = true
    @Published var includeCurve = true
    @Published var includeMilestones = true
    @Published var includeCost = true

    // A4 portrait
    private let pageSize = CGSize(width: 595, height: 842)
    private let margin: CGFloat = 40
    private var contentWidth: CGFloat { pageSize.width - margin * 2 }

    func generate(_ snap: ReportSnapshot) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuilderClock-\(safe(snap.pour.name)).pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                var y = newPage(ctx)

                y = drawHeader(snap, at: y)
                y = drawSectionsTable(snap, ctx: ctx, y: y)

                if includeMix {
                    y = ensurePage(ctx, y, need: 160)
                    y = drawMix(snap, y: y)
                }
                if includeCurve {
                    y = ensurePage(ctx, y, need: 240)
                    y = drawCurve(snap, ctx: ctx, y: y)
                }
                if includeMilestones {
                    y = ensurePage(ctx, y, need: 200)
                    y = drawMilestones(snap, ctx: ctx, y: y)
                }
                if includeCost {
                    y = ensurePage(ctx, y, need: 200)
                    y = drawCost(snap, y: y)
                }
            }
            return url
        } catch { return nil }
    }

    // MARK: - Sections

    private func drawHeader(_ snap: ReportSnapshot, at y: CGFloat) -> CGFloat {
        let pour = snap.pour
        var cy = y
        cy = text("Builder Clock — Pour Report", font: .systemFont(ofSize: 22, weight: .bold),
                  color: UIColor(hex: 0x0891B2), at: cy)
        cy = text(pour.name, font: .systemFont(ofSize: 16, weight: .semibold), color: .black, at: cy + 2)
        cy = text("Poured \(Formatters.date(pour.pourDate))  ·  \(pour.strengthClass.displayName) (\(pour.strengthClass.cEquivalent))  ·  \(Int(pour.cureTempC))°C cure",
                  font: .systemFont(ofSize: 11), color: .darkGray, at: cy + 2)
        cy += 8
        line(at: cy); return cy + 14
    }

    private func drawSectionsTable(_ snap: ReportSnapshot, ctx: UIGraphicsPDFRendererContext, y: CGFloat) -> CGFloat {
        var cy = sectionTitle("Volume", at: y)
        let u = snap.volumeUnit
        for s in snap.pour.sections {
            cy = ensurePage(ctx, cy, need: 22)
            let dims = "\(snap.length(s.widthM))×\(snap.length(s.lengthM)) \(u.lengthSymbol) × \(snap.thickness(s.thicknessM))  (+\(Int(s.wastePercent))%)"
            cy = row(left: "\(s.label):  \(dims)", right: snap.volume(s.volumeM3, digits: 3), at: cy)
        }
        cy = row(left: "Total volume", right: snap.volume(snap.pour.totalVolumeM3, digits: 3),
                 at: cy + 2, bold: true)
        return cy + 10
    }

    private func drawMix(_ snap: ReportSnapshot, y: CGFloat) -> CGFloat {
        let m = snap.mix
        var cy = sectionTitle("Mix (dry-volume ×1.54)", at: y)
        cy = row(left: "Cement", right: "\(Formatters.decimal(m.cementKg, digits: 0)) kg  ·  \(m.bags(ofSizeKg: snap.bagSizeKg)) × \(Int(snap.bagSizeKg)) kg bags", at: cy)
        cy = row(left: "Cement content", right: "≈ \(Int(m.cementKgPerM3.rounded())) kg/m³", at: cy)
        cy = row(left: "Sand", right: "\(Formatters.decimal(m.sandKg, digits: 0)) kg  ·  \(snap.volume(m.sandVolumeM3))", at: cy)
        if !snap.pour.isScreed {
            cy = row(left: "Aggregate", right: "\(Formatters.decimal(m.aggKg, digits: 0)) kg  ·  \(snap.volume(m.aggVolumeM3))", at: cy)
        }
        cy = row(left: "Water (W/C \(Formatters.decimal(snap.pour.wcRatio, digits: 2)))", right: "\(Formatters.decimal(m.waterL, digits: 0)) L", at: cy)
        let q = snap.waterQuality
        cy = text("Water quality: \(q.title) — \(q.message)", font: .systemFont(ofSize: 10),
                  color: UIColor(hex: q == .tooWet ? 0xEF4444 : 0x5A6E78), at: cy + 4)
        return cy + 10
    }

    private func drawCurve(_ snap: ReportSnapshot, ctx: UIGraphicsPDFRendererContext, y: CGFloat) -> CGFloat {
        let cy = sectionTitle("Strength-gain curve (≈% of 28-day)", at: y)
        let box = CGRect(x: margin, y: cy, width: contentWidth, height: 180)
        let cg = ctx.cgContext

        // frame + gridlines
        UIColor(hex: 0xCBD7DE).setStroke()
        cg.stroke(box, width: 0.5)
        for i in 1..<4 {
            let gy = box.minY + box.height * CGFloat(i) / 4
            cg.move(to: CGPoint(x: box.minX, y: gy)); cg.addLine(to: CGPoint(x: box.maxX, y: gy)); cg.strokePath()
        }

        let series = snap.curve
        let maxDay = CGFloat(max(series.count - 1, 1))
        func px(_ day: Double) -> CGFloat { box.minX + CGFloat(day) / maxDay * box.width }
        func py(_ pct: Double) -> CGFloat { box.maxY - CGFloat(min(max(pct, 0), 100) / 100) * box.height }

        // curve
        UIColor(hex: 0x06B6D4).setStroke()
        cg.setLineWidth(2)
        for (i, v) in series.enumerated() {
            let p = CGPoint(x: px(Double(i)), y: py(v))
            if i == 0 { cg.move(to: p) } else { cg.addLine(to: p) }
        }
        cg.strokePath()

        // Milestone dots + labels. Gates can sit a day or so apart, so labels are
        // pushed down the page rather than drawn on top of one another.
        var lastLabelY: CGFloat = -.greatestFiniteMagnitude
        for ms in snap.milestones {
            guard let days = ms.daysFromPour else { continue }
            let p = CGPoint(x: px(min(days, Double(maxDay))), y: py(ms.type.gatePercent))
            UIColor(hex: 0x0891B2).setFill()
            cg.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))

            let labelY = max(p.y - 10, lastLabelY + 11)
            lastLabelY = labelY
            _ = text("\(Int(ms.type.gatePercent))% \(ms.type.displayName)", font: .systemFont(ofSize: 8),
                     color: UIColor(hex: 0x16232B), at: labelY, x: min(p.x + 5, box.maxX - 90))
        }
        return box.maxY + 16
    }

    private func drawMilestones(_ snap: ReportSnapshot, ctx: UIGraphicsPDFRendererContext, y: CGFloat) -> CGFloat {
        var cy = sectionTitle("Milestone schedule", at: y)
        for ms in snap.milestones {
            cy = ensurePage(ctx, cy, need: 20)
            let status: String
            if ms.reached {
                status = "✓ reached"
            } else if let est = ms.estDate {
                status = "due \(Formatters.date(est))"
            } else {
                status = "cure stalled — no date"
            }
            cy = row(left: "\(ms.type.displayName)  (≥\(Int(ms.type.gatePercent))%)", right: status, at: cy)
        }
        cy = ensurePage(ctx, cy, need: 40)
        cy = text(EngineeringDisclaimer.text, font: .systemFont(ofSize: 9),
                  color: UIColor(hex: 0xB45309), at: cy + 4)
        return cy + 10
    }

    private func drawCost(_ snap: ReportSnapshot, y: CGFloat) -> CGFloat {
        let c = snap.cost
        var cy = sectionTitle("Cost estimate", at: y)
        cy = row(left: "Materials", right: snap.money(c.materials), at: cy)
        cy = row(left: "Rental (mixer + pump)", right: snap.money(c.rental), at: cy)
        if c.laborCost > 0 { cy = row(left: "Labour", right: snap.money(c.laborCost), at: cy) }
        cy = row(left: "Total", right: snap.money(c.total), at: cy + 2, bold: true)
        cy = row(left: "Per \(snap.volumeUnit.symbol)",
                 right: snap.money(snap.costPerM3 / snap.volumeUnit.fromM3), at: cy)
        if c.cementFromStockCost > 0 {
            cy = row(left: "Cement already in stock", right: "− \(snap.money(c.cementFromStockCost))", at: cy)
            cy = row(left: "Still to buy", right: snap.money(c.stillToBuy), at: cy)
        }
        return cy + 10
    }

    // MARK: - Drawing primitives

    @discardableResult
    private func text(_ s: String, font: UIFont, color: UIColor, at y: CGFloat, x: CGFloat? = nil) -> CGFloat {
        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
        let originX = x ?? margin
        let width = (x == nil) ? contentWidth : (pageSize.width - margin - originX)
        let rect = CGRect(x: originX, y: y, width: width, height: 400)
        let bounding = (s as NSString).boundingRect(with: CGSize(width: width, height: 400),
                                                     options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        (s as NSString).draw(in: rect, withAttributes: attrs)
        return y + ceil(bounding.height)
    }

    private func sectionTitle(_ s: String, at y: CGFloat) -> CGFloat {
        text(s, font: .systemFont(ofSize: 13, weight: .bold), color: UIColor(hex: 0x0891B2), at: y) + 4
    }

    @discardableResult
    private func row(left: String, right: String, at y: CGFloat, bold: Bool = false) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 11, weight: bold ? .semibold : .regular)
        let lAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(hex: 0x16232B)]
        let rAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(hex: 0x0891B2)]
        (left as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: lAttrs)
        let rSize = (right as NSString).size(withAttributes: rAttrs)
        (right as NSString).draw(at: CGPoint(x: pageSize.width - margin - rSize.width, y: y), withAttributes: rAttrs)
        return y + 18
    }

    private func line(at y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y)); path.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        UIColor(hex: 0xCBD7DE).setStroke(); path.lineWidth = 0.5; path.stroke()
    }

    /// Starts a page and stamps the footer on it straight away — drawing the footer
    /// once at the end of the render only ever put it on the final page.
    private func newPage(_ ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        ctx.beginPage()
        _ = text("Generated by Builder Clock · estimates only — verify on site before loading.",
                 font: .systemFont(ofSize: 9), color: .lightGray, at: pageSize.height - margin - 4)
        return margin
    }

    private func ensurePage(_ ctx: UIGraphicsPDFRendererContext, _ y: CGFloat, need: CGFloat) -> CGFloat {
        if y + need > pageSize.height - margin { return newPage(ctx) }
        return y
    }

    private func safe(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "_").components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).inverted).joined()
    }
}
