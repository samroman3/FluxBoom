//
//  fluxBoomApp.swift
//  fluxBoom
//
//  Created by Sam Roman on 8/6/24.
//

import SwiftUI
import SwiftData

@main
struct fluxBoomApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GeneratedImage.self,
            PromptHistory.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            BufferingView()
                .modelContainer(sharedModelContainer)
        }
    }
}

struct BufferingView: View {
    @State private var showMainView = false
    @State private var scale: CGFloat = 1.0
    @State private var opacity: CGFloat = 1.0

    var body: some View {
        ZStack {
            if showMainView {
                ContentView()
                    .transition(.scale.animation(.bouncy))
            } else {
                BufferSymbolView(isAnimated: true)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        animateBufferSymbol()
                        startLoadingTransition()
                    }
            }
        }
    }

    private func animateBufferSymbol() {
        withAnimation(Animation
            .easeInOut(duration: Double.random(in: 0.5...1))
            .repeatForever(autoreverses: true)
        ) {
            self.scale = CGFloat.random(in: 0.5...1.5)
        }
    }

    private func startLoadingTransition() {
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 1)) {
                self.opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showMainView = true
            }
        }
    }
}


struct BufferSymbolView: View {
    var isAnimated: Bool
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            gradientOverlay
                .mask(
                    ZStack {
                        Image(systemName: "triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 90)
                            .rotation3DEffect(
                                .degrees(rotationAngle),
                                axis: (x: 5, y: 0, z: 2)
                            )
                        Image(systemName: "triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 90)
                            .rotation3DEffect(
                                .degrees(-rotationAngle),
                                axis: (x: 0, y: 5, z: 2)
                            )
                        Image(systemName: "sparkles")
                            .resizable()
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
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
            gradient: Gradient(colors: [.purple, .blue]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func startAnimating() {
        let duration = 1.0
        withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}


