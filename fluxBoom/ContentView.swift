//
//  ContentView.swift
//  fluxBoom
//
//  Created by Sam Roman on 8/6/24.
//

import SwiftUI
import SwiftData
import Combine
import UIKit

struct DrawingView: View {
    @Binding var lines: [Line]
    var imageSize: CGSize
    var onDrawEnd: () -> Void
    @Binding var isEraserActive: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear

                // Draw existing lines
                ForEach(lines) { line in
                    Path { path in
                        guard let firstPoint = line.points.first else { return }
                        path.move(to: firstPoint)
                        for point in line.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(line.color, lineWidth: line.lineWidth)
                    .blendMode(.normal)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPoint = value.location
                        if isEraserActive {
                        } else {
                            if lines.isEmpty || value.predictedEndLocation != value.location {
                                lines.append(Line(points: [newPoint], color: .black, lineWidth: 20))
                            } else {
                                lines[lines.count - 1].points.append(newPoint)
                            }
                        }
                    }
                    .onEnded { _ in
                        onDrawEnd()
                    }
            )
        }
    }
}


struct Line: Identifiable {
    var id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}


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
    
    // Flux Schnell and Flux Dev specific inputs
    @State private var seed: Int? = nil
    @State private var outputFormat: String = "webp"
    @State private var outputQuality: Double = 80
    @State private var disableSafetyChecker: Bool = false
    
    // Flux Dev Inpainting specific inputs
    @State private var selectedImage: UIImage?
    @State private var maskImage: UIImage?
    @State private var fetchedImage: UIImage?
    @State private var isFetchingImage: Bool = false
    @State private var imageUrl: String = ""
    @State private var isDrawingMode: Bool = false
    @State private var isEraserActive: Bool = false
    @State private var lines: [Line] = []

    @FocusState private var isPromptFocused: Bool
    
    @State private var isLoading: Bool = false
    @State private var predictionStatus: String = ""
    @State private var errorMessage: String = ""
    @State private var navigateToGallery: Bool = false
    @State private var symbolPosition: CGPoint = .zero
    @State private var symbolFinalPosition: CGPoint = .zero
    @State private var isSymbolAtFinalPosition: Bool = false
    
    @State private var isKeyboardVisible: Bool = false
    
    @State private var apiKey: String = ""
    @State private var imgbbApiKey: String = ""
    @State private var isApiKeyValid: Bool = true
    @State private var showApiKeyModal: Bool = false
    @State private var showSavedMessage: Bool = false
    
    @State private var showPromptDetails: Bool = false
    @State private var selectedPromptHistory: PromptHistory?
    @State private var isFirstLaunch: Bool = true
    @State private var showDeleteConfirmation: Bool = false
    @State private var showClearConfirmation: Bool = false

    let models = ["Flux Pro", "Flux Schnell", "Flux Dev Inpainting"]
    let aspectRatios = ["1:1", "16:9", "21:9", "2:3", "3:2", "4:5", "5:4", "9:16", "9:21"]
    let outputFormats = ["webp", "jpg", "png"]
    
    @State private var selectedTab: Int = 1 // Default to the second tab (Generate)
    @State private var showImagePicker: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                modelSelector
                
                if isLoading {
                    loadingView
                        .transition(.opacity)
                } else {
                    TabView(selection: $selectedTab) {
                        VStack {
                            Text("Settings")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.secondary)
                            ScrollView(.vertical) {
                                Picker("Aspect Ratio", selection: $aspectRatio) {
                                    ForEach(aspectRatios, id: \.self) {
                                        Text($0)
                                    }
                                }
                                .pickerStyle(.wheel)
                                if selectedModel == "Flux Pro" {
                                    fluxProInputs
                                } else if selectedModel == "Flux Schnell" {
                                    fluxSchnellInputs
                                } else if selectedModel == "Flux Dev Inpainting" {
                                    fluxDevInpaintingInputs
                                }
                            }
                        }.padding()
                        .tabItem {
                            Text("Settings")
                        }
                        .tag(0)
                        
                        VStack {
                                Spacer()
                                if selectedModel == "Flux Dev Inpainting" {
                                    devInpaintingView
                                }
                                if !isDrawingMode {
                                    promptInput
                                    generateButton
                                        .padding(.top)
                                }
                            
                            if !errorMessage.isEmpty {
                                    Text("Error: \(errorMessage)")
                                        .foregroundColor(.red)
                                        .padding()
                                }
                        }
                        .tabItem {
                            Text("Generate")
                            
                        }
                        .tag(1)
                        
                        VStack {
                            Text("History")
                             .font(.title2.weight(.bold))
                             .foregroundStyle(.secondary)
                            promptHistoryView
                        }
                        .tabItem {
                            Text("History")
                        }
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: isKeyboardVisible ? .never : .automatic))
                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .automatic))
                }
                Spacer()
            }
            .hideKeyboardOnTap()

            .navigationDestination(isPresented: $navigateToGallery) {
                PhotoGalleryView(generatedImages: generatedImages, modelContext: _modelContext)
            }
            .overlay(keyboardToolbar, alignment: .bottom)
            .onAppear {
                loadApiKey()
                selectedTab = 1 // Set the default tab to "Generate"
            }
            .onReceive(Publishers.keyboardHeight) { height in
                isKeyboardVisible = height > 0
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, errorMessage: $errorMessage)
        }
        .sheet(isPresented: $showApiKeyModal) {
            apiKeyModal.background(Material.ultraThin.opacity(0.6)).edgesIgnoringSafeArea(.all)
        }
        .sheet(item: $selectedPromptHistory) { promptHistory in
            promptDetailsSheet(promptHistory: promptHistory)
                .presentationDetents([.fraction(0.5)])
                .background(Material.ultraThin.opacity(0.5))
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
    
    var devInpaintingView: some View {
        ZStack {
            VStack {
                if let image = selectedImage ?? fetchedImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .edgesIgnoringSafeArea(isDrawingMode ? .all : [])
                            .frame(maxHeight: isDrawingMode ? UIScreen.main.bounds.height : 300)
                            .cornerRadius(isDrawingMode ? 0 : 10)
                            .padding(isDrawingMode ? 0 : 10)

                        if let mask = maskImage {
                            Image(uiImage: mask)
                                .resizable()
                                .scaledToFit()
                                .edgesIgnoringSafeArea(isDrawingMode ? .all : [])
                                .frame(maxHeight: isDrawingMode ? UIScreen.main.bounds.height : 300)
                                .opacity(0.5)
                                .blendMode(.multiply)
                                .cornerRadius(isDrawingMode ? 0 : 10)
                                .padding(isDrawingMode ? 0 : 10)
                        }

                        if isDrawingMode {
                            DrawingView(
                                lines: $lines,
                                imageSize: image.size,
                                onDrawEnd: {
                                    Task {
                                        await updateMaskImage()
                                    }
                                },
                                isEraserActive: $isEraserActive
                            )
                            .edgesIgnoringSafeArea(.all)
                        }
                    }
                    .frame(maxHeight: isDrawingMode ? UIScreen.main.bounds.height : 300)
                    .edgesIgnoringSafeArea(isDrawingMode ? .all : [])
                } else {
                    if isFetchingImage {
                        ProgressView("Loading image...")
                            .padding()
                    } else {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .padding()
                                Text("Upload Image")
                                    .font(.headline)
                            }
                            .foregroundColor(.purple)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding()
                    }
                }
            }

            // Drawing Mode Controls
            if isDrawingMode {
                VStack {
                    HStack {
                        Button(action: {
                            isDrawingMode = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                        Button(action: {
                            isEraserActive.toggle()
                        }) {
                            Image(systemName: isEraserActive ? "pencil" : "eraser")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    Spacer()
                    HStack {
                        Button(action: clearMask) {
                            Image(systemName: "trash")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                }
                .padding()
            } else {
                // Button to enter drawing mode
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isDrawingMode = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.purple)
                                .padding()
                        }
                    }
                }
            }
        }
    }

    func clearImage() {
        selectedImage = nil
        fetchedImage = nil
        imageUrl = ""
        maskImage = nil
        lines.removeAll()
    }


    func updateMaskImage() async {
        guard let image = selectedImage ?? fetchedImage else { return }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        let newImage = renderer.image { context in
            // Fill background with black color
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: image.size))

            // Set drawing properties for white color
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(20)
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineJoin(.round)

            for line in lines {
                guard !line.points.isEmpty else { continue }
                context.cgContext.beginPath()
                context.cgContext.move(to: line.points[0])
                for point in line.points.dropFirst() {
                    context.cgContext.addLine(to: point)
                }
                context.cgContext.strokePath()
            }
        }

        maskImage = newImage
    }


    func clearMask() {
        lines.removeAll()
        maskImage = nil
    }

    var fluxDevInpaintingInputs: some View {
        Group {
            HStack {
                Text("Seed (Optional):")
                TextField("Random", value: $seed, formatter: NumberFormatter())
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 150)
                    .font(.title2)
                    .padding(.trailing, 10)
                    .focused($isPromptFocused)
            }
            TextField("Image URL (for Image-to-Image)", text: $imageUrl)
                .keyboardType(.URL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: imageUrl) { newUrl in
                    fetchImageFromUrl(newUrl)
                }
            if maskImage == nil {
                Text("No mask image drawn")
                    .foregroundColor(.red)
                    .padding()
            }
        }
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
                Text("Seed (Optional):")
                TextField("Random", value: $seed, formatter: NumberFormatter())
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 150)
                    .font(.title2)
                    .padding(.trailing, 10)
                    .focused($isPromptFocused)
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
    
    func fetchImageFromUrl(_ urlString: String) {
        // Clear previous image and error
        fetchedImage = nil
        errorMessage = ""
        
        // Check if the URL is valid and not empty
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            errorMessage = "Invalid image URL."
            return
        }
        
        isFetchingImage = true
        
        // Fetch the image asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let imageSizeInMB = Double(data.count) / (1024.0 * 1024.0)
                
                if imageSizeInMB > 1.0 {
                    DispatchQueue.main.async {
                        self.errorMessage = "Image size exceeds 1MB. Please choose a smaller file."
                        self.isFetchingImage = false
                    }
                } else if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.fetchedImage = image
                        self.isFetchingImage = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Could not load image."
                        self.isFetchingImage = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching image: \(error.localizedDescription)"
                    self.isFetchingImage = false
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
    
    func promptDetailsSheet(promptHistory: PromptHistory) -> some View {
        let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }()
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prompt Details")
                    .font(.headline)
                    .padding(.top)
                Spacer()
            }
            Divider()
            
            // Common details across all models
            Text("Model: \(promptHistory.model)")
                .font(.subheadline)
            Text("Prompt: \(promptHistory.prompt)")
                .font(.subheadline)
            Text("Aspect Ratio: \(promptHistory.aspectRatio ?? "1:1")")
                .font(.subheadline)
            
            // Handle model-specific details
            if promptHistory.model == "Flux Pro" {
                Text("Guidance: \(numberFormatter.string(for: promptHistory.guidance) ?? "")")
                    .font(.subheadline)
                Text("Steps: \(Int(promptHistory.steps))")
                    .font(.subheadline)
                Text("Interval: \(numberFormatter.string(for: promptHistory.interval) ?? "")")
                    .font(.subheadline)
                Text("Safety Tolerance: \(Int(promptHistory.safetyTolerance))")
                    .font(.subheadline)
            } else if promptHistory.model == "Flux Schnell" {
                if let seed = promptHistory.seed {
                    Text("Seed: \(seed)")
                        .font(.subheadline)
                }
                Text("Output Format: \(promptHistory.outputFormat)")
                    .font(.subheadline)
                if promptHistory.outputFormat != "png" {
                    Text("Output Quality: \(Int(promptHistory.outputQuality))")
                        .font(.subheadline)
                }
                Text("Disable Safety Checker: \(promptHistory.disableSafetyChecker ? "Yes" : "No")")
                    .font(.subheadline)
            } else if promptHistory.model == "Flux Dev Inpainting" {
                if let seed = promptHistory.seed {
                    Text("Seed: \(seed)")
                        .font(.subheadline)
                }
                Text("Image URL: \(promptHistory.imageUrl ?? "Not Provided")")
                    .font(.subheadline)

                if let maskData = promptHistory.mask, let uiImage = UIImage(data: maskData) {
                    Text("Mask Image:")
                        .font(.subheadline)
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .cornerRadius(8)
                        .padding(.vertical, 10)
                } else {
                    Text("Mask Image: Not Provided")
                        .font(.subheadline)
                }

                Text("Output Format: \(promptHistory.outputFormat)")
                    .font(.subheadline)
                if promptHistory.outputFormat != "png" {
                    Text("Output Quality: \(Int(promptHistory.outputQuality))")
                        .font(.subheadline)
                }
                Text("Disable Safety Checker: \(promptHistory.disableSafetyChecker ? "Yes" : "No")")
                    .font(.subheadline)
            }
            
            // Button to reload this prompt into the generation tab
            Button(action: {
                withAnimation {
                    loadPromptHistory(promptHistory)
                    selectedPromptHistory = nil
                    selectedTab = 1
                }
            }) {
                Text("Load Prompt")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
            Spacer()
        }
        .padding()
        .presentationDetents([.fraction(0.5)])
    }

    
    func loadPromptHistory(_ history: PromptHistory) {
        selectedModel = history.model
        prompt = history.prompt
        aspectRatio = history.aspectRatio ?? "1:1"
        
        if history.model == "Flux Pro" {
            guidance = history.guidance
            steps = history.steps
            interval = history.interval
            safetyTolerance = history.safetyTolerance
        } else if history.model == "Flux Schnell" {
            seed = history.seed
            outputFormat = history.outputFormat
            outputQuality = history.outputQuality
            disableSafetyChecker = history.disableSafetyChecker
        } else if history.model == "Flux Dev Inpainting" {
            seed = history.seed
            outputFormat = history.outputFormat
            outputQuality = history.outputQuality
            disableSafetyChecker = history.disableSafetyChecker
            imageUrl = history.imageUrl ?? ""  // Default to an empty string if nil
            
            // Handle the mask image
            if let maskData = history.mask {
                maskImage = UIImage(data: maskData)
            } else {
                maskImage = nil
            }
        }
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
            Spacer()
            VStack(spacing: 20) {
                Text("API Keys")
                    .font(.headline)
                VStack(alignment: .leading) {
                    Text("Replicate API Key")
                        .font(.subheadline)
                    TextField("Enter Replicate API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading) {
                    Text("ImgBB API Key")
                        .font(.subheadline)
                    TextField("Enter ImgBB API Key", text: $imgbbApiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Button(action: {
                    saveApiKeys()
                    withAnimation {
                        showSavedMessage = true
                    }
                    showApiKeyModal = false
                }) {
                    Text("Save")
                        .padding()
                        .foregroundColor(.white)
                        .background((apiKey.isEmpty || imgbbApiKey.isEmpty) ? Color.gray : Color.purple)
                        .cornerRadius(10)
                }
                .disabled(apiKey.isEmpty || imgbbApiKey.isEmpty)
            }
            .padding()
            Spacer()
        }
        .background(Material.ultraThick)
        .presentationDetents([.fraction(0.5)])
        .edgesIgnoringSafeArea(.all)
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
            TextField("Enter prompt", text: $prompt, axis: .vertical)
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
                .frame(maxWidth: .infinity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isPromptFocused)
                .multilineTextAlignment(.center)
                .lineLimit(6)
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

    var promptHistoryView: some View {
        List {
            ForEach(promptHistory) { history in
                VStack(alignment: .leading) {
                    Text(history.prompt)
                        .font(.headline)
                    Text("\(history.model) • \(history.timestamp.formatted())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }.transition(.scale(0))
                .onTapGesture {
                    selectedPromptHistory = history
                    if isFirstLaunch {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFirstLaunch = false
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
        .padding([.leading, .trailing, .bottom])
    }

    func generateImage() {
        guard !prompt.isEmpty else {
            errorMessage = "Prompt cannot be empty."
            return
        }

        guard isApiKeyValid else {
            errorMessage = "Please enter a valid API key."
            return
        }

        isLoading = true
        predictionStatus = "Starting prediction..."
        errorMessage = ""

        switch selectedModel {
        case "Flux Pro":
            var parameters: [String: Any] = ["prompt": prompt]
            parameters["steps"] = Int(steps)
            parameters["guidance"] = guidance
            parameters["interval"] = interval
            parameters["safety_tolerance"] = Int(safetyTolerance)

            NetworkManager.shared.createPrediction(model: selectedModel, parameters: parameters) { result in
                switch result {
                case .success(let predictionId):
                    self.trackPrediction(predictionId: predictionId)
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }

        case "Flux Schnell":
            var parameters: [String: Any] = ["prompt": prompt]
            if let seed = seed {
                parameters["seed"] = seed
            }
            parameters["output_format"] = outputFormat
            if outputFormat != "png" {
                parameters["output_quality"] = Int(outputQuality)
            }
            parameters["disable_safety_checker"] = disableSafetyChecker

            NetworkManager.shared.createPrediction(model: selectedModel, parameters: parameters) { result in
                switch result {
                case .success(let predictionId):
                    self.trackPrediction(predictionId: predictionId)
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }

        case "Flux Dev Inpainting":
            let imageToUpload: UIImage?

            if let selected = selectedImage {
                imageToUpload = selected
            } else if let fetched = fetchedImage {
                imageToUpload = fetched
            } else {
                errorMessage = "Please upload an image or provide a valid image URL."
                isLoading = false
                return
            }

            // Check image size
            guard let imageData = imageToUpload?.jpegData(compressionQuality: 0.8) else {
                errorMessage = "Failed to process the image."
                isLoading = false
                return
            }
            let imageSizeInMB = Double(imageData.count) / (1024.0 * 1024.0)
            if imageSizeInMB > 32.0 {
                errorMessage = "Image size exceeds 32MB. Please choose a smaller file."
                isLoading = false
                return
            }

            // Prepare for uploading images
            let dispatchGroup = DispatchGroup()
            var imageURL: String?
            var maskURL: String?
            var uploadError: Error?

            // Upload image
            dispatchGroup.enter()
            uploadImageToImgBB(imageData: imageData) { result in
                switch result {
                case .success(let url):
                    imageURL = url
                case .failure(let error):
                    uploadError = error
                }
                dispatchGroup.leave()
            }

            // Handle mask (if any)
            if let mask = maskImage {
                // Ensure mask is same size as image
                let resizedMask = resizeImage(mask, targetSize: imageToUpload!.size)

                // Convert mask to black and white
                if let bwMask = convertToBlackAndWhite(mask: resizedMask) {
                    // Convert mask to data
                    guard let maskData = bwMask.jpegData(compressionQuality: 0.8) else {
                        errorMessage = "Failed to process the mask image."
                        isLoading = false
                        return
                    }

                    // Upload mask
                    dispatchGroup.enter()
                    uploadImageToImgBB(imageData: maskData) { result in
                        switch result {
                        case .success(let url):
                            maskURL = url
                        case .failure(let error):
                            uploadError = error
                        }
                        dispatchGroup.leave()
                    }
                } else {
                    errorMessage = "Failed to convert mask to black and white."
                    isLoading = false
                    return
                }
            }

            dispatchGroup.notify(queue: .main) {
                if let error = uploadError {
                    self.errorMessage = "Upload error: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }

                guard let imageURL = imageURL else {
                    self.errorMessage = "Failed to upload image."
                    self.isLoading = false
                    return
                }

                var parameters: [String: Any] = [
                    "prompt": self.prompt,
                    "image": imageURL,
                    "strength": 1,
                    "output_quality": 90
                ]

                if let maskURL = maskURL {
                    parameters["mask"] = maskURL
                }

                parameters["guidance_scale"] = guidance
                parameters["num_inference_steps"] = Int(steps)
                parameters["seed"] = seed

                NetworkManager.shared.createPrediction(model: self.selectedModel, parameters: parameters) { result in
                    switch result {
                    case .success(let predictionId):
                        self.trackPrediction(predictionId: predictionId)
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        default:
            errorMessage = "Unsupported model."
            isLoading = false
        }
    }
    
    func uploadImageToImgBB(imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        // Retrieve the API key from the Keychain
        guard let apiKey = KeychainHelper.shared.retrieve(key: "imgbbApiKey") else {
            completion(.failure(NSError(domain: "API Key Missing", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key not found in Keychain"])))
            return
        }
        
        // Prepare the URL
        guard let url = URL(string: "https://api.imgbb.com/1/upload") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set multipart form boundary
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create the multipart body
        let body = createMultipartBody(with: imageData, boundary: boundary, apiKey: apiKey)
        
        // Attach the body to the request
        request.httpBody = body
        
        // Create a URLSession task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Parse the response
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let dict = json as? [String: Any], let imageUrl = (dict["data"] as? [String: Any])?["url"] as? String {
                    print("Image URL: \(imageUrlL)")
                    completion(.success(imageUrl))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }

    func createMultipartBody(with imageData: Data, boundary: String, apiKey: String) -> Data {
        var body = Data()
        
        // Add the API key field
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"key\"\r\n\r\n")
        body.appendString("\(apiKey)\r\n")
        
        // Add the image data
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n")
        
        // Close the boundary
        body.appendString("--\(boundary)--\r\n")
        
        return body
    }


    struct ImgBBUploadResponse: Codable {
        let data: ImgBBUploadData
    }

    struct ImgBBUploadData: Codable {
        let url: String
    }

    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Determine the scale factor that preserves aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)

        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        // Draw and resize the image
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    func convertToBlackAndWhite(mask: UIImage) -> UIImage? {
        guard let cgImage = mask.cgImage else { return nil }
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)

        // Apply a threshold filter
        let thresholdFilter = CIFilter(name: "CIColorClamp")!
        thresholdFilter.setValue(ciImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0), forKey: "inputMinComponents")
        thresholdFilter.setValue(CIVector(x: 1.0, y: 1.0, z: 1.0, w: 1.0), forKey: "inputMaxComponents")

        if let outputImage = thresholdFilter.outputImage,
           let cgImageResult = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImageResult)
        }

        return nil
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

    func savePromptHistory() {
        let maskData = maskImage?.jpegData(compressionQuality: 0.8)
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
            disableSafetyChecker: disableSafetyChecker,
            imageUrl: selectedModel == "Flux Dev Inpainting" ? imageUrl : nil,
            mask: selectedModel == "Flux Dev Inpainting" ? maskData : nil
        )
        modelContext.insert(newHistory)
        try? modelContext.save()
    }



    func sliderInput(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(.primary)
                .font(.title3)
            HStack(alignment: .center) {
                CustomSlider(value: value, range: range, step: step)
                    .focused($isPromptFocused)
            }
        }
    }


    func loadApiKey() {
        if let storedKey = KeychainHelper.shared.retrieve(key: "apiKey") {
            apiKey = storedKey
        }
        if let storedImgBBKey = KeychainHelper.shared.retrieve(key: "imgbbApiKey") {
            imgbbApiKey = storedImgBBKey
        }
    }
    
    func saveApiKeys() {
        KeychainHelper.shared.save(apiKey, forKey: "apiKey")
        KeychainHelper.shared.save(imgbbApiKey, forKey: "imgbbApiKey")
        isApiKeyValid = validateApiKeys()
    }


    func validateApiKeys() -> Bool {
        return !apiKey.isEmpty && !imgbbApiKey.isEmpty
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
                .background(Material.ultraThick.opacity(0.6))
            }
        }
    }
    
    func encodeImage(_ image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return "" }
        return imageData.base64EncodedString()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var errorMessage: String // Changed to non-optional String

    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    let imageSizeInMB = Double(imageData.count) / (1024.0 * 1024.0)
                    if imageSizeInMB <= 1.0 {
                        parent.image = image
                        parent.errorMessage = "" // Clear error if image is valid
                    } else {
                        parent.errorMessage = "Selected image exceeds 1MB."
                    }
                } else {
                    parent.errorMessage = "Failed to process the selected image."
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
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
                    .frame(width: 55)
                    .font(.title2)
                    .padding(.trailing, 10)
                    .onChange(of: value) { newValue in
                        value = clampValue(newValue)
                    }
                    .onTapGesture {
                        dismissKeyboard() // Dismiss the keyboard when tapping outside
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
    
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
    @Environment(\.dismiss) var dismiss
    @State private var selectedImage: GeneratedImage? = nil
    @State private var isShowingHistory: Bool = false
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(generatedImages) { image in
                    if let uiImage = UIImage(data: image.originalImageData) {
                        NavigationLink(destination: ImageDetailView(imageEntity: image, modelContext: _modelContext)) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .navigationTitle("Gallery")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
        .tint(.primary)
        .padding()
    }
}

struct ImageDetailView: View {
    let imageEntity: GeneratedImage
    @Environment(\.modelContext) var modelContext: ModelContext
    @State private var showSaveStatus: Bool = false
    @State private var selectedEditHistory: EditHistory? = nil
    
    var body: some View {
        ScrollView {
            VStack {
                if let originalImage = UIImage(data: imageEntity.originalImageData) {
                    Image(uiImage: originalImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 300)
                        .cornerRadius(10)
                }
                
                // Display edited images if available
                if let editedImageData = imageEntity.editedImageData, !editedImageData.isEmpty {
                    ForEach(editedImageData.indices, id: \.self) { index in
                        if let editedImage = UIImage(data: editedImageData[index]) {
                            Image(uiImage: editedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 300)
                                .cornerRadius(10)
                                .onTapGesture {
                                    // Show the details of this edit (inputs used in inpainting)
                                    selectedEditHistory = imageEntity.editHistory?[index]
                                }
                        }
                    }
                }
                
                // Show detailed inpainting inputs if tapped on an edited image
                if let selectedEditHistory = selectedEditHistory {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Inpainting Details")
                            .font(.headline)
                        Text("Prompt: \(selectedEditHistory.prompt)")
                        Text("Mask URL: \(selectedEditHistory.maskUrl)")
                        Text("Dimensions: \(selectedEditHistory.width)x\(selectedEditHistory.height)")
                        Text("Strength: \(selectedEditHistory.strength)")
                        Text("Guidance Scale: \(selectedEditHistory.guidanceScale)")
                        Text("Output Quality: \(selectedEditHistory.outputQuality)")
                        Text("Inference Steps: \(selectedEditHistory.numInferenceSteps)")
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Image Details")
    }
}


struct InpaintingView: View {
    var generatedImage: GeneratedImage
    @Environment(\.modelContext) var modelContext: ModelContext
    @Binding var isPresented: Bool
    @State private var prompt: String = ""
    @State private var maskUrl: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack {
            Text("Inpainting Mode")
                .font(.headline)
            
            TextField("Enter prompt", text: $prompt)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Mask Image URL", text: $maskUrl)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: performInpainting) {
                Text("Generate Inpainting")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(prompt.isEmpty || maskUrl.isEmpty)
            .padding()
            
            if isLoading {
                ProgressView("Generating Inpainting...")
                    .padding()
            }
            
            if !errorMessage.isEmpty {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
    
    private func performInpainting() {
        isLoading = true
        let parameters: [String: Any] = [
            "prompt": prompt,
            "mask": maskUrl,
            "image": "https://your.image.uri",  // You may need to provide the actual URI or load from GeneratedImage object
            "width": 1024,
            "height": 1024,
            "strength": 1,
            "num_outputs": 1,
            "output_format": "webp",
            "guidance_scale": 7,
            "output_quality": 90,
            "num_inference_steps": 30
        ]
        
        NetworkManager.shared.createPrediction(model: "Flux Dev Inpainting", parameters: parameters) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let predictionId):
                    self.trackInpainting(predictionId: predictionId)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func trackInpainting(predictionId: String) {
        NetworkManager.shared.getPredictionOutput(predictionId: predictionId, model: "Flux Dev Inpainting", context: modelContext) { result in
            switch result {
            case .success(let image):
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    // Save edited image and inpainting details in GeneratedImage
                    var editHistory = generatedImage.editHistory ?? []
                    let newHistory = EditHistory(
                        prompt: prompt,
                        maskUrl: maskUrl,
                        width: 1024,
                        height: 1024,
                        strength: 1,
                        numOutputs: 1,
                        outputFormat: "webp",
                        guidanceScale: 7,
                        outputQuality: 90,
                        numInferenceSteps: 30
                    )
                    editHistory.append(newHistory)
                    
                    var editedImages = generatedImage.editedImageData ?? []
                    editedImages.append(imageData)
                    
                    generatedImage.editHistory = editHistory
                    generatedImage.editedImageData = editedImages
                    
                    try? modelContext.save()
                }
                self.isPresented = false
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}



//struct ImageDetailView: View {
//    let image: UIImage
//    let imageEntity: GeneratedImage
//    @Environment(\.modelContext) var modelContext: ModelContext
//    @Environment(\.dismiss) var dismiss
//    @State private var isDeleted: Bool = false
//    @State private var showingSaveStatus: Bool = false
//    @State private var saveStatusMessage: String = ""
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack(alignment: .bottomTrailing) {
//                Image(uiImage: image)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: geometry.size.width, height: geometry.size.height)
//                    .clipped()
//                
//                if !isDeleted {
//                    HStack(spacing: 20) {
//                        Button(action: shareImage) {
//                            Image(systemName: "square.and.arrow.up")
//                                .foregroundColor(.white)
//                                .padding(10)
//                                .background(Color.black.opacity(0.6))
//                                .clipShape(Circle())
//                        }
//                        
//                        Button(action: deleteImage) {
//                            Image(systemName: "trash")
//                                .foregroundColor(.white)
//                                .padding(10)
//                                .background(Color.red.opacity(0.6))
//                                .clipShape(Circle())
//                        }
//                    }
//                    .padding()
//                }
//            }
//        }
//        .overlay(
//            Group {
//                if showingSaveStatus {
//                    Text(saveStatusMessage)
//                        .padding()
//                        .background(Color.black.opacity(0.7))
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .transition(.move(edge: .top).combined(with: .opacity))
//                }
//            }
//        )
//        .animation(.easeInOut, value: showingSaveStatus)
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden()
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: {
//                    dismiss()
//                }) {
//                    Image(systemName: "chevron.left")
//                        .foregroundColor(.primary)
//                }
//            }
//        }
//        .tint(.primary)
//    }
//    
//    func shareImage() {
//        let imageSaver = ImageSaver()
//        if let jpegData = image.jpegData(compressionQuality: 0.8) {
//            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("shared_image.jpg")
//            try? jpegData.write(to: tempURL)
//            
//            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
//            UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
//        } else {
//            saveStatusMessage = "Error preparing image for sharing"
//            showSaveStatus()
//        }
//    }
//    
//    func deleteImage() {
//        withAnimation {
//            isDeleted = true
//            modelContext.delete(imageEntity)
//            try? modelContext.save()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                dismiss()
//            }
//        }
//    }
//    
//    func showSaveStatus() {
//        withAnimation {
//            showingSaveStatus = true
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            withAnimation {
//                showingSaveStatus = false
//            }
//        }
//    }
//}

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
    @Attribute var originalImageData: Data   // Store original image data
    @Attribute var editedImageData: [Data]?  // Store edited images
    @Attribute var editHistory: [EditHistory]? // Store inpainting or other edit history
    @Attribute var timestamp: Date

    init(id: UUID = UUID(), originalImageData: Data, editedImageData: [Data]? = nil, editHistory: [EditHistory]? = nil, timestamp: Date = Date()) {
        self.id = id
        self.originalImageData = originalImageData
        self.editedImageData = editedImageData
        self.editHistory = editHistory
        self.timestamp = timestamp
    }
}

@Model
class EditHistory {
    @Attribute var timestamp: Date
    @Attribute var prompt: String
    @Attribute var maskUrl: String
    @Attribute var width: Int
    @Attribute var height: Int
    @Attribute var strength: Float
    @Attribute var numOutputs: Int
    @Attribute var outputFormat: String
    @Attribute var guidanceScale: Float
    @Attribute var outputQuality: Int
    @Attribute var numInferenceSteps: Int

    init(timestamp: Date = Date(), prompt: String, maskUrl: String, width: Int, height: Int, strength: Float, numOutputs: Int, outputFormat: String, guidanceScale: Float, outputQuality: Int, numInferenceSteps: Int) {
        self.timestamp = timestamp
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
    @Attribute var aspectRatio: String?
    @Attribute var steps: Double
    @Attribute var interval: Double
    @Attribute var safetyTolerance: Double
    @Attribute var seed: Int?
    @Attribute var outputFormat: String
    @Attribute var outputQuality: Double
    @Attribute var disableSafetyChecker: Bool
    @Attribute var imageUrl: String?     // Optional image URL for inpainting
    @Attribute var mask: Data?           // Optional mask for inpainting
    @Attribute var timestamp: Date

    init(id: UUID = UUID(), model: String, prompt: String, guidance: Double, aspectRatio: String? = nil, steps: Double, interval: Double, safetyTolerance: Double, seed: Int? = nil, outputFormat: String, outputQuality: Double, disableSafetyChecker: Bool, imageUrl: String? = nil, mask: Data? = nil, timestamp: Date = Date()) {
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
        self.imageUrl = imageUrl
        self.mask = mask
        self.timestamp = timestamp
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    private let baseUrl = "https://api.replicate.com/v1/predictions"
    
    private let modelConfigurations: [String: NetworkModelConfig] = [
        "Flux Pro": .standard(endpoint: "black-forest-labs/flux-pro"),
        "Flux Schnell": .standard(endpoint: "black-forest-labs/flux-schnell"),
        "Flux Dev Inpainting": .standard(endpoint: "zsxkib/flux-dev-inpainting")
    ]
    
    var currentPredictionId: String?
    
    func createPrediction(model: String, parameters: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = KeychainHelper.shared.retrieve(key: "apiKey") else {
            completion(.failure(NSError(domain: "API Key Missing", code: 401, userInfo: nil)))
            return
        }
        
        guard let config = modelConfigurations[model] else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid model"])))
            return
        }
        
        let url = config.endpointURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare the JSON body
        var finalParameters: [String: Any] = [:]
        switch config {
        case .standard:
            finalParameters = ["input": parameters]
        case .versioned(let version):
            finalParameters = [
                "version": version,
                "input": parameters
            ]
        }
        
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
                let decoder = JSONDecoder()
                let predictionResponse = try decoder.decode(PredictionResponse.self, from: data)
                
                if let predictionId = predictionResponse.id {
                    self.currentPredictionId = predictionId
                    completion(.success(predictionId))
                } else if let errorMessage = predictionResponse.detail {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON parsing error: \(error.localizedDescription)"])))
            }
        }
        
        task.resume()
    }
    
    // Method to track the prediction status
    func getPredictionStatus(predictionId: String, completion: @escaping (Result<String, Error>) -> Void) {
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
                let decoder = JSONDecoder()
                let statusResponse = try decoder.decode(PredictionResponse.self, from: data)
                
                if let status = statusResponse.status {
                    completion(.success(status))
                } else if let errorMessage = statusResponse.detail {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid status response format"])))
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
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("Get Prediction Output: No data or invalid response")
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            print("Get Prediction Output HTTP Status: \(httpResponse.statusCode)")
            
            do {
                let decoder = JSONDecoder()
                let outputResponse = try decoder.decode(PredictionResponse.self, from: data)
                
                // Extract the first output URL based on the Output enum
                let outputUrlString: String?
                switch outputResponse.output {
                case .single(let urlString):
                    outputUrlString = urlString
                case .multiple(let urlArray):
                    outputUrlString = urlArray.first
                case .none:
                    outputUrlString = nil
                }
                
                if let outputUrlString = outputUrlString,
                   let imageUrl = URL(string: outputUrlString) {
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let imageData = try? Data(contentsOf: imageUrl),
                           let image = UIImage(data: imageData) {
                            
                            DispatchQueue.main.async {
                                let newImage = GeneratedImage(originalImageData: imageData)
                                context.insert(newImage)
                                do {
                                    try context.save()
                                    completion(.success(image))
                                } catch {
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.handleOutputError(outputResponse, completion: completion)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.handleOutputError(outputResponse, completion: completion)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Output JSON parsing error: \(error.localizedDescription)"])))
                }
            }
        }
        
        task.resume()
    }
    
    // Helper method to handle errors
    func handleOutputError(_ jsonResponse: PredictionResponse, completion: @escaping (Result<UIImage, Error>) -> Void) {
        if let errorMessage = jsonResponse.detail {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
        } else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid output response format"])))
        }
    }
    
    // Method to cancel a prediction
    func cancelPrediction(predictionId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "https://api.replicate.com/v1/predictions/\(predictionId)/cancel")!
        guard let apiKey = KeychainHelper.shared.retrieve(key: "apiKey") else {
            completion(.failure(NSError(domain: "API Key Missing", code: 401, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
            
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to cancel prediction"])))
            }
        }
        
        task.resume()
    }
    
    
    func uploadToImgBB(apiKey: String, imageData: Data, name: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.imgbb.com/1/upload") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "image", value: imageData.base64EncodedString())
        ]
        if let name = name {
            bodyComponents.queryItems?.append(URLQueryItem(name: "name", value: name))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let dataDict = json?["data"] as? [String: Any], let url = dataDict["url"] as? String {
                    completion(.success(url))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}




// MARK: - Extension for NavigationController

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
// MARK: - ModelConfiguration Enum

enum NetworkModelConfig {
    case standard(endpoint: String)
    case versioned(version: String)
    
    var endpointURL: URL {
        switch self {
        case .standard(let endpoint):
            return URL(string: "https://api.replicate.com/v1/models/\(endpoint)/predictions")!
        case .versioned:
            return URL(string: "https://api.replicate.com/v1/predictions")!
        }
    }
    
    var requiresVersion: Bool {
        switch self {
        case .versioned:
            return true
        case .standard:
            return false
        }
    }
}

// MARK: - PredictionResponse Struct

struct PredictionResponse: Codable {
    let id: String?
    let status: String?
    let output: Output?
    let detail: String?
    
}

enum Output: Codable {
    case single(String)
    case multiple([String])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            self = .single(single)
            return
        }
        if let multiple = try? container.decode([String].self) {
            self = .multiple(multiple)
            return
        }
        throw DecodingError.typeMismatch(Output.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String] for output"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let str):
            try container.encode(str)
        case .multiple(let arr):
            try container.encode(arr)
        }
    }
}

extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
