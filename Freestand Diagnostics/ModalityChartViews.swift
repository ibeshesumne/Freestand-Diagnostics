//
//  ModalityChartViews.swift
//

import Charts
import SwiftUI

private let chartAxisFont: Font = .callout

/// Calendars for Swift Charts `unit:` / `calendar:` so temporal marks don’t fall back to a fixed width (console: “Consider adding unit to the data…”).
private enum ChartsUtcCalendar {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Monday-first ISO-style weeks in UTC (matches analytics `weekStartMondayKeyUtc`).
    static let mondayWeek: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }()
}

/// Parse `yyyy-MM-dd` at UTC midnight (matches `weekStartMondayKeyUtc` / `dayKeyUtc`).
private func utcMidnightDate(fromYMD dayKey: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = TimeZone(identifier: "UTC")!
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: dayKey)
}

// MARK: - Week charts: compact x-axis (overlap-resistant)

private enum WeekChartLayout {
    /// Minimum chart width scales with bar count so bars are not crushed on the phone.
    static let minWidthPerWeekBar: CGFloat = 28
    static let plotHeightBarChart: CGFloat = 232
    /// Taller frame so rotated week ticks are not clipped above the home indicator / tab bar.
    static let scrollFrameHeightBarChart: CGFloat = 348
    static let lineChartHeight: CGFloat = 176
    static let lineChartWithXAxisHeight: CGFloat = 212
    /// Fewer ticks + rotation keeps labels legible on narrow widths.
    static let xAxisDesiredTickCount: Int = 4
    static let xTickRotationDegrees: Double = -56
}

// MARK: - Strength weekly volume: horizontal bars + ISO year/week (quarter labels)

private func isoYearAndWeekForMondayUtc(_ monday: Date) -> (year: Int, week: Int) {
    var c = Calendar(identifier: .iso8601)
    c.timeZone = TimeZone(identifier: "UTC")!
    let week = c.component(.weekOfYear, from: monday)
    let year = c.component(.yearForWeekOfYear, from: monday)
    return (year, week)
}

/// First logged week in each calendar quarter (Jan / Apr / Jul / Oct UTC) that intersects the data range.
private func isoKeysFirstLoggedWeekPerQuarter(sortedIsoKeysAscending: [String]) -> Set<String> {
    guard let lo = sortedIsoKeysAscending.first, let hi = sortedIsoKeysAscending.last else { return [] }
    var result = Set<String>()
    let yStart = Int(lo.prefix(4))!
    let yEnd = Int(hi.prefix(4))!
    for y in yStart...yEnd {
        let quarterStarts = [
            String(format: "%04d-01-01", y),
            String(format: "%04d-04-01", y),
            String(format: "%04d-07-01", y),
            String(format: "%04d-10-01", y),
        ]
        for i in quarterStarts.indices {
            let s = quarterStarts[i]
            if s > hi { continue }
            let next: String
            if i == 3 { next = String(format: "%04d-01-01", y + 1) }
            else { next = quarterStarts[i + 1] }
            if next <= lo { continue }
            if let first = sortedIsoKeysAscending.first(where: { $0 >= s && $0 < next }), first <= hi {
                result.insert(first)
            }
        }
    }
    return result
}

/// Bar colors for weekly strength volume, keyed by distinct ISO week years (newest year → first swatch).
private let strengthWeeklyIsoYearBarPalette: [Color] = [
    .teal,
    .orange,
    .indigo,
    .purple,
    .pink,
    .mint,
]

private func strengthWeeklyBarColorForIsoWeekYear(
    isoWeekYear: Int,
    yearsDescending: [Int],
    isZeroCalendarWeek: Bool
) -> Color {
    let idx = yearsDescending.firstIndex(of: isoWeekYear) ?? 0
    let base = strengthWeeklyIsoYearBarPalette[idx % strengthWeeklyIsoYearBarPalette.count]
    if isZeroCalendarWeek { return base.opacity(0.22) }
    return base
}

/// UTC Gregorian year + month for a Monday `yyyy-MM-dd` key (heatmap / bimonth ticks).
private func utcGregorianYearMonth(mondayIso: String) -> (year: Int, month: Int)? {
    guard let d = utcMidnightDate(fromYMD: mondayIso) else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return (cal.component(.year, from: d), cal.component(.month, from: d))
}

/// Jan–Feb → 0, Mar–Apr → 1, … within each calendar year (UTC).
private func utcBimonthIndex(year: Int, month: Int) -> Int {
    year * 6 + (month - 1) / 2
}

/// Activity overview weekly bars: newest year uses the modality `baseColor`; older years cycle distinct hues.
private func activityWeeklyBarFill(
    isoWeekYear: Int,
    yearsDescending: [Int],
    baseColor: Color,
    colorIsoYears: Bool,
    isDimZero: Bool
) -> Color {
    guard colorIsoYears, yearsDescending.count > 1, let idx = yearsDescending.firstIndex(of: isoWeekYear) else {
        return isDimZero ? baseColor.opacity(0.22) : baseColor
    }
    let palette: [Color] = [baseColor, .orange, .indigo, .purple, .pink, .mint]
    let c = palette[idx % palette.count]
    return isDimZero ? c.opacity(0.22) : c
}

/// Monday dates (UTC) where the bimonth bucket changes vs the prior bar — for sparse `Wnn` x-axis labels (~every two months).
private func weeklyBarChartBimonthTickWeekStarts(
    datedPoints: [(iso: String, weekStart: Date, value: Float)]
) -> [Date] {
    if datedPoints.isEmpty { return [] }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    var ticks: [Date] = []
    var lastBucket: Int?
    for row in datedPoints {
        let d = row.weekStart
        let y = cal.component(.year, from: d)
        let m = cal.component(.month, from: d)
        let b = utcBimonthIndex(year: y, month: m)
        if lastBucket == nil || b != lastBucket {
            ticks.append(d)
            lastBucket = b
        }
    }
    if let last = datedPoints.last?.weekStart, ticks.last != last {
        ticks.append(last)
    }
    return ticks
}

/// Upper bound for the horizontal weekly volume x-axis so bars are not clipped; steps in 5k / 10k / 25k bands.
private func strengthVolumeChartXAxisMax(peakKg: Double) -> Double {
    let p = max(peakKg, 1)
    let padded = p * 1.18
    if padded <= 2_500 { return ceil(padded / 250) * 250 }
    if padded <= 12_500 { return ceil(padded / 2_500) * 2_500 }
    if padded <= 62_500 { return ceil(padded / 12_500) * 12_500 }
    return ceil(padded / 25_000) * 25_000
}

private func strengthHorizontalWeekYAxisText(
    isoKey: String,
    monday: Date,
    quarterLabelKeys: Set<String>,
    latestIso: String
) -> (text: String, emphasize: Bool) {
    let (iy, iw) = isoYearAndWeekForMondayUtc(monday)
    if quarterLabelKeys.contains(isoKey) {
        return ("\(iy) · W\(iw)", true)
    }
    if isoKey == latestIso {
        return ("W\(iw) · latest", true)
    }
    return ("W\(iw)", false)
}

/// **Month/day** for the Monday date (UTC). Adds **two-digit year** when the chart range crosses calendar years (e.g. `12/1/25`).
private func formatWeekAxisTickMdUtc(date: Date, rangeStart: Date, rangeEnd: Date) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let yR0 = cal.component(.year, from: rangeStart)
    let yR1 = cal.component(.year, from: rangeEnd)
    let mo = cal.component(.month, from: date)
    let d = cal.component(.day, from: date)
    if yR0 != yR1 {
        let y = cal.component(.year, from: date) % 100
        return String(format: "%d/%d/%02d", mo, d, y)
    }
    return String(format: "%d/%d", mo, d)
}

@ViewBuilder
private func weekAxisRotatedTick(_ value: AxisValue, rangeStart: Date, rangeEnd: Date) -> some View {
    if let d = value.as(Date.self) {
        Text(formatWeekAxisTickMdUtc(date: d, rangeStart: rangeStart, rangeEnd: rangeEnd))
            .font(.system(size: 9, weight: .medium, design: .default))
            .monospacedDigit()
            .lineLimit(1)
            .rotationEffect(.degrees(WeekChartLayout.xTickRotationDegrees), anchor: .center)
            .frame(width: 44, height: 40, alignment: .center)
    }
}

@ViewBuilder
private func weekAxisRotatedIsoWeekNumberTick(
    _ value: AxisValue,
    isoWeekYearsDescending: [Int],
    baseColor: Color,
    colorIsoYears: Bool
) -> some View {
    if let d = value.as(Date.self) {
        let iw = isoYearAndWeekForMondayUtc(d)
        let fg = activityWeeklyBarFill(
            isoWeekYear: iw.year,
            yearsDescending: isoWeekYearsDescending,
            baseColor: baseColor,
            colorIsoYears: colorIsoYears,
            isDimZero: false
        )
        Text("W\(iw.week)")
            .font(.system(size: 9, weight: .semibold, design: .default))
            .monospacedDigit()
            .foregroundStyle(fg)
            .lineLimit(1)
            .rotationEffect(.degrees(WeekChartLayout.xTickRotationDegrees), anchor: .center)
            .frame(width: 44, height: 44, alignment: .center)
    }
}

@ViewBuilder
private func weekAxisTitleFootnote(title: String, footnote: String) -> some View {
    VStack(spacing: 2) {
        Text(title)
            .font(.caption.weight(.semibold))
        Text(footnote)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

/// One `Text` from attributed parts (macOS 26 deprecates `Text` + `Text`).
private func captionProvenanceLeadingBold(_ boldPrefix: String, secondaryTail: String) -> Text {
    var head = AttributedString(boldPrefix)
    head.font = .caption.weight(.semibold)
    var tail = AttributedString(secondaryTail)
    tail.font = .caption
    tail.foregroundColor = .secondary
    return Text(head + tail)
}

private func captionProvenanceChartFilterLine(periodLabel: String, windowStartMs: Int64, windowEndMs: Int64) -> Text {
    var lead = AttributedString("Chart filter: ")
    lead.font = .caption.weight(.semibold)
    var period = AttributedString(periodLabel)
    period.font = .caption.weight(.semibold)
    var mid = AttributedString(" — window ")
    mid.font = .caption
    mid.foregroundColor = .secondary
    var dates = AttributedString(
        "\(formatUtcDateTime(epochMs: windowStartMs)) → \(formatUtcDateTime(epochMs: windowEndMs)) UTC"
    )
    dates.font = .caption
    dates.foregroundColor = .secondary
    return Text(lead + period + mid + dates)
}

/// Section title + optional caption for visualize charts (name avoids clash with Charts.ChartSection).
private struct VisualizeChartSection<Content: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }
}

private enum StrengthChartsTab: String, CaseIterable {
    case weekly = "Weekly volume"
    case topExercises = "Top exercises"
}

struct StrengthChartsView: View {
    let exercises: [ExerciseDTO]

    @State private var strengthChartsTab: StrengthChartsTab = .weekly
    @State private var topExercisesPeriod: BackupAnalyticsPeriod = .allData
    @State private var weeklyStrengthFillCalendarWeeks = false

    var body: some View {
        let snap = buildStrengthAnalytics(exercises: exercises)
        let sparseWeekly = Array(strengthVolumeKgByWeek(volumeByDay: snap.volumeByDay).suffix(20))
        let denseWeekly = strengthWeeklyVolumeDenseTrailingWeeks(volumeByDay: snap.volumeByDay, trailingWeekCount: 20)
        let weekBars: [(String, Double)] = {
            if weeklyStrengthFillCalendarWeeks, let d = denseWeekly { return d }
            return sparseWeekly
        }()
        let topChart = buildStrengthTopExercisesChartData(exercises: exercises, period: topExercisesPeriod)
        let topExercises = Array(topChart.volumeByExercise.prefix(8).reversed())
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Strength")
                    .font(.title2.weight(.semibold))

                Picker("Strength chart", selection: $strengthChartsTab) {
                    ForEach(StrengthChartsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch strengthChartsTab {
                    case .weekly:
                        if weekBars.isEmpty {
                            Text("No kg volume rows with timestamps.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            VisualizeChartSection(
                                title: "Weekly strength volume",
                                caption: weeklyStrengthFillCalendarWeeks
                                    ? "Exactly 20 consecutive UTC weeks (Monday 00:00), newest at the top of the chart. Weeks without lifting show a faint bar at zero kg."
                                    : "Last \(sparseWeekly.count) UTC weeks that have at least one logged set with known units. The horizontal chart lists weeks with the newest at the top; bar length is total kg that week. Weeks with no volume are omitted."
                            ) {
                                Toggle(isOn: $weeklyStrengthFillCalendarWeeks) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("20-week calendar view")
                                        Text("Include empty weeks (zero kg) so each column is one UTC week.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityHint("When on, shows twenty consecutive Monday weeks with zeros for gaps.")

                                if weeklyStrengthFillCalendarWeeks {
                                    strengthWeeklyDenseCalendarNotice(weekBars: weekBars)
                                } else {
                                    strengthWeeklyTimelineNotice(weekIsoKeys: sparseWeekly.map(\.0))
                                }

                                let strengthWeekRows: [(iso: String, monday: Date, kg: Double)] = weekBars.compactMap { pair in
                                    guard let d = utcMidnightDate(fromYMD: pair.0) else { return nil }
                                    return (pair.0, d, pair.1)
                                }
                                if strengthWeekRows.isEmpty {
                                    Text("Could not parse week keys for this chart.")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                } else {
                                    let sortedIsos = strengthWeekRows.map(\.iso).sorted()
                                    let quarterLabelKeys = isoKeysFirstLoggedWeekPerQuarter(sortedIsoKeysAscending: sortedIsos)
                                    let latestIso = sortedIsos.last!
                                    let peakKg = strengthWeekRows.map(\.kg).max() ?? 0
                                    let xMax = strengthVolumeChartXAxisMax(peakKg: peakKg)
                                    let rowH: CGFloat = 30
                                    let plotHeight = CGFloat(strengthWeekRows.count) * rowH + 56
                                    let scrollCap: CGFloat = 460
                                    let rowsForChart = strengthWeekRows.sorted { $0.iso < $1.iso }
                                    let isoWeekYearsInChart = Set(strengthWeekRows.map { isoYearAndWeekForMondayUtc($0.monday).year })
                                    let isoWeekYearsDescending = Array(isoWeekYearsInChart).sorted(by: >)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Horizontal layout: volume left → right, weeks bottom → top (newest at top).")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if isoWeekYearsDescending.count > 1 {
                                            Text("Bar color follows ISO week year (UTC).")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            HStack(alignment: .center, spacing: 14) {
                                                ForEach(isoWeekYearsDescending, id: \.self) { y in
                                                    HStack(spacing: 6) {
                                                        RoundedRectangle(cornerRadius: 2)
                                                            .fill(
                                                                strengthWeeklyBarColorForIsoWeekYear(
                                                                    isoWeekYear: y,
                                                                    yearsDescending: isoWeekYearsDescending,
                                                                    isZeroCalendarWeek: false
                                                                )
                                                            )
                                                            .frame(width: 14, height: 8)
                                                        Text(String(y))
                                                            .font(.caption2.weight(.medium))
                                                            .monospacedDigit()
                                                    }
                                                }
                                            }
                                        }
                                        ScrollView(.vertical, showsIndicators: true) {
                                            Chart(rowsForChart, id: \.iso) { row in
                                                let isoY = isoYearAndWeekForMondayUtc(row.monday).year
                                                let zeroCal = weeklyStrengthFillCalendarWeeks && row.kg == 0
                                                BarMark(
                                                    x: .value("Volume (kg)", row.kg),
                                                    y: .value("Week (UTC Mon)", row.iso)
                                                )
                                                .foregroundStyle(
                                                    strengthWeeklyBarColorForIsoWeekYear(
                                                        isoWeekYear: isoY,
                                                        yearsDescending: isoWeekYearsDescending,
                                                        isZeroCalendarWeek: zeroCal
                                                    )
                                                )
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: plotHeight)
                                            .chartXScale(domain: 0 ... xMax)
                                            .chartYScale(domain: sortedIsos)
                                            .chartXAxis {
                                                AxisMarks(preset: .extended, position: .bottom) { value in
                                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                                                    AxisValueLabel {
                                                        if let kg = value.as(Double.self) {
                                                            Text(kg, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                                                .font(.caption2)
                                                                .monospacedDigit()
                                                        }
                                                    }
                                                }
                                            }
                                            .chartYAxis {
                                                AxisMarks(position: .leading) { value in
                                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.35, dash: [2, 3]))
                                                    AxisValueLabel {
                                                        if let key = value.as(String.self),
                                                           let row = strengthWeekRows.first(where: { $0.iso == key }) {
                                                            let pair = strengthHorizontalWeekYAxisText(
                                                                isoKey: key,
                                                                monday: row.monday,
                                                                quarterLabelKeys: quarterLabelKeys,
                                                                latestIso: latestIso
                                                            )
                                                            Text(pair.text)
                                                                .font(.caption2.weight(pair.emphasize ? .semibold : .regular))
                                                                .monospacedDigit()
                                                                .lineLimit(1)
                                                                .minimumScaleFactor(0.85)
                                                        }
                                                    }
                                                }
                                            }
                                            .chartXAxisLabel(position: .bottom, alignment: .center) {
                                                Text("Volume (kg)")
                                                    .font(.caption.weight(.semibold))
                                            }
                                            .chartYAxisLabel(position: .leading, alignment: .center) {
                                                Text("Week (ISO, UTC Mon)")
                                                    .font(.caption.weight(.semibold))
                                            }
                                        }
                                        .frame(maxHeight: scrollCap)
                                        weekAxisTitleFootnote(
                                            title: "Year & week on the left",
                                            footnote: "ISO week-of-year (UTC). Full year + week at each calendar quarter’s first logged week (Jan / Apr / Jul / Oct). Other rows: Wnn. Latest row also marked."
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    case .topExercises:
                        if let df = topChart.datasetFirstMs, let dl = topChart.datasetLastMs {
                            strengthTopExercisesBlock(
                                datasetFirstMs: df,
                                datasetLastMs: dl,
                                topChart: topChart,
                                topExercises: topExercises
                            )
                        } else {
                            Text("No sets with kilogram volume in this backup for the top-exercises chart.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func strengthTopExercisesBlock(
        datasetFirstMs: Int64,
        datasetLastMs: Int64,
        topChart: StrengthTopExercisesChartResult,
        topExercises: [StrengthExerciseVolumeRow]
    ) -> some View {
        VisualizeChartSection(
            title: "Top exercises by cumulative volume",
            caption: "Each bar is one exercise name from your log. Volume = Σ (load × reps) per set, converted to kg when logged in lb. Up to eight exercises with the largest totals in the selected range."
        ) {
            Picker("Time range", selection: $topExercisesPeriod) {
                ForEach(BackupAnalyticsPeriod.allCases) { p in
                    Text(p.shortPickerLabel).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Time range for top exercises")

            strengthTopExercisesProvenance(
                datasetFirstMs: datasetFirstMs,
                datasetLastMs: datasetLastMs,
                topChart: topChart
            )

            if topExercises.isEmpty {
                Text("No sets with kilogram volume in this time range.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Chart(Array(topExercises.enumerated()), id: \.offset) { _, row in
                    BarMark(
                        x: .value("Volume (kg)", row.volumeKg),
                        y: .value("Exercise", row.exerciseName)
                    )
                    .foregroundStyle(.indigo)
                }
                .frame(height: min(420, CGFloat(56 + topExercises.count * 44)))
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let kg = value.as(Double.self) {
                                Text(kg, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                    .font(chartAxisFont)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let name = value.as(String.self) {
                                Text(name).font(.caption)
                            }
                        }
                    }
                }
                .chartXAxisLabel(alignment: .center) {
                    Text("Cumulative volume (kg)")
                        .font(.subheadline.weight(.medium))
                }
                .chartYAxisLabel(alignment: .leading) {
                    Text("Exercise")
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private func strengthTopExercisesProvenance(
        datasetFirstMs: Int64,
        datasetLastMs: Int64,
        topChart: StrengthTopExercisesChartResult
    ) -> some View {
        let ws = topChart.windowStartMs ?? datasetFirstMs
        let we = topChart.windowEndMs ?? datasetLastMs
        return VStack(alignment: .leading, spacing: 8) {
            captionProvenanceLeadingBold(
                "Backup span (sets with kg volume): ",
                secondaryTail: "\(formatUtcDateTime(epochMs: datasetFirstMs)) → \(formatUtcDateTime(epochMs: datasetLastMs)) UTC"
            )
            .fixedSize(horizontal: false, vertical: true)

            captionProvenanceChartFilterLine(periodLabel: topChart.period.fullLabel, windowStartMs: ws, windowEndMs: we)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                "\(topChart.setsInWindow) sets in window · \(topChart.exercisesInWindow) distinct exercise names · bars ranked high → low (top eight shown)."
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)

            if topChart.period != .allData {
                Text("Rolling and year-to-date ranges end at the latest logged set (UTC), not today’s calendar date.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Explains categorical spacing: only weeks with data appear; calendar gaps are not shown as empty space.
    @ViewBuilder
    private func strengthWeeklyTimelineNotice(weekIsoKeys: [String]) -> some View {
        let hasGap = strengthWeeklyChartHasCalendarGap(weekIsoKeys: weekIsoKeys)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hasGap ? "calendar.badge.exclamationmark" : "info.circle.fill")
                .font(.body)
                .foregroundStyle(hasGap ? Color.orange : Color.secondary)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 4) {
                Text("How to read the week axis")
                    .font(.subheadline.weight(.semibold))
                Text(
                    "Each row is a UTC Monday week with logged volume. Weeks with no data are omitted. The chart is horizontal (volume vs week); see the note under the chart for year and ISO week labels."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if hasGap {
                    Text("This dataset skips at least one calendar week between two shown weeks (large real-world gap).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.95))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(hasGap ? 0.12 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Shown when the 20-week dense UTC timeline is enabled.
    @ViewBuilder
    private func strengthWeeklyDenseCalendarNotice(weekBars: [(String, Double)]) -> some View {
        let zeroWeeks = weekBars.filter { $0.1 == 0 }.count
        let firstIso = weekBars.first?.0 ?? "—"
        let lastIso = weekBars.last?.0 ?? "—"
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar")
                .font(.body)
                .foregroundStyle(.teal)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 4) {
                Text("True calendar timeline")
                    .font(.subheadline.weight(.semibold))
                Group {
                    if zeroWeeks == 0 {
                        Text(
                            "Each bar is one UTC week (Monday start). The right edge is the week that contains your latest logged set with kg volume. All 20 weeks in this window include some volume."
                        )
                    } else {
                        Text(
                            "Each bar is one UTC week (Monday start). The right edge is the week that contains your latest logged set with kg volume. \(zeroWeeks) of 20 weeks have no volume and show as a faint bar at zero kg."
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("UTC range: \(firstIso) → \(lastIso)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// True if any two consecutive displayed weeks are more than 7 days apart (Monday-to-Monday is 7).
private func strengthWeeklyChartHasCalendarGap(weekIsoKeys: [String]) -> Bool {
    let mondays = weekIsoKeys.compactMap { mondayUtcStartOfDayFromIsoWeekStart($0) }
    guard mondays.count >= 2 else { return false }
    let weekSeconds: TimeInterval = 7 * 24 * 60 * 60
    for i in 1 ..< mondays.count {
        let delta = mondays[i].timeIntervalSince(mondays[i - 1])
        if delta > weekSeconds + 60 { return true }
    }
    return false
}

/// Parses `YYYY-MM-DD` week-start keys from analytics into UTC start-of-day for gap detection.
private func mondayUtcStartOfDayFromIsoWeekStart(_ dayKey: String) -> Date? {
    let parts = dayKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    var c = DateComponents()
    c.year = parts[0]
    c.month = parts[1]
    c.day = parts[2]
    c.hour = 0
    c.minute = 0
    c.second = 0
    return cal.date(from: c)
}

struct CardioChartsView: View {
    let cardio: [CardioDTO]

    @State private var cardioByTypePeriod: BackupAnalyticsPeriod = .allData

    var body: some View {
        let pts = cardioPlannedVsRecordedPoints(cardio: cardio)
        let typeChart = buildCardioMinutesByTypeChartData(cardio: cardio, period: cardioByTypePeriod)
        let barRows = Array(typeChart.rows.prefix(12).reversed())
        let hasRecordedCardio = cardio.contains { ($0.recordedDurationSeconds ?? 0) > 0 }
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Cardio")
                    .font(.title2.weight(.semibold))

                if pts.isEmpty {
                    Text("No rows with both planned and recorded duration.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    let hi = max(
                        pts.map { max(Double($0.plannedMinutes), Double($0.recordedMinutes)) }.max() ?? 1,
                        1
                    ) * 1.06
                    let axisX = "Planned (min)"
                    let axisY = "Recorded (min)"
                    VisualizeChartSection(
                        title: "Planned vs recorded duration",
                        caption: "Each point is one cardio entry in this backup with both planned and recorded duration. Axes use the same minute scale (0–\(String(format: "%.0f", hi)) min). Above the dashed line you went longer than planned; below is shorter."
                    ) {
                        cardioPlanRecordedLineLegend()

                        Chart {
                            LineMark(
                                x: .value(axisX, 0),
                                y: .value(axisY, 0)
                            )
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .lineStyle(StrokeStyle(lineWidth: 1.35, dash: [7, 5]))
                            LineMark(
                                x: .value(axisX, hi),
                                y: .value(axisY, hi)
                            )
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .lineStyle(StrokeStyle(lineWidth: 1.35, dash: [7, 5]))

                            ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                                PointMark(
                                    x: .value(axisX, Double(p.plannedMinutes)),
                                    y: .value(axisY, Double(p.recordedMinutes))
                                )
                                .symbolSize(88)
                                .foregroundStyle(by: .value("Exercise type", p.seriesKey))
                            }
                        }
                        .chartXScale(domain: 0...hi)
                        .chartYScale(domain: 0...hi)
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(v, format: .number.precision(.fractionLength(0)))
                                            .font(chartAxisFont)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(v, format: .number.precision(.fractionLength(0)))
                                            .font(chartAxisFont)
                                    }
                                }
                            }
                        }
                        .chartXAxisLabel(alignment: .center) {
                            Text(axisX)
                                .font(.subheadline.weight(.medium))
                        }
                        .chartYAxisLabel(alignment: .leading) {
                            Text(axisY)
                                .font(.subheadline.weight(.medium))
                        }
                        .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
                        .frame(height: 400)
                    }
                }

                if hasRecordedCardio {
                    VisualizeChartSection(
                        title: "Recorded time by exercise type",
                        caption: "Sum of recorded session duration, grouped by exercise type. Use the range control to match the strength chart (rolling windows end at your latest dated cardio row, UTC)."
                    ) {
                        Picker("Time range", selection: $cardioByTypePeriod) {
                            ForEach(BackupAnalyticsPeriod.allCases) { p in
                                Text(p.shortPickerLabel).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Time range for recorded minutes by type")

                        cardioByTypeProvenance(result: typeChart)

                        if barRows.isEmpty {
                            Text("No recorded cardio minutes fall in this time range.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(Array(barRows.enumerated()), id: \.offset) { _, row in
                                BarMark(
                                    x: .value("Minutes", row.minutes),
                                    y: .value("Type", row.exerciseType)
                                )
                                .foregroundStyle(Color.indigo.opacity(0.88))
                            }
                            .frame(height: min(440, CGFloat(52 + barRows.count * 42)))
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let m = value.as(Double.self) {
                                            Text(m, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                                .font(chartAxisFont)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let name = value.as(String.self) {
                                            Text(name).font(.caption)
                                        }
                                    }
                                }
                            }
                            .chartXAxisLabel(alignment: .center) {
                                Text("Recorded minutes (total)")
                                    .font(.subheadline.weight(.medium))
                            }
                            .chartYAxisLabel(alignment: .leading) {
                                Text("Exercise type")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func cardioByTypeProvenance(result: CardioMinutesByTypeChartResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let f = result.timedDatasetFirstMs, let l = result.timedDatasetLastMs {
                captionProvenanceLeadingBold(
                    "Dated cardio rows: ",
                    secondaryTail: "\(formatUtcDateTime(epochMs: f)) → \(formatUtcDateTime(epochMs: l)) UTC"
                )
                .fixedSize(horizontal: false, vertical: true)
            } else if result.period == .allData {
                Text("No timestamps on cardio rows; totals include all sessions with recorded duration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let ws = result.windowStartMs, let we = result.windowEndMs, result.timedDatasetFirstMs != nil {
                captionProvenanceChartFilterLine(periodLabel: result.period.fullLabel, windowStartMs: ws, windowEndMs: we)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                "\(result.sessionsInWindow) session(s) in range · \(result.typesInWindow) type(s) · chart shows up to 12 types by minutes."
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)

            if result.period == .allData, result.durationRowsWithoutTimestamp > 0 {
                Text(
                    "\(result.durationRowsWithoutTimestamp) session(s) have no originalTimestamp or exerciseDate; they are counted in All only and excluded from 7 / 30 / YTD filters."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if result.period != .allData {
                Text("Rolling and year-to-date ranges use the latest dated cardio row (UTC), not today’s date.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func cardioPlanRecordedLineLegend() -> some View {
        HStack(alignment: .center, spacing: 10) {
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height * 0.5))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                context.stroke(
                    path,
                    with: .color(.secondary.opacity(0.75)),
                    style: StrokeStyle(lineWidth: 1.35, dash: [5, 4])
                )
            }
            .frame(width: 32, height: 14)
            Text("Dashed line: planned minutes = recorded minutes (perfect match).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct StretchChartsView: View {
    let sessions: [StretchSessionDTO]

    @State private var stretchByTypePeriod: BackupAnalyticsPeriod = .allData

    var body: some View {
        let typeChart = buildStretchMinutesByTypeChartData(sessions: sessions, period: stretchByTypePeriod)
        let barRows = Array(typeChart.rows.prefix(12).reversed())
        let hasRecordedStretch = sessions.contains { ($0.recordedDurationSeconds ?? 0) > 0 }
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Stretch")
                    .font(.title2.weight(.semibold))

                if !hasRecordedStretch {
                    Text("No stretch sessions with recorded duration in this backup.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    VisualizeChartSection(
                        title: "Recorded stretch time by type",
                        caption: "Total recorded minutes summed by stretch type (same grouping as the Stretch tables). Types like “Head” or “Neck” are merged into Head Stretches for totals. Time filters use sessionDate when present, then originalTimestamp (same as weekly stretch charts). Rolling ranges end at your latest dated row (UTC)."
                    ) {
                        Picker("Time range", selection: $stretchByTypePeriod) {
                            ForEach(BackupAnalyticsPeriod.allCases) { p in
                                Text(p.shortPickerLabel).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Time range for stretch minutes by type")

                        stretchByTypeProvenance(result: typeChart)

                        if barRows.isEmpty {
                            Text("No stretch minutes fall in this time range.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(Array(barRows.enumerated()), id: \.offset) { _, row in
                                BarMark(
                                    x: .value("Recorded minutes", row.minutes),
                                    y: .value("Stretch type", row.label)
                                )
                                .foregroundStyle(Color.purple.opacity(0.88))
                            }
                            .frame(height: min(440, CGFloat(52 + barRows.count * 42)))
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let m = value.as(Double.self) {
                                            Text(m, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                                .font(chartAxisFont)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let name = value.as(String.self) {
                                            Text(name).font(.caption)
                                        }
                                    }
                                }
                            }
                            .chartXAxisLabel(alignment: .center) {
                                Text("Recorded minutes (total)")
                                    .font(.subheadline.weight(.medium))
                            }
                            .chartYAxisLabel(alignment: .leading) {
                                Text("Stretch type")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func stretchByTypeProvenance(result: StretchMinutesByTypeChartResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let f = result.timedDatasetFirstMs, let l = result.timedDatasetLastMs {
                captionProvenanceLeadingBold(
                    "Dated stretch rows: ",
                    secondaryTail: "\(formatUtcDateTime(epochMs: f)) → \(formatUtcDateTime(epochMs: l)) UTC"
                )
                .fixedSize(horizontal: false, vertical: true)
            } else if result.period == .allData {
                Text("No timestamps on stretch rows; totals include all sessions with recorded duration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let ws = result.windowStartMs, let we = result.windowEndMs, result.timedDatasetFirstMs != nil {
                captionProvenanceChartFilterLine(periodLabel: result.period.fullLabel, windowStartMs: ws, windowEndMs: we)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                "\(result.sessionsInWindow) session(s) in range · \(result.typesInWindow) stretch type(s) · chart shows up to 12 types by minutes."
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)

            if result.period == .allData, result.sessionsWithoutTimestamp > 0 {
                Text(
                    "\(result.sessionsWithoutTimestamp) session(s) have no sessionDate or originalTimestamp; they are counted in All only and excluded from 7 / 30 / YTD filters."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if result.period != .allData {
                Text("Rolling and year-to-date ranges use the latest dated stretch row (UTC), not today’s date.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Timeline chart only — temperature buckets (must stay in sync with `coldTempStyleBucket`).
/// Coolest = deepest blue; warmer buckets move lighter then toward yellow.
private let coldTempBucketDomain: [String] = ["≤9 °C", "9–11 °C", "11–13 °C", ">13 °C"]
private let coldTempBucketColors: [Color] = [
    Color(red: 0.02, green: 0.14, blue: 0.48),
    Color(red: 0.10, green: 0.38, blue: 0.92),
    Color(red: 0.42, green: 0.70, blue: 0.96),
    Color(red: 0.93, green: 0.80, blue: 0.18),
]

/// Scatter chart: single fill distinct from the timeline’s blue→yellow scale.
private let coldScatterPointColor = Color(red: 0.11, green: 0.42, blue: 0.22)

struct ColdChartsView: View {
    let sessions: [ColdBathSessionDTO]

    var body: some View {
        let pts = coldTempVsDurationPoints(sessions: sessions)
        let timeline = pts
            .compactMap { p -> (ColdTempDurationPoint, Int64)? in
                guard let ms = p.epochMs else { return nil }
                return (p, ms)
            }
            .sorted { $0.1 < $1.1 }
        let untimedCount = pts.filter { $0.epochMs == nil }.count

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Cold bath")
                    .font(.title2.weight(.semibold))

                if pts.isEmpty {
                    Text("No sessions with parsed water temperature and recorded duration.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    if timeline.isEmpty {
                        Text("Timeline needs sessionDate or originalTimestamp on each row. These sessions still appear in the scatter chart below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VisualizeChartSection(
                            title: "Cold sessions over time",
                            caption: "Horizontal axis is when the session was logged (UTC): sessionDate when present, otherwise originalTimestamp. Vertical axis is recorded duration. Point color shows water temperature bucket: ≤9, 9–11, 11–13, or >13 °C (cooler = deeper blue, warmer → yellow)."
                        ) {
                            Chart(Array(timeline.enumerated()), id: \.offset) { _, pair in
                                let p = pair.0
                                let ms = pair.1
                                let when = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
                                PointMark(
                                    x: .value("Session (UTC)", when, unit: .hour, calendar: ChartsUtcCalendar.utc),
                                    y: .value("Minutes", Double(p.durationMinutes))
                                )
                                .symbolSize(78)
                                .foregroundStyle(by: .value("Water (bucket)", coldTempStyleBucket(p.tempCelsius)))
                            }
                            .chartForegroundStyleScale(domain: coldTempBucketDomain, range: coldTempBucketColors)
                            .frame(height: 300)
                            .chartXAxis {
                                AxisMarks(preset: .aligned, values: .automatic(desiredCount: 5)) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let d = value.as(Date.self) {
                                            Text(d, format: .dateTime.month(.abbreviated).day().hour(.twoDigits(amPM: .abbreviated)))
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let m = value.as(Double.self) {
                                            Text(m, format: .number.precision(.fractionLength(0)))
                                                .font(chartAxisFont)
                                        }
                                    }
                                }
                            }
                            .chartXAxisLabel(alignment: .center) {
                                Text("Session time (UTC)")
                                    .font(.subheadline.weight(.medium))
                            }
                            .chartYAxisLabel(alignment: .leading) {
                                Text("Recorded minutes")
                                    .font(.subheadline.weight(.medium))
                            }
                            .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
                        }
                    }

                    VisualizeChartSection(
                        title: "Water temperature vs duration",
                        caption: "Each point is one session with a parsed °C value and recorded time in the water. This view ignores calendar order (see timeline above). Points use a single forest green; use Cold tables for location breakdown."
                    ) {
                        coldScatterChart(pts: pts)
                    }

                    coldBathFootnote(total: pts.count, timed: timeline.count, untimed: untimedCount)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func coldScatterChart(pts: [ColdTempDurationPoint]) -> some View {
        Chart(pts.indices, id: \.self) { i in
            let p = pts[i]
            PointMark(
                x: .value("Water temp (°C)", Double(p.tempCelsius)),
                y: .value("Minutes", Double(p.durationMinutes))
            )
            .symbolSize(78)
            .foregroundStyle(coldScatterPointColor)
        }
        .frame(height: 320)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let t = value.as(Double.self) {
                        Text(t, format: .number.precision(.fractionLength(0)))
                            .font(chartAxisFont)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let m = value.as(Double.self) {
                        Text(m, format: .number.precision(.fractionLength(0)))
                            .font(chartAxisFont)
                    }
                }
            }
        }
        .chartXAxisLabel(alignment: .center) {
            Text("Water temperature (°C)")
                .font(.subheadline.weight(.medium))
        }
        .chartYAxisLabel(alignment: .leading) {
            Text("Recorded minutes")
                .font(.subheadline.weight(.medium))
        }
        .chartLegend(.hidden)
    }

    private func coldBathFootnote(total: Int, timed: Int, untimed: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(total) session(s) with temperature and duration in these charts.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if untimed > 0 {
                Text("\(untimed) of those lack sessionDate and originalTimestamp, so they are omitted from the timeline only.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum HeatmapActivityHighlight: String, CaseIterable, Identifiable {
    case allActivities
    case strength
    case cardio
    case stretch
    case coldBath

    var id: String { rawValue }

    var chipTitle: String {
        switch self {
        case .allActivities: "All activities"
        case .strength: "Strength"
        case .cardio: "Cardio"
        case .stretch: "Stretch"
        case .coldBath: "Cold bath"
        }
    }

    /// Active cell color when “Color by activity type” is on.
    var highlightColor: Color {
        switch self {
        case .allActivities:
            Color(red: 0.28, green: 0.38, blue: 0.62)
        case .strength:
            Color(red: 0.95, green: 0.82, blue: 0.15)
        case .cardio:
            Color(red: 0.18, green: 0.62, blue: 0.38)
        case .stretch:
            Color.purple.opacity(0.88)
        case .coldBath:
            Color(red: 0.88, green: 0.22, blue: 0.28)
        }
    }

    func highlightedDays(_ export: FreeStandExport) -> Set<String> {
        switch self {
        case .allActivities: collectActiveDaysUtc(export)
        case .strength: collectStrengthActiveDaysUtc(export)
        case .cardio: collectCardioActiveDaysUtc(export)
        case .stretch: collectStretchActiveDaysUtc(export)
        case .coldBath: collectColdActiveDaysUtc(export)
        }
    }
}

struct ActivityOverviewChartsView: View {
    let export: FreeStandExport

    @State private var heatmapYears: Set<Int> = []
    @State private var heatmapActivityFilterOn = false
    @State private var heatmapActivityKind: HeatmapActivityHighlight = .allActivities

    var body: some View {
        let unionDays = collectActiveDaysUtc(export)
        let highlightedDays = heatmapActivityFilterOn
            ? heatmapActivityKind.highlightedDays(export)
            : unionDays
        let fullHeatmap = buildActiveDaysHeatmap(unionSpan: unionDays, highlightedDays: highlightedDays)
        let heatmapFillColor = heatmapActivityFilterOn ? heatmapActivityKind.highlightColor : Color.teal
        let years = fullHeatmap.map { distinctYearsInHeatmap($0) } ?? []
        let heatmap = filteredHeatmap(full: fullHeatmap, years: years)

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Activity overview")
                    .font(.title2.weight(.semibold))

                if let hm = heatmap, !hm.columns.isEmpty {
                    Text("UTC \(hm.rangeStartIso) → \(hm.rangeEndIso)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    yearChips(years: years)
                    Toggle(isOn: $heatmapActivityFilterOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Color by activity type")
                            Text("Keep the same calendar grid; choose which logs fill the squares.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHint("When on, pick a modality color or all activities.")
                    if heatmapActivityFilterOn {
                        Text("Highlight")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(HeatmapActivityHighlight.allCases) { kind in
                                    let on = heatmapActivityKind == kind
                                    Button {
                                        heatmapActivityKind = kind
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(kind.highlightColor)
                                                .frame(width: 9, height: 9)
                                            Text(kind.chipTitle)
                                                .font(.subheadline.weight(on ? .semibold : .regular))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(on ? Color.secondary.opacity(0.22) : Color.secondary.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Text("Days without the selected activity stay light grey. “All activities” uses its own color for any logged day (same days as the default view).")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ActiveDaysHeatmapGrid(heatmap: hm, activeFillColor: heatmapFillColor)
                } else {
                    Text("No active-day data for heatmap.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                let snap = buildActivityOverviewAnalytics(export)
                let str = buildStrengthSetsPerWeek(exercises: export.exercises)

                chartCard("Strength sets / week") {
                    WeeklyBarChart(points: str, color: .teal)
                }
                chartCard("Cardio minutes / week") {
                    WeeklyBarChart(points: buildCardioMinutesPerWeek(cardio: export.cardio), color: .indigo)
                }
                chartCard("Stretch minutes / week") {
                    WeeklyBarChart(points: buildStretchMinutesPerWeek(sessions: export.stretchSessions), color: .purple)
                }
                chartCard("Cold minutes / week") {
                    WeeklyBarChart(points: buildColdMinutesPerWeek(sessions: export.coldBathSessions), color: .red)
                }

                let strengthSnap = buildStrengthAnalytics(exercises: export.exercises)
                let dual = weeklyStrengthKgAndCardio(volumeByDay: strengthSnap.volumeByDay, weeklyVolume: snap.weeklyVolume)
                    .filter { $0.strengthKg > 0 || $0.cardioMinutes > 0 }
                if dual.count >= 2 {
                    chartCard("Strength (kg) vs cardio (min)") {
                        StrengthCardioDualLineCharts(points: dual)
                    }
                }

                let cons = recentWeeksConsistency(weeklyActiveDays: snap.weeklyActiveDays, window: 12)
                Text("Recent consistency: \(cons.0) of last \(cons.1) UTC weeks with ≥1 active day")
                    .font(.body)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.3))
                        Capsule()
                            .fill(Color.teal)
                            .frame(width: g.size.width * CGFloat(cons.0) / CGFloat(max(cons.1, 1)))
                    }
                }
                .frame(height: 24)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 28)
        }
        .onAppear {
            if heatmapYears.isEmpty, let y = years.first {
                heatmapYears = [y]
            }
        }
    }

    private func filteredHeatmap(full: ActiveDaysHeatmap?, years: [Int]) -> ActiveDaysHeatmap? {
        guard let full else { return nil }
        let selected = heatmapYears.isEmpty ? Set(years.prefix(1)) : heatmapYears
        return filterHeatmapByYears(full, selectedYears: selected)
    }

    @ViewBuilder
    private func yearChips(years: [Int]) -> some View {
        if years.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(years, id: \.self) { y in
                        let on = heatmapYears.contains(y)
                        Button {
                            if on {
                                if heatmapYears.count > 1 { heatmapYears.remove(y) }
                            } else {
                                heatmapYears.insert(y)
                            }
                        } label: {
                            Text(String(y))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(on ? Color.teal.opacity(0.25) : Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button("All") { heatmapYears = Set(years) }
                        .font(.subheadline)
                }
            }
        }
    }

    private func chartCard(_ title: String, @ViewBuilder chart: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            chart()
        }
    }
}

/// Strength (kg) and cardio (minutes) on **separate** Y scales; shared UTC week date X with sparse tick labels (avoids one axis mixing kg and minutes).
private struct StrengthCardioDualLineCharts: View {
    let points: [WeekStrengthCardioPoint]

    private var dated: [(iso: String, weekStart: Date, strengthKg: Double, cardioMinutes: Double)] {
        points.compactMap { p in
            guard let d = utcMidnightDate(fromYMD: p.weekStartIso) else { return nil }
            return (p.weekStartIso, d, p.strengthKg, p.cardioMinutes)
        }
    }

    private var dateDomain: ClosedRange<Date>? {
        let ds = dated.map(\.weekStart)
        guard let lo = ds.min(), let hi = ds.max() else { return nil }
        return lo ... hi
    }

    private var xAxisRange: (Date, Date)? {
        let ds = dated.map(\.weekStart)
        guard let lo = ds.min(), let hi = ds.max() else { return nil }
        return (lo, hi)
    }

    var body: some View {
        if dated.isEmpty {
            Text("Could not parse week keys for this chart.")
                .font(.body)
                .foregroundStyle(.secondary)
        } else if let domain = dateDomain {
            VStack(alignment: .leading, spacing: 10) {
                Text("Two separate vertical scales: kg (top) and minutes (bottom). Week start is UTC (Monday 00:00).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Strength (kg)")
                    .font(.caption.weight(.semibold))
                Chart(dated, id: \.iso) { row in
                    LineMark(
                        x: .value("Week start (UTC)", row.weekStart, unit: .weekOfYear, calendar: ChartsUtcCalendar.mondayWeek),
                        y: .value("Strength (kg)", row.strengthKg)
                    )
                    .foregroundStyle(.teal)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: WeekChartLayout.lineChartHeight)
                .chartXScale(domain: domain)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                Text("Cardio (minutes)")
                    .font(.caption.weight(.semibold))
                Chart(dated, id: \.iso) { row in
                    LineMark(
                        x: .value("Week start (UTC)", row.weekStart, unit: .weekOfYear, calendar: ChartsUtcCalendar.mondayWeek),
                        y: .value("Cardio (min)", row.cardioMinutes)
                    )
                    .foregroundStyle(.indigo)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: WeekChartLayout.lineChartWithXAxisHeight)
                .chartXScale(domain: domain)
                .chartXAxis {
                    AxisMarks(
                        preset: .aligned,
                        values: .automatic(desiredCount: WeekChartLayout.xAxisDesiredTickCount)
                    ) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let r = xAxisRange {
                                weekAxisRotatedTick(value, rangeStart: r.0, rangeEnd: r.1)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxisLabel(alignment: .center) {
                    weekAxisTitleFootnote(
                        title: "Week of (UTC)",
                        footnote: "Ticks = Mondays, month/day (UTC). Year shown only if the range crosses years."
                    )
                }
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.teal).frame(width: 8, height: 8)
                        Text("Strength (kg)")
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.indigo).frame(width: 8, height: 8)
                        Text("Cardio (minutes)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        } else {
            Text("Could not parse week keys for this chart.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WeeklyBarChart: View {
    let points: [WeeklySeriesPoint]
    let color: Color
    var dimZeroBars: Bool = false
    /// Sparse x-axis: first bar in each two-calendar-month span (UTC), plus last bar — shows rotated `Wnn`.
    var bimonthIsoWeekTicks: Bool = true
    /// When several ISO week years appear, bar (and tick) colors distinguish years; newest year uses `color`.
    var colorBarsByIsoWeekYear: Bool = true

    /// Rows with valid UTC week-start dates (stable chart identity via ISO key).
    private var datedPoints: [(iso: String, weekStart: Date, value: Float)] {
        points.compactMap { p in
            guard let d = utcMidnightDate(fromYMD: p.weekStartIso) else { return nil }
            return (p.weekStartIso, d, p.value)
        }
    }

    var body: some View {
        if points.isEmpty {
            Text("No weeks with data.")
                .font(.body)
                .foregroundStyle(.secondary)
        } else if datedPoints.isEmpty {
            Text("Could not parse week keys for the chart.")
                .font(.body)
                .foregroundStyle(.secondary)
        } else {
            let rangeLo = datedPoints.first!.weekStart
            let rangeHi = datedPoints.last!.weekStart
            let chartW = max(300, CGFloat(datedPoints.count) * WeekChartLayout.minWidthPerWeekBar)
            let tickWeekStarts = weeklyBarChartBimonthTickWeekStarts(datedPoints: datedPoints)
            let isoYearSet = Set(datedPoints.map { isoYearAndWeekForMondayUtc($0.weekStart).year })
            let isoYearsDesc = Array(isoYearSet).sorted(by: >)
            let axisFootnote = bimonthIsoWeekTicks
                ? "Each bar = UTC week (Monday). X-axis shows Wnn about every two calendar months (rotated). When multiple ISO week years appear, bar colors distinguish years (newest uses this chart’s main color). Swipe sideways if many weeks."
                : "Each bar = week starting that Monday. Labels month/day (UTC). Swipe sideways if many weeks."
            VStack(alignment: .center, spacing: 8) {
                if colorBarsByIsoWeekYear && isoYearsDesc.count > 1 {
                    HStack(alignment: .center, spacing: 12) {
                        ForEach(isoYearsDesc, id: \.self) { y in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        activityWeeklyBarFill(
                                            isoWeekYear: y,
                                            yearsDescending: isoYearsDesc,
                                            baseColor: color,
                                            colorIsoYears: true,
                                            isDimZero: false
                                        )
                                    )
                                    .frame(width: 14, height: 8)
                                Text(String(y))
                                    .font(.caption2.weight(.medium))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                ScrollView(.horizontal, showsIndicators: true) {
                    Group {
                        if bimonthIsoWeekTicks, !tickWeekStarts.isEmpty {
                            Chart(datedPoints, id: \.iso) { row in
                                let isoY = isoYearAndWeekForMondayUtc(row.weekStart).year
                                let dim = dimZeroBars && row.value == 0
                                BarMark(
                                    x: .value("Week start (UTC)", row.weekStart, unit: .weekOfYear, calendar: ChartsUtcCalendar.mondayWeek),
                                    y: .value("V", row.value)
                                )
                                .foregroundStyle(
                                    activityWeeklyBarFill(
                                        isoWeekYear: isoY,
                                        yearsDescending: isoYearsDesc,
                                        baseColor: color,
                                        colorIsoYears: colorBarsByIsoWeekYear,
                                        isDimZero: dim
                                    )
                                )
                            }
                            .frame(width: chartW, height: WeekChartLayout.plotHeightBarChart)
                            .chartXAxis {
                                AxisMarks(values: tickWeekStarts) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        weekAxisRotatedIsoWeekNumberTick(
                                            value,
                                            isoWeekYearsDescending: isoYearsDesc,
                                            baseColor: color,
                                            colorIsoYears: colorBarsByIsoWeekYear
                                        )
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let v = value.as(Double.self) {
                                            Text(v, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                                .font(chartAxisFont)
                                        }
                                    }
                                }
                            }
                        } else {
                            Chart(datedPoints, id: \.iso) { row in
                                let isoY = isoYearAndWeekForMondayUtc(row.weekStart).year
                                let dim = dimZeroBars && row.value == 0
                                BarMark(
                                    x: .value("Week start (UTC)", row.weekStart, unit: .weekOfYear, calendar: ChartsUtcCalendar.mondayWeek),
                                    y: .value("V", row.value)
                                )
                                .foregroundStyle(
                                    activityWeeklyBarFill(
                                        isoWeekYear: isoY,
                                        yearsDescending: isoYearsDesc,
                                        baseColor: color,
                                        colorIsoYears: colorBarsByIsoWeekYear,
                                        isDimZero: dim
                                    )
                                )
                            }
                            .frame(width: chartW, height: WeekChartLayout.plotHeightBarChart)
                            .chartXAxis {
                                AxisMarks(
                                    preset: .aligned,
                                    values: .automatic(desiredCount: WeekChartLayout.xAxisDesiredTickCount)
                                ) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        weekAxisRotatedTick(value, rangeStart: rangeLo, rangeEnd: rangeHi)
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let v = value.as(Double.self) {
                                            Text(v, format: .number.grouping(.automatic).precision(.fractionLength(0)))
                                                .font(chartAxisFont)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: WeekChartLayout.scrollFrameHeightBarChart)
                weekAxisTitleFootnote(title: "Week of (UTC)", footnote: axisFootnote)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ActiveDaysHeatmapGrid: View {
    let heatmap: ActiveDaysHeatmap
    var activeFillColor: Color = .teal

    private var isoWeekYearsDescending: [Int] {
        let ys = heatmap.weekStartMondays.compactMap { mon -> Int? in
            guard let d = utcMidnightDate(fromYMD: mon) else { return nil }
            return isoYearAndWeekForMondayUtc(d).year
        }
        return Array(Set(ys)).sorted(by: >)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(Array(heatmap.columns.enumerated()), id: \.offset) { colIdx, col in
                        heatmapColumn(colIdx: colIdx, col: col)
                    }
                }
                .padding(.vertical, 6)
            }
            Text(
                "Week numbers appear about every two calendar months (UTC), rotated. Label color follows ISO week year when multiple years appear."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shouldShowBimonthWeekLabel(colIdx: Int) -> Bool {
        guard colIdx < heatmap.weekStartMondays.count else { return false }
        let mon = heatmap.weekStartMondays[colIdx]
        guard let (y, m) = utcGregorianYearMonth(mondayIso: mon) else { return colIdx == 0 }
        let b = utcBimonthIndex(year: y, month: m)
        if colIdx == 0 { return true }
        let prev = heatmap.weekStartMondays[colIdx - 1]
        guard let (py, pm) = utcGregorianYearMonth(mondayIso: prev) else { return true }
        return b != utcBimonthIndex(year: py, month: pm)
    }

    @ViewBuilder
    private func heatmapColumn(colIdx: Int, col: [Bool]) -> some View {
        let mon = heatmap.weekStartMondays[colIdx]
        let showTick = shouldShowBimonthWeekLabel(colIdx: colIdx)
        let weekNum: Int = {
            guard let d = utcMidnightDate(fromYMD: mon) else { return 0 }
            return isoYearAndWeekForMondayUtc(d).week
        }()
        let labelColor: Color = {
            guard let d = utcMidnightDate(fromYMD: mon) else { return .secondary }
            if isoWeekYearsDescending.count <= 1 {
                return Color.secondary
            }
            let y = isoYearAndWeekForMondayUtc(d).year
            return strengthWeeklyBarColorForIsoWeekYear(
                isoWeekYear: y,
                yearsDescending: isoWeekYearsDescending,
                isZeroCalendarWeek: false
            )
        }()

        VStack(spacing: 3) {
            ZStack {
                Color.clear
                if showTick, weekNum > 0 {
                    Text("W\(weekNum)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                        .fixedSize()
                        .rotationEffect(.degrees(WeekChartLayout.xTickRotationDegrees), anchor: .center)
                }
            }
            .frame(width: 18, height: 48)
            ForEach(Array(col.enumerated()), id: \.offset) { _, on in
                RoundedRectangle(cornerRadius: 3)
                    .fill(on ? activeFillColor : Color.secondary.opacity(0.2))
                    .frame(width: 18, height: 18)
            }
        }
    }
}
