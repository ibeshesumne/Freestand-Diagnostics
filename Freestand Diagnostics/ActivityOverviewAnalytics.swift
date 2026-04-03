//
//  ActivityOverviewAnalytics.swift
//

import Foundation

private func minutesFromSeconds(_ sec: Int64?) -> Double {
    Double(max(0, sec ?? 0)) / 60.0
}

struct ActivityWeekVolumeRow: Sendable {
    let weekStartIso: String
    let cardioMinutes: Double
    let stretchMinutes: Double
    let coldMinutes: Double
    let strengthSets: Int
}

struct ActivityMonthVolumeRow: Sendable {
    let monthKey: String
    let cardioMinutes: Double
    let stretchMinutes: Double
    let coldMinutes: Double
    let strengthSets: Int
}

struct ActivityWeekActiveDaysRow: Sendable {
    let weekStartIso: String
    let activeDays: Int
}

struct ActivityWeekSessionFreqRow: Sendable {
    let weekStartIso: String
    let cardioEvents: Int
    let stretchEvents: Int
    let coldEvents: Int
    let strengthSessionDays: Int
}

struct ActivityOverviewSnapshot: Sendable {
    let weeklyVolume: [ActivityWeekVolumeRow]
    let monthlyVolume: [ActivityMonthVolumeRow]
    let weeklyActiveDays: [ActivityWeekActiveDaysRow]
    let weeklySessionFreq: [ActivityWeekSessionFreqRow]
    let longestStreakDays: Int
    let totalActiveDays: Int
}

func buildActivityOverviewAnalytics(_ export: FreeStandExport) -> ActivityOverviewSnapshot {
    var weekKeys = Set<String>()
    var monthKeys = Set<String>()

    func touchEpoch(_ ms: Int64?) {
        guard let ms, ms > 0 else { return }
        weekKeys.insert(weekStartMondayKeyUtc(epochMs: ms))
        monthKeys.insert(monthKeyUtc(epochMs: ms))
    }

    for c in export.cardio { touchEpoch(c.exerciseDate) }
    for s in export.stretchSessions { touchEpoch(s.sessionDate) }
    for b in export.coldBathSessions { touchEpoch(b.sessionDate) }
    for e in export.exercises { touchEpoch(e.originalTimestamp) }

    let activeDaysAll = collectActiveDaysUtc(export).sorted()
    let streak = longestTrainingStreakDays(sortedDistinctDayKeys: activeDaysAll)

    var activeDaysByWeek: [String: Set<String>] = [:]
    for d in activeDaysAll {
        let w = weekStartForDayKeyUtc(d)
        activeDaysByWeek[w, default: []].insert(d)
    }

    let sortedWeeks = weekKeys.sorted()
    let sortedMonths = monthKeys.sorted()

    let weeklyVolume = sortedWeeks.map { w -> ActivityWeekVolumeRow in
        var cm = 0.0, sm = 0.0, bm = 0.0, sets = 0
        for c in export.cardio {
            guard let t = c.exerciseDate, t > 0 else { continue }
            guard weekStartMondayKeyUtc(epochMs: t) == w else { continue }
            cm += minutesFromSeconds(c.recordedDurationSeconds)
        }
        for s in export.stretchSessions {
            guard let t = s.sessionDate, t > 0 else { continue }
            guard weekStartMondayKeyUtc(epochMs: t) == w else { continue }
            sm += minutesFromSeconds(s.recordedDurationSeconds)
        }
        for b in export.coldBathSessions {
            guard let t = b.sessionDate, t > 0 else { continue }
            guard weekStartMondayKeyUtc(epochMs: t) == w else { continue }
            bm += minutesFromSeconds(b.recordedDurationSeconds)
        }
        for e in export.exercises {
            guard let t = e.originalTimestamp, t > 0 else { continue }
            guard weekStartMondayKeyUtc(epochMs: t) == w else { continue }
            sets += 1
        }
        return ActivityWeekVolumeRow(
            weekStartIso: w, cardioMinutes: cm, stretchMinutes: sm, coldMinutes: bm, strengthSets: sets
        )
    }

    let monthlyVolume = sortedMonths.map { m -> ActivityMonthVolumeRow in
        var cm = 0.0, sm = 0.0, bm = 0.0, sets = 0
        for c in export.cardio {
            guard let t = c.exerciseDate, t > 0 else { continue }
            guard monthKeyUtc(epochMs: t) == m else { continue }
            cm += minutesFromSeconds(c.recordedDurationSeconds)
        }
        for s in export.stretchSessions {
            guard let t = s.sessionDate, t > 0 else { continue }
            guard monthKeyUtc(epochMs: t) == m else { continue }
            sm += minutesFromSeconds(s.recordedDurationSeconds)
        }
        for b in export.coldBathSessions {
            guard let t = b.sessionDate, t > 0 else { continue }
            guard monthKeyUtc(epochMs: t) == m else { continue }
            bm += minutesFromSeconds(b.recordedDurationSeconds)
        }
        for e in export.exercises {
            guard let t = e.originalTimestamp, t > 0 else { continue }
            guard monthKeyUtc(epochMs: t) == m else { continue }
            sets += 1
        }
        return ActivityMonthVolumeRow(
            monthKey: m, cardioMinutes: cm, stretchMinutes: sm, coldMinutes: bm, strengthSets: sets
        )
    }

    let weeklyActiveDays = sortedWeeks.map { w in
        ActivityWeekActiveDaysRow(weekStartIso: w, activeDays: activeDaysByWeek[w]?.count ?? 0)
    }

    let weeklySessionFreq = sortedWeeks.map { w -> ActivityWeekSessionFreqRow in
        var ce = 0, se = 0, be = 0
        var strDays = Set<String>()
        for c in export.cardio {
            guard let t = c.exerciseDate, t > 0 else { continue }
            if weekStartMondayKeyUtc(epochMs: t) == w { ce += 1 }
        }
        for s in export.stretchSessions {
            guard let t = s.sessionDate, t > 0 else { continue }
            if weekStartMondayKeyUtc(epochMs: t) == w { se += 1 }
        }
        for b in export.coldBathSessions {
            guard let t = b.sessionDate, t > 0 else { continue }
            if weekStartMondayKeyUtc(epochMs: t) == w { be += 1 }
        }
        for e in export.exercises {
            guard let t = e.originalTimestamp, t > 0 else { continue }
            if weekStartMondayKeyUtc(epochMs: t) == w { strDays.insert(dayKeyUtc(epochMs: t)) }
        }
        return ActivityWeekSessionFreqRow(
            weekStartIso: w, cardioEvents: ce, stretchEvents: se, coldEvents: be, strengthSessionDays: strDays.count
        )
    }

    return ActivityOverviewSnapshot(
        weeklyVolume: weeklyVolume,
        monthlyVolume: monthlyVolume,
        weeklyActiveDays: weeklyActiveDays,
        weeklySessionFreq: weeklySessionFreq,
        longestStreakDays: streak,
        totalActiveDays: activeDaysAll.count
    )
}
