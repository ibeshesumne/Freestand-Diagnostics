//
//  BackupReportPdf.swift
//  Text summary PDF (port of Android BackupReportPdf.kt).
//

import Foundation
import CoreGraphics

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private let maxWeekRows = 52
private let maxMonthRows = 36

func writeBackupReportPdf(
    to url: URL,
    analysis: BackupAnalysisResult,
    sourceFileName: String?,
    generatedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
) throws {
    let data = try pdfReportData(analysis: analysis, sourceFileName: sourceFileName, generatedAtMs: generatedAtMs)
    try data.write(to: url, options: .atomic)
}

func pdfReportData(
    analysis: BackupAnalysisResult,
    sourceFileName: String?,
    generatedAtMs: Int64
) throws -> Data {
    #if os(iOS) || os(visionOS)
    return try pdfDataIOS(analysis: analysis, sourceFileName: sourceFileName, generatedAtMs: generatedAtMs)
    #elseif os(macOS)
    return try pdfDataMac(analysis: analysis, sourceFileName: sourceFileName, generatedAtMs: generatedAtMs)
    #else
    return Data()
    #endif
}

#if os(iOS) || os(visionOS)

private func pdfDataIOS(
    analysis: BackupAnalysisResult,
    sourceFileName: String?,
    generatedAtMs: Int64
) throws -> Data {
    let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    let format = UIGraphicsPDFRendererFormat()
    let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
    let margin: CGFloat = 48
    let contentWidth = pageRect.width - 2 * margin

    let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
    let headingFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    let bodyFont = UIFont.systemFont(ofSize: 10.5)
    let monoFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
    let footerFont = UIFont.systemFont(ofSize: 9)

    var pageIndex = 0
    var y: CGFloat = margin
    var isFirstPdfPage = true

    let data = renderer.pdfData { ctx in
        func newPage() {
            if !isFirstPdfPage {
                let footer = "Page \(pageIndex)"
                let fa: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.darkGray]
                let sz = (footer as NSString).size(withAttributes: fa)
                let fx = (pageRect.width - sz.width) / 2
                (footer as NSString).draw(at: CGPoint(x: fx, y: pageRect.height - 28), withAttributes: fa)
            }
            ctx.beginPage(withBounds: pageRect, pageInfo: [:])
            pageIndex += 1
            isFirstPdfPage = false
            y = margin
        }

        func ensureSpace(_ h: CGFloat, cg: CGContext) {
            if y + h > pageRect.height - margin {
                newPage()
            }
        }

        func drawParagraph(_ text: String, font: UIFont, afterGap: CGFloat = 8, cg: CGContext) {
            if text.isEmpty {
                ensureSpace(font.lineHeight, cg: cg)
                y += font.lineHeight + afterGap
                return
            }
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let r = (text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: 10_000),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            let h = ceil(r.height)
            ensureSpace(h + afterGap, cg: cg)
            let rect = CGRect(x: margin, y: y, width: contentWidth, height: h)
            (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
            y += h + afterGap
        }

        func drawMonoLine(_ line: String, cg: CGContext) {
            let clipped = line.count > 120 ? String(line.prefix(117)) + "..." : line
            let attrs: [NSAttributedString.Key: Any] = [.font: monoFont]
            let h = monoFont.lineHeight * 1.15
            ensureSpace(h, cg: cg)
            (clipped as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
            y += h
        }

        newPage()
        let cg = ctx.cgContext

        drawParagraph("Free Stand Diagnostics", font: titleFont, afterGap: 6, cg: cg)
        drawParagraph("Backup report", font: headingFont, afterGap: 14, cg: cg)

        let genDate = Date(timeIntervalSince1970: TimeInterval(generatedAtMs) / 1000)
        let genFmt = DateFormatter()
        genFmt.dateStyle = .medium
        genFmt.timeStyle = .short
        drawParagraph("Generated: \(genFmt.string(from: genDate))", font: bodyFont, cg: cg)
        if let sourceFileName, !sourceFileName.isEmpty {
            drawParagraph("Source file: \(sourceFileName)", font: bodyFont, cg: cg)
        }
        drawParagraph("", font: bodyFont, afterGap: 12, cg: cg)

        let e = analysis.export
        drawParagraph("Backup metadata", font: headingFont, afterGap: 6, cg: cg)
        if e.exportedAt > 0 {
            drawParagraph(
                "Exported (backup): \(formatLocalDateTime(epochMs: e.exportedAt)) · \(formatUtcDateTime(epochMs: e.exportedAt))",
                font: bodyFont,
                cg: cg
            )
        } else {
            drawParagraph("Exported (backup): not set in file", font: bodyFont, cg: cg)
        }
        drawParagraph("Schema version: \(e.schemaVersion)", font: bodyFont, cg: cg)
        drawParagraph(
            "Library: \(e.theories.count) theories · \(e.theoryVersions.count) theory version rows",
            font: bodyFont,
            afterGap: 14,
            cg: cg
        )

        drawParagraph("Import checks", font: headingFont, afterGap: 6, cg: cg)
        drawParagraph(
            analysis.integrityOk ? "Status: all structural checks passed." : "Status: issues found (see below).",
            font: bodyFont,
            cg: cg
        )
        drawParagraph("Distinct active UTC days (any modality): \(analysis.activeDaysUtc)", font: bodyFont, afterGap: 8, cg: cg)
        if !analysis.schemaVersionOk {
            drawParagraph("• Schema is not v1 as expected.", font: bodyFont, cg: cg)
        }
        if !analysis.topLevelKeysMatch {
            if !analysis.missingKeys.isEmpty {
                drawParagraph("• Missing keys: \(analysis.missingKeys.sorted().joined(separator: ", "))", font: bodyFont, cg: cg)
            }
            if !analysis.extraKeys.isEmpty {
                drawParagraph("• Extra keys: \(analysis.extraKeys.sorted().joined(separator: ", "))", font: bodyFont, cg: cg)
            }
        }
        for d in analysis.duplicateReports {
            drawParagraph("• Duplicate IDs in \(d.arrayName): \(d.duplicateCount)", font: bodyFont, cg: cg)
        }
        drawParagraph("", font: bodyFont, afterGap: 12, cg: cg)

        drawParagraph(
            "Charts in this app (bars, heatmap, etc.) are not drawn into the PDF; the following sections mirror the same numbers behind the Tables tab.",
            font: bodyFont,
            afterGap: 14,
            cg: cg
        )

        drawParagraph("Modality overview", font: headingFont, afterGap: 6, cg: cg)
        for m in analysis.modalities {
            let time: String
            if let sec = m.totalRecordedSeconds {
                time = String(format: "Σ recorded time: %.1f min", locale: Locale(identifier: "en_US_POSIX"), Double(sec) / 60.0)
            } else {
                time = "Σ recorded time: —"
            }
            drawParagraph("• \(m.label): \(m.countLabel) \(m.count); \(time)", font: bodyFont, cg: cg)
            let span: String
            if let a = m.dateStartMs, let b = m.dateEndMs {
                span = "\(formatUtcDate(epochMs: a)) → \(formatUtcDate(epochMs: b)) (\(m.dateFieldLabel), UTC calendar day)"
            } else {
                span = "Date span: —"
            }
            drawParagraph("  \(span)", font: bodyFont, afterGap: 4, cg: cg)
        }
        drawParagraph("", font: bodyFont, afterGap: 10, cg: cg)

        let snap = buildActivityOverviewAnalytics(e)
        drawParagraph("Activity summary", font: headingFont, afterGap: 6, cg: cg)
        drawParagraph(
            "Longest streak (consecutive UTC days with any log): \(snap.longestStreakDays) day(s)",
            font: bodyFont,
            cg: cg
        )
        drawParagraph("Total distinct active UTC days: \(snap.totalActiveDays)", font: bodyFont, afterGap: 10, cg: cg)

        drawParagraph("Weekly volume (recent weeks, UTC Monday start)", font: headingFont, afterGap: 6, cg: cg)
        drawParagraph(
            "Cardio / stretch / cold = minutes (from recorded duration). Strength = set count in week.",
            font: monoFont,
            afterGap: 4,
            cg: cg
        )
        let weeks = Array(snap.weeklyVolume.suffix(maxWeekRows))
        if weeks.isEmpty {
            drawParagraph("No weekly rows.", font: bodyFont, cg: cg)
        } else {
            drawMonoLine(
                "\("Week start".padding(toLength: 12, withPad: " ", startingAt: 0)) \("Cardio".paddingLeft(8)) \("Stretch".paddingLeft(8)) \("Cold".paddingLeft(8)) \("Str sets".paddingLeft(8))",
                cg: cg
            )
            for row in weeks {
                let line = String(format: "%@ %@ %@ %@ %@",
                                  row.weekStartIso.padding(toLength: 12, withPad: " ", startingAt: 0),
                                  String(format: "%8.1f", row.cardioMinutes),
                                  String(format: "%8.1f", row.stretchMinutes),
                                  String(format: "%8.1f", row.coldMinutes),
                                  String(format: "%8d", row.strengthSets))
                drawMonoLine(line, cg: cg)
            }
        }
        drawParagraph("", font: bodyFont, afterGap: 10, cg: cg)

        drawParagraph("Monthly volume (UTC calendar month)", font: headingFont, afterGap: 6, cg: cg)
        let months = Array(snap.monthlyVolume.suffix(maxMonthRows))
        if months.isEmpty {
            drawParagraph("No monthly rows.", font: bodyFont, cg: cg)
        } else {
            drawMonoLine(
                "\("Month".padding(toLength: 10, withPad: " ", startingAt: 0)) \("Cardio".paddingLeft(8)) \("Stretch".paddingLeft(8)) \("Cold".paddingLeft(8)) \("Str sets".paddingLeft(8))",
                cg: cg
            )
            for row in months {
                let line = String(format: "%@ %@ %@ %@ %@",
                                  row.monthKey.padding(toLength: 10, withPad: " ", startingAt: 0),
                                  String(format: "%8.1f", row.cardioMinutes),
                                  String(format: "%8.1f", row.stretchMinutes),
                                  String(format: "%8.1f", row.coldMinutes),
                                  String(format: "%8d", row.strengthSets))
                drawMonoLine(line, cg: cg)
            }
        }
        drawParagraph("", font: bodyFont, afterGap: 10, cg: cg)

        drawParagraph("Weekly active days (distinct UTC days per week, any modality)", font: headingFont, afterGap: 6, cg: cg)
        let actDays = Array(snap.weeklyActiveDays.suffix(maxWeekRows))
        if actDays.isEmpty {
            drawParagraph("No rows.", font: bodyFont, cg: cg)
        } else {
            drawMonoLine("\("Week start".padding(toLength: 14, withPad: " ", startingAt: 0)) \("Active days".paddingLeft(12))", cg: cg)
            for row in actDays {
                drawMonoLine(
                    "\(row.weekStartIso.padding(toLength: 14, withPad: " ", startingAt: 0)) \(String(format: "%12d", row.activeDays))",
                    cg: cg
                )
            }
        }
        drawParagraph("", font: bodyFont, afterGap: 10, cg: cg)

        drawParagraph("Weekly session frequency", font: headingFont, afterGap: 6, cg: cg)
        drawParagraph(
            "Cardio / stretch / cold = event counts. Strength = distinct UTC days with ≥1 set.",
            font: monoFont,
            afterGap: 4,
            cg: cg
        )
        let sess = Array(snap.weeklySessionFreq.suffix(maxWeekRows))
        if sess.isEmpty {
            drawParagraph("No rows.", font: bodyFont, cg: cg)
        } else {
            drawMonoLine(
                "\("Week start".padding(toLength: 12, withPad: " ", startingAt: 0)) \("Cardio".paddingLeft(7)) \("Strch".paddingLeft(7)) \("Cold".paddingLeft(7)) \("Str day".paddingLeft(7))",
                cg: cg
            )
            for row in sess {
                let line = String(format: "%@ %7d %7d %7d %7d",
                                  row.weekStartIso.padding(toLength: 12, withPad: " ", startingAt: 0),
                                  row.cardioEvents,
                                  row.stretchEvents,
                                  row.coldEvents,
                                  row.strengthSessionDays)
                drawMonoLine(line, cg: cg)
            }
        }

        drawParagraph("", font: bodyFont, afterGap: 8, cg: cg)
        drawParagraph("— End of report —", font: footerFont, cg: cg)
        let footer = "Page \(pageIndex)"
        let fa: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.darkGray]
        let sz = (footer as NSString).size(withAttributes: fa)
        let fx = (pageRect.width - sz.width) / 2
        (footer as NSString).draw(at: CGPoint(x: fx, y: pageRect.height - 28), withAttributes: fa)
    }
    return data
}

#endif

#if os(macOS)

private func pdfDataMac(
    analysis: BackupAnalysisResult,
    sourceFileName: String?,
    generatedAtMs: Int64
) throws -> Data {
    let pageRect = NSRect(x: 0, y: 0, width: 595, height: 842)
    let margin: CGFloat = 48
    let contentWidth = pageRect.width - 2 * margin

    let titleFont = NSFont.systemFont(ofSize: 20, weight: .bold)
    let headingFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let bodyFont = NSFont.systemFont(ofSize: 10.5)
    let monoFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
    let footerFont = NSFont.systemFont(ofSize: 9)

    let data = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
    guard let consumer = CGDataConsumer(data: data) else { throw BackupExportError.pdfFailed }
    guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw BackupExportError.pdfFailed }

    var pageIndex = 0
    var y: CGFloat = margin

    /// PDF page space uses a bottom-left origin; flip so our layout matches UIKit (y grows downward).
    func pushTopDownPageSpace() {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pageRect.height)
        ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    }

    func popPageSpace() {
        NSGraphicsContext.current = nil
        ctx.restoreGState()
    }

    func newPage() {
        drawFooter()
        popPageSpace()
        ctx.endPDFPage()
        ctx.beginPDFPage(nil)
        pageIndex += 1
        y = margin
        pushTopDownPageSpace()
    }

    ctx.beginPDFPage(nil)
    pageIndex = 1
    pushTopDownPageSpace()

    func drawFooter() {
        let footer = "Page \(pageIndex)"
        let attrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: NSColor.darkGray]
        let sz = (footer as NSString).size(withAttributes: attrs)
        let fx = (pageRect.width - sz.width) / 2
        (footer as NSString).draw(at: NSPoint(x: fx, y: pageRect.height - 28), withAttributes: attrs)
    }

    func ensureSpace(_ h: CGFloat) {
        if y + h > pageRect.height - margin {
            newPage()
        }
    }

    func drawParagraph(_ text: String, font: NSFont, afterGap: CGFloat = 8) {
        if text.isEmpty {
            ensureSpace(font.ascender - font.descender + font.leading)
            y += font.ascender - font.descender + font.leading + afterGap
            return
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let r = (text as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let h = ceil(r.height)
        ensureSpace(h + afterGap)
        let rect = NSRect(x: margin, y: y, width: contentWidth, height: h)
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
        y += h + afterGap
    }

    func drawMonoLine(_ line: String) {
        let clipped = line.count > 120 ? String(line.prefix(117)) + "..." : line
        let attrs: [NSAttributedString.Key: Any] = [.font: monoFont]
        let h = monoFont.ascender - monoFont.descender + monoFont.leading
        ensureSpace(h * 1.15)
        (clipped as NSString).draw(at: NSPoint(x: margin, y: y), withAttributes: attrs)
        y += h * 1.15
    }

    drawParagraph("Free Stand Diagnostics", font: titleFont, afterGap: 6)
    drawParagraph("Backup report", font: headingFont, afterGap: 14)

    let genDate = Date(timeIntervalSince1970: TimeInterval(generatedAtMs) / 1000)
    let genFmt = DateFormatter()
    genFmt.dateStyle = .medium
    genFmt.timeStyle = .short
    drawParagraph("Generated: \(genFmt.string(from: genDate))", font: bodyFont)
    if let sourceFileName, !sourceFileName.isEmpty {
        drawParagraph("Source file: \(sourceFileName)", font: bodyFont)
    }
    drawParagraph("", font: bodyFont, afterGap: 12)

    let e = analysis.export
    drawParagraph("Backup metadata", font: headingFont, afterGap: 6)
    if e.exportedAt > 0 {
        drawParagraph(
            "Exported (backup): \(formatLocalDateTime(epochMs: e.exportedAt)) · \(formatUtcDateTime(epochMs: e.exportedAt))",
            font: bodyFont
        )
    } else {
        drawParagraph("Exported (backup): not set in file", font: bodyFont)
    }
    drawParagraph("Schema version: \(e.schemaVersion)", font: bodyFont)
    drawParagraph(
        "Library: \(e.theories.count) theories · \(e.theoryVersions.count) theory version rows",
        font: bodyFont,
        afterGap: 14
    )

    drawParagraph("Import checks", font: headingFont, afterGap: 6)
    drawParagraph(
        analysis.integrityOk ? "Status: all structural checks passed." : "Status: issues found (see below).",
        font: bodyFont
    )
    drawParagraph("Distinct active UTC days (any modality): \(analysis.activeDaysUtc)", font: bodyFont, afterGap: 8)
    if !analysis.schemaVersionOk { drawParagraph("• Schema is not v1 as expected.", font: bodyFont) }
    if !analysis.topLevelKeysMatch {
        if !analysis.missingKeys.isEmpty {
            drawParagraph("• Missing keys: \(analysis.missingKeys.sorted().joined(separator: ", "))", font: bodyFont)
        }
        if !analysis.extraKeys.isEmpty {
            drawParagraph("• Extra keys: \(analysis.extraKeys.sorted().joined(separator: ", "))", font: bodyFont)
        }
    }
    for d in analysis.duplicateReports {
        drawParagraph("• Duplicate IDs in \(d.arrayName): \(d.duplicateCount)", font: bodyFont)
    }
    drawParagraph("", font: bodyFont, afterGap: 12)

    drawParagraph(
        "Charts in this app (bars, heatmap, etc.) are not drawn into the PDF; the following sections mirror the same numbers behind the Tables tab.",
        font: bodyFont,
        afterGap: 14
    )

    drawParagraph("Modality overview", font: headingFont, afterGap: 6)
    for m in analysis.modalities {
        let time: String
        if let sec = m.totalRecordedSeconds {
            time = String(format: "Σ recorded time: %.1f min", locale: Locale(identifier: "en_US_POSIX"), Double(sec) / 60.0)
        } else {
            time = "Σ recorded time: —"
        }
        drawParagraph("• \(m.label): \(m.countLabel) \(m.count); \(time)", font: bodyFont)
        let span: String
        if let a = m.dateStartMs, let b = m.dateEndMs {
            span = "\(formatUtcDate(epochMs: a)) → \(formatUtcDate(epochMs: b)) (\(m.dateFieldLabel), UTC calendar day)"
        } else {
            span = "Date span: —"
        }
        drawParagraph("  \(span)", font: bodyFont, afterGap: 4)
    }
    drawParagraph("", font: bodyFont, afterGap: 10)

    let snap = buildActivityOverviewAnalytics(e)
    drawParagraph("Activity summary", font: headingFont, afterGap: 6)
    drawParagraph("Longest streak (consecutive UTC days with any log): \(snap.longestStreakDays) day(s)", font: bodyFont)
    drawParagraph("Total distinct active UTC days: \(snap.totalActiveDays)", font: bodyFont, afterGap: 10)

    drawParagraph("Weekly volume (recent weeks, UTC Monday start)", font: headingFont, afterGap: 6)
    drawParagraph("Cardio / stretch / cold = minutes (from recorded duration). Strength = set count in week.", font: monoFont, afterGap: 4)
    let weeks = Array(snap.weeklyVolume.suffix(maxWeekRows))
    if weeks.isEmpty {
        drawParagraph("No weekly rows.", font: bodyFont)
    } else {
        drawMonoLine("\("Week start".padding(toLength: 12, withPad: " ", startingAt: 0)) \("Cardio".paddingLeft(8)) \("Stretch".paddingLeft(8)) \("Cold".paddingLeft(8)) \("Str sets".paddingLeft(8))")
        for row in weeks {
            let line = String(format: "%@ %@ %@ %@ %@",
                              row.weekStartIso.padding(toLength: 12, withPad: " ", startingAt: 0),
                              String(format: "%8.1f", row.cardioMinutes),
                              String(format: "%8.1f", row.stretchMinutes),
                              String(format: "%8.1f", row.coldMinutes),
                              String(format: "%8d", row.strengthSets))
            drawMonoLine(line)
        }
    }
    drawParagraph("", font: bodyFont, afterGap: 10)

    drawParagraph("Monthly volume (UTC calendar month)", font: headingFont, afterGap: 6)
    let months = Array(snap.monthlyVolume.suffix(maxMonthRows))
    if months.isEmpty {
        drawParagraph("No monthly rows.", font: bodyFont)
    } else {
        drawMonoLine("\("Month".padding(toLength: 10, withPad: " ", startingAt: 0)) \("Cardio".paddingLeft(8)) \("Stretch".paddingLeft(8)) \("Cold".paddingLeft(8)) \("Str sets".paddingLeft(8))")
        for row in months {
            let line = String(format: "%@ %@ %@ %@ %@",
                              row.monthKey.padding(toLength: 10, withPad: " ", startingAt: 0),
                              String(format: "%8.1f", row.cardioMinutes),
                              String(format: "%8.1f", row.stretchMinutes),
                              String(format: "%8.1f", row.coldMinutes),
                              String(format: "%8d", row.strengthSets))
            drawMonoLine(line)
        }
    }
    drawParagraph("", font: bodyFont, afterGap: 10)

    drawParagraph("Weekly active days (distinct UTC days per week, any modality)", font: headingFont, afterGap: 6)
    let actDays = Array(snap.weeklyActiveDays.suffix(maxWeekRows))
    if actDays.isEmpty {
        drawParagraph("No rows.", font: bodyFont)
    } else {
        drawMonoLine("\("Week start".padding(toLength: 14, withPad: " ", startingAt: 0)) \("Active days".paddingLeft(12))")
        for row in actDays {
            drawMonoLine("\(row.weekStartIso.padding(toLength: 14, withPad: " ", startingAt: 0)) \(String(format: "%12d", row.activeDays))")
        }
    }
    drawParagraph("", font: bodyFont, afterGap: 10)

    drawParagraph("Weekly session frequency", font: headingFont, afterGap: 6)
    drawParagraph("Cardio / stretch / cold = event counts. Strength = distinct UTC days with ≥1 set.", font: monoFont, afterGap: 4)
    let sess = Array(snap.weeklySessionFreq.suffix(maxWeekRows))
    if sess.isEmpty {
        drawParagraph("No rows.", font: bodyFont)
    } else {
        drawMonoLine("\("Week start".padding(toLength: 12, withPad: " ", startingAt: 0)) \("Cardio".paddingLeft(7)) \("Strch".paddingLeft(7)) \("Cold".paddingLeft(7)) \("Str day".paddingLeft(7))")
        for row in sess {
            let line = String(format: "%@ %7d %7d %7d %7d",
                              row.weekStartIso.padding(toLength: 12, withPad: " ", startingAt: 0),
                              row.cardioEvents,
                              row.stretchEvents,
                              row.coldEvents,
                              row.strengthSessionDays)
            drawMonoLine(line)
        }
    }

    drawParagraph("", font: bodyFont, afterGap: 8)
    drawParagraph("— End of report —", font: footerFont)
    drawFooter()

    popPageSpace()
    ctx.endPDFPage()
    ctx.closePDF()

    return data as Data
}

#endif

enum BackupExportError: Error {
    case pdfFailed
}

private extension String {
    func paddingLeft(_ totalWidth: Int) -> String {
        if count >= totalWidth { return self }
        return String(repeating: " ", count: totalWidth - count) + self
    }
}
