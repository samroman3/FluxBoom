//
//  EditHistory.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI
import SwiftData

@Model
class EditHistory: ObservableObject {
    var timestamp: Date = Date()
    var prompt: String
    var maskUrl: String
    var width: Int
    var height: Int
    var strength: Float
    var numOutputs: Int
    var outputFormat: String
    var guidanceScale: Float
    var outputQuality: Int
    var numInferenceSteps: Int
    
    // Relationship back to GeneratedImage
    @Relationship(inverse: \GeneratedImage.editHistory) var generatedImage: GeneratedImage?
    
    init(prompt: String, maskUrl: String, width: Int, height: Int, strength: Float, numOutputs: Int, outputFormat: String, guidanceScale: Float, outputQuality: Int, numInferenceSteps: Int, generatedImage: GeneratedImage?) {
        self.prompt = prompt
        self.maskUrl = maskUrl
        self.width = width
        self.height = height
        self.strength = strength
        self.numOutputs = numOutputs
        self.outputFormat = outputFormat
        self.guidanceScale = guidanceScale
        self.outputQuality = outputQuality
        self.numInferenceSteps = numInferenceSteps
        self.generatedImage = generatedImage
    }
}
