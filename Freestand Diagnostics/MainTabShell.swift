//
//  MainTabShell.swift
//

import SwiftUI
import UniformTypeIdentifiers

struct MainTabShell: View {
    @State private var vm = BackupViewModel()
    @State private var tab: AppTab = .home
    @State private var importJson = false
    @State private var exportPresented = false
    @State private var exportDocument: BackupExportDocument?
    @State private var exportContentType: UTType = .pdf
    @State private var exportDefaultFilename: String = "export.pdf"

    private enum AppTab: Hashable {
        case home, importJson, visualize
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(
                    hasBackup: vm.analysis != nil,
                    onExportPdf: {
                        guard let a = vm.analysis else { return }
                        presentExport(BackupExportDocument(analysis: a, sourceFileName: vm.fileName))
                    }
                )
                .navigationTitle("Free Stand Diagnostics")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Text("v\(appVersionString)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                }
                .fileExporter(
                    isPresented: $exportPresented,
                    document: exportDocument,
                    contentType: exportContentType,
                    defaultFilename: exportDefaultFilename
                ) { result in
                    if case .success = result {}
                    exportDocument = nil
                }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack {
                ImportJsonView(vm: vm, onPickFile: { importJson = true })
                    .navigationTitle("Import JSON")
            }
            .tabItem { Label("Import JSON", systemImage: "doc.badge.arrow.up") }
            .tag(AppTab.importJson)

            NavigationStack {
                VisualizeView(vm: vm)
                    .navigationTitle("Visualize")
            }
            .tabItem { Label("Visualize", systemImage: "chart.bar.fill") }
            .tag(AppTab.visualize)
        }
        .fileImporter(
            isPresented: $importJson,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.importJson(from: url)
            }
        }
    }

    private func presentExport(_ document: BackupExportDocument) {
        exportContentType = document.exportUTType
        exportDefaultFilename = document.suggestedFilename
        exportDocument = document
        exportPresented = true
    }

    private var appVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

// MARK: - FileDocument for export (single type so one `fileExporter` compiles)

struct BackupExportDocument: FileDocument {
    let analysis: BackupAnalysisResult
    let sourceFileName: String?

    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }

    init(analysis: BackupAnalysisResult, sourceFileName: String?) {
        self.analysis = analysis
        self.sourceFileName = sourceFileName
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnknown)
    }

    var exportUTType: UTType { .pdf }

    var suggestedFilename: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let stamp = fmt.string(from: Date())
        return "FreeStand_Diagnostics_\(stamp).pdf"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try pdfReportData(
            analysis: analysis,
            sourceFileName: sourceFileName,
            generatedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        return FileWrapper(regularFileWithContents: data)
    }
}
