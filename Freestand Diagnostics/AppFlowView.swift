//
//  AppFlowView.swift
//

import SwiftUI

struct AppFlowView: View {
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    var body: some View {
        Group {
            if hasSeenIntro {
                MainTabShell()
            } else {
                NavigationStack {
                    IntroScreen {
                        hasSeenIntro = true
                    }
                }
            }
        }
    }
}

struct IntroScreen: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Welcome")
                    .font(.title)
                Text(
                    """
                    Free Stand Diagnostics helps you inspect JSON backups exported from the Free Stand app on another device.

                    Import your backup to confirm the file structure, check for duplicate IDs, and review a clear summary of your logged activity: cardio, strength sets, stretch sessions, and cold baths. Library content (theories) is listed separately from workout logs.

                    This app is for your own records only—it does not replace medical advice.
                    """
                )
                .font(.body)
                .foregroundStyle(.secondary)
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .navigationTitle("Welcome")
    }
}
