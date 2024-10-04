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
    
    // Flux Schnell and Flux Dev specific inputs
    @State private var seed: Int? = nil
    @State private var outputFormat: String = "webp"
    @State private var outputQuality: Double = 80
    @State private var disableSafetyChecker: Bool = false
    
    @State private var strength: Int = 1
    @State private var numOutputs: Int = 1
    
    
    // Flux Dev Inpainting specific inputs
    @State private var selectedImage: UIImage?
    @State private var maskImage: UIImage?
    @State private var fetchedImage: UIImage?
    @State private var isFetchingImage: Bool = false
    @State private var imageUrl: String = ""
    @State private var maskImageUrl: String = ""
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
            .fullScreenCover(isPresented: $isDrawingMode) {
                if let image = selectedImage ?? fetchedImage {
                    DrawingMaskView(
                        uploadedImage: $selectedImage,
                        maskImage: $maskImage,
                        isDrawingMode: $isDrawingMode,
                        lines: $lines,
                        isEraserActive: $isEraserActive,
                        imageSize: image.size, // Pass the original image size
                        onDrawEnd: {
                            Task {
                                await updateMaskImage()
                            }
                        },
                        clearMask: {
                            clearMask()
                        }
                    )
                } else {
                    // Handle case where no image is selected
                    VStack {
                        Text("No image available for drawing.")
                            .font(.headline)
                            .padding()
                        Button("Dismiss") {
                            isDrawingMode = false
                        }
                        .padding()
                    }
                }
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
                    ZStack(alignment: .topTrailing) { // Align clear button to top-right
                        // Display the uploaded image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 500) // Increased maxHeight for better visibility
                            .cornerRadius(10)
                            .padding(10)
                        
                        // Display the mask image if it exists
                        if let mask = maskImage {
                            Image(uiImage: mask)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 500)
                                .opacity(0.5)
                                .blendMode(.multiply)
                                .cornerRadius(10)
                                .padding(10)
                        }
                        
                        // Clear Button in Top-Right Corner
                        Button(action: {
                            clearImage()
                            print("Image and mask cleared") // Debugging
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(10)
                        }
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .padding(10)
                    }
                } else {
                    // Show upload image button if no image is selected
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
            
            // Button to enter drawing mode
            if !isDrawingMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isDrawingMode = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 40)) // Increased size for better visibility
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
        if let generatedMask = generateMaskImage(from: selectedImage!, with: lines) {
            maskImage = generatedMask
        }
    }
    
    func generateMaskImage(from uploadedImage: UIImage, with lines: [Line]) -> UIImage? {
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = uploadedImage.scale
        rendererFormat.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: uploadedImage.size, format: rendererFormat)
        let mask = renderer.image { context in
            // Fill background with black
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: uploadedImage.size))
            
            // Draw the white lines (the mask) on top
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(40 / uploadedImage.scale) // Adjust line width
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
        
        // Log the mask image size and aspect ratio
        let maskSize = mask.size
        let maskScale = mask.scale
        let maskPixelSize = CGSize(width: maskSize.width * maskScale, height: maskSize.height * maskScale)
        let maskAspectRatio = maskSize.width / maskSize.height
        print("Generated Mask Size: \(maskSize.width) x \(maskSize.height) points")
        print("Generated Mask Scale: \(maskScale)")
        print("Generated Mask Pixel Size: \(maskPixelSize.width) x \(maskPixelSize.height) pixels")
        print("Generated Mask Aspect Ratio: \(maskAspectRatio)")
        
        return mask
    }
    
    
    func clearMask() {
        lines.removeAll()
        maskImage = nil
    }
    
    var fluxDevInpaintingInputs: some View {
        Group {
            // Output format picker
            Picker("Output Format", selection: $outputFormat) {
                ForEach(outputFormats, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Output quality slider (new)
            if outputFormat != "png" {
                sliderInput(title: "Output Quality:", value: $outputQuality, range: 0...100, step: 1)
            }
            
            // Guidance scale (new)
            sliderInput(title: "Guidance:", value: $guidance, range: 0...20, step: 0.1)
            
            // Number of inference steps (new)
            sliderInput(title: "Steps:", value: $steps, range: 1...50, step: 1)
            
            // Image URL input for image-to-image generation
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
            var imageToUpload: UIImage?
            
            if let selected = selectedImage {
                imageToUpload = selected
            } else if let fetched = fetchedImage {
                imageToUpload = fetched
            } else {
                errorMessage = "Please upload an image or provide a valid image URL."
                isLoading = false
                return
            }
            
            // Ensure both image and mask have the same orientation and size
            if let imageToUpload = imageToUpload,
               let mask = maskImage {
                
                // Resize the image and mask
                let maxDimension: CGFloat = 2048 // Adjust as needed
                let resizedImage = resizeImageIfNeeded(image: imageToUpload, maxDimension: maxDimension)
                if let blackAndWhiteMask = convertToBlackAndWhite(mask: mask) {
                    // Convert the resized mask to black and white
                    let resizedMask = resizeImageIfNeeded(image: blackAndWhiteMask, maxDimension: maxDimension)
                    
                    
                    
                    // Convert mask to PNG format
                    if let maskPNGData = resizedMask.pngData() {
                        
                        // Upload both the image and the mask to ImgBB
                        let dispatchGroup = DispatchGroup()
                        var imageURL: String?
                        var maskURL: String?
                        var uploadError: Error?
                        
                        // Upload the main image
                        dispatchGroup.enter()
                        uploadImageToImgBB(imageData: resizedImage.jpegData(compressionQuality: 0.8)!) { result in
                            switch result {
                            case .success(let url):
                                imageURL = url
                            case .failure(let error):
                                uploadError = error
                            }
                            dispatchGroup.leave()
                        }
                        
                        // Upload the mask image
                        dispatchGroup.enter()
                        uploadImageToImgBB(imageData: maskPNGData) { result in
                            switch result {
                            case .success(let url):
                                maskURL = url
                            case .failure(let error):
                                uploadError = error
                            }
                            dispatchGroup.leave()
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
                            
                            guard let maskURL = maskURL else {
                                self.errorMessage = "Failed to upload mask image."
                                self.isLoading = false
                                return
                            }
                            
                            // Adjust width and height to multiples of 8
                            let adjustedWidth = (Int(resizedImage.size.width) / 8) * 8
                            let adjustedHeight = (Int(resizedImage.size.height) / 8) * 8
                            
                            // Adjust strength to 0.85
                            let adjustedStrength: Float = 0.85
                            
                            // Usage after uploading
                            fetchImageDimensions(from: imageURL) { width, height in
                                print("Uploaded image dimensions: \(width)x\(height)")
                            }
                            fetchImageDimensions(from: maskURL) { width, height in
                                print("Uploaded mask dimensions: \(width)x\(height)")
                            }
                            
                            // Prepare the parameters
                            var parameters: [String: Any] = [
                                "prompt": self.prompt,
                                "image": imageURL,
                                "mask": maskURL,
                                "strength": adjustedStrength,
                                "width": adjustedWidth,
                                "height": adjustedHeight,
                                "output_format": self.outputFormat,
                                "guidance_scale": 7.0, // Adjusted to a standard value
                                "num_inference_steps": 25,
                                "num_outputs": self.numOutputs,
                                "output_quality": self.outputQuality
                            ]
                            
                            // Debugging prints
                            print("Parameters being sent: \(parameters)")
                            
                            if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted) {
                                if let jsonString = String(data: jsonData, encoding: .utf8) {
                                    print("JSON Payload: \n\(jsonString)")
                                }
                            }
                            
                            // Send the prediction request
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
                    } else {
                        errorMessage = "Failed to convert mask to PNG."
                        isLoading = false
                        return
                    }
                } else {
                    errorMessage = "Failed to convert mask to black and white."
                    isLoading = false
                    return
                }
            }
        default:
            errorMessage = "Unsupported model."
            isLoading = false
        }
    }
    
    
    func resizeImageIfNeeded(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height

        // Calculate new dimensions that are multiples of 64
        let newWidth = CGFloat(Int(min(width, maxDimension) / 64) * 64)
        let newHeight = CGFloat(Int(min(height, maxDimension) / 64) * 64)

        let newSize = CGSize(width: newWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
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
                    print("Image URL: \(imageUrl)")
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
    
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? image
    }
    
    func fetchImageDimensions(from urlString: String, completion: @escaping (Int, Int) -> Void) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                completion(Int(image.size.width), Int(image.size.height))
            } else {
                print("Failed to fetch image dimensions.")
            }
        }.resume()
    }


    
    func convertToBlackAndWhite(mask: UIImage) -> UIImage? {
        guard let cgImage = mask.cgImage else { return nil }
        
        // Convert the image to grayscale
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply a monochrome filter (grayscale conversion)
        let monochromeFilter = CIFilter(name: "CIColorMonochrome")!
        monochromeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        monochromeFilter.setValue(CIColor(color: .white), forKey: "inputColor")
        monochromeFilter.setValue(1.0, forKey: "inputIntensity")
        
        guard let outputImage = monochromeFilter.outputImage else {
            return nil
        }
        
        // Render the grayscale image into a CGImage
        guard let cgMonochromeImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        // Create a bitmap context for thresholding
        let width = cgMonochromeImage.width
        let height = cgMonochromeImage.height
        let bitsPerComponent = 8
        let bytesPerRow = width
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        
        guard let contextRef = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        contextRef.draw(cgMonochromeImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = contextRef.data else { return nil }
        let threshold: UInt8 = 128  // Adjust threshold value (0-255)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let pixel = pixelData.load(fromByteOffset: pixelIndex, as: UInt8.self)
                
                // Apply threshold: white if pixel is above the threshold, black if below
                let newPixelValue: UInt8 = pixel < threshold ? 0 : 255
                pixelData.storeBytes(of: newPixelValue, toByteOffset: pixelIndex, as: UInt8.self)
            }
        }
        
        // Create a new CGImage from the thresholded pixel data
        guard let thresholdedCGImage = contextRef.makeImage() else { return nil }
        
        // Convert the CGImage back to a UIImage and return as PNG format
        return UIImage(cgImage: thresholdedCGImage)
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
            mask: selectedModel == "Flux Dev Inpainting" ? maskData : nil,
            generatedImage: nil
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

extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
