//
//  BackupAnalysis.swift
//  Freestand Diagnostics
//

import Foundation

nonisolated let expectedTopLevelKeys: Set<String> = [
    "cardio",
    "coldBathSessions",
    "exercises",
    "exportedAt",
    "schemaVersion",
    "stretchSessions",
    "theories",
    "theoryVersions",
]

struct DuplicateIdReport: Sendable {
    let arrayName: String
    let duplicateCount: Int
}

struct ModalitySummary: Sendable {
    let label: String
    let countLabel: String
    let count: Int
    let totalRecordedSeconds: Int64?
    let dateFieldLabel: String
    let dateStartMs: Int64?
    let dateEndMs: Int64?
}

struct BackupAnalysisResult: Sendable {
    let export: FreeStandExport
    let topLevelKeysMatch: Bool
    let missingKeys: Set<String>
    let extraKeys: Set<String>
    let schemaVersionOk: Bool
    let duplicateReports: [DuplicateIdReport]
    let integrityOk: Bool
    let modalities: [ModalitySummary]
    let activeDaysUtc: Int
}

nonisolated func duplicateIdCount(ids: [String]) -> Int {
    if ids.isEmpty { return 0 }
    return ids.count - Set(ids).count
}

nonisolated func collectActiveDaysUtc(_ export: FreeStandExport) -> Set<String> {
    var days = Set<String>()
    for row in export.cardio {
        if let ms = row.exerciseDate { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    for row in export.exercises {
        if let ms = row.originalTimestamp { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    for row in export.stretchSessions {
        if let ms = row.sessionDate { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    for row in export.coldBathSessions {
        if let ms = row.sessionDate { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    return days
}

nonisolated func collectStrengthActiveDaysUtc(_ export: FreeStandExport) -> Set<String> {
    var days = Set<String>()
    for row in export.exercises {
        if let ms = row.originalTimestamp, ms > 0 { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    return days
}

nonisolated func collectCardioActiveDaysUtc(_ export: FreeStandExport) -> Set<String> {
    var days = Set<String>()
    for row in export.cardio {
        if let ms = row.exerciseDate, ms > 0 { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    return days
}

nonisolated func collectStretchActiveDaysUtc(_ export: FreeStandExport) -> Set<String> {
    var days = Set<String>()
    for row in export.stretchSessions {
        if let ms = row.sessionDate, ms > 0 { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    return days
}

nonisolated func collectColdActiveDaysUtc(_ export: FreeStandExport) -> Set<String> {
    var days = Set<String>()
    for row in export.coldBathSessions {
        if let ms = row.sessionDate, ms > 0 { days.insert(dayKeyUtc(epochMs: ms)) }
    }
    return days
}

nonisolated func analyzeBackup(_ json: String) throws -> BackupAnalysisResult {
    let keys = try jsonTopLevelKeys(json)
    let missing = expectedTopLevelKeys.subtracting(keys)
    let extra = keys.subtracting(expectedTopLevelKeys)
    let topLevelKeysMatch = missing.isEmpty && extra.isEmpty

    let export = try parseExportJson(json)
    let schemaVersionOk = export.schemaVersion == 1

    let dupCardio = duplicateIdCount(ids: export.cardio.map(\.id))
    let dupExercises = duplicateIdCount(ids: export.exercises.map(\.id))
    let dupStretch = duplicateIdCount(ids: export.stretchSessions.map(\.id))
    let dupCold = duplicateIdCount(ids: export.coldBathSessions.map(\.id))
    let dupTheories = duplicateIdCount(ids: export.theories.map(\.id))
    let theoryVersionRowIds = export.theoryVersions.compactMap(\.rowId)
    let dupTheoryVersions = theoryVersionRowIds.count - Set(theoryVersionRowIds).count

    let duplicateReports = [
        DuplicateIdReport(arrayName: "cardio", duplicateCount: dupCardio),
        DuplicateIdReport(arrayName: "exercises", duplicateCount: dupExercises),
        DuplicateIdReport(arrayName: "stretchSessions", duplicateCount: dupStretch),
        DuplicateIdReport(arrayName: "coldBathSessions", duplicateCount: dupCold),
        DuplicateIdReport(arrayName: "theories", duplicateCount: dupTheories),
        DuplicateIdReport(arrayName: "theoryVersions (rowId)", duplicateCount: dupTheoryVersions),
    ].filter { $0.duplicateCount > 0 }

    let integrityOk = duplicateReports.isEmpty && schemaVersionOk && topLevelKeysMatch

    let modalities = [
        modalityCardio(export),
        modalityStrength(export),
        modalityStretch(export),
        modalityCold(export),
    ]

    let activeDaysUtc = collectActiveDaysUtc(export).count

    return BackupAnalysisResult(
        export: export,
        topLevelKeysMatch: topLevelKeysMatch,
        missingKeys: missing,
        extraKeys: extra,
        schemaVersionOk: schemaVersionOk,
        duplicateReports: duplicateReports,
        integrityOk: integrityOk,
        modalities: modalities,
        activeDaysUtc: activeDaysUtc
    )
}

nonisolated private func modalityCardio(_ export: FreeStandExport) -> ModalitySummary {
    let items = export.cardio
    let totalSec = items.compactMap(\.recordedDurationSeconds).reduce(0, +)
    let dates = items.compactMap(\.exerciseDate)
    return ModalitySummary(
        label: "Cardio",
        countLabel: "Sessions",
        count: items.count,
        totalRecordedSeconds: items.isEmpty ? nil : totalSec,
        dateFieldLabel: "exerciseDate",
        dateStartMs: dates.min(),
        dateEndMs: dates.max()
    )
}

nonisolated private func modalityStrength(_ export: FreeStandExport) -> ModalitySummary {
    let items = export.exercises
    let times = items.compactMap(\.originalTimestamp)
    return ModalitySummary(
        label: "Strength",
        countLabel: "Sets",
        count: items.count,
        totalRecordedSeconds: nil,
        dateFieldLabel: "originalTimestamp",
        dateStartMs: times.min(),
        dateEndMs: times.max()
    )
}

nonisolated private func modalityStretch(_ export: FreeStandExport) -> ModalitySummary {
    let items = export.stretchSessions
    let totalSec = items.compactMap(\.recordedDurationSeconds).reduce(0, +)
    let dates = items.compactMap(\.sessionDate)
    return ModalitySummary(
        label: "Stretch",
        countLabel: "Sessions",
        count: items.count,
        totalRecordedSeconds: items.isEmpty ? nil : totalSec,
        dateFieldLabel: "sessionDate",
        dateStartMs: dates.min(),
        dateEndMs: dates.max()
    )
}

nonisolated private func modalityCold(_ export: FreeStandExport) -> ModalitySummary {
    let items = export.coldBathSessions
    let totalSec = items.compactMap(\.recordedDurationSeconds).reduce(0, +)
    let dates = items.compactMap(\.sessionDate)
    return ModalitySummary(
        label: "Cold bath",
        countLabel: "Sessions",
        count: items.count,
        totalRecordedSeconds: items.isEmpty ? nil : totalSec,
        dateFieldLabel: "sessionDate",
        dateStartMs: dates.min(),
        dateEndMs: dates.max()
    )
}
