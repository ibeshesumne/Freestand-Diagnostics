//
//  HomeView.swift
//

import SwiftUI

struct HomeView: View {
    let hasBackup: Bool
    let onExportPdf: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Home")
                    .font(.title2.weight(.semibold))

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("v\(Bundle.main.shortVersion)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.tint)
                        Text(
                            "Use Import JSON to pick a backup file from your device. Open Visualize to see the summary tables and charts for the loaded data."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(
                    hasBackup
                        ? "A backup is loaded. Open Visualize for the full summary."
                        : "No backup loaded yet. Go to Import JSON to select your export file."
                )
                .font(.body)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Share this backup as a report")
                            .font(.headline)
                        Text(
                            "Save a PDF you can open elsewhere—good for printing or archiving a text summary of the loaded backup."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if hasBackup {
                            Button("Save PDF report", action: onExportPdf)
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Import a JSON backup first — then you can export a PDF from here.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
