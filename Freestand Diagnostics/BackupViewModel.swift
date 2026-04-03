//
//  BackupViewModel.swift
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class BackupViewModel {
    var isLoading = false
    var errorMessage: String?
    var fileName: String?
    var analysis: BackupAnalysisResult?

    private var importTask: Task<Void, Never>?

    func clearLoadedBackup() {
        importTask?.cancel()
        importTask = nil
        isLoading = false
        errorMessage = nil
        fileName = nil
        analysis = nil
    }

    func importJson(from url: URL) {
        importTask?.cancel()
        importTask = Task {
            let previousAnalysis = analysis
            let previousFileName = fileName
            isLoading = true
            errorMessage = nil
            fileName = url.lastPathComponent

            do {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard let json = String(data: data, encoding: .utf8) else {
                    throw ExportParseError.invalidJSON("File is not valid UTF-8 text")
                }
                let result = try await Task.detached(priority: .userInitiated) {
                    try analyzeBackup(json)
                }.value
                if !Task.isCancelled {
                    analysis = result
                    isLoading = false
                    errorMessage = nil
                }
            } catch is CancellationError {
                return
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                analysis = previousAnalysis
                fileName = previousFileName
            }
        }
    }

    func exportPdf(to url: URL) throws {
        guard let analysis else {
            throw NSError(domain: "Backup", code: 1, userInfo: [NSLocalizedDescriptionKey: "No backup loaded"])
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        try writeBackupReportPdf(to: url, analysis: analysis, sourceFileName: fileName)
    }
}
