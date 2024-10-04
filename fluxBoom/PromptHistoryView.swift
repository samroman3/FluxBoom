//
//  PromptHistoryView.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI

struct PromptHistoryView: View {
    let promptHistories: [PromptHistory]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(promptHistories) { history in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Prompt: \(history.prompt)")
                            .font(.headline)
                        Text("Model: \(history.model)")
                            .font(.subheadline)
                        Text("Guidance: \(history.guidance)")
                            .font(.subheadline)
                        Text("Steps: \(history.steps)")
                            .font(.subheadline)
                        Text("Timestamp: \(history.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Prompt History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
