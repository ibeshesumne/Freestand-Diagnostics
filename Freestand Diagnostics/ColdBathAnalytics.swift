//
//  ColdBathAnalytics.swift
//

import Foundation

private let waterTempNumberRegex = try! NSRegularExpression(pattern: #"(-?\d+(?:[.,]\d+)?)"#)

func parseWaterTemperatureCelsius(_ raw: String?) -> Double? {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(s.startIndex..., in: s)
    guard let m = waterTempNumberRegex.firstMatch(in: s, range: range),
          let tr = Range(m.range(at: 1), in: s)
    else { return nil }
    let token = String(s[tr]).replacingOccurrences(of: ",", with: ".")
    return Double(token)
}

struct ColdWeeklyRow: Sendable {
    let weekStartIso: String
    let sessionCount: Int
    let totalSeconds: Int64
}

struct ColdLocationRow: Sendable {
    let location: String
    let sessionCount: Int
    let totalSeconds: Int64
}

struct ColdBathAnalyticsSnapshot: Sendable {
    let totalSessions: Int
    let sessionsWithSessionDate: Int
    let sessionsWithRecordedDuration: Int
    let sessionsWithLocationLabel: Int
    let sessionsWithWaterTemperatureText: Int
    let sessionsWithParsedTemperature: Int
    let weekly: [ColdWeeklyRow]
    let byLocation: [ColdLocationRow]
    let totalDoseDegreeSeconds: Double
    let doseSessionCount: Int
}

func buildColdBathAnalytics(sessions: [ColdBathSessionDTO], referenceTempCelsius: Double) -> ColdBathAnalyticsSnapshot {
    if sessions.isEmpty {
        return ColdBathAnalyticsSnapshot(
            totalSessions: 0,
            sessionsWithSessionDate: 0,
            sessionsWithRecordedDuration: 0,
            sessionsWithLocationLabel: 0,
            sessionsWithWaterTemperatureText: 0,
            sessionsWithParsedTemperature: 0,
            weekly: [],
            byLocation: [],
            totalDoseDegreeSeconds: 0,
            doseSessionCount: 0
        )
    }

    var weekSessions: [String: Int] = [:]
    var weekSeconds: [String: Int64] = [:]
    var locSessions: [String: Int] = [:]
    var locSeconds: [String: Int64] = [:]

    var withDate = 0
    var withDuration = 0
    var withLocation = 0
    var withWaterTempText = 0
    var withParsedTemp = 0
    var doseSum = 0.0
    var doseCount = 0

    for row in sessions {
        let sec = row.recordedDurationSeconds ?? 0
        if sec > 0 { withDuration += 1 }

        if let sessionMs = row.sessionDate, sessionMs > 0 {
            withDate += 1
            let wk = weekStartMondayKeyUtc(epochMs: sessionMs)
            weekSessions[wk, default: 0] += 1
            weekSeconds[wk, default: 0] += max(0, sec)
        }

        let locRaw = row.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let loc = locRaw.isEmpty ? "—" : locRaw
        if !locRaw.isEmpty { withLocation += 1 }
        locSessions[loc, default: 0] += 1
        locSeconds[loc, default: 0] += max(0, sec)

        if let wt = row.waterTemperature, !wt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withWaterTempText += 1
        }

        if let temp = parseWaterTemperatureCelsius(row.waterTemperature) {
            withParsedTemp += 1
            if sec > 0 {
                let delta = max(0.0, referenceTempCelsius - temp)
                doseSum += Double(sec) * delta
                doseCount += 1
            }
        }
    }

    let weekly = weekSessions.keys.sorted().map { wk in
        ColdWeeklyRow(
            weekStartIso: wk,
            sessionCount: weekSessions[wk] ?? 0,
            totalSeconds: weekSeconds[wk] ?? 0
        )
    }

    let byLocation = locSessions.keys.map { k in
        ColdLocationRow(
            location: k,
            sessionCount: locSessions[k] ?? 0,
            totalSeconds: locSeconds[k] ?? 0
        )
    }.sorted { $0.totalSeconds > $1.totalSeconds }

    return ColdBathAnalyticsSnapshot(
        totalSessions: sessions.count,
        sessionsWithSessionDate: withDate,
        sessionsWithRecordedDuration: withDuration,
        sessionsWithLocationLabel: withLocation,
        sessionsWithWaterTemperatureText: withWaterTempText,
        sessionsWithParsedTemperature: withParsedTemp,
        weekly: weekly,
        byLocation: byLocation,
        totalDoseDegreeSeconds: doseSum,
        doseSessionCount: doseCount
    )
}
