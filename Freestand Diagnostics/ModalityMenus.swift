//
//  ModalityMenus.swift
//

import SwiftUI

struct MoreActivityStatsMenu: View {
    let export: FreeStandExport
    let activeDaysUtc: Int
    let onOpenDetail: (Int) -> Void

    private var rows: [(label: String, count: Int, index: Int)] {
        [
            ("Strength", export.exercises.count, 0),
            ("Cardio", export.cardio.count, 1),
            ("Stretch", export.stretchSessions.count, 2),
            ("Cold bath", export.coldBathSessions.count, 3),
            ("Activity overview", activeDaysUtc, 4),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity stats overall")
                    .font(.title2.weight(.semibold))
                Text("Choose a modality to open its tables.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    HStack {
                        Text("Modality").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Count").frame(width: 88, alignment: .trailing)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Divider()
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        Button {
                            onOpenDetail(r.index)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.label)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if r.index == 4 {
                                        Text("Cross-modality volume, session days, and streaks")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(r.count)")
                                    .font(.body.monospacedDigit())
                                    .frame(width: 88, alignment: .trailing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        if i < rows.count - 1 { Divider() }
                    }
                }
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
    }
}

struct ChartsModalityMenu: View {
    let export: FreeStandExport
    let activeDaysUtc: Int
    let onOpenDetail: (Int) -> Void

    private var rows: [(label: String, count: Int, index: Int)] {
        [
            ("Strength", export.exercises.count, 0),
            ("Cardio", export.cardio.count, 1),
            ("Stretch", export.stretchSessions.count, 2),
            ("Cold bath", export.coldBathSessions.count, 3),
            ("Activity overview", activeDaysUtc, 4),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Charts")
                    .font(.title2.weight(.semibold))
                Text("Pick a modality for chart views derived from this backup.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    HStack {
                        Text("Modality").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Count").frame(width: 88, alignment: .trailing)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Divider()
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        Button {
                            onOpenDetail(r.index)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.label)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if r.index == 4 {
                                        Text("Heatmap, weekly modality bars, strength vs cardio")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(r.count)")
                                    .font(.body.monospacedDigit())
                                    .frame(width: 88, alignment: .trailing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        if i < rows.count - 1 { Divider() }
                    }
                }
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
    }
}
