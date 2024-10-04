//
//  GeneratedImage.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI
import SwiftData

@Model
class GeneratedImage: ObservableObject {
    @Attribute var id: UUID
    @Attribute var originalImageData: Data   // Store original image data
    @Attribute var editedImageData: [Data]?  // Store edited images
    @Attribute var timestamp: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var editHistory: [EditHistory] = []
    @Relationship(deleteRule: .cascade) var promptHistory: [PromptHistory] = []
    
    
    
    init(id: UUID = UUID(), originalImageData: Data, editedImageData: [Data]? = nil, editHistory: [EditHistory]? = nil, timestamp: Date = Date()) {
        self.id = id
        self.originalImageData = originalImageData
        self.editedImageData = editedImageData
        self.editHistory = editHistory ?? []
        self.timestamp = timestamp
    }
}
