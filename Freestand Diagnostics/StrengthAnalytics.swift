//
//  StrengthAnalytics.swift
//

import Foundation

private let lbToKg = 0.45359237

func epleyE1rmKg(loadKg: Double, reps: Int) -> Double {
    if loadKg <= 0 || reps <= 0 { return 0 }
    return loadKg * (1.0 + Double(reps) / 30.0)
}

func unitToKgMultiplier(_ unit: String?) -> Double? {
    guard let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 1.0 }
    switch unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "kg", "kgs", "kilogram", "kilograms": return 1.0
    case "lb", "lbs", "pound", "pounds", "#": return lbToKg
    default: return nil
    }
}

func exerciseDisplayName(_ raw: String?) -> String {
    let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return t.isEmpty ? "—" : t
}

private func roundLoadKg(_ loadKg: Double) -> Double {
    let r = (loadKg * 10).rounded() / 10
    return r == -0 ? 0 : r
}

private func isLoggedUnitPounds(_ unitRaw: String) -> Bool {
    let u = unitRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return u == "lb" || u == "lbs" || u == "#" || u == "pound" || u == "pounds"
}

func formatRepsAtLoadWeightLine(loadKgRounded: Double, loadRaw: Double, unitRaw: String) -> String {
    let kgPart = String(format: "%.1f kg", locale: Locale(identifier: "en_US_POSIX"), loadKgRounded)
    if isLoggedUnitPounds(unitRaw) {
        let rawPart = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), loadRaw)
        return "\(kgPart) (\(rawPart) \(unitRaw))"
    }
    return kgPart
}

private struct ParsedSet {
    /// `originalTimestamp` from the row (ms since Unix epoch, UTC interpretation for analytics).
    let epochMs: Int64
    let dayKey: String
    let exerciseName: String
    let loadRaw: Double
    let rep: Int
    let unitRaw: String
    let loadKg: Double?
    let volumeKg: Double?
    let e1rmKg: Double?
}

private func parseSets(_ rows: [ExerciseDTO]) -> [ParsedSet] {
    var out: [ParsedSet] = []
    for row in rows {
        guard let ts = row.originalTimestamp, ts > 0 else { continue }
        let dayKey = dayKeyUtc(epochMs: ts)
        let name = exerciseDisplayName(row.exercisename)
        guard let load = row.load, let rep = row.rep, load > 0, rep > 0 else { continue }
        let mult = unitToKgMultiplier(row.unit)
        let loadKg = mult.map { load * $0 }
        let volumeKg = loadKg.map { $0 * Double(rep) }
        let e1rm = loadKg.map { epleyE1rmKg(loadKg: $0, reps: rep) }
        out.append(ParsedSet(
            epochMs: ts,
            dayKey: dayKey,
            exerciseName: name,
            loadRaw: load,
            rep: rep,
            unitRaw: row.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "?",
            loadKg: loadKg,
            volumeKg: volumeKg,
            e1rmKg: e1rm
        ))
    }
    return out
}

struct StrengthDayVolumeRow: Sendable {
    let dayKey: String
    let volumeKg: Double
    let setCount: Int
}

struct StrengthExerciseVolumeRow: Sendable {
    let exerciseName: String
    let volumeKg: Double
    let setCount: Int
}

struct StrengthMaxLoadRow: Sendable {
    let exerciseName: String
    let loadRaw: Double
    let unitLabel: String
    let loadKg: Double?
    let dayKey: String
}

struct StrengthRepsAtLoadEntry: Sendable {
    let dayKey: String
    let reps: Int
}

struct StrengthRepsAtLoadCard: Sendable {
    let exerciseName: String
    let loadKgRounded: Double
    let loadDisplay: String
    let entries: [StrengthRepsAtLoadEntry]
}

struct StrengthE1rmRow: Sendable {
    let exerciseName: String
    let e1rmKg: Double
    let fromLoadKg: Double
    let fromReps: Int
}

struct StrengthTagCountRow: Sendable {
    let tag: StrengthMovementTag
    let setCount: Int
}

struct StrengthAnalyticsSnapshot: Sendable {
    let totalExerciseRows: Int
    let rowsWithValidTimestamp: Int
    let rowsWithVolume: Int
    let rowsWithUnknownUnit: Int
    let volumeByDay: [StrengthDayVolumeRow]
    let volumeByExercise: [StrengthExerciseVolumeRow]
    let maxLoadByExercise: [StrengthMaxLoadRow]
    let repsAtLoadCards: [StrengthRepsAtLoadCard]
    let e1rmByExercise: [StrengthE1rmRow]
    let setsByMovementTag: [StrengthTagCountRow]
}

func buildStrengthAnalytics(exercises: [ExerciseDTO]) -> StrengthAnalyticsSnapshot {
    if exercises.isEmpty {
        return StrengthAnalyticsSnapshot(
            totalExerciseRows: 0,
            rowsWithValidTimestamp: 0,
            rowsWithVolume: 0,
            rowsWithUnknownUnit: 0,
            volumeByDay: [],
            volumeByExercise: [],
            maxLoadByExercise: [],
            repsAtLoadCards: [],
            e1rmByExercise: [],
            setsByMovementTag: []
        )
    }

    let withTs = exercises.filter { ($0.originalTimestamp ?? 0) > 0 }.count
    let parsed = parseSets(exercises)
    let contributingKgVolume = parsed.filter { $0.volumeKg != nil }.count
    let unknownUnit = parsed.filter { $0.loadKg == nil }.count

    var volDay: [String: Double] = [:]
    var volDaySets: [String: Int] = [:]
    var volEx: [String: Double] = [:]
    var volExSets: [String: Int] = [:]
    for p in parsed {
        guard let v = p.volumeKg else { continue }
        volDay[p.dayKey, default: 0] += v
        volDaySets[p.dayKey, default: 0] += 1
        volEx[p.exerciseName, default: 0] += v
        volExSets[p.exerciseName, default: 0] += 1
    }

    let volumeByDay = volDay.keys.sorted().map { d in
        StrengthDayVolumeRow(dayKey: d, volumeKg: volDay[d]!, setCount: volDaySets[d] ?? 0)
    }

    let volumeByExercise = volEx.keys.map { name in
        StrengthExerciseVolumeRow(
            exerciseName: name,
            volumeKg: volEx[name]!,
            setCount: volExSets[name] ?? 0
        )
    }.sorted { $0.volumeKg > $1.volumeKg }

    let maxLoadByExercise = Dictionary(grouping: parsed, by: \.exerciseName).map { _, list in
        let withKg = list.filter { $0.loadKg != nil }
        let p: ParsedSet
        if !withKg.isEmpty {
            p = withKg.max(by: { ($0.loadKg ?? 0) < ($1.loadKg ?? 0) })!
        } else {
            p = list.max(by: { $0.loadRaw < $1.loadRaw })!
        }
        return StrengthMaxLoadRow(
            exerciseName: p.exerciseName,
            loadRaw: p.loadRaw,
            unitLabel: p.unitRaw,
            loadKg: p.loadKg,
            dayKey: p.dayKey
        )
    }.sorted {
        if ($0.loadKg != nil) != ($1.loadKg != nil) { return $0.loadKg != nil }
        if let a = $0.loadKg, let b = $1.loadKg, a != b { return a > b }
        return $0.loadRaw > $1.loadRaw
    }

    var e1Map: [String: ParsedSet] = [:]
    for p in parsed {
        guard let e = p.e1rmKg else { continue }
        if let prev = e1Map[p.exerciseName] {
            if (prev.e1rmKg ?? 0) < e { e1Map[p.exerciseName] = p }
        } else {
            e1Map[p.exerciseName] = p
        }
    }
    let e1rmByExercise = e1Map.values.map { p in
        StrengthE1rmRow(
            exerciseName: p.exerciseName,
            e1rmKg: p.e1rmKg!,
            fromLoadKg: p.loadKg!,
            fromReps: p.rep
        )
    }.sorted { $0.e1rmKg > $1.e1rmKg }

    var repsAtLoadCards: [StrengthRepsAtLoadCard] = []
    for volRow in volumeByExercise.prefix(8) {
        let name = volRow.exerciseName
        let setsForEx = parsed.filter { $0.exerciseName == name && $0.loadKg != nil }
        if setsForEx.count < 2 { continue }
        let byBucket = Dictionary(grouping: setsForEx) { roundLoadKg($0.loadKg!) }
        guard let bestBucket = byBucket.max(by: { $0.value.count < $1.value.count }) else { continue }
        if bestBucket.value.count < 2 { continue }
        let loadKgR = bestBucket.key
        let example = bestBucket.value[0]
        let loadDisplay = formatRepsAtLoadWeightLine(
            loadKgRounded: loadKgR,
            loadRaw: example.loadRaw,
            unitRaw: example.unitRaw
        )
        let byDay = Dictionary(grouping: bestBucket.value, by: \.dayKey)
            .mapValues { $0.map(\.rep).max()! }
            .sorted { $0.key < $1.key }
            .map { StrengthRepsAtLoadEntry(dayKey: $0.key, reps: $0.value) }
        if byDay.count >= 2 {
            repsAtLoadCards.append(StrengthRepsAtLoadCard(
                exerciseName: name,
                loadKgRounded: loadKgR,
                loadDisplay: loadDisplay,
                entries: byDay
            ))
        }
    }

    var tagCounts: [StrengthMovementTag: Int] = [:]
    for e in exercises {
        guard let t = e.originalTimestamp, t > 0 else { continue }
        let tag = strengthMovementTagForExerciseName(e.exercisename)
        tagCounts[tag, default: 0] += 1
    }
    let setsByMovementTag = StrengthMovementTag.allCases
        .map { StrengthTagCountRow(tag: $0, setCount: tagCounts[$0] ?? 0) }
        .filter { $0.setCount > 0 }
        .sorted { $0.setCount > $1.setCount }

    return StrengthAnalyticsSnapshot(
        totalExerciseRows: exercises.count,
        rowsWithValidTimestamp: withTs,
        rowsWithVolume: contributingKgVolume,
        rowsWithUnknownUnit: unknownUnit,
        volumeByDay: volumeByDay,
        volumeByExercise: volumeByExercise,
        maxLoadByExercise: maxLoadByExercise,
        repsAtLoadCards: Array(repsAtLoadCards.prefix(6)),
        e1rmByExercise: Array(e1rmByExercise.prefix(40)),
        setsByMovementTag: setsByMovementTag
    )
}

func strengthVolumeKgByWeek(volumeByDay: [StrengthDayVolumeRow]) -> [(String, Double)] {
    var byWeek: [String: Double] = [:]
    for row in volumeByDay {
        let wk = weekStartForDayKeyUtc(row.dayKey)
        byWeek[wk, default: 0] += row.volumeKg
    }
    return byWeek.keys.sorted().map { ($0, byWeek[$0]!) }
}

/// Exactly `trailingWeekCount` consecutive UTC Monday weeks ending at the latest week that has any kg volume,
/// with `0` for weeks that have no logged volume (sparse weeks omitted in the raw rollup).
func strengthWeeklyVolumeDenseTrailingWeeks(
    volumeByDay: [StrengthDayVolumeRow],
    trailingWeekCount: Int = 20
) -> [(String, Double)]? {
    guard trailingWeekCount > 0 else { return nil }
    let totals = strengthVolumeKgByWeek(volumeByDay: volumeByDay)
    guard let endMonday = totals.map(\.0).max() else { return nil }
    let keys = consecutiveUtcMondayKeys(endingAtMondayIso: endMonday, count: trailingWeekCount)
    guard keys.count == trailingWeekCount else { return nil }
    let dict = Dictionary(uniqueKeysWithValues: totals)
    return keys.map { ($0, dict[$0] ?? 0) }
}

func weeklyStrengthKgAndCardio(
    volumeByDay: [StrengthDayVolumeRow],
    weeklyVolume: [ActivityWeekVolumeRow]
) -> [WeekStrengthCardioPoint] {
    let strength = Dictionary(uniqueKeysWithValues: strengthVolumeKgByWeek(volumeByDay: volumeByDay))
    let cardio = Dictionary(uniqueKeysWithValues: weeklyVolume.map { ($0.weekStartIso, $0.cardioMinutes) })
    let keys = Set(strength.keys).union(cardio.keys).sorted()
    return keys.map {
        WeekStrengthCardioPoint(weekStartIso: $0, strengthKg: strength[$0] ?? 0, cardioMinutes: cardio[$0] ?? 0)
    }
}

// MARK: - Top exercises chart (time windows)

struct StrengthTopExercisesChartResult: Sendable {
    let volumeByExercise: [StrengthExerciseVolumeRow]
    let period: BackupAnalyticsPeriod
    /// Inclusive UTC window used after clipping to available data (ms).
    let windowStartMs: Int64?
    let windowEndMs: Int64?
    let datasetFirstMs: Int64?
    let datasetLastMs: Int64?
    let setsInWindow: Int
    let exercisesInWindow: Int
}

func buildStrengthTopExercisesChartData(
    exercises: [ExerciseDTO],
    period: BackupAnalyticsPeriod
) -> StrengthTopExercisesChartResult {
    let parsed = parseSets(exercises)
    let withVol = parsed.filter { $0.volumeKg != nil }
    if withVol.isEmpty {
        return StrengthTopExercisesChartResult(
            volumeByExercise: [],
            period: period,
            windowStartMs: nil,
            windowEndMs: nil,
            datasetFirstMs: nil,
            datasetLastMs: nil,
            setsInWindow: 0,
            exercisesInWindow: 0
        )
    }

    let dFirst = withVol.map(\.epochMs).min()!
    let dLast = withVol.map(\.epochMs).max()!

    let (winStart, winEnd): (Int64, Int64) = switch period {
    case .allData:
        (dFirst, dLast)
    case .pastWeek:
        (max(dFirst, dLast - 7 * backupAnalyticsMsPerDay), dLast)
    case .pastMonth:
        (max(dFirst, dLast - 30 * backupAnalyticsMsPerDay), dLast)
    case .yearToDate:
        (max(dFirst, utcStartOfYearEpochMs(epochMs: dLast)), dLast)
    }

    let filtered = withVol.filter { $0.epochMs >= winStart && $0.epochMs <= winEnd }

    var volEx: [String: Double] = [:]
    var exSets: [String: Int] = [:]
    for p in filtered {
        guard let v = p.volumeKg else { continue }
        volEx[p.exerciseName, default: 0] += v
        exSets[p.exerciseName, default: 0] += 1
    }

    let rows = volEx.keys.map { name in
        StrengthExerciseVolumeRow(
            exerciseName: name,
            volumeKg: volEx[name]!,
            setCount: exSets[name] ?? 0
        )
    }.sorted { $0.volumeKg > $1.volumeKg }

    return StrengthTopExercisesChartResult(
        volumeByExercise: rows,
        period: period,
        windowStartMs: winStart,
        windowEndMs: winEnd,
        datasetFirstMs: dFirst,
        datasetLastMs: dLast,
        setsInWindow: filtered.count,
        exercisesInWindow: volEx.count
    )
}
