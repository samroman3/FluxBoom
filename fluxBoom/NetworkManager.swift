//
//  NetworkManager.swift
//  fluxBoom
//
//  Created by Sam Roman on 10/3/24.
//

import SwiftUI
import SwiftData

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    private let baseUrl = "https://api.replicate.com/v1/predictions"
    
    private let modelConfigurations: [String: NetworkModelConfig] = [
        "Flux Pro": .standard(endpoint: "black-forest-labs/flux-pro"),
        "Flux Schnell": .standard(endpoint: "black-forest-labs/flux-schnell"),
        "Flux Dev Inpainting": .versioned(version: "ca8350ff748d56b3ebbd5a12bd3436c2214262a4ff8619de9890ecc41751a008")
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
