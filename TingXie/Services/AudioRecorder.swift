import AVFoundation
import Foundation

/// Thread-safe ring buffer that stores the most recent ~0.5s of PCM audio.
/// Used to capture audio that arrived BEFORE the user pressed the recording key.
private class AudioRingBuffer {
    private var buffers: [AVAudioPCMBuffer] = []
    private let lock = NSLock()
    private let maxDuration: TimeInterval  // seconds of audio to keep
    private let sampleRate: Double
    
    /// Total frames currently stored
    private var totalFrames: AVAudioFrameCount = 0
    private var maxFrames: AVAudioFrameCount
    
    init(maxDuration: TimeInterval = 0.5, sampleRate: Double = 16000) {
        self.maxDuration = maxDuration
        self.sampleRate = sampleRate
        self.maxFrames = AVAudioFrameCount(maxDuration * sampleRate)
    }
    
    /// Append a buffer, evicting oldest data if over capacity
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        
        buffers.append(buffer)
        totalFrames += buffer.frameLength
        
        // Evict oldest buffers when over capacity
        while totalFrames > maxFrames, !buffers.isEmpty {
            let oldest = buffers.removeFirst()
            totalFrames -= oldest.frameLength
        }
    }
    
    /// Drain all buffered audio and return it, clearing the buffer
    func drain() -> [AVAudioPCMBuffer] {
        lock.lock()
        defer { lock.unlock() }
        
        let result = buffers
        buffers.removeAll()
        totalFrames = 0
        return result
    }
    
    /// Clear without returning
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffers.removeAll()
        totalFrames = 0
    }
}

class AudioRecorder: ObservableObject {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private let outputURL: URL
    
    /// When true, audio frames are written directly to the output file
    private var isCapturing = false
    
    /// Ring buffer holds ~0.5s of pre-press audio
    private let ringBuffer = AudioRingBuffer(maxDuration: 0.5, sampleRate: 16000)
    
    /// Audio converter (created once, reused)
    private var converter: AVAudioConverter?
    private var processingFormat: AVAudioFormat?
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    init() {
        outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("tingxie_recording.m4a")
        startAlwaysOnEngine()
    }
    
    // MARK: - Always-On Engine
    
    /// Set up and start the engine once. It runs continuously while the app is alive.
    /// The tap feeds audio into the ring buffer (idle) or directly to file (recording).
    private func startAlwaysOnEngine() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Processing format: PCM 16k mono
        guard let pFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            print("[AudioRecorder] Failed to create processing format")
            return
        }
        self.processingFormat = pFormat
        
        guard let conv = AVAudioConverter(from: inputFormat, to: pFormat) else {
            print("[AudioRecorder] Failed to create audio converter")
            return
        }
        self.converter = conv
        
        // Install tap — runs continuously
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Update audio level for UI
            let level = self.calculateRMS(buffer: buffer)
            DispatchQueue.main.async {
                self.audioLevel = level
            }
            
            // Convert to 16kHz mono PCM
            guard let convertedBuffer = self.convertBuffer(buffer) else { return }
            
            if self.isCapturing {
                // Recording mode: write directly to file
                if let audioFile = self.audioFile {
                    try? audioFile.write(from: convertedBuffer)
                }
            } else {
                // Idle mode: feed ring buffer (keeps last ~0.5s)
                self.ringBuffer.append(convertedBuffer)
            }
        }
        
        // Prepare and start engine
        engine.prepare()
        do {
            try engine.start()
            print("[AudioRecorder] ✅ Always-on engine started")
        } catch {
            print("[AudioRecorder] Failed to start always-on engine: \(error)")
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Clean up previous recording file
        try? FileManager.default.removeItem(at: outputURL)
        
        guard processingFormat != nil else {
            print("[AudioRecorder] Processing format not available")
            return
        }
        
        // Target settings for AAC output file
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 32000
        ]
        
        do {
            audioFile = try AVAudioFile(
                forWriting: outputURL,
                settings: settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
        } catch {
            print("[AudioRecorder] Failed to create audio file: \(error)")
            return
        }
        
        // ★ Flush ring buffer → file (pre-press audio, ~0.3-0.5s before the keypress)
        let preBuffers = ringBuffer.drain()
        if let audioFile = audioFile {
            var preFrames: AVAudioFrameCount = 0
            for buf in preBuffers {
                try? audioFile.write(from: buf)
                preFrames += buf.frameLength
            }
            if preFrames > 0 {
                let preMs = Double(preFrames) / 16000.0 * 1000.0
                print("[AudioRecorder] Flushed \(preFrames) pre-buffer frames (\(String(format: "%.0f", preMs))ms)")
            }
        }
        
        // Enable direct-to-file capture (the tap is already running)
        isCapturing = true
        isRecording = true
        print("[AudioRecorder] ● Recording started (zero-latency, engine was already running)")
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        // Stop capturing (but engine and tap keep running)
        isCapturing = false
        isRecording = false
        audioFile = nil  // close file handle
        
        DispatchQueue.main.async {
            self.audioLevel = 0.0
        }
        
        print("[AudioRecorder] ■ Recording stopped, file: \(outputURL.path)")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            print("[AudioRecorder] Recording file not found")
            return nil
        }
        
        return outputURL
    }
    
    // MARK: - Helpers
    
    /// Convert a buffer from the input format to 16kHz mono PCM
    private func convertBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter = self.converter, let pFormat = self.processingFormat else { return nil }
        
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * pFormat.sampleRate / buffer.format.sampleRate
        )
        
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: pFormat,
            frameCapacity: frameCount
        ) else { return nil }
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status == .error || error != nil {
            return nil
        }
        
        return convertedBuffer
    }
    
    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.0 }
        
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        
        // Normalize to 0.0 - 1.0, with some amplification for visual effect
        let normalized = min(rms * 3.0, 1.0)
        return normalized
    }
}
