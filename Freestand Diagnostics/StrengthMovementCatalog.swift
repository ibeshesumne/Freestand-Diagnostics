//
//  StrengthMovementCatalog.swift
//

import Foundation

enum StrengthMovementTag: String, CaseIterable, Sendable {
    case push = "Push"
    case pull = "Pull"
    case legsHinge = "Legs — hinge"
    case legsKnee = "Legs — squat / knee"
    case core = "Core"
    case carry = "Carry / locomotion"
    case other = "Other / unmapped"
}

private let legsHingeKeys = [
    "deadlift", "rdl", "romanian", "stiff leg", "good morning",
    "hip thrust", "glute bridge", "back extension", "hyperextension",
]
private let legsKneeKeys = [
    "squat", "leg press", "lunge", "hack squat", "split squat",
    "leg extension", "leg curl", "calf", "sissy squat", "step up",
    "goblet squat", "front squat", "bulgarian",
]
private let pullKeys = [
    "row", "pulldown", "pull-up", "pullup", "chin-up", "chinup",
    "lat ", "face pull", "shrug", "curl", "hammer", "preacher",
    "reverse fly", "rear delt",
]
private let pushKeys = [
    "bench", "press", "fly", "push-up", "pushup", "dip",
    "tricep", "triceps", "skull", "overhead", "ohp", "incline", "decline",
]
private let coreKeys = [
    "plank", "ab ", "abs", "crunch", "sit-up", "situp", "leg raise",
    "pallof", "dead bug", "cable wood", "rotation", "oblique",
]
private let carryKeys = [
    "carry", "walk", "farmer", "suitcase", "yoke",
]

private extension String {
    func normalizedForMatch() -> String {
        lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

func strengthMovementTagForExerciseName(_ exerciseName: String?) -> StrengthMovementTag {
    let n = exerciseName?.normalizedForMatch() ?? ""
    if n.isEmpty { return .other }
    if legsHingeKeys.contains(where: { n.contains($0) }) { return .legsHinge }
    if legsKneeKeys.contains(where: { n.contains($0) }) { return .legsKnee }
    if pullKeys.contains(where: { n.contains($0) }) { return .pull }
    if pushKeys.contains(where: { n.contains($0) }) { return .push }
    if coreKeys.contains(where: { n.contains($0) }) { return .core }
    if carryKeys.contains(where: { n.contains($0) }) { return .carry }
    return .other
}
