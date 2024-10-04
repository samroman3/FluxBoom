//
//  ImageDetailView.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI
import SwiftData

struct ImageDetailView: View {
    @ObservedObject var imageEntity: GeneratedImage
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var isDeleted: Bool = false
    @State private var showingSaveStatus: Bool = false
    @State private var saveStatusMessage: String = ""
    @State private var isShowingPromptHistory: Bool = false
    @State private var isShowingEditHistory: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                if let image = UIImage(data: imageEntity.originalImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Text("Image data is invalid")
                        .foregroundColor(.red)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                if !isDeleted {
                    VStack(alignment: .trailing, spacing: 15) {
                        Button(action: shareImage) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            isShowingPromptHistory.toggle()
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.blue.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            isShowingEditHistory.toggle()
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.green.opacity(0.6))
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
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $isShowingPromptHistory) {
            PromptHistoryView(promptHistories: imageEntity.promptHistory)
        }
        .sheet(isPresented: $isShowingEditHistory) {
            EditHistoryView(editHistories: imageEntity.editHistory)
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
    }
    
    func shareImage() {
        if let image = UIImage(data: imageEntity.originalImageData) {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
        } else {
            saveStatusMessage = "Error loading image data"
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
