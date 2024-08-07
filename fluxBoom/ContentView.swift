//
//  ContentView.swift
//  fluxBoom
//
//  Created by Sam Roman on 8/6/24.
//

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \GeneratedImage.timestamp, order: .reverse) private var generatedImages: [GeneratedImage]
    @Query(sort: \PromptHistory.timestamp, order: .reverse) private var promptHistory: [PromptHistory]
    
    @State private var selectedModel = "Flux Pro"
    @State private var prompt: String = ""
    @State private var guidance: Double = 3.0
    @State private var aspectRatio: String = "1:1"
    @State private var steps: Double = 25
    @State private var interval: Double = 2.0
    @State private var safetyTolerance: Double = 2
    
    // Flux Schnell specific inputs
    @State private var seed: Int? = nil
    @State private var outputFormat: String = "webp"
    @State private var outputQuality: Double = 80
    @State private var disableSafetyChecker: Bool = false
    
    @State private var isLoading: Bool = false
    @State private var predictionStatus: String = ""
    @State private var errorMessage: String = ""
    @State private var navigateToGallery: Bool = false
    @State private var symbolPosition: CGPoint = .zero
    @State private var symbolFinalPosition: CGPoint = .zero
    @State private var isSymbolAtFinalPosition: Bool = false
    
    @State private var isKeyboardVisible: Bool = false
    @FocusState private var isPromptFocused: Bool
    
    @State private var apiKey: String = ""
    @State private var isApiKeyValid: Bool = true
    @State private var showApiKeyModal: Bool = false
    @State private var showSavedMessage: Bool = false
    
    let models = ["Flux Pro", "Flux Schnell"]
    let aspectRatios = ["1:1", "16:9", "21:9", "2:3", "3:2", "4:5", "5:4", "9:16", "9:21"]
    let outputFormats = ["webp", "jpg", "png"]
    
    @State private var selectedTab: Int = 1 // Default to the second tab (Generate)

    var body: some View {
        NavigationStack {
            VStack {
                modelSelector
                
                if isLoading {
                    loadingView
                        .transition(.opacity)
                }
                else {
                    TabView(selection: $selectedTab) {
                        VStack {
                            if selectedModel == "Flux Pro" {
                                fluxProInputs
                            } else if selectedModel == "Flux Schnell" {
                                fluxSchnellInputs
                            }
                        }
                        .padding()
                        .tabItem {
                            Text("Settings")
                        }
                        .tag(0)
                        
                        VStack {
                            Spacer()
                            promptInput
                            generateButton
                            if !errorMessage.isEmpty {
                                Text("Error: \(errorMessage)")
                                    .foregroundColor(.red)
                                    .padding()
                            }
                            Spacer()
                        }
                        .tabItem {
                            Text("Generate")
                        }
                        .tag(1)
                        
                        VStack {
                            promptHistoryView
                        }
                        .tabItem {
                            Text("History")
                        }
                        .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never))
                }
                Spacer()
            }
            .navigationDestination(isPresented: $navigateToGallery) {
                PhotoGalleryView(generatedImages: generatedImages, modelContext: _modelContext)
            }
            .overlay(keyboardToolbar, alignment: .bottom)
            .onAppear {
                loadApiKey() // Load the API key when the view appears
                selectedTab = 1 // Set the default tab to "Generate"
            }
            .onReceive(Publishers.keyboardHeight) { height in
                isKeyboardVisible = height > 0
            }
        }
        .sheet(isPresented: $showApiKeyModal) {
            apiKeyModal
        }
        .overlay(
            Group {
                if showSavedMessage {
                    Text("Saved")
                        .font(.headline)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.scale)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                withAnimation {
                                    showSavedMessage = false
                                }
                            }
                        }
                    Spacer()

                }
            }
        )
    }
    
    var loadingView: some View {
        VStack {
            Spacer()
            
            Text(predictionStatus)
                .padding()
                .font(.largeTitle)
                .foregroundColor(.primary)
            
            Spacer()
            
            CombinedSymbolView(isAnimated: true, isLoading: true, prompt: $prompt)
            
            Button(action: cancelPrediction) {
                Text("Cancel")
                    .padding()
                    .foregroundColor(.gray)
                    .cornerRadius(10)
            }
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var apiKeyModal: some View {
        VStack {
            Text("Replicate API Key")
                .font(.headline)
            TextField("API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: {
                saveApiKey()
                withAnimation {
                    showSavedMessage = true
                }
                showApiKeyModal = false
            }) {
                Text("Save")
                    .padding()
                    .foregroundColor(.white)
                    .background(apiKey.isEmpty ? Color.gray : Color.purple)
                    .cornerRadius(10)
            }
            .disabled(apiKey.isEmpty)
        }
        .padding()
    }
    
    var modelSelector: some View {
        HStack {
            if !isLoading {
                Button(action: {
                    showApiKeyModal = true
                }) {
                    Image(systemName: "key.fill")
                        .padding()
                        .cornerRadius(10)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            Menu {
                Picker("Model", selection: $selectedModel) {
                    ForEach(models, id: \.self) {
                        Text($0)
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    Text(selectedModel)
                        .font(.largeTitle)
                        .foregroundColor(.primary)
                    Image(systemName:"chevron.up.chevron.down")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.5 : 1)
            
            Spacer()
            
            if !isLoading {
                NavigationLink(destination: PhotoGalleryView(generatedImages: generatedImages, modelContext: _modelContext)) {
                    Image(systemName: "photo.stack")
                        .padding()
                        .cornerRadius(10)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
    }
    
    
    var promptInput: some View {
        VStack {
            TextField("Enter prompt", text: $prompt,axis: .vertical)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple.opacity(brightnessFactor), .blue.opacity(brightnessFactor)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .mask(RoundedRectangle(cornerRadius: 10))
                )
                .padding(3)
                .background(Color.clear)
                .cornerRadius(10)
                .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .lineLimit(12)
                .frame(width: UIScreen.main.bounds.width * 0.75)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isPromptFocused)
                .multilineTextAlignment(.center)
                .lineLimit(0...6)
                .padding()
        }
    }

    private var brightnessFactor: Double {
        let maxCharacters = 20.0
        let currentCharacters = Double(prompt.count)
        return min(currentCharacters / maxCharacters, 1.0)
    }

    
    var generateButton: some View {
        Button(action: {
            withAnimation {
                generateImage()
            }
        }) {
            CombinedSymbolView(isAnimated: isLoading, isLoading: false, prompt: $prompt)
                .opacity(prompt.isEmpty ? 0.5 : 1.0)
        }
        .disabled(prompt.isEmpty)
        .padding()
        .background(GeometryReader { geometry in
            Color.clear.onAppear {
                self.symbolPosition = CGPoint(x: geometry.frame(in: .global).midX, y: geometry.frame(in: .global).midY)
            }
        })
    }
    
    var fluxProInputs: some View {
        Group {
            sliderInput(title: "Guidance:", value: $guidance, range: 2...5, step: 0.1)
            sliderInput(title: "Steps:", value: $steps, range: 1...50, step: 1)
            sliderInput(title: "Interval:", value: $interval, range: 1...4, step: 0.1)
            sliderInput(title: "Safety Tolerance:", value: $safetyTolerance, range: 1...5, step: 1)
        }
    }
    
    var fluxSchnellInputs: some View {
        Group {
            HStack {
                Text("Seed:")
                TextField("Random seed (optional)", value: $seed, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Picker("Output Format", selection: $outputFormat) {
                ForEach(outputFormats, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if outputFormat != "png" {
                sliderInput(title: "Output Quality:", value: $outputQuality, range: 0...100, step: 1)
            }
            
            Toggle("Disable Safety Checker", isOn: $disableSafetyChecker)
                .toggleStyle(SwitchToggleStyle(tint: .purple))
        }.padding()
    }
    
    var promptHistoryView: some View {
        List {
            ForEach(promptHistory) { history in
                VStack(alignment: .leading) {
                    Text("Model: \(history.model)")
                    Text("Prompt: \(history.prompt)")
                    Text("Guidance: \(history.guidance)")
                    Text("Aspect Ratio: \(history.aspectRatio)")
                    Text("Steps: \(history.steps)")
                    Text("Interval: \(history.interval)")
                    Text("Safety Tolerance: \(history.safetyTolerance)")
                    Text("Seed: \(history.seed ?? 0)")
                    Text("Output Format: \(history.outputFormat)")
                    Text("Output Quality: \(history.outputQuality)")
                    Text("Disable Safety Checker: \(history.disableSafetyChecker ? "Yes" : "No")")
                }
                .padding()
            }
        }
        .padding()
    }
    
    func sliderInput(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(.primary)
                .font(.title2)
            HStack(alignment: .center) {
            CustomSlider(value: value, range: range, step: step)
        }
        }
    }
    
    func loadApiKey() {
        if let storedKey = KeychainHelper.shared.retrieve(key: "apiKey") {
            apiKey = storedKey
        }
    }
    
    func saveApiKey() {
        if validateApiKey(apiKey) {
            KeychainHelper.shared.save(key: "apiKey", value: apiKey)
            isApiKeyValid = true
            print(apiKey)
        } else {
            isApiKeyValid = false
        }
    }
    
    func validateApiKey(_ key: String) -> Bool {
        // Placeholder validation logic for the API key
        return !key.isEmpty && key.count >= 10 // Example: minimum length
    }
    
    func generateImage() {
        guard !prompt.isEmpty else { return }
        guard isApiKeyValid else {
            errorMessage = "Please enter a valid API key."
            return
        }
        isLoading = true
        predictionStatus = "Starting prediction..."
        errorMessage = ""
        isSymbolAtFinalPosition = false

        symbolFinalPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)

        withAnimation(.spring()) {
            isSymbolAtFinalPosition = true
        }

        var parameters: [String: Any] = [
            "prompt": prompt,
            "aspect_ratio": aspectRatio
        ]

        if selectedModel == "Flux Pro" {
            parameters["steps"] = Int(steps)
            parameters["guidance"] = guidance
            parameters["interval"] = interval
            parameters["safety_tolerance"] = Int(safetyTolerance)
        } else if selectedModel == "Flux Schnell" {
            if let seed = seed {
                parameters["seed"] = seed
            }
            parameters["output_format"] = outputFormat
            if outputFormat != "png" {
                parameters["output_quality"] = Int(outputQuality)
            }
            parameters["disable_safety_checker"] = disableSafetyChecker
        }

        NetworkManager.shared.createPrediction(model: selectedModel, parameters: parameters) { result in
            switch result {
            case .success(let predictionId):
                self.trackPrediction(predictionId: predictionId)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.resetSymbolPosition()
                }
            }
        }
    }

    func trackPrediction(predictionId: String) {
        DispatchQueue.global().async {
            var status: String = ""
            repeat {
                NetworkManager.shared.getPredictionStatus(predictionId: predictionId) { result in
                    switch result {
                    case .success(let newStatus):
                        status = newStatus
                        DispatchQueue.main.async {
                            self.predictionStatus = "Status: \(newStatus.capitalized)"
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
                sleep(2)
            } while status != "succeeded" && status != "failed"

            DispatchQueue.main.async {
                self.isLoading = false
                if status == "succeeded" {
                    NetworkManager.shared.getPredictionOutput(predictionId: predictionId, model: self.selectedModel, context: self.modelContext) { result in
                        switch result {
                        case .success(_):
                            self.predictionStatus = "Image successfully generated"
                            self.savePromptHistory()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                self.navigateToGallery = true
                            }
                        case .failure(let error):
                            self.errorMessage = error.localizedDescription
                        }
                    }
                } else {
                    self.errorMessage = "Prediction failed"
                }
            }
        }
    }


    func cancelPrediction() {
        guard let predictionId = NetworkManager.shared.currentPredictionId else { return }
        NetworkManager.shared.cancelPrediction(predictionId: predictionId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    withAnimation {
                        self.isLoading = false
                        self.predictionStatus = "Prediction cancelled"
                        self.resetSymbolPosition()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func savePromptHistory() {
        let newHistory = PromptHistory(
            model: selectedModel,
            prompt: prompt,
            guidance: guidance,
            aspectRatio: aspectRatio,
            steps: steps,
            interval: interval,
            safetyTolerance: safetyTolerance,
            seed: seed,
            outputFormat: outputFormat,
            outputQuality: outputQuality,
            disableSafetyChecker: disableSafetyChecker
        )
        modelContext.insert(newHistory)
        try? modelContext.save()
    }

    
    func resetSymbolPosition() {
        withAnimation(.spring()) {
            isSymbolAtFinalPosition = false
        }
    }
    
    var keyboardToolbar: some View {
        VStack {
            Spacer()
            if isKeyboardVisible {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isPromptFocused = false
                        }
                    }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .foregroundColor(.primary)
                            .padding()
                    }
                }
                .frame(height: 44)
                .background(Color.clear)
                .transition(.move(edge: .bottom))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    
    @State private var sliderWidth: CGFloat = 0
    
    var body: some View {
        VStack {
            HStack {
                TextField("", value: $value, formatter: numberFormatter)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 50)
                    .font(.title2)
                    .padding(.trailing, 10)
                    .onChange(of: value) { newValue in
                        value = clampValue(newValue)
                    }

                
                ZStack(alignment: .leading) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 6)
                            .cornerRadius(3)
                            
                            Circle()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                                .shadow(color: Color.purple.opacity(0.5), radius: 5, x: 0, y: 5)
                                .offset(x: self.xOffset(in: geometry))
                                .gesture(
                                    DragGesture()
                                        .onChanged { gesture in
                                            self.value = self.valueFrom(offset: gesture.location.x, in: geometry)
                                        }
                                )
                        }
                    }
                }
                .frame(height: 20)
                .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            self.value = self.clampValue(self.value)
        }
    }
    
    private func xOffset(in geometry: GeometryProxy) -> CGFloat {
        let clampedValue = clampValue(value)
        let width = geometry.size.width
        return CGFloat((clampedValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * width - 10 // -10 to center the thumb
    }
    
    private func valueFrom(offset: CGFloat, in geometry: GeometryProxy) -> Double {
        let width = geometry.size.width
        let ratio = max(0, min(1, offset / width))
        let newValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
        return round(newValue / step) * step
    }
    
    private func clampValue(_ value: Double) -> Double {
        return min(max(value, range.lowerBound), range.upperBound)
    }
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = range.lowerBound as NSNumber
        formatter.maximum = range.upperBound as NSNumber
        return formatter
    }
}

struct CustomSlider_Previews: PreviewProvider {
    @State static var sliderValue = 50.0
    
    static var previews: some View {
        CustomSlider(value: $sliderValue, range: 0...100, step: 1)
    }
}




struct CombinedSymbolView: View {
    var isAnimated: Bool
    var isLoading: Bool
    @Binding var prompt: String
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            gradientOverlay
                .mask(
                    ZStack {
                        Image(systemName: "triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .rotation3DEffect(
                                .degrees(rotationAngle),
                                axis: (x: 5, y: 0, z: 2)
                            )
                        Image(systemName: "triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .rotation3DEffect(
                                .degrees(-rotationAngle),
                                axis: (x: 0, y: 5, z: 2)
                            )
                        Image(systemName: "sparkles")
                            .resizable()
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .rotation3DEffect(
                                .degrees(rotationAngle),
                                axis: (x: 1, y: 0, z: 2)
                            )
                    }
                )
                .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 10)
        }
        .frame(width: 150, height: 150)
        .onAppear {
            if isAnimated {
                startAnimating()
            }
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [.purple.opacity(brightnessFactor), .blue.opacity(brightnessFactor)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var brightnessFactor: Double {
        let maxCharacters = 20.0
        let currentCharacters = Double(prompt.count)
        return isLoading ? 1.0 : min(currentCharacters / maxCharacters, 1.0)
    }

    private func startAnimating() {
        let duration = isLoading ? 1.0 : (2.0 - brightnessFactor)
        withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}

struct CombinedSymbolView_Previews: PreviewProvider {
    @State static var previewPrompt = "Sample prompt"
    static var previews: some View {
        CombinedSymbolView(isAnimated: true, isLoading: true, prompt: $previewPrompt)
    }
}






extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }
        
        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

extension Notification {
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}



import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PhotoGalleryView: View {
    @State var generatedImages: [GeneratedImage]
    @Environment(\.modelContext) var modelContext: ModelContext
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(generatedImages) { image in
                    if let uiImage = UIImage(data: image.imageData) {
                        NavigationLink(destination: ImageDetailView(image: uiImage, imageEntity: image, modelContext: _modelContext)) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                        }
                    }
                }
            }
        }
        .navigationTitle("Gallery")
        .padding()
    }
}

struct ImageDetailView: View {
    let image: UIImage
    let imageEntity: GeneratedImage
    @Environment(\.modelContext) var modelContext: ModelContext
    @Environment(\.dismiss) var dismiss
    @State private var isDeleted: Bool = false
    @State private var showingSaveStatus: Bool = false
    @State private var saveStatusMessage: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                if !isDeleted {
                    HStack(spacing: 20) {
                        Button(action: shareImage) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Button(action: deleteImage) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.red.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                }
            }
        }
        .overlay(
            Group {
                if showingSaveStatus {
                    Text(saveStatusMessage)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        )
        .animation(.easeInOut, value: showingSaveStatus)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func shareImage() {
        let imageSaver = ImageSaver()
        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("shared_image.jpg")
            try? jpegData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
        } else {
            saveStatusMessage = "Error preparing image for sharing"
            showSaveStatus()
        }
    }
    
    func deleteImage() {
        withAnimation {
            isDeleted = true
            modelContext.delete(imageEntity)
            try? modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
    
    func showSaveStatus() {
        withAnimation {
            showingSaveStatus = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSaveStatus = false
            }
        }
    }
}

class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveComplete), nil)
    }

    @objc func saveComplete(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            errorHandler?(error)
        } else {
            successHandler?()
        }
    }
}

@Model
class GeneratedImage {
    @Attribute var id: UUID
    @Attribute var imageData: Data
    @Attribute var timestamp: Date

    init(id: UUID = UUID(), imageData: Data, timestamp: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.timestamp = timestamp
    }
}

import SwiftData
import SwiftUI


@Model
class PromptHistory {
    @Attribute var id: UUID
    @Attribute var model: String
    @Attribute var prompt: String
    @Attribute var guidance: Double
    @Attribute var aspectRatio: String
    @Attribute var steps: Double
    @Attribute var interval: Double
    @Attribute var safetyTolerance: Double
    @Attribute var seed: Int?
    @Attribute var outputFormat: String
    @Attribute var outputQuality: Double
    @Attribute var disableSafetyChecker: Bool
    @Attribute var timestamp: Date

    init(id: UUID = UUID(), model: String, prompt: String, guidance: Double, aspectRatio: String, steps: Double, interval: Double, safetyTolerance: Double, seed: Int?, outputFormat: String, outputQuality: Double, disableSafetyChecker: Bool, timestamp: Date = Date()) {
        self.id = id
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
        self.timestamp = timestamp
    }
}


class NetworkManager {
    static let shared = NetworkManager()
      private init() {}

      private let baseUrl = "https://api.replicate.com/v1/models/"
      
      private let modelEndpoints = [
          "Flux Pro": "black-forest-labs/flux-pro/predictions",
          "Flux Schnell": "black-forest-labs/flux-schnell/predictions"
      ]

      var currentPredictionId: String?

      func createPrediction(model: String, parameters: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
          guard let apiKey = KeychainHelper.shared.retrieve(key: "apiKey") else {
                  completion(.failure(NSError(domain: "API Key Missing", code: 401, userInfo: nil)))
                  return
              }
              
          guard let endpoint = modelEndpoints[model],
                let url = URL(string: baseUrl + endpoint) else {
              completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid model or URL"])))
              return
          }

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          let finalParameters: [String: Any] = ["input": parameters]

          guard let httpBody = try? JSONSerialization.data(withJSONObject: finalParameters, options: []) else {
              completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize parameters"])))
              return
          }
          request.httpBody = httpBody

          let task = URLSession.shared.dataTask(with: request) { data, response, error in
              if let error = error {
                  print("Create Prediction Error: \(error.localizedDescription)")
                  completion(.failure(error))
                  return
              }

              guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                  print("Create Prediction: No data or invalid response")
                  completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                  return
              }

              print("Create Prediction HTTP Status: \(httpResponse.statusCode)")

              do {
                  if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                      print("Create Prediction Response JSON: \(jsonResponse)")

                      if let predictionId = jsonResponse["id"] as? String {
                          self.currentPredictionId = predictionId
                          completion(.success(predictionId))
                      } else if let errorMessage = jsonResponse["detail"] as? String {
                          completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                      } else {
                          completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                      }
                  } else {
                      completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse JSON"])))
                  }
              } catch {
                  completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON parsing error: \(error.localizedDescription)"])))
              }
          }

          task.resume()
      }

    func getPredictionStatus(predictionId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)")!
        guard let apiKey = KeychainHelper.shared.retrieve(key: "apiKey") else {
                completion(.failure(NSError(domain: "API Key Missing", code: 401, userInfo: nil)))
                return
            }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(String(describing: apiKey))", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Get Prediction Status Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("Get Prediction Status: No data or invalid response")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            print("Get Prediction Status HTTP Status: \(httpResponse.statusCode)")

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Get Prediction Status Response JSON: \(jsonResponse)")

                    if let status = jsonResponse["status"] as? String {
                        completion(.success(status))
                    } else if let errorMessage = jsonResponse["detail"] as? String {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    } else {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid status response format"])))
                    }
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse status JSON"])))
                }
            } catch {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Status JSON parsing error: \(error.localizedDescription)"])))
            }
        }

        task.resume()
    }
    func getPredictionOutput(predictionId: String, model: String, context: ModelContext, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let url = URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)")!
        guard let apiKey = KeychainHelper.shared.retrieve(key: "apiKey") else {
            completion(.failure(NSError(domain: "API Key Missing", code: 401, userInfo: nil)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Get Prediction Output Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("Get Prediction Output: No data or invalid response")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            print("Get Prediction Output HTTP Status: \(httpResponse.statusCode)")

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Get Prediction Output Response JSON: \(jsonResponse)")

                    if model == "Flux Schnell" {
                        // Handle array of URLs
                        if let outputArray = jsonResponse["output"] as? [String],
                           let outputUrlString = outputArray.first,
                           let imageUrl = URL(string: outputUrlString),
                           let imageData = try? Data(contentsOf: imageUrl),
                           let image = UIImage(data: imageData) {

                            DispatchQueue.main.async {
                                let newImage = GeneratedImage(imageData: imageData)
                                context.insert(newImage)
                                try? context.save()
                                completion(.success(image))
                            }
                        } else {
                            self.handleOutputError(jsonResponse, completion: completion)
                        }
                    } else {
                        // Handle single URL
                        if let outputUrlString = jsonResponse["output"] as? String,
                           let imageUrl = URL(string: outputUrlString),
                           let imageData = try? Data(contentsOf: imageUrl),
                           let image = UIImage(data: imageData) {

                            DispatchQueue.main.async {
                                let newImage = GeneratedImage(imageData: imageData)
                                context.insert(newImage)
                                try? context.save()
                                completion(.success(image))
                            }
                        } else {
                            self.handleOutputError(jsonResponse, completion: completion)
                        }
                    }
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse output JSON"])))
                }
            } catch {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Output JSON parsing error: \(error.localizedDescription)"])))
            }
        }

        task.resume()
    }

    func handleOutputError(_ jsonResponse: [String: Any], completion: @escaping (Result<UIImage, Error>) -> Void) {
        if let errorMessage = jsonResponse["detail"] as? String {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
        } else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid output response format"])))
        }
    }


    func cancelPrediction(predictionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)/cancel")!
        guard let apiKey = KeychainHelper.shared.retrieve(key: "apiKey") else {
                completion(.failure(NSError(domain: "API Key Missing", code: 401, userInfo: nil)))
                return
            }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(String(describing: apiKey))", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Cancel Prediction Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Cancel Prediction: Invalid response")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response received"])))
                return
            }

            print("Cancel Prediction HTTP Status: \(httpResponse.statusCode)")

            completion(.success(()))
        }

        task.resume()
    }
    
    
}
