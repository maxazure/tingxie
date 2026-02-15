import Foundation
import Combine
import AppKit

enum TranscriptionState: String {
    case idle = "idle"
    case recording = "recording"
    case processing = "processing"
}

struct TranscriptionRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let rawText: String
    let polishedText: String?
    let finalText: String
    
    init(id: UUID = UUID(), date: Date, rawText: String, polishedText: String?, finalText: String) {
        self.id = id
        self.date = date
        self.rawText = rawText
        self.polishedText = polishedText
        self.finalText = finalText
    }
}

@MainActor
class TranscriptionManager: ObservableObject {
    static let shared = TranscriptionManager()
    
    @Published var state: TranscriptionState = .idle
    @Published var history: [TranscriptionRecord] = []
    @Published var lastError: String?
    
    let audioRecorder = AudioRecorder()
    private let hotkeyManager = HotkeyManager()
    private let asrService = ASRService()
    private let groqService = GroqService()
    private let textInserter = TextInserter()
    
    private let maxHistoryCount = 50
    
    init() {
        loadHistory()
        setupHotkey()
    }
    
    private func setupHotkey() {
        hotkeyManager.onKeyDown = { [weak self] in
            Task { @MainActor in
                self?.startRecording()
            }
        }
        
        hotkeyManager.onKeyUp = { [weak self] in
            Task { @MainActor in
                self?.stopRecordingAndProcess()
            }
        }
        
        hotkeyManager.start()
    }
    
    func startRecording() {
        guard state == .idle else { return }
        lastError = nil
        
        // Engine is always running — startRecording() flushes pre-buffer + enables capture
        // This is zero-latency: audio before the keypress is already captured
        audioRecorder.startRecording()
        
        state = .recording
        print("[TranscriptionManager] State: recording (zero-latency start)")
        
        // Show recording indicator
        let mouseLocation = NSEvent.mouseLocation
        RecordingIndicatorWindow.shared.show(at: mouseLocation)
    }
    
    func stopRecordingAndProcess() {
        guard state == .recording else { return }
        
        // Hide recording indicator
        RecordingIndicatorWindow.shared.hide()
        
        guard let audioURL = audioRecorder.stopRecording() else {
            state = .idle
            lastError = "Recording failed"
            return
        }
        
        state = .processing
        print("[TranscriptionManager] State: processing")
        
        Task {
            do {
                // Step 1: ASR
                let rawText = try await asrService.transcribe(audioFileURL: audioURL)
                
                // Check if ASR returned meaningful text (not just noise/punctuation)
                let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                let strippedText = trimmedText.filter { !$0.isPunctuation && !$0.isWhitespace }
                guard strippedText.count > 1 else {
                    await MainActor.run {
                        state = .idle
                        print("[TranscriptionManager] No meaningful speech detected, returning to idle")
                    }
                    return
                }
                
                // Step 2: Optional LLM polishing
                var polishedText: String? = nil
                var finalText = rawText
                
                var isNoContent = false
                
                if AppSettings.shared.enableLLMPolish {
                    let hasKey = AppSettings.shared.llmProvider == "openai"
                        ? !AppSettings.shared.openaiAPIKey.isEmpty
                        : !AppSettings.shared.groqAPIKey.isEmpty
                    
                    if hasKey {
                        do {
                            // Detect active app for dynamic style
                            let activeAppBundleID = getActiveAppBundleID()
                            let appStyle = AppSettings.shared.styleForApp(bundleID: activeAppBundleID)
                            
                            let result = try await groqService.polish(rawText: rawText, appStyle: appStyle)
                            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Filter out meta-responses where LLM says "nothing to process"
                            let metaResponses = ["没有需要处理的文本", "没有需要处理", "无需处理", "没有文本", "无输出"]
                            isNoContent = metaResponses.contains(where: { cleaned.contains($0) })
                            
                            if !isNoContent && !cleaned.isEmpty {
                                polishedText = cleaned
                                finalText = cleaned
                            }
                        } catch {
                            print("[TranscriptionManager] LLM polish failed: \(error), using raw text")
                            // Fall back to raw text
                        }
                    }
                }
                
                // If LLM determined no meaningful content, skip insertion
                guard !isNoContent else {
                    await MainActor.run {
                        state = .idle
                        print("[TranscriptionManager] LLM detected no meaningful content, returning to idle")
                    }
                    return
                }
                
                // Step 3: Insert text
                await MainActor.run {
                    textInserter.insert(text: finalText)
                    
                    // Step 4: Save to history
                    let record = TranscriptionRecord(
                        date: Date(),
                        rawText: rawText,
                        polishedText: polishedText,
                        finalText: finalText
                    )
                    history.insert(record, at: 0)
                    if history.count > maxHistoryCount {
                        history.removeLast()
                    }
                    saveHistory()
                    
                    state = .idle
                    lastError = nil
                    print("[TranscriptionManager] State: idle, inserted: \(finalText)")
                }
                
                // Clean up audio file
                try? FileManager.default.removeItem(at: audioURL)
                
            } catch {
                await MainActor.run {
                    state = .idle
                    lastError = error.localizedDescription
                    print("[TranscriptionManager] Error: \(error)")
                }
            }
        }
    }
    
    private func getActiveAppBundleID() -> String? {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            print("[TranscriptionManager] Active app: \(frontmostApp.bundleIdentifier ?? "unknown")")
            return frontmostApp.bundleIdentifier
        }
        return nil
    }
    
    deinit {
        hotkeyManager.stop()
    }
    
    // MARK: - Persistence
    
    private var historyFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("tingxie_history.json")
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL)
        } catch {
            print("[TranscriptionManager] Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFileURL)
            history = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
        } catch {
            print("[TranscriptionManager] Failed to load history: \(error)")
        }
    }
    
    func deleteRecord(_ record: TranscriptionRecord) {
        history.removeAll { $0.id == record.id }
        saveHistory()
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
}
