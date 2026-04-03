//
//  ActivityModalityWeeklySeries.swift
//

import Foundation

struct WeeklySeriesPoint: Sendable {
    let weekStartIso: String
    let value: Float
}

func buildStrengthSetsPerWeek(exercises: [ExerciseDTO]) -> [WeeklySeriesPoint] {
    if exercises.isEmpty { return [] }
    var m: [String: Int] = [:]
    for e in exercises {
        guard let t = e.originalTimestamp, t > 0 else { continue }
        let w = weekStartMondayKeyUtc(epochMs: t)
        m[w, default: 0] += 1
    }
    if m.isEmpty { return [] }
    return m.keys.sorted().map { WeeklySeriesPoint(weekStartIso: $0, value: Float(m[$0]!)) }
}

private extension CardioDTO {
    func eventEpochMs() -> Int64? {
        let t = exerciseDate ?? originalTimestamp
        guard let t, t > 0 else { return nil }
        return t
    }
}

private extension StretchSessionDTO {
    func eventEpochMs() -> Int64? {
        let t = sessionDate ?? originalTimestamp
        guard let t, t > 0 else { return nil }
        return t
    }
}

private extension ColdBathSessionDTO {
    func eventEpochMs() -> Int64? {
        let t = sessionDate ?? originalTimestamp
        guard let t, t > 0 else { return nil }
        return t
    }
}

func buildCardioMinutesPerWeek(cardio: [CardioDTO]) -> [WeeklySeriesPoint] {
    if cardio.isEmpty { return [] }
    var m: [String: Double] = [:]
    for c in cardio {
        guard let t = c.eventEpochMs() else { continue }
        guard let sec = c.recordedDurationSeconds, sec > 0 else { continue }
        let w = weekStartMondayKeyUtc(epochMs: t)
        m[w, default: 0] += Double(sec) / 60.0
    }
    if m.isEmpty { return [] }
    return m.keys.sorted().map { WeeklySeriesPoint(weekStartIso: $0, value: Float(m[$0]!)) }
}

func buildStretchMinutesPerWeek(sessions: [StretchSessionDTO]) -> [WeeklySeriesPoint] {
    if sessions.isEmpty { return [] }
    var m: [String: Double] = [:]
    for s in sessions {
        guard let t = s.eventEpochMs() else { continue }
        guard let sec = s.recordedDurationSeconds, sec > 0 else { continue }
        let w = weekStartMondayKeyUtc(epochMs: t)
        m[w, default: 0] += Double(sec) / 60.0
    }
    if m.isEmpty { return [] }
    return m.keys.sorted().map { WeeklySeriesPoint(weekStartIso: $0, value: Float(m[$0]!)) }
}

func buildColdMinutesPerWeek(sessions: [ColdBathSessionDTO]) -> [WeeklySeriesPoint] {
    if sessions.isEmpty { return [] }
    var m: [String: Double] = [:]
    for s in sessions {
        guard let t = s.eventEpochMs() else { continue }
        guard let sec = s.recordedDurationSeconds, sec > 0 else { continue }
        let w = weekStartMondayKeyUtc(epochMs: t)
        m[w, default: 0] += Double(sec) / 60.0
    }
    if m.isEmpty { return [] }
    return m.keys.sorted().map { WeeklySeriesPoint(weekStartIso: $0, value: Float(m[$0]!)) }
}
