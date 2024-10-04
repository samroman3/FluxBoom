//
//  EditHistoryView.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI

struct EditHistoryView: View {
    let editHistories: [EditHistory]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(editHistories) { history in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Prompt: \(history.prompt)")
                            .font(.headline)
                        Text("Mask URL: \(history.maskUrl)")
                            .font(.subheadline)
                        Text("Dimensions: \(history.width)x\(history.height)")
                            .font(.subheadline)
                        Text("Strength: \(history.strength)")
                            .font(.subheadline)
                        Text("Guidance Scale: \(history.guidanceScale)")
                            .font(.subheadline)
                        Text("Inference Steps: \(history.numInferenceSteps)")
                            .font(.subheadline)
                        Text("Timestamp: \(history.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Edit History")
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
