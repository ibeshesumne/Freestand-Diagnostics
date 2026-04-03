//
//  ChartData.swift
//

import Foundation

// MARK: - Shared backup time ranges (strength “top exercises”, cardio by type, …)

enum BackupAnalyticsPeriod: String, CaseIterable, Identifiable, Sendable {
    /// Rolling 7 days ending at the latest dated event in the dataset (UTC).
    case pastWeek
    /// Rolling 30 days ending at that same anchor.
    case pastMonth
    /// 1 Jan UTC through the anchor, intersected with data.
    case yearToDate
    /// Full backup (cardio: includes rows even if they lack a timestamp).
    case allData

    var id: String { rawValue }

    var shortPickerLabel: String {
        switch self {
        case .pastWeek: "7 days"
        case .pastMonth: "30 days"
        case .yearToDate: "YTD"
        case .allData: "All"
        }
    }

    var fullLabel: String {
        switch self {
        case .pastWeek: "Past 7 days"
        case .pastMonth: "Past 30 days"
        case .yearToDate: "Year to date (UTC)"
        case .allData: "All data in backup"
        }
    }
}

nonisolated let backupAnalyticsMsPerDay: Int64 = 24 * 60 * 60 * 1000

struct ActiveDaysHeatmap: Sendable {
    let columns: [[Bool]]
    let weekStartMondays: [String]
    let rangeStartIso: String
    let rangeEndIso: String
}

func buildActiveDaysHeatmap(activeDays: Set<String>) -> ActiveDaysHeatmap? {
    buildActiveDaysHeatmap(unionSpan: activeDays, highlightedDays: activeDays)
}

/// `unionSpan` sets the calendar range (typically all modalities). `highlightedDays` decides which day cells are filled (a subset when filtering by modality).
func buildActiveDaysHeatmap(unionSpan unionDays: Set<String>, highlightedDays: Set<String>) -> ActiveDaysHeatmap? {
    if unionDays.isEmpty { return nil }
    let sorted = unionDays.sorted()
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let fmt = DateFormatter()
    fmt.calendar = cal
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"

    guard let firstDate = fmt.date(from: sorted.first!) else { return nil }
    var c = cal.dateComponents([.year, .month, .day], from: firstDate)
    c.hour = 0
    c.minute = 0
    c.second = 0
    guard let startOfFirst = cal.date(from: c) else { return nil }
    let dow = cal.component(.weekday, from: startOfFirst)
    let back = (dow + 5) % 7
    guard let startMs = cal.date(byAdding: .day, value: -back, to: startOfFirst) else { return nil }

    guard let lastDate = fmt.date(from: sorted.last!) else { return nil }
    var cur = lastDate
    while cal.component(.weekday, from: cur) != 1 {
        guard let n = cal.date(byAdding: .day, value: 1, to: cur) else { break }
        cur = n
    }
    let endMs = cur

    var dayKeys: [String] = []
    var flags: [Bool] = []
    var walk = startMs
    while walk <= endMs {
        dayKeys.append(dayKeyUtc(epochMs: Int64(walk.timeIntervalSince1970 * 1000)))
        flags.append(highlightedDays.contains(dayKeys.last!))
        guard let next = cal.date(byAdding: .day, value: 1, to: walk) else { break }
        walk = next
    }
    let columns = stride(from: 0, to: flags.count, by: 7).map { i in
        Array(flags[i..<min(i + 7, flags.count)])
    }
    let weekStartMondays = columns.indices.map { i in dayKeys[i * 7] }
    return ActiveDaysHeatmap(
        columns: columns,
        weekStartMondays: weekStartMondays,
        rangeStartIso: dayKeys.first ?? "",
        rangeEndIso: dayKeys.last ?? ""
    )
}

func distinctYearsInHeatmap(_ heatmap: ActiveDaysHeatmap) -> [Int] {
    heatmap.weekStartMondays
        .map { heatmapColumnYear(mondayIso: $0) }
        .filter { $0 > 0 }
        .uniqued()
        .sorted(by: >)
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

func filterHeatmapByYears(_ heatmap: ActiveDaysHeatmap, selectedYears: Set<Int>) -> ActiveDaysHeatmap? {
    if selectedYears.isEmpty { return nil }
    let idx = heatmap.weekStartMondays.indices.filter {
        selectedYears.contains(heatmapColumnYear(mondayIso: heatmap.weekStartMondays[$0]))
    }
    if idx.isEmpty {
        return ActiveDaysHeatmap(
            columns: [],
            weekStartMondays: [],
            rangeStartIso: heatmap.rangeStartIso,
            rangeEndIso: heatmap.rangeEndIso
        )
    }
    let cols = idx.map { heatmap.columns[$0] }
    let starts = idx.map { heatmap.weekStartMondays[$0] }
    return ActiveDaysHeatmap(
        columns: cols,
        weekStartMondays: starts,
        rangeStartIso: starts.first!,
        rangeEndIso: weekSundayUtc(mondayIso: starts.last!)
    )
}

struct CardioPlanPoint: Sendable {
    let plannedMinutes: Float
    let recordedMinutes: Float
    /// Groups points in the legend (prefer exercise type, else activity name).
    let seriesKey: String
}

func cardioPlannedVsRecordedPoints(cardio: [CardioDTO]) -> [CardioPlanPoint] {
    var out: [CardioPlanPoint] = []
    for c in cardio {
        guard let p = c.plannedDurationSeconds, p > 0 else { continue }
        guard let r = c.recordedDurationSeconds, r > 0 else { continue }
        let typePart = c.exerciseType?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let namePart = c.exercisename?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let seriesKey = typePart ?? namePart ?? "—"
        out.append(CardioPlanPoint(
            plannedMinutes: Float(p) / 60,
            recordedMinutes: Float(r) / 60,
            seriesKey: seriesKey
        ))
    }
    return out
}

struct StretchTypeMinutesRow: Sendable {
    let label: String
    let minutes: Double
}

func stretchMinutesByType(sessions: [StretchSessionDTO]) -> [StretchTypeMinutesRow] {
    var map: [String: Double] = [:]
    for s in sessions {
        let sec = s.recordedDurationSeconds ?? 0
        if sec <= 0 { continue }
        let label = stretchAnalyticsTypeLabel(s.stretchType)
        map[label, default: 0] += Double(sec) / 60.0
    }
    return map.map { StretchTypeMinutesRow(label: $0.key, minutes: $0.value) }
        .sorted { $0.minutes > $1.minutes }
}

struct ColdTempDurationPoint: Sendable {
    /// `sessionDate` if set, else `originalTimestamp` (ms UTC); nil if neither is usable.
    let epochMs: Int64?
    let tempCelsius: Float
    let durationMinutes: Float
    let locationLabel: String
}

nonisolated private func coldBathEventEpochMs(_ s: ColdBathSessionDTO) -> Int64? {
    if let t = s.sessionDate, t > 0 { return t }
    if let t = s.originalTimestamp, t > 0 { return t }
    return nil
}

/// Discrete bucket for chart color / legend (cold bath °C).
nonisolated func coldTempStyleBucket(_ tempCelsius: Float) -> String {
    let t = Double(tempCelsius)
    if t <= 9 { return "≤9 °C" }
    if t <= 11 { return "9–11 °C" }
    if t <= 13 { return "11–13 °C" }
    return ">13 °C"
}

func coldTempVsDurationPoints(sessions: [ColdBathSessionDTO]) -> [ColdTempDurationPoint] {
    var out: [ColdTempDurationPoint] = []
    for s in sessions {
        guard let sec = s.recordedDurationSeconds, sec > 0 else { continue }
        guard let t = parseWaterTemperatureCelsius(s.waterTemperature) else { continue }
        let loc = s.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—"
        out.append(ColdTempDurationPoint(
            epochMs: coldBathEventEpochMs(s),
            tempCelsius: Float(t),
            durationMinutes: Float(sec) / 60,
            locationLabel: loc
        ))
    }
    return out
}

func recentWeeksConsistency(weeklyActiveDays: [ActivityWeekActiveDaysRow], window: Int = 12) -> (Int, Int) {
    if weeklyActiveDays.isEmpty { return (0, 0) }
    let tail = Array(weeklyActiveDays.suffix(max(1, window)))
    let with = tail.filter { $0.activeDays > 0 }.count
    return (with, tail.count)
}

struct WeekStrengthCardioPoint: Sendable {
    let weekStartIso: String
    let strengthKg: Double
    let cardioMinutes: Double
}

