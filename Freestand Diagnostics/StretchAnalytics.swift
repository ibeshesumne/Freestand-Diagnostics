//
//  StretchAnalytics.swift
//

import Foundation

func herfindahlHirschman(shares: [Double]) -> Double {
    if shares.isEmpty { return 0 }
    let sum = shares.reduce(0, +)
    if sum <= 0 { return 0 }
    return shares.reduce(0.0) { acc, s in
        let p = s / sum
        return acc + p * p
    }
}

nonisolated private func stretchTypeLabel(_ raw: String?) -> String {
    let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return t.isEmpty ? "—" : t
}

struct StretchTypeStatsRow: Sendable {
    let stretchType: String
    let sessionCount: Int
    let minutes: Double
    let percentOfTime: Double
    let percentOfSessions: Double
}

struct StretchAnalyticsSnapshot: Sendable {
    let totalSessions: Int
    let sessionsWithRecordedDuration: Int
    let totalMinutes: Double
    let distinctStretchTypes: Int
    let distinctStretchNames: Int
    let hhiTimeByStretchType: Double
    let hhiCountByStretchType: Double
    let equalSpreadHhiTime: Double
    let byStretchType: [StretchTypeStatsRow]
    let underusedStretchTypes: [StretchTypeStatsRow]
}

func buildStretchAnalytics(sessions: [StretchSessionDTO]) -> StretchAnalyticsSnapshot {
    if sessions.isEmpty {
        return StretchAnalyticsSnapshot(
            totalSessions: 0,
            sessionsWithRecordedDuration: 0,
            totalMinutes: 0,
            distinctStretchTypes: 0,
            distinctStretchNames: 0,
            hhiTimeByStretchType: 0,
            hhiCountByStretchType: 0,
            equalSpreadHhiTime: 0,
            byStretchType: [],
            underusedStretchTypes: []
        )
    }

    var typeSet = Set<String>()
    var nameSet = Set<String>()
    for row in sessions {
        if let st = row.stretchType?.trimmingCharacters(in: .whitespacesAndNewlines), !st.isEmpty {
            typeSet.insert(st)
        }
        if let sn = row.stretchName?.trimmingCharacters(in: .whitespacesAndNewlines), !sn.isEmpty {
            nameSet.insert(sn)
        }
    }

    var countByType: [String: Int] = [:]
    var secondsByType: [String: Int64] = [:]
    var sessionsWithDur = 0
    var totalSec: Int64 = 0

    for row in sessions {
        let label = stretchAnalyticsTypeLabel(row.stretchType)
        countByType[label, default: 0] += 1
        let sec = row.recordedDurationSeconds ?? 0
        if sec > 0 {
            sessionsWithDur += 1
            totalSec += sec
            secondsByType[label, default: 0] += sec
        }
    }

    let totalMin = Double(totalSec) / 60.0
    let nTypes = countByType.count
    let equalSpreadHhi = nTypes > 0 ? 1.0 / Double(nTypes) : 0.0

    let typeKeys = countByType.keys.sorted()
    let timeShares = typeKeys.map { Double(secondsByType[$0] ?? 0) }
    let countShares = typeKeys.map { Double(countByType[$0] ?? 0) }

    let hhiTime = herfindahlHirschman(shares: timeShares)
    let hhiCount = herfindahlHirschman(shares: countShares)

    let byStretchType = typeKeys.map { key -> StretchTypeStatsRow in
        let c = countByType[key] ?? 0
        let min = Double(secondsByType[key] ?? 0) / 60.0
        return StretchTypeStatsRow(
            stretchType: key,
            sessionCount: c,
            minutes: min,
            percentOfTime: totalMin > 0 ? (min / totalMin) * 100.0 : 0.0,
            percentOfSessions: (Double(c) / Double(sessions.count)) * 100.0
        )
    }.sorted { $0.minutes > $1.minutes }

    let underused: [StretchTypeStatsRow]
    if nTypes < 2 || totalMin <= 0 {
        underused = []
    } else {
        let thresholdPct = (100.0 / Double(nTypes)) * 0.5
        underused = byStretchType
            .filter { $0.percentOfTime < thresholdPct && $0.minutes > 0 }
            .sorted { $0.minutes < $1.minutes }
    }

    return StretchAnalyticsSnapshot(
        totalSessions: sessions.count,
        sessionsWithRecordedDuration: sessionsWithDur,
        totalMinutes: totalMin,
        distinctStretchTypes: typeSet.count,
        distinctStretchNames: nameSet.count,
        hhiTimeByStretchType: hhiTime,
        hhiCountByStretchType: hhiCount,
        equalSpreadHhiTime: equalSpreadHhi,
        byStretchType: byStretchType,
        underusedStretchTypes: underused
    )
}

// MARK: - Free Stand stretch catalog / body regions

nonisolated let freeStandStretchTypesOrdered: [String] = [
    "Head Stretches",
    "Shoulder Mobility",
    "Chest Opener",
    "Upper Arm",
    "Spinal Twist",
    "Spinal Mobility",
    "Core (abs, back, shoulders)",
    "Pelvic Floor Lower Abdominals",
    "Hip Flexor",
    "Quad",
    "Hamstring",
    "Calf",
]

nonisolated func canonicalFreeStandStretchType(_ raw: String?) -> String? {
    let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if t.isEmpty { return nil }
    return freeStandStretchTypesOrdered.first { $0.caseInsensitiveCompare(t) == .orderedSame }
}

/// Lowercased free-text / short labels → exact catalog name (only where we can do so safely).
nonisolated private let stretchTypeAliasToCanonical: [String: String] = {
    let head = "Head Stretches"
    var m: [String: String] = [:]
    for a in [
        "head", "neck", "head stretch", "head stretches", "head/neck", "head & neck", "head and neck",
    ] {
        m[a] = head
    }
    return m
}()

/// Catalog match, else known alias; used for tables, charts, and body-region bucketing.
nonisolated func resolvedStretchCatalogName(_ raw: String?) -> String? {
    if let exact = canonicalFreeStandStretchType(raw) {
        return exact
    }
    let l = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    if l.isEmpty { return nil }
    return stretchTypeAliasToCanonical[l]
}

/// Single label for analytics aggregation (merges e.g. "Head" into "Head Stretches").
nonisolated func stretchAnalyticsTypeLabel(_ raw: String?) -> String {
    if let c = resolvedStretchCatalogName(raw) {
        return c
    }
    return stretchTypeLabel(raw)
}

enum StretchBodyRegion: String, CaseIterable, Sendable {
    case head
    case shoulders
    case chest
    case upperArm = "upper_arm"
    case spine
    case core
    case hip
    case quad
    case hamstring
    case calf
    case other

    static var orderedForFigure: [StretchBodyRegion] {
        [.head, .shoulders, .chest, .upperArm, .spine, .core, .hip, .quad, .hamstring, .calf, .other]
    }
}

nonisolated func stretchBodyRegionForCanonicalType(_ canonical: String?) -> StretchBodyRegion {
    guard let canonical, !canonical.isEmpty else { return .other }
    switch canonical {
    case "Head Stretches": return .head
    case "Shoulder Mobility": return .shoulders
    case "Chest Opener": return .chest
    case "Upper Arm": return .upperArm
    case "Spinal Twist", "Spinal Mobility": return .spine
    case "Core (abs, back, shoulders)", "Pelvic Floor Lower Abdominals": return .core
    case "Hip Flexor": return .hip
    case "Quad": return .quad
    case "Hamstring": return .hamstring
    case "Calf": return .calf
    default: return .other
    }
}

nonisolated func stretchBodyRegionForRawStretchType(_ raw: String?) -> StretchBodyRegion {
    stretchBodyRegionForCanonicalType(resolvedStretchCatalogName(raw))
}

struct StretchBodyRegionStat: Sendable {
    let region: StretchBodyRegion
    let minutes: Double
    let sessionCount: Int
}

func buildStretchBodyRegionStats(sessions: [StretchSessionDTO]) -> [StretchBodyRegionStat] {
    var minutes: [StretchBodyRegion: Double] = [:]
    var counts: [StretchBodyRegion: Int] = [:]
    StretchBodyRegion.allCases.forEach {
        minutes[$0] = 0
        counts[$0] = 0
    }
    for row in sessions {
        let region = stretchBodyRegionForRawStretchType(row.stretchType)
        counts[region, default: 0] += 1
        let sec = row.recordedDurationSeconds ?? 0
        if sec > 0 {
            minutes[region, default: 0] += Double(sec) / 60.0
        }
    }
    return StretchBodyRegion.orderedForFigure.map { r in
        StretchBodyRegionStat(region: r, minutes: minutes[r] ?? 0, sessionCount: counts[r] ?? 0)
    }
}

// MARK: - Recorded minutes by stretch type chart (time windows)

struct StretchMinutesByTypeChartResult: Sendable {
    let rows: [StretchTypeMinutesRow]
    let period: BackupAnalyticsPeriod
    let windowStartMs: Int64?
    let windowEndMs: Int64?
    let timedDatasetFirstMs: Int64?
    let timedDatasetLastMs: Int64?
    let sessionsInWindow: Int
    let typesInWindow: Int
    let sessionsWithoutTimestamp: Int
}

/// Prefer when the session occurred (`sessionDate`), same as weekly stretch series and activity overview.
nonisolated private func stretchSessionEpochMs(_ s: StretchSessionDTO) -> Int64? {
    if let t = s.sessionDate, t > 0 { return t }
    if let t = s.originalTimestamp, t > 0 { return t }
    return nil
}

nonisolated func buildStretchMinutesByTypeChartData(
    sessions: [StretchSessionDTO],
    period: BackupAnalyticsPeriod
) -> StretchMinutesByTypeChartResult {
    let withDuration = sessions.filter { ($0.recordedDurationSeconds ?? 0) > 0 }
    if withDuration.isEmpty {
        return StretchMinutesByTypeChartResult(
            rows: [],
            period: period,
            windowStartMs: nil,
            windowEndMs: nil,
            timedDatasetFirstMs: nil,
            timedDatasetLastMs: nil,
            sessionsInWindow: 0,
            typesInWindow: 0,
            sessionsWithoutTimestamp: 0
        )
    }

    let timed = withDuration.filter { stretchSessionEpochMs($0) != nil }
    let withoutTs = withDuration.count - timed.count

    func addRow(_ s: StretchSessionDTO, into map: inout [String: Double]) {
        let sec = Int64(s.recordedDurationSeconds ?? 0)
        guard sec > 0 else { return }
        let label = stretchAnalyticsTypeLabel(s.stretchType)
        map[label, default: 0] += Double(sec) / 60.0
    }

    if timed.isEmpty {
        guard period == .allData else {
            return StretchMinutesByTypeChartResult(
                rows: [],
                period: period,
                windowStartMs: nil,
                windowEndMs: nil,
                timedDatasetFirstMs: nil,
                timedDatasetLastMs: nil,
                sessionsInWindow: 0,
                typesInWindow: 0,
                sessionsWithoutTimestamp: withoutTs
            )
        }
        var map: [String: Double] = [:]
        for s in withDuration { addRow(s, into: &map) }
        let rows = map.map { StretchTypeMinutesRow(label: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
        return StretchMinutesByTypeChartResult(
            rows: rows,
            period: period,
            windowStartMs: nil,
            windowEndMs: nil,
            timedDatasetFirstMs: nil,
            timedDatasetLastMs: nil,
            sessionsInWindow: withDuration.count,
            typesInWindow: map.count,
            sessionsWithoutTimestamp: withoutTs
        )
    }

    let epochList = timed.map { stretchSessionEpochMs($0)! }
    let dFirst = epochList.min()!
    let dLast = epochList.max()!

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

    var map: [String: Double] = [:]
    var sessionsCounted = 0

    switch period {
    case .allData:
        for s in withDuration {
            addRow(s, into: &map)
        }
        sessionsCounted = withDuration.count
    case .pastWeek, .pastMonth, .yearToDate:
        for s in timed {
            let t = stretchSessionEpochMs(s)!
            guard t >= winStart && t <= winEnd else { continue }
            addRow(s, into: &map)
            sessionsCounted += 1
        }
    }

    let rows = map.map { StretchTypeMinutesRow(label: $0.key, minutes: $0.value) }
        .sorted { $0.minutes > $1.minutes }

    return StretchMinutesByTypeChartResult(
        rows: rows,
        period: period,
        windowStartMs: winStart,
        windowEndMs: winEnd,
        timedDatasetFirstMs: dFirst,
        timedDatasetLastMs: dLast,
        sessionsInWindow: sessionsCounted,
        typesInWindow: map.count,
        sessionsWithoutTimestamp: withoutTs
    )
}
