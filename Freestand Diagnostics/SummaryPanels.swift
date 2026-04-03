//
//  SummaryPanels.swift
//

import SwiftUI

struct ImportStatusSection: View {
    let analysis: BackupAnalysisResult

    var body: some View {
        let allOk = analysis.integrityOk
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: allOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(allOk ? .green : .orange)
                Text(allOk ? "Import verified" : "Import issues")
                    .font(.title3.weight(.semibold))
            }

            let exportedMs = analysis.export.exportedAt
            Text(
                exportedMs > 0
                    ? "Exported: \(formatLocalDateTime(epochMs: exportedMs)) (this device) · \(formatUtcDateTime(epochMs: exportedMs)) · schema v\(analysis.export.schemaVersion)"
                    : "Exported: not set in backup · schema v\(analysis.export.schemaVersion)"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                StatusChip(label: "JSON parsed", ok: true)
                StatusChip(label: "Schema v1", ok: analysis.schemaVersionOk)
                StatusChip(label: "Expected keys", ok: analysis.topLevelKeysMatch)
                StatusChip(label: "No duplicate IDs", ok: analysis.duplicateReports.isEmpty)
            }

            if !analysis.topLevelKeysMatch {
                Text(missingExtraLine)
                    .font(.subheadline)
            }
            ForEach(analysis.duplicateReports, id: \.arrayName) { rep in
                Text("\(rep.arrayName): \(rep.duplicateCount) duplicate id(s)")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            FlowLayout(spacing: 10) {
                let e = analysis.export
                Text("cardio \(e.cardio.count)").chip()
                Text("strength \(e.exercises.count)").chip()
                Text("stretch \(e.stretchSessions.count)").chip()
                Text("cold \(e.coldBathSessions.count)").chip()
                Text("theories \(e.theories.count)").chip()
                Text("versions \(e.theoryVersions.count)").chip()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(allOk ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var missingExtraLine: String {
        var parts: [String] = []
        if !analysis.missingKeys.isEmpty {
            parts.append("Missing: \(analysis.missingKeys.sorted().joined(separator: ", "))")
        }
        if !analysis.extraKeys.isEmpty {
            parts.append("Extra: \(analysis.extraKeys.sorted().joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}

private struct StatusChip: View {
    let label: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text(label)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5))
        .clipShape(Capsule())
    }
}

private extension Text {
    func chip() -> some View {
        self
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5))
            .clipShape(Capsule())
    }
}

/// Simple wrapping chip row (replaces Compose FlowRow).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let res = layout(proposal: proposal, subviews: subviews)
        for (i, p) in res.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        var positions: [CGPoint] = []
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowH = max(rowH, s.height)
            x += s.width + spacing
        }
        return (CGSize(width: maxW, height: y + rowH), positions)
    }
}

struct SummaryVisualizationContent: View {
    let analysis: BackupAnalysisResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ActiveDaysHighlightCard(analysis: analysis)
                ForEach(Array(analysis.modalities.enumerated()), id: \.offset) { _, m in
                    ModalityCard(m: m)
                }
                Text(
                    "Library (catalog, not activity logs): \(analysis.export.theories.count) theories · \(analysis.export.theoryVersions.count) version rows"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
            .padding(20)
        }
    }
}

private struct ActiveDaysHighlightCard: View {
    let analysis: BackupAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active days (logged)")
                .font(.headline)
            Text("\(analysis.activeDaysUtc)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Distinct UTC calendar days with ≥1 cardio, strength set, stretch, or cold session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ModalityCard: View {
    let m: ModalitySummary

    private var timeLine: String {
        if let sec = m.totalRecordedSeconds {
            return String(format: "Total time: %.1f min (Σ recordedDurationSeconds)", Double(sec) / 60.0)
        }
        return "Total time: — (not tracked per set)"
    }

    private var span: String {
        if let a = m.dateStartMs, let b = m.dateEndMs {
            return "\(formatUtcDate(epochMs: a)) → \(formatUtcDate(epochMs: b)) (\(m.dateFieldLabel))"
        }
        return "Date span: —"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(m.label)
                .font(.title3.weight(.semibold))
            Text("\(m.countLabel): \(m.count)")
                .font(.body.weight(.medium))
            Text(timeLine)
                .font(.body)
                .foregroundStyle(.secondary)
            Text(span)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
