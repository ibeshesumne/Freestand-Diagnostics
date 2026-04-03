//
//  ModalityTableViews.swift
//

import SwiftUI

// MARK: - Shared chrome

private struct SectionChrome<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Modality data tables (headers + aligned numerics, units once)

private struct ModalityTableShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct StrengthDayVolumeTable: View {
    let rows: [StrengthDayVolumeRow]

    private let tonnesColumn: CGFloat = 76
    private let setsColumn: CGFloat = 48

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Date")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Tonnes")
                    .frame(width: tonnesColumn, alignment: .trailing)
                Text("Sets")
                    .frame(width: setsColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.element.dayKey) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.dayKey)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.2f", row.volumeKg / 1000))
                        .font(.body.monospacedDigit())
                        .frame(width: tonnesColumn, alignment: .trailing)
                    Text("\(row.setCount)")
                        .font(.body.monospacedDigit())
                        .frame(width: setsColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct StrengthTopExercisesTable: View {
    let rows: [StrengthExerciseVolumeRow]

    private let kgColumn: CGFloat = 80

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Exercise")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Volume (kg)")
                    .frame(width: kgColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.exerciseName)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(format: "%.0f", row.volumeKg))
                        .font(.body.monospacedDigit())
                        .frame(width: kgColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct StrengthMovementPatternTable: View {
    let rows: [StrengthTagCountRow]

    private let setsColumn: CGFloat = 52

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Pattern")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Sets")
                    .frame(width: setsColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.element.tag) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.tag.rawValue)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.setCount)")
                        .font(.body.monospacedDigit())
                        .frame(width: setsColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct CardioMinutesByTypeTable: View {
    let rows: [MinutesByExerciseTypeRow]

    private let minColumn: CGFloat = 72

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Exercise type")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Minutes")
                    .frame(width: minColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.exerciseType)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(format: "%.1f", row.minutes))
                        .font(.body.monospacedDigit())
                        .frame(width: minColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct CardioIntensityMixTable: View {
    let rows: [IntensityMixRow]

    private let minColumn: CGFloat = 64
    private let pctColumn: CGFloat = 52

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Intensity (planned)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Minutes")
                    .frame(width: minColumn, alignment: .trailing)
                Text("% of time")
                    .frame(width: pctColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.element.band) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.band.rawValue)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(format: "%.1f", row.minutes))
                        .font(.body.monospacedDigit())
                        .frame(width: minColumn, alignment: .trailing)
                    Text(String(format: "%.0f", row.percentOfCardioTime))
                        .font(.body.monospacedDigit())
                        .frame(width: pctColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct StretchByTypeTable: View {
    let rows: [StretchTypeStatsRow]

    private let minColumn: CGFloat = 64
    private let sessColumn: CGFloat = 52

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Stretch type")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Minutes")
                    .frame(width: minColumn, alignment: .trailing)
                Text("Sessions")
                    .frame(width: sessColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.stretchType)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(format: "%.1f", row.minutes))
                        .font(.body.monospacedDigit())
                        .frame(width: minColumn, alignment: .trailing)
                    Text("\(row.sessionCount)")
                        .font(.body.monospacedDigit())
                        .frame(width: sessColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct StretchBodyRegionTable: View {
    let rows: [(label: String, minutes: Double, sessions: Int)]

    private let minColumn: CGFloat = 64
    private let sessColumn: CGFloat = 52

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Region")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Minutes")
                    .frame(width: minColumn, alignment: .trailing)
                Text("Sessions")
                    .frame(width: sessColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.label)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f", row.minutes))
                        .font(.body.monospacedDigit())
                        .frame(width: minColumn, alignment: .trailing)
                    Text("\(row.sessions)")
                        .font(.body.monospacedDigit())
                        .frame(width: sessColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct ColdWeeklyTable: View {
    let rows: [ColdWeeklyRow]

    private let sessColumn: CGFloat = 52
    private let minColumn: CGFloat = 64

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Week starting (UTC)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Sessions")
                    .frame(width: sessColumn, alignment: .trailing)
                Text("Minutes")
                    .frame(width: minColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.element.weekStartIso) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.weekStartIso)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.sessionCount)")
                        .font(.body.monospacedDigit())
                        .frame(width: sessColumn, alignment: .trailing)
                    Text(String(format: "%.1f", Double(row.totalSeconds) / 60))
                        .font(.body.monospacedDigit())
                        .frame(width: minColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private struct ColdLocationTable: View {
    let rows: [ColdLocationRow]

    private let sessColumn: CGFloat = 52
    private let minColumn: CGFloat = 64

    var body: some View {
        ModalityTableShell {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Location")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Sessions")
                    .frame(width: sessColumn, alignment: .trailing)
                Text("Minutes")
                    .frame(width: minColumn, alignment: .trailing)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.location)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                    Text("\(row.sessionCount)")
                        .font(.body.monospacedDigit())
                        .frame(width: sessColumn, alignment: .trailing)
                    Text(String(format: "%.1f", Double(row.totalSeconds) / 60))
                        .font(.body.monospacedDigit())
                        .frame(width: minColumn, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
            }
        }
    }
}

private enum StrengthTablesSegment: String, CaseIterable {
    case all = "All"
    case summary = "Summary"
    case daily = "Daily"
}

struct StrengthTablesView: View {
    let exercises: [ExerciseDTO]

    @State private var segment: StrengthTablesSegment = .all

    var body: some View {
        let snap = buildStrengthAnalytics(exercises: exercises)
        let dayRowsRecentFirst = Array(snap.volumeByDay.suffix(40).reversed())
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Strength (resistance)")
                    .font(.title2.weight(.semibold))
                Text(
                    String(
                        format: "%d exercise rows · %d with originalTimestamp · %d sets with volume (kg) · %d skipped (unknown unit)",
                        snap.totalExerciseRows,
                        snap.rowsWithValidTimestamp,
                        snap.rowsWithVolume,
                        snap.rowsWithUnknownUnit
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if !snap.volumeByDay.isEmpty {
                    Picker("Tables", selection: $segment) {
                        ForEach(StrengthTablesSegment.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Group {
                    switch segment {
                    case .all:
                        strengthSummarySections(snap: snap)
                        strengthDailySection(dayRows: dayRowsRecentFirst, snap: snap)
                    case .summary:
                        strengthSummarySections(snap: snap)
                    case .daily:
                        strengthDailySection(dayRows: dayRowsRecentFirst, snap: snap)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func strengthSummarySections(snap: StrengthAnalyticsSnapshot) -> some View {
        SectionChrome(title: "Top exercises by volume") {
            StrengthTopExercisesTable(rows: Array(snap.volumeByExercise.prefix(12)))
        }
        SectionChrome(title: "Movement patterns") {
            StrengthMovementPatternTable(rows: snap.setsByMovementTag)
        }
    }

    @ViewBuilder
    private func strengthDailySection(dayRows: [StrengthDayVolumeRow], snap: StrengthAnalyticsSnapshot) -> some View {
        if snap.volumeByDay.isEmpty {
            Text("No qualifying sets for kg volume.")
                .font(.body)
                .foregroundStyle(.secondary)
        } else {
            SectionChrome(title: "Volume load by day") {
                Text("Daily total in metric tonnes (newest days first; up to 40 days).")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                StrengthDayVolumeTable(rows: dayRows)
            }
        }
    }
}

struct CardioTablesView: View {
    let cardio: [CardioDTO]

    var body: some View {
        let snap = buildCardioAnalytics(cardio: cardio, longEffortThresholdMinutes: 45)
        let intensityRows = snap.intensityMix.filter { $0.minutes > 0 }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Cardio & conditioning")
                    .font(.title2.weight(.semibold))
                Text(
                    String(
                        format: "%d cardio rows · %d with recorded duration · %.1f min total time",
                        snap.totalCardioSessions,
                        snap.sessionsWithRecordedDuration,
                        snap.totalCardioMinutes
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                SectionChrome(title: "Minutes by exercise type") {
                    CardioMinutesByTypeTable(rows: Array(snap.minutesByExerciseType.prefix(15)))
                }

                SectionChrome(title: "Intensity mix (planned)") {
                    if intensityRows.isEmpty {
                        Text("No planned intensity labels with recorded duration.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        CardioIntensityMixTable(rows: intensityRows)
                    }
                }

                if let ad = snap.planAdherence {
                    SectionChrome(title: "Plan adherence") {
                        Text(
                            String(
                                format: "Mean capped ratio %.2f · median %.2f · %d sessions (cap %.0f×)",
                                ad.meanCappedRatio,
                                ad.medianCappedRatio,
                                ad.sessionsWithPlan,
                                ad.capUsed
                            )
                        )
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct StretchTablesView: View {
    let sessions: [StretchSessionDTO]

    var body: some View {
        let snap = buildStretchAnalytics(sessions: sessions)
        let regions = buildStretchBodyRegionStats(sessions: sessions)
        let regionTableRows = regions
            .filter { $0.sessionCount > 0 || $0.minutes > 0 }
            .map { (label: regionLabel($0.region), minutes: $0.minutes, sessions: $0.sessionCount) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Stretch & mobility")
                    .font(.title2.weight(.semibold))
                Text(
                    String(
                        format: "%d stretch rows · %d with recorded duration · %.1f min total",
                        snap.totalSessions,
                        snap.sessionsWithRecordedDuration,
                        snap.totalMinutes
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(
                    String(
                        format: "Unique stretchType: %d · stretchName: %d · time HHI: %.3f",
                        snap.distinctStretchTypes,
                        snap.distinctStretchNames,
                        snap.hhiTimeByStretchType
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                SectionChrome(title: "Minutes by stretchType") {
                    StretchByTypeTable(rows: Array(snap.byStretchType.prefix(15)))
                }

                SectionChrome(title: "Body regions (Free Stand order)") {
                    if regionTableRows.isEmpty {
                        Text("No time logged by region.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        StretchBodyRegionTable(rows: regionTableRows)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func regionLabel(_ r: StretchBodyRegion) -> String {
        switch r {
        case .head: return "Head / neck"
        case .shoulders: return "Shoulders"
        case .chest: return "Chest"
        case .upperArm: return "Upper arms"
        case .spine: return "Spine"
        case .core: return "Core"
        case .hip: return "Hips"
        case .quad: return "Quads"
        case .hamstring: return "Hamstrings"
        case .calf: return "Calves"
        case .other: return "Other"
        }
    }
}

struct ColdTablesView: View {
    let sessions: [ColdBathSessionDTO]

    var body: some View {
        let snap = buildColdBathAnalytics(sessions: sessions, referenceTempCelsius: 37)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Cold exposure")
                    .font(.title2.weight(.semibold))
                if snap.totalSessions == 0 {
                    Text("No cold bath rows in this backup.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text(
                        String(
                            format: "%d rows · %d with sessionDate · %d with recorded duration",
                            snap.totalSessions,
                            snap.sessionsWithSessionDate,
                            snap.sessionsWithRecordedDuration
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    SectionChrome(title: "Per week (UTC)") {
                        ColdWeeklyTable(rows: Array(snap.weekly.suffix(30).reversed()))
                    }

                    SectionChrome(title: "By location") {
                        ColdLocationTable(rows: Array(snap.byLocation.prefix(12)))
                    }

                    Text(
                        String(
                            format: "Exploratory dose proxy: %.0f degree-seconds (%d sessions with temp+duration)",
                            snap.totalDoseDegreeSeconds,
                            snap.doseSessionCount
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

private enum ActivityVolumeOverviewTab: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct ActivityOverviewTablesView: View {
    let export: FreeStandExport

    @State private var volumeTab: ActivityVolumeOverviewTab = .weekly

    var body: some View {
        let snap = buildActivityOverviewAnalytics(export)
        let weeks = Array(snap.weeklyVolume.suffix(24).reversed())
        let months = Array(snap.monthlyVolume.suffix(18).reversed())
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Activity volume & time")
                    .font(.title2.weight(.semibold))
                Text("Weeks start Monday 00:00 UTC. The week column is that Monday as YYYY-MM-DD. Strength uses set counts, not minutes. Newest periods first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(
                    String(
                        format: "Longest streak: %d consecutive UTC days · %d distinct active days overall",
                        snap.longestStreakDays,
                        snap.totalActiveDays
                    )
                )
                .font(.body.weight(.medium))

                Picker("Volume period", selection: $volumeTab) {
                    ForEach(ActivityVolumeOverviewTab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch volumeTab {
                    case .weekly:
                        SectionChrome(title: "Weekly volume (recent)") {
                            ActivityVolumeGrid(
                                firstHeader: "Week (UTC)",
                                labels: weeks.map(\.weekStartIso),
                                rows: weeks.map { ($0.cardioMinutes, $0.stretchMinutes, $0.coldMinutes, $0.strengthSets) }
                            )
                        }
                    case .monthly:
                        SectionChrome(title: "Monthly volume (recent)") {
                            ActivityVolumeGrid(
                                firstHeader: "Month",
                                labels: months.map(\.monthKey),
                                rows: months.map { ($0.cardioMinutes, $0.stretchMinutes, $0.coldMinutes, $0.strengthSets) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

/// Weekly / monthly modality totals: fixed column widths + horizontal scroll so each row stays one line on narrow phones.
private struct ActivityVolumeGrid: View {
    let firstHeader: String
    let labels: [String]
    let rows: [(Double, Double, Double, Int)]

    /// Fits `yyyy-MM-dd` / `yyyy-MM` monospaced at caption size on one line.
    private let labelColumnWidth: CGFloat = 96
    private let metricColumnWidth: CGFloat = 52
    /// Slightly wider so “Strength” + “(sets)” do not wrap mid-word.
    private let strengthColumnWidth: CGFloat = 76
    private let columnSpacing: CGFloat = 8

    private var contentMinWidth: CGFloat {
        labelColumnWidth + columnSpacing + (metricColumnWidth + columnSpacing) * 3 + strengthColumnWidth
    }

    var body: some View {
        ModalityTableShell {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        Text(firstHeader)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: labelColumnWidth, alignment: .leading)
                        volumeColumnHeader(title: "Cardio", unit: "min", width: metricColumnWidth)
                        volumeColumnHeader(title: "Stretch", unit: "min", width: metricColumnWidth)
                        volumeColumnHeader(title: "Cold", unit: "min", width: metricColumnWidth)
                        volumeColumnHeader(title: "Strength", unit: "sets", width: strengthColumnWidth)
                    }
                    .frame(minWidth: contentMinWidth, alignment: .leading)

                    Divider()
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(Array(zip(labels, rows).enumerated()), id: \.offset) { index, pair in
                        let (label, r) = pair
                        HStack(alignment: .firstTextBaseline, spacing: columnSpacing) {
                            Text(label)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: labelColumnWidth, alignment: .leading)
                            Text(fmt(r.0))
                                .font(.caption.monospacedDigit())
                                .lineLimit(1)
                                .frame(width: metricColumnWidth, alignment: .trailing)
                            Text(fmt(r.1))
                                .font(.caption.monospacedDigit())
                                .lineLimit(1)
                                .frame(width: metricColumnWidth, alignment: .trailing)
                            Text(fmt(r.2))
                                .font(.caption.monospacedDigit())
                                .lineLimit(1)
                                .frame(width: metricColumnWidth, alignment: .trailing)
                            Text("\(r.3)")
                                .font(.caption.monospacedDigit())
                                .lineLimit(1)
                                .frame(width: strengthColumnWidth, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                        .frame(minWidth: contentMinWidth, alignment: .leading)
                        .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
                    }
                }
                .frame(minWidth: contentMinWidth)
            }
        }
    }

    @ViewBuilder
    private func volumeColumnHeader(title: String, unit: String, width: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("(\(unit))")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .trailing)
    }

    private func fmt(_ x: Double) -> String {
        String(format: "%.0f", x)
    }
}
