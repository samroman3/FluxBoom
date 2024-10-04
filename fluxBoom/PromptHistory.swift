//
//  PromptHistory.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI
import SwiftData

@Model
class PromptHistory: ObservableObject {
    var model: String
    var prompt: String
    var guidance: Double
    var aspectRatio: String?
    var steps: Double
    var interval: Double
    var safetyTolerance: Double
    var seed: Int?
    var outputFormat: String
    var outputQuality: Double
    var disableSafetyChecker: Bool
    var imageUrl: String?     // Optional image URL for inpainting
    var mask: Data?           // Optional mask for inpainting
    var timestamp: Date = Date()
    
    // Relationship back to GeneratedImage
    @Relationship(inverse: \GeneratedImage.promptHistory) var generatedImage: GeneratedImage?
    
    init(model: String, prompt: String, guidance: Double, aspectRatio: String? = nil, steps: Double, interval: Double, safetyTolerance: Double, seed: Int? = nil, outputFormat: String, outputQuality: Double, disableSafetyChecker: Bool, imageUrl: String? = nil, mask: Data? = nil, generatedImage: GeneratedImage?) {
        self.model = model
        self.prompt = prompt
        self.guidance = guidance
        self.aspectRatio = aspectRatio
        self.steps = steps
        self.interval = interval
        self.safetyTolerance = safetyTolerance
        self.seed = seed
        self.outputFormat = outputFormat
        self.outputQuality = outputQuality
        self.disableSafetyChecker = disableSafetyChecker
        self.imageUrl = imageUrl
        self.mask = mask
        self.generatedImage = generatedImage
    }
}

