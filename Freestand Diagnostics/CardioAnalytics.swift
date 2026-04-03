//
//  CardioAnalytics.swift
//

import Foundation

let planAdherenceRatioCap = 3.0

enum IntensityBand: String, CaseIterable, Sendable {
    case easy = "Easy"
    case moderate = "Moderate"
    case hard = "Hard"
    case unknown = "Unknown / not set"
}

func normalizeIntensity(_ intensityPlanned: String?) -> IntensityBand {
    guard let s = intensityPlanned?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
        return .unknown
    }
    let l = s.lowercased()
    if ["low", "light", "easy", "recovery", "z1", "zone 1", "zone1"].contains(l) { return .easy }
    if ["med", "medium", "moderate", "mod", "z2", "zone 2", "zone2"].contains(l) { return .moderate }
    if ["hard", "high", "heavy", "intense", "z3", "zone 3", "zone3", "z4", "z5"].contains(l) { return .hard }
    return .unknown
}

struct MinutesByExerciseTypeRow: Sendable {
    let exerciseType: String
    let minutes: Double
}

struct IntensityMixRow: Sendable {
    let band: IntensityBand
    let minutes: Double
    let percentOfCardioTime: Double
}

struct PlanAdherenceStats: Sendable {
    let sessionsWithPlan: Int
    let meanCappedRatio: Double
    let medianCappedRatio: Double
    let capUsed: Double
}

struct LongEffortByTypeRow: Sendable {
    let exerciseType: String
    let sessionCount: Int
    let totalMinutesInLongSessions: Double
    let minutesBeyondThreshold: Double
}

struct LongEffortStats: Sendable {
    let thresholdMinutes: Int
    let qualifyingSessionCount: Int
    let totalMinutesInQualifyingSessions: Double
    let minutesBeyondThreshold: Double
    let byExerciseType: [LongEffortByTypeRow]
}

struct CardioAnalyticsSnapshot: Sendable {
    let minutesByExerciseType: [MinutesByExerciseTypeRow]
    let intensityMix: [IntensityMixRow]
    let planAdherence: PlanAdherenceStats?
    let longEfforts: LongEffortStats
    let totalCardioSessions: Int
    let sessionsWithRecordedDuration: Int
    let totalCardioMinutes: Double
}

func buildCardioAnalytics(cardio: [CardioDTO], longEffortThresholdMinutes: Int) -> CardioAnalyticsSnapshot {
    let thresholdSec = Int64(max(1, longEffortThresholdMinutes) * 60)

    var byTypeMinutes: [String: Double] = [:]
    var bandMinutes: [IntensityBand: Double] = [:]
    IntensityBand.allCases.forEach { bandMinutes[$0] = 0 }
    var planRatiosCapped: [Double] = []
    var totalRecordedSec: Int64 = 0
    var sessionsWithDuration = 0

    for row in cardio {
        guard let sec = row.recordedDurationSeconds, sec > 0 else { continue }
        sessionsWithDuration += 1
        totalRecordedSec += sec
        let min = Double(sec) / 60.0
        let typeLabel = row.exerciseType?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—"
        byTypeMinutes[typeLabel, default: 0] += min

        let band = normalizeIntensity(row.intensityPlanned)
        bandMinutes[band, default: 0] += min

        if let planned = row.plannedDurationSeconds, planned > 0 {
            let ratio = Double(sec) / Double(planned)
            planRatiosCapped.append(Swift.min(ratio, planAdherenceRatioCap))
        }
    }

    let totalMin = Double(totalRecordedSec) / 60.0
    let minutesByExerciseType = byTypeMinutes.map { MinutesByExerciseTypeRow(exerciseType: $0.key, minutes: $0.value) }
        .sorted { $0.minutes > $1.minutes }

    let intensityMix = IntensityBand.allCases.map { band in
        let m = bandMinutes[band] ?? 0
        let pct = totalMin > 0 ? (m / totalMin) * 100.0 : 0.0
        return IntensityMixRow(band: band, minutes: m, percentOfCardioTime: pct)
    }

    let planAdherence: PlanAdherenceStats?
    if planRatiosCapped.isEmpty {
        planAdherence = nil
    } else {
        let sorted = planRatiosCapped.sorted()
        let mid = sorted.count / 2
        let median: Double
        if sorted.count % 2 == 0 {
            median = (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            median = sorted[mid]
        }
        planAdherence = PlanAdherenceStats(
            sessionsWithPlan: planRatiosCapped.count,
            meanCappedRatio: planRatiosCapped.reduce(0, +) / Double(planRatiosCapped.count),
            medianCappedRatio: median,
            capUsed: planAdherenceRatioCap
        )
    }

    var longByType: [String: (Int, Double)] = [:]
    var longByTypeBeyond: [String: Double] = [:]
    var longCount = 0
    var longTotalMin = 0.0
    var beyondTotalMin = 0.0

    for row in cardio {
        guard let sec = row.recordedDurationSeconds, sec >= thresholdSec else { continue }
        longCount += 1
        let minRecorded = Double(sec) / 60.0
        longTotalMin += minRecorded
        let beyond = Double(sec - thresholdSec) / 60.0
        beyondTotalMin += max(0, beyond)
        let typeLabel = row.exerciseType?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—"
        let pair = longByType[typeLabel] ?? (0, 0.0)
        longByType[typeLabel] = (pair.0 + 1, pair.1 + minRecorded)
        longByTypeBeyond[typeLabel, default: 0] += max(0, beyond)
    }

    let longEfforts = LongEffortStats(
        thresholdMinutes: max(1, longEffortThresholdMinutes),
        qualifyingSessionCount: longCount,
        totalMinutesInQualifyingSessions: longTotalMin,
        minutesBeyondThreshold: beyondTotalMin,
        byExerciseType: longByType.map { type, pair in
            LongEffortByTypeRow(
                exerciseType: type,
                sessionCount: pair.0,
                totalMinutesInLongSessions: pair.1,
                minutesBeyondThreshold: longByTypeBeyond[type] ?? 0
            )
        }.sorted { $0.totalMinutesInLongSessions > $1.totalMinutesInLongSessions }
    )

    return CardioAnalyticsSnapshot(
        minutesByExerciseType: minutesByExerciseType,
        intensityMix: intensityMix,
        planAdherence: planAdherence,
        longEfforts: longEfforts,
        totalCardioSessions: cardio.count,
        sessionsWithRecordedDuration: sessionsWithDuration,
        totalCardioMinutes: totalMin
    )
}

// MARK: - Recorded minutes by type chart (time windows)

struct CardioMinutesByTypeChartResult: Sendable {
    let rows: [MinutesByExerciseTypeRow]
    let period: BackupAnalyticsPeriod
    let windowStartMs: Int64?
    let windowEndMs: Int64?
    /// Min/max among cardio rows that have recorded duration and a positive `originalTimestamp` or `exerciseDate`.
    let timedDatasetFirstMs: Int64?
    let timedDatasetLastMs: Int64?
    let sessionsInWindow: Int
    let typesInWindow: Int
    /// Rows with recorded duration but no usable timestamp (only included when period is `allData`).
    let durationRowsWithoutTimestamp: Int
}

private func cardioEventEpochMs(_ c: CardioDTO) -> Int64? {
    if let t = c.originalTimestamp, t > 0 { return t }
    if let t = c.exerciseDate, t > 0 { return t }
    return nil
}

func buildCardioMinutesByTypeChartData(
    cardio: [CardioDTO],
    period: BackupAnalyticsPeriod
) -> CardioMinutesByTypeChartResult {
    let withDuration = cardio.filter { ($0.recordedDurationSeconds ?? 0) > 0 }
    if withDuration.isEmpty {
        return CardioMinutesByTypeChartResult(
            rows: [],
            period: period,
            windowStartMs: nil,
            windowEndMs: nil,
            timedDatasetFirstMs: nil,
            timedDatasetLastMs: nil,
            sessionsInWindow: 0,
            typesInWindow: 0,
            durationRowsWithoutTimestamp: 0
        )
    }

    let timed = withDuration.filter { cardioEventEpochMs($0) != nil }
    let withoutTs = withDuration.count - timed.count

    func typeLabel(_ c: CardioDTO) -> String {
        c.exerciseType?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—"
    }

    func addRow(_ c: CardioDTO, into map: inout [String: Double]) {
        let sec = Int64(c.recordedDurationSeconds ?? 0)
        guard sec > 0 else { return }
        let label = typeLabel(c)
        map[label, default: 0] += Double(sec) / 60.0
    }

    if timed.isEmpty {
        guard period == .allData else {
            return CardioMinutesByTypeChartResult(
                rows: [],
                period: period,
                windowStartMs: nil,
                windowEndMs: nil,
                timedDatasetFirstMs: nil,
                timedDatasetLastMs: nil,
                sessionsInWindow: 0,
                typesInWindow: 0,
                durationRowsWithoutTimestamp: withoutTs
            )
        }
        var map: [String: Double] = [:]
        for c in withDuration { addRow(c, into: &map) }
        let rows = map.map { MinutesByExerciseTypeRow(exerciseType: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
        return CardioMinutesByTypeChartResult(
            rows: rows,
            period: period,
            windowStartMs: nil,
            windowEndMs: nil,
            timedDatasetFirstMs: nil,
            timedDatasetLastMs: nil,
            sessionsInWindow: withDuration.count,
            typesInWindow: map.count,
            durationRowsWithoutTimestamp: withoutTs
        )
    }

    let epochList = timed.map { cardioEventEpochMs($0)! }
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
        for c in withDuration {
            addRow(c, into: &map)
        }
        sessionsCounted = withDuration.count
    case .pastWeek, .pastMonth, .yearToDate:
        for c in timed {
            let t = cardioEventEpochMs(c)!
            guard t >= winStart && t <= winEnd else { continue }
            addRow(c, into: &map)
            sessionsCounted += 1
        }
    }

    let rows = map.map { MinutesByExerciseTypeRow(exerciseType: $0.key, minutes: $0.value) }
        .sorted { $0.minutes > $1.minutes }

    return CardioMinutesByTypeChartResult(
        rows: rows,
        period: period,
        windowStartMs: winStart,
        windowEndMs: winEnd,
        timedDatasetFirstMs: dFirst,
        timedDatasetLastMs: dLast,
        sessionsInWindow: sessionsCounted,
        typesInWindow: map.count,
        durationRowsWithoutTimestamp: withoutTs
    )
}
