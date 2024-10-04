//
//  DrawingMaskView.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//
import SwiftUI

struct DrawingMaskView: View {
    @Binding var uploadedImage: UIImage?
    @Binding var maskImage: UIImage?
    @Binding var isDrawingMode: Bool
    @Binding var lines: [Line]
    @Binding var isEraserActive: Bool
    var imageSize: CGSize
    var onDrawEnd: () -> Void
    var clearMask: () -> Void
    
    @State private var scaleFactor: CGFloat = 1.0
    @State private var imageAspectRatio: CGFloat = 1.0  // Set initial value
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Image and Canvas
                    ZStack {
                        if let image = uploadedImage {
                            // Calculate aspect ratio
                            let aspectRatio = image.size.width / image.size.height
                            
                            // Calculate the display size based on available geometry
                            let availableWidth = geometry.size.width
                            let availableHeight = geometry.size.height * 0.8
                            let fittedHeight = availableWidth / aspectRatio
                            let fittedWidth = availableHeight * aspectRatio
                            
                            let displayWidth = fittedHeight <= availableHeight ? availableWidth : fittedWidth
                            let displayHeight = fittedHeight <= availableHeight ? fittedHeight : fittedWidth / aspectRatio
                            
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: displayWidth, height: displayHeight)
                                .clipped()
                                .onAppear {
                                    // Move the imageAspectRatio assignment here
                                    imageAspectRatio = aspectRatio
                                    calculateScaleFactor(image: image, displayWidth: displayWidth, displayHeight: displayHeight)
                                    logImageDetails(image: image, size: imageSize)
                                }
                            
                            // Canvas for drawing with adjusted size to match the image
                            Canvas { context, size in
                                let xScale = size.width / imageSize.width
                                let yScale = size.height / imageSize.height
                                
                                for line in lines {
                                    var path = Path()
                                    if let firstPoint = line.points.first {
                                        let mappedPoint = CGPoint(x: firstPoint.x * xScale, y: firstPoint.y * yScale)
                                        path.move(to: mappedPoint)
                                        for point in line.points.dropFirst() {
                                            let mappedPoint = CGPoint(x: point.x * xScale, y: point.y * yScale)
                                            path.addLine(to: mappedPoint)
                                        }
                                        context.stroke(path, with: .color(line.color.opacity(0.9)), lineWidth: line.lineWidth * xScale)
                                    }
                                }
                            }
                            .frame(width: displayWidth, height: displayHeight)
                            .gesture(drawingGesture(displayWidth: displayWidth, displayHeight: displayHeight))
                            .background(Color.clear)
                        } else {
                            Color.gray
                                .frame(width: geometry.size.width, height: geometry.size.height * 0.8)
                        }
                    }
                    
                    Spacer()
                    
                    // Control Panel at Bottom
                    HStack {
                        // Eraser Toggle Button
                        Button(action: {
                            isEraserActive.toggle()
                            print("Eraser toggled to: \(isEraserActive)") // Debugging
                        }) {
                            Image(systemName: isEraserActive ? "eraser.fill" : "pencil.tip")
                                .font(.title)
                                .foregroundColor(isEraserActive ? .red : .blue)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Clear Mask Button
                        Button(action: {
                            clearMask()
                            print("Mask cleared") // Debugging
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .frame(height: 60)
                    .background(Color.black.opacity(0.05))
                }
                
                // Close Button at Top-Right Corner of the Screen
                Button(action: {
                    isDrawingMode = false
                    print("Exiting drawing mode") // Debugging
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding([.top, .trailing], 20)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    // Calculate scale factor based on image and display size
    private func calculateScaleFactor(image: UIImage, displayWidth: CGFloat, displayHeight: CGFloat) {
        let imagePixelWidth = image.size.width * image.scale
        let displayPixelWidth = displayWidth * UIScreen.main.scale
        
        scaleFactor = imagePixelWidth / displayPixelWidth
        print("Scale Factor Calculated: \(scaleFactor)")
    }
    
    
    // Logging function to print image details
    private func logImageDetails(image: UIImage, size: CGSize) {
        let aspectRatio = size.width / size.height
        print("Uploaded Image Size: \(size.width) x \(size.height)")
        print("Uploaded Image Aspect Ratio: \(aspectRatio)")
    }
    
    // Convert image points to canvas points
    private func convertPoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x / scaleFactor, y: point.y / scaleFactor)
    }
    
    private func drawingGesture(displayWidth: CGFloat, displayHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0.1, coordinateSpace: .local)
            .onChanged { value in
                let location = value.location
                
                // Map the touch point to the image coordinate system
                let xScale = imageSize.width / displayWidth
                let yScale = imageSize.height / displayHeight
                let newPoint = CGPoint(x: location.x * xScale, y: location.y * yScale)
                
                // Clamp the point within the image bounds
                let clampedPoint = clampPoint(newPoint, within: imageSize)
                
                if isEraserActive {
                    erase(at: clampedPoint)
                } else {
                    if lines.isEmpty || lines.last?.points.isEmpty ?? true {
                        // Start a new line
                        lines.append(Line(points: [clampedPoint], color: .white, lineWidth: 40))
                        print("Started new line with initial point: \(clampedPoint)")
                    } else {
                        // Continue adding to the last line
                        if var lastLine = lines.popLast() {
                            lastLine.points.append(clampedPoint)
                            lines.append(lastLine)
                            print("Added point to current line: \(clampedPoint)")
                        }
                    }
                }
            }
            .onEnded { _ in
                if !isEraserActive {
                    onDrawEnd()
                    print("Drawing ended")
                }
            }
    }
    
    
    // Erase Functionality
    private func erase(at point: CGPoint) {
        let eraseThreshold: CGFloat = 60.0 * scaleFactor
        for i in 0..<lines.count {
            lines[i].points.removeAll { p in
                distance(from: p, to: point) < eraseThreshold
            }
        }
        lines.removeAll { $0.points.isEmpty }
        print("Erased at: \(point), remaining lines: \(lines.count)")
    }
    
    // Helper Function to Calculate Distance
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // Clamping Function
    private func clampPoint(_ point: CGPoint, within size: CGSize) -> CGPoint {
        let clampedX = min(max(point.x, 0), size.width)
        let clampedY = min(max(point.y, 0), size.height)
        return CGPoint(x: clampedX, y: clampedY)
    }
}
