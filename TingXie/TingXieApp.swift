import SwiftUI

@main
struct TingXieApp: App {
    @ObservedObject private var transcriptionManager = TranscriptionManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: transcriptionManager)
        } label: {
            MenuBarIconView(
                state: transcriptionManager.state,
                audioLevel: transcriptionManager.audioRecorder.audioLevel
            )
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarIconView: View {
    let state: TranscriptionState
    let audioLevel: Float
    
    var body: some View {
        switch state {
        case .idle:
            Image(systemName: "mic.fill")
        case .recording:
            Image(systemName: "mic.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.green)
                .opacity(0.4 + Double(audioLevel) * 0.6)
        case .processing:
            Image(systemName: "ellipsis.circle")
        }
    }
}
