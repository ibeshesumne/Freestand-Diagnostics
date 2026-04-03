//
//  ExportModels.swift
//  Freestand Diagnostics
//
//  DTOs matching Free Stand JSON export (Gson field names).
//

import Foundation

extension String {
    /// Module default isolation is MainActor; analytics and JSON parsing call this from `nonisolated` code.
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}

nonisolated struct ExerciseDTO: Codable, Sendable, Identifiable {
    let id: String
    let set: Int?
    let rep: Int?
    let load: Double?
    let exercisename: String?
    let unit: String?
    let comments: String?
    let originalTimestamp: Int64?
    let modifiedTimestamp: Int64?
}

nonisolated struct CardioDTO: Codable, Sendable, Identifiable {
    let id: String
    let exerciseType: String?
    let exercisename: String?
    let set: Int?
    let plannedDurationSeconds: Int?
    let intensityPlanned: String?
    let recordedDurationSeconds: Int64?
    let exerciseDate: Int64?
    let originalTimestamp: Int64?
    let modifiedTimestamp: Int64?
    let comments: String?
}

nonisolated struct StretchSessionDTO: Codable, Sendable, Identifiable {
    let id: String
    let stretchType: String?
    let stretchName: String?
    let set: Int?
    let plannedDurationSeconds: Int?
    let recordedDurationSeconds: Int64?
    let sessionDate: Int64?
    let originalTimestamp: Int64?
    let modifiedTimestamp: Int64?
    let comments: String?
}

nonisolated struct ColdBathSessionDTO: Codable, Sendable, Identifiable {
    let id: String
    let location: String?
    let waterTemperature: String?
    let recordedDurationSeconds: Int64?
    let sessionDate: Int64?
    let originalTimestamp: Int64?
    let modifiedTimestamp: Int64?
    let comments: String?
}

nonisolated struct TheoryDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String?
    let shortDescription: String?
    let detailedDescription: String?
    let workoutDetails: String?
    let notes: String?
    let updatedAt: Int64?
    let sortOrder: Int?
    let category: String?
}

nonisolated struct TheoryVersionDTO: Codable, Sendable {
    let rowId: Int64?
    let theoryId: String?
    let versionTimestamp: Int64?
    let name: String?
    let shortDescription: String?
    let detailedDescription: String?
    let workoutDetails: String?
    let notes: String?
    let category: String?
}

nonisolated struct FreeStandExport: Sendable {
    var schemaVersion: Int
    var exportedAt: Int64
    var exercises: [ExerciseDTO]
    var cardio: [CardioDTO]
    var stretchSessions: [StretchSessionDTO]
    var coldBathSessions: [ColdBathSessionDTO]
    var theories: [TheoryDTO]
    var theoryVersions: [TheoryVersionDTO]
}

nonisolated private struct FreeStandExportRaw: Codable {
    var schemaVersion: Int?
    var exportedAt: Int64?
    var exercises: [ExerciseDTO]?
    var cardio: [CardioDTO]?
    var stretchSessions: [StretchSessionDTO]?
    var coldBathSessions: [ColdBathSessionDTO]?
    var theories: [TheoryDTO]?
    var theoryVersions: [TheoryVersionDTO]?

    nonisolated func toExport() -> FreeStandExport {
        FreeStandExport(
            schemaVersion: schemaVersion ?? 0,
            exportedAt: exportedAt ?? 0,
            exercises: exercises ?? [],
            cardio: cardio ?? [],
            stretchSessions: stretchSessions ?? [],
            coldBathSessions: coldBathSessions ?? [],
            theories: theories ?? [],
            theoryVersions: theoryVersions ?? []
        )
    }
}

enum ExportParseError: Error, LocalizedError {
    case invalidJSON(String)
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let m): return m
        case .emptyDocument: return "Invalid JSON: empty document"
        }
    }
}

nonisolated func parseExportJson(_ json: String) throws -> FreeStandExport {
    guard let data = json.data(using: .utf8) else {
        throw ExportParseError.invalidJSON("Could not encode string as UTF-8")
    }
    let decoder = JSONDecoder()
    do {
        let raw = try decoder.decode(FreeStandExportRaw.self, from: data)
        return raw.toExport()
    } catch {
        throw ExportParseError.invalidJSON("Invalid JSON: \(error.localizedDescription)")
    }
}

nonisolated func jsonTopLevelKeys(_ json: String) throws -> Set<String> {
    guard let data = json.data(using: .utf8) else { return [] }
    let obj = try JSONSerialization.jsonObject(with: data)
    guard let dict = obj as? [String: Any] else {
        throw ExportParseError.invalidJSON("Root is not a JSON object")
    }
    return Set(dict.keys)
}
