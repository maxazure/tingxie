import Foundation

struct ASRResponse: Codable {
    let success: Bool
    let text: String?
    let timeCost: Double?
    let model: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case text
        case timeCost = "time_cost"
        case model
        case error
    }
}

/// OpenAI-compatible Whisper API response (used by both Groq and OpenAI)
struct WhisperResponse: Codable {
    let text: String?
}

class ASRService {
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }
    
    func transcribe(audioFileURL: URL) async throws -> String {
        let provider = AppSettings.shared.asrProvider
        
        switch provider {
        case "groq":
            return try await groqTranscribe(audioFileURL: audioFileURL)
        case "openai":
            return try await openaiTranscribe(audioFileURL: audioFileURL)
        default:
            return try await customTranscribe(audioFileURL: audioFileURL)
        }
    }
    
    // MARK: - Custom ASR Server
    
    private func customTranscribe(audioFileURL: URL) async throws -> String {
        let serverURL = AppSettings.shared.asrServerURL
        guard let url = URL(string: serverURL) else {
            throw ASRError.invalidURL(serverURL)
        }
        
        let audioData = try Data(contentsOf: audioFileURL)
        
        // Build multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add Bearer token if configured
        let token = AppSettings.shared.asrToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("[ASR] Sending audio (\(audioData.count) bytes) to \(serverURL)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ASRError.serverError(statusCode)
        }
        
        let asrResponse = try JSONDecoder().decode(ASRResponse.self, from: data)
        
        guard asrResponse.success, let rawText = asrResponse.text, !rawText.isEmpty else {
            // If no speech detected (empty text), return empty string silently
            if asrResponse.text?.isEmpty ?? true {
                print("[ASR] No speech detected (empty response)")
                return ""
            }
            throw ASRError.transcriptionFailed(asrResponse.error ?? "Unknown error")
        }
        
        print("[ASR] Raw response: \(rawText)")
        print("[ASR] Time cost: \(asrResponse.timeCost ?? 0)s")
        
        let cleanedText = cleanSenseVoiceTags(rawText)
        print("[ASR] Cleaned text: \(cleanedText)")
        
        return cleanedText
    }
    
    // MARK: - Groq Whisper
    
    private func groqTranscribe(audioFileURL: URL) async throws -> String {
        let apiKey = AppSettings.shared.groqAPIKey
        guard !apiKey.isEmpty else {
            throw ASRError.transcriptionFailed("Groq API Key 未配置")
        }
        
        let model = AppSettings.shared.groqWhisperModel
        let endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
        
        guard let url = URL(string: endpoint) else {
            throw ASRError.invalidURL(endpoint)
        }
        
        let audioData = try Data(contentsOf: audioFileURL)
        
        // Build multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // response_format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("[ASR] Sending audio (\(audioData.count) bytes) to Groq Whisper (model: \(model))")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            // Try to parse error message
            if let errorBody = String(data: data, encoding: .utf8) {
                print("[ASR] Groq Whisper error response: \(errorBody)")
            }
            throw ASRError.serverError(statusCode)
        }
        
        let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
        
        guard let rawText = whisperResponse.text, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[ASR] Groq Whisper: No speech detected (empty response)")
            return ""
        }
        
        let cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[ASR] Groq Whisper result: \(cleanedText)")
        
        return cleanedText
    }
    
    // MARK: - OpenAI Transcription
    
    private func openaiTranscribe(audioFileURL: URL) async throws -> String {
        let apiKey = AppSettings.shared.openaiAPIKey
        guard !apiKey.isEmpty else {
            throw ASRError.transcriptionFailed("OpenAI API Key 未配置")
        }
        
        let model = AppSettings.shared.openaiTranscribeModel
        let endpoint = "https://api.openai.com/v1/audio/transcriptions"
        
        guard let url = URL(string: endpoint) else {
            throw ASRError.invalidURL(endpoint)
        }
        
        let audioData = try Data(contentsOf: audioFileURL)
        
        // Build multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body = Data()
        
        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // response_format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("[ASR] Sending audio (\(audioData.count) bytes) to OpenAI (model: \(model))")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let errorBody = String(data: data, encoding: .utf8) {
                print("[ASR] OpenAI error response: \(errorBody)")
            }
            throw ASRError.serverError(statusCode)
        }
        
        let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
        
        guard let rawText = whisperResponse.text, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[ASR] OpenAI: No speech detected (empty response)")
            return ""
        }
        
        let cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[ASR] OpenAI result: \(cleanedText)")
        
        return cleanedText
    }
    
    /// Remove SenseVoice special tags like <|en|>, <|zh|>, <|NEUTRAL|>, <|Speech|>, etc.
    private func cleanSenseVoiceTags(_ text: String) -> String {
        // Remove all <|...|> tags
        let pattern = "<\\|[^|]*\\|>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ASRError: LocalizedError {
    case invalidURL(String)
    case serverError(Int)
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid ASR server URL: \(url)"
        case .serverError(let code): return "ASR server returned HTTP \(code)"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        }
    }
}
