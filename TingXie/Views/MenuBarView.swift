import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: TranscriptionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Status Header
            HStack(spacing: 10) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusLabel)
                        .font(.system(size: 14, weight: .semibold))
                    if manager.state == .recording {
                        Text("正在录制您的语音...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                // Active Mode Indicator (if Translation is on)
                if AppSettings.shared.enableTranslation {
                    Text("翻译: \(AppSettings.shared.targetLanguage)")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if let error = manager.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .imageScale(.small)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            }
            
            Divider().padding(.horizontal, 12)
            
            // Recent history
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(manager.history.isEmpty ? "开始使用" : "最近识别")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                if manager.history.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("按住右 Option 键开始说话\n松开即可自动识别并插入")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 4) {
                        ForEach(manager.history.prefix(3)) { record in
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.finalText, forType: .string)
                            }) {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.finalText)
                                            .lineLimit(2)
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)
                                        
                                        HStack {
                                            Text(timeAgo(record.date))
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                            
                                            if record.polishedText != nil {
                                                Text("•")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                                Text("已润色")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.green.opacity(0.8))
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            Divider().padding(.horizontal, 12)
            
            // Actions
            VStack(spacing: 2) {
                // Secondary Actions Group
                HStack(spacing: 12) {
                    actionButton(title: "历史记录", icon: "clock.arrow.circlepath") {
                        UnifiedWindowController.shared.showWindow(tab: .history)
                    }
                    actionButton(title: "设置", icon: "gearshape") {
                        UnifiedWindowController.shared.showWindow(tab: .general)
                    }
                }
                .padding(.horizontal, 12)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Label("退出听写", systemImage: "power")
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 300)
    }
    
    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 32, height: 32)
            
            switch manager.state {
            case .idle:
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .symbolRenderingMode(.hierarchical)
            case .recording:
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .symbolEffect(.pulse)
            case .processing:
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
    
    private var statusColor: Color {
        switch manager.state {
        case .idle: return .green
        case .recording: return .red
        case .processing: return .blue
        }
    }
    
    private var statusLabel: String {
        switch manager.state {
        case .idle: return "廷写就绪"
        case .recording: return "录音中"
        case .processing: return "正在处理"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前" }
        if seconds < 86400 { return "\(seconds / 3600) 小时前" }
        return "\(seconds / 86400) 天前"
    }
}

// Unified settings + history window
class UnifiedWindowController {
    static let shared = UnifiedWindowController()
    private var window: NSWindow?
    private var settingsView: UnifiedSettingsView?
    
    func showWindow(tab: SettingsTab = .general) {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Switch tab
            settingsView?.selectTab(tab)
            return
        }
        
        let view = UnifiedSettingsView()
        settingsView = view
        let hostingView = NSHostingView(rootView: view)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "听写设置"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 480, height: 400)
        newWindow.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        
        window = newWindow
    }
}
