//
//  VisualizeView.swift
//

import Charts
import SwiftUI

struct VisualizeView: View {
    @Bindable var vm: BackupViewModel

    private enum VizTab: String, CaseIterable {
        case summary = "Summary"
        case tables = "Tables"
        case charts = "Charts"
    }

    @State private var tab: VizTab = .summary
    @State private var tablesDetail: Int? = nil
    @State private var chartsDetail: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(VizTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                switch tab {
                case .summary:
                    if let a = vm.analysis {
                        SummaryVisualizationContent(analysis: a)
                    } else {
                        needImport
                    }
                case .tables:
                    if vm.analysis == nil {
                        needImport
                    } else {
                        tablesStack
                    }
                case .charts:
                    if vm.analysis == nil {
                        needImport
                    } else {
                        chartsStack
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: tab) { _, new in
            if new == .summary {
                tablesDetail = nil
                chartsDetail = nil
            }
        }
        .onChange(of: vm.fileName) { _, _ in
            tablesDetail = nil
            chartsDetail = nil
        }
    }

    private var needImport: some View {
        Text("Import a JSON backup first to see visualizations.")
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var tablesStack: some View {
        if let analysis = vm.analysis {
            if let d = tablesDetail {
                ModalityDetailShell(title: modalityTitle(d), onBack: { tablesDetail = nil }) {
                    tablesContent(d, export: analysis.export)
                }
            } else {
                MoreActivityStatsMenu(export: analysis.export, activeDaysUtc: analysis.activeDaysUtc) {
                    tablesDetail = $0
                }
            }
        } else {
            needImport
        }
    }

    @ViewBuilder
    private var chartsStack: some View {
        if let analysis = vm.analysis {
            if let d = chartsDetail {
                ModalityDetailShell(title: modalityTitle(d), onBack: { chartsDetail = nil }) {
                    chartsContent(d, export: analysis.export)
                }
            } else {
                ChartsModalityMenu(export: analysis.export, activeDaysUtc: analysis.activeDaysUtc) {
                    chartsDetail = $0
                }
            }
        } else {
            needImport
        }
    }

    @ViewBuilder
    private func tablesContent(_ d: Int, export: FreeStandExport) -> some View {
        switch d {
        case 0: StrengthTablesView(exercises: export.exercises)
        case 1: CardioTablesView(cardio: export.cardio)
        case 2: StretchTablesView(sessions: export.stretchSessions)
        case 3: ColdTablesView(sessions: export.coldBathSessions)
        case 4: ActivityOverviewTablesView(export: export)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func chartsContent(_ d: Int, export: FreeStandExport) -> some View {
        switch d {
        case 0: StrengthChartsView(exercises: export.exercises)
        case 1: CardioChartsView(cardio: export.cardio)
        case 2: StretchChartsView(sessions: export.stretchSessions)
        case 3: ColdChartsView(sessions: export.coldBathSessions)
        case 4: ActivityOverviewChartsView(export: export)
        default: EmptyView()
        }
    }

    private func modalityTitle(_ d: Int) -> String {
        switch d {
        case 0: return "Strength"
        case 1: return "Cardio"
        case 2: return "Stretch"
        case 3: return "Cold bath"
        case 4: return "Activity overview"
        default: return "Activity"
        }
    }
}

private struct ModalityDetailShell<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                }
                Text(title)
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
