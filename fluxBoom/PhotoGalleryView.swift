//
//  PhotoGalleryView.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

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
