//
//  ImportJsonView.swift
//

import SwiftUI

struct ImportJsonView: View {
    @Bindable var vm: BackupViewModel
    let onPickFile: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select a JSON file exported from Free Stand (same format as the main app’s backup export).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Choose backup file", action: onPickFile)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                let canClear = !vm.isLoading && (vm.analysis != nil || vm.fileName != nil || vm.errorMessage != nil)
                if canClear {
                    Button("Clear loaded backup", role: .destructive) {
                        vm.clearLoadedBackup()
                    }
                    .frame(maxWidth: .infinity)
                    Text("Use Clear loaded backup to remove the current file from memory, then choose another JSON. If a new file fails to parse, your previous backup stays loaded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if vm.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }

                if let err = vm.errorMessage {
                    Group {
                        Text(err)
                            .font(.body)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let name = vm.fileName {
                    Text("File: \(name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let analysis = vm.analysis {
                    ImportStatusSection(analysis: analysis)
                }
            }
            .padding(20)
        }
    }
}
