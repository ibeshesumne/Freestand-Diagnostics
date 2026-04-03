//
//  DateUTC.swift
//  Freestand Diagnostics
//
//  UTC calendar helpers (ported from Android ColdBathAnalytics / ActivityOverviewAnalytics).
//

import Foundation

/// Shared UTC calendar for analytics (nonisolated so backup parsing can run off the main actor).
private enum UtcCalendarHolder {
    nonisolated static let shared: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
}

nonisolated func dayKeyUtc(epochMs: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
    let comps = UtcCalendarHolder.shared.dateComponents([.year, .month, .day], from: date)
    let y = comps.year ?? 0
    let m = comps.month ?? 0
    let d = comps.day ?? 0
    return String(format: "%04d-%02d-%02d", y, m, d)
}

/// Monday-start ISO week key (yyyy-MM-dd of Monday 00:00 UTC) containing `epochMs`.
nonisolated func weekStartMondayKeyUtc(epochMs: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
    let cal = UtcCalendarHolder.shared
    var c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    c.hour = 0
    c.minute = 0
    c.second = 0
    guard let startOfDay = cal.date(from: c) else { return dayKeyUtc(epochMs: epochMs) }
    let weekday = cal.component(.weekday, from: startOfDay)
    let daysFromMonday = (weekday + 5) % 7
    guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) else {
        return dayKeyUtc(epochMs: epochMs)
    }
    return dayKeyUtc(epochMs: Int64(monday.timeIntervalSince1970 * 1000))
}

nonisolated func monthKeyUtc(epochMs: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
    let comps = UtcCalendarHolder.shared.dateComponents([.year, .month], from: date)
    let y = comps.year ?? 0
    let m = comps.month ?? 0
    return String(format: "%04d-%02d", y, m)
}

/// Week (Monday UTC) that contains calendar day `dayKey` (yyyy-MM-dd).
nonisolated func weekStartForDayKeyUtc(_ dayKey: String) -> String {
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    guard let date = fmt.date(from: dayKey) else { return dayKey }
    return weekStartMondayKeyUtc(epochMs: Int64(date.timeIntervalSince1970 * 1000))
}

nonisolated private func nextDayKeyUtc(_ dayKey: String) -> String {
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    guard let date = fmt.date(from: dayKey),
          let next = UtcCalendarHolder.shared.date(byAdding: .day, value: 1, to: date)
    else { return dayKey }
    return dayKeyUtc(epochMs: Int64(next.timeIntervalSince1970 * 1000))
}

nonisolated func longestTrainingStreakDays(sortedDistinctDayKeys: [String]) -> Int {
    if sortedDistinctDayKeys.isEmpty { return 0 }
    var best = 1
    var cur = 1
    for i in 1..<sortedDistinctDayKeys.count {
        if sortedDistinctDayKeys[i] == nextDayKeyUtc(sortedDistinctDayKeys[i - 1]) {
            cur += 1
        } else {
            cur = 1
        }
        best = max(best, cur)
    }
    return best
}

nonisolated func formatUtcDateTime(epochMs: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
    return fmt.string(from: date)
}

nonisolated func formatUtcDate(epochMs: Int64) -> String {
    dayKeyUtc(epochMs: epochMs)
}

/// `count` consecutive UTC calendar Mondays as `yyyy-MM-dd`, oldest first, ending at `lastMondayIso` (inclusive).
nonisolated func consecutiveUtcMondayKeys(endingAtMondayIso lastMondayIso: String, count: Int) -> [String] {
    guard count > 0 else { return [] }
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    guard let endMonday = fmt.date(from: lastMondayIso) else { return [] }
    let cal = UtcCalendarHolder.shared
    var keys: [String] = []
    keys.reserveCapacity(count)
    for offset in 0..<count {
        let daysBack = (count - 1 - offset) * 7
        guard let d = cal.date(byAdding: .day, value: -daysBack, to: endMonday) else { return [] }
        keys.append(dayKeyUtc(epochMs: Int64(d.timeIntervalSince1970 * 1000)))
    }
    return keys
}

/// 1 Jan 00:00:00 UTC for the calendar year that contains `epochMs`.
nonisolated func utcStartOfYearEpochMs(epochMs: Int64) -> Int64 {
    let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
    let cal = UtcCalendarHolder.shared
    let y = cal.component(.year, from: date)
    var c = DateComponents()
    c.year = y
    c.month = 1
    c.day = 1
    c.hour = 0
    c.minute = 0
    c.second = 0
    guard let start = cal.date(from: c) else { return epochMs }
    return Int64(start.timeIntervalSince1970 * 1000)
}

nonisolated func formatLocalDateTime(epochMs: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt.string(from: date)
}

/// Sunday (UTC) of the week that starts on `mondayIso` (yyyy-MM-dd).
nonisolated func weekSundayUtc(mondayIso: String) -> String {
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    guard let monday = fmt.date(from: mondayIso),
          let sunday = UtcCalendarHolder.shared.date(byAdding: .day, value: 6, to: monday)
    else { return mondayIso }
    return dayKeyUtc(epochMs: Int64(sunday.timeIntervalSince1970 * 1000))
}

nonisolated func heatmapMonthShortUtc(mondayIso: String) -> String {
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    guard let date = fmt.date(from: mondayIso) else { return "" }
    let out = DateFormatter()
    out.calendar = UtcCalendarHolder.shared
    out.timeZone = TimeZone(identifier: "UTC")
    out.locale = Locale(identifier: "en_US_POSIX")
    out.dateFormat = "MMM"
    return out.string(from: date)
}

nonisolated func heatmapYearUtc(mondayIso: String) -> String {
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    guard let date = fmt.date(from: mondayIso) else { return "" }
    return String(UtcCalendarHolder.shared.component(.year, from: date))
}

nonisolated func heatmapWeekOfYearUtc(mondayIso: String) -> Int {
    let fmt = DateFormatter()
    fmt.calendar = UtcCalendarHolder.shared
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    guard let date = fmt.date(from: mondayIso) else { return 0 }
    var cal = UtcCalendarHolder.shared
    cal.firstWeekday = 2
    cal.minimumDaysInFirstWeek = 4
    return cal.component(.weekOfYear, from: date)
}

nonisolated func heatmapColumnYear(mondayIso: String) -> Int {
    Int(mondayIso.prefix(4)) ?? 0
}
