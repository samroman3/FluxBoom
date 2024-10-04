
<img src="https://github.com/user-attachments/assets/f823c21e-e45d-4dd3-8a41-a28d6ab2203b" width="220" height="200">



# Flux Boom 

## Flux Models with Replicate in iOS

Flux Boom is a demo application showcasing how to use Flux models from Replicate in an iOS app. The goal of this project is to provide a clear and practical example for those interested in integrating generative AI models, allowing for experimentation and rapid prototyping.

<img width="900" alt="Screenshot 2024-10-03 at 3 29 19 PM" src="https://github.com/user-attachments/assets/73b5ada1-ba66-4f3b-a4fd-1d5bb08cc8f5">


## Features

- **Image Generation using Flux Models**: Easily generate images using Flux models available through the Replicate API. Supports parameter control to adjust the output to your preferences.

- **Image Inpainting**: Leverage Flux Dev to fill or modify specific parts of images, enabling creative edits directly within the app.

- **Parameter Control**: Fine-tune parameters such as prompt, guidance scale, output quality, and more to get precisely the results you want from the generative models.

- **Image Gallery and Prompt History**: Store generated images and track your prompt history. This helps visualize past experiments and compare different outputs.

- **Upload and Share Images**: Integrate with the ImgBB API to upload generated images for inpainting/editing or provide image URLs.

## Technical Highlights

- **SwiftUI**: Built using SwiftUI for a modern and interactive UI, with a focus on clean code and easy maintainability.

- **Keychain Integration**: Keychain usage in this demo is simplified and should be enhanced for production. API keys should never be stored on device.

- **Replicate API Integration**: Provides examples of how to make RESTful API calls to Replicate, with the ability to swap in different model versions and endpoints.

- **State Management**: Uses Swift's `@State` and `@Environment` for efficient state management across views, showcasing best practices in a SwiftUI environment.

## Getting Started

1. **Clone the Repository**
   ```sh
   git clone https://github.com/samroman3/FluxBoom.git
   cd fluxBoom
   ```

2. **Add API Keys**
   - You will need an API key from [Replicate](https://replicate.com/) and an optional key for [ImgBB](https://imgbb.com/).
   - You can enter these keys directly in the app UI when prompted or modify the code for your specific use case.

3. **Open in Xcode**
   - Open the project in Xcode (`fluxBoom.xcodeproj`).
   - Make sure you have a recent version of Xcode that supports SwiftUI.

4. **Run the App**
   - Compile and run the app on a simulator or an actual device to see how Flux Boom interacts with the models and generates images.

## Disclaimer

This app is intended as a developer demonstration, not for production use. As such, some practices (e.g., error handling, security considerations) are simplified for clarity and to focus on the core capabilities of the app:

- **Security**: Hardcoded URLs and simplified Keychain usage are employed for demonstration purposes. Sensitive information should be handled more securely in a production environment.

## Contribution

Contributions are welcome! If you have improvements or suggestions, feel free to open an issue or submit a pull request. This project was intended as a learning tool for myself, so any enhancements that add to the educational value are greatly appreciated.


