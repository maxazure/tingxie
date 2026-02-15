import SwiftUI
import ServiceManagement

enum SettingsTab: String, CaseIterable {
    case general = "通用"
    case recognition = "识别"
    case polish = "AI 润色"
    case history = "历史记录"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .recognition: return "mic.fill"
        case .polish: return "wand.and.stars"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

struct UnifiedSettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)
            
            RecognitionSettingsTab()
                .tabItem {
                    Label(SettingsTab.recognition.rawValue, systemImage: SettingsTab.recognition.icon)
                }
                .tag(SettingsTab.recognition)
            
            PolishSettingsTab()
                .tabItem {
                    Label(SettingsTab.polish.rawValue, systemImage: SettingsTab.polish.icon)
                }
                .tag(SettingsTab.polish)
            
            HistorySettingsTab()
                .tabItem {
                    Label(SettingsTab.history.rawValue, systemImage: SettingsTab.history.icon)
                }
                .tag(SettingsTab.history)
        }
        .frame(minWidth: 520, minHeight: 480)
    }
    
    func selectTab(_ tab: SettingsTab) {
        selectedTab = tab
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        Form {
            Section("启动") {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("[Settings] Launch at login error: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            
            Section("快捷键") {
                HStack {
                    Text("按住说话键")
                    Spacer()
                    Text(hotkeyDisplayName)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(6)
                }
                Text("按住录音，松开识别并输入")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("API Keys") {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Groq API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("gsk_...", text: $settings.groqAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenAI API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("sk-...", text: $settings.openaiAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var hotkeyDisplayName: String {
        switch settings.hotkeyCode {
        case 61: return "右 Option ⌥"
        case 58: return "左 Option ⌥"
        case 60: return "右 Shift ⇧"
        case 56: return "左 Shift ⇧"
        default: return "Key \(settings.hotkeyCode)"
        }
    }
}

// MARK: - Recognition Tab

struct RecognitionSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("ASR 语音识别") {
                Picker("识别服务", selection: $settings.asrProvider) {
                    Text("自建服务器").tag("custom")
                    Text("Groq Whisper").tag("groq")
                    Text("OpenAI").tag("openai")
                }
                
                if settings.asrProvider == "custom" {
                    TextField("服务器地址", text: $settings.asrServerURL)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API Token", text: $settings.asrToken)
                        .textFieldStyle(.roundedBorder)
                } else if settings.asrProvider == "groq" {
                    Picker("Whisper 模型", selection: $settings.groqWhisperModel) {
                        Text("whisper-large-v3-turbo（推荐）").tag("whisper-large-v3-turbo")
                        Text("whisper-large-v3").tag("whisper-large-v3")
                        Text("distil-whisper-large-v3-en").tag("distil-whisper-large-v3-en")
                    }
                    Text("使用「通用」中的 Groq API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if settings.asrProvider == "openai" {
                    Picker("听写模型", selection: $settings.openaiTranscribeModel) {
                        Text("gpt-4o-mini-transcribe（推荐）").tag("gpt-4o-mini-transcribe")
                        Text("gpt-4o-transcribe").tag("gpt-4o-transcribe")
                        Text("whisper-1").tag("whisper-1")
                    }
                    Text("使用「通用」中的 OpenAI API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("翻译模式") {
                Toggle("启用实时翻译", isOn: $settings.enableTranslation)
                
                if settings.enableTranslation {
                    Picker("目标语言", selection: $settings.targetLanguage) {
                        Text("English").tag("English")
                        Text("简体中文").tag("Chinese (Simplified)")
                        Text("繁體中文").tag("Chinese (Traditional)")
                        Text("日本語").tag("Japanese")
                        Text("한국어").tag("Korean")
                        Text("Français").tag("French")
                        Text("Deutsch").tag("German")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - AI Polish Tab

struct PolishSettingsTab: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("LLM 文本润色") {
                Toggle("启用 AI 文本润色", isOn: $settings.enableLLMPolish)
                
                if settings.enableLLMPolish {
                    Picker("润色服务", selection: $settings.llmProvider) {
                        Text("Groq").tag("groq")
                        Text("OpenAI").tag("openai")
                    }
                    
                    if settings.llmProvider == "groq" {
                        Picker("模型", selection: $settings.groqModel) {
                            Text("llama-3.3-70b-versatile").tag("llama-3.3-70b-versatile")
                            Text("openai/gpt-oss-120b").tag("openai/gpt-oss-120b")
                            Text("qwen/qwen3-32b").tag("qwen/qwen3-32b")
                        }
                    } else if settings.llmProvider == "openai" {
                        Picker("模型", selection: $settings.openaiLLMModel) {
                            Text("gpt-5-mini-2025-08-07").tag("gpt-5-mini-2025-08-07")
                            Text("gpt-4o-mini").tag("gpt-4o-mini")
                            Text("gpt-4o").tag("gpt-4o")
                        }
                    }
                }
            }
            
            if settings.enableLLMPolish {
                Section("系统提示词") {
                    TextEditor(text: $settings.customPrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 140)
                        .border(Color.gray.opacity(0.3))
                    
                    HStack {
                        Button("恢复默认") {
                            settings.customPrompt = AppSettings.defaultPrompt
                        }
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Text("\(settings.customPrompt.count) 字")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("热词纠错") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每行一个专有名词。ASR 识别错误时 AI 会自动纠正为正确拼写")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $settings.hotWords)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 60)
                            .border(Color.gray.opacity(0.3))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - History Tab

struct HistorySettingsTab: View {
    @ObservedObject var manager = TranscriptionManager.shared
    @State private var searchText = ""
    @State private var currentPage = 0
    private let pageSize = 20
    
    var filteredHistory: [TranscriptionRecord] {
        if searchText.isEmpty {
            return manager.history
        } else {
            return manager.history.filter {
                $0.finalText.localizedCaseInsensitiveContains(searchText) ||
                $0.rawText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var totalPages: Int {
        max(1, Int(ceil(Double(filteredHistory.count) / Double(pageSize))))
    }
    
    var pagedHistory: [TranscriptionRecord] {
        let start = currentPage * pageSize
        let end = min(start + pageSize, filteredHistory.count)
        guard start < filteredHistory.count else { return [] }
        return Array(filteredHistory[start..<end])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索历史记录...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onChange(of: searchText) { _, _ in
                        currentPage = 0
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // List
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text(searchText.isEmpty ? "暂无历史记录" : "未找到相关记录")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(pagedHistory) { record in
                        HistoryRow(record: record)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                copyToClipboard(record.finalText)
                            }
                            .contextMenu {
                                Button("复制") {
                                    copyToClipboard(record.finalText)
                                }
                                Button("复制原文 (无 AI 润色)") {
                                    copyToClipboard(record.rawText)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    manager.deleteRecord(record)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredHistory.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if totalPages > 1 {
                    Button(action: { currentPage = max(0, currentPage - 1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage == 0)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Text("\(currentPage + 1) / \(totalPages)")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(minWidth: 50)
                    
                    Button(action: { currentPage = min(totalPages - 1, currentPage + 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= totalPages - 1)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button("清空历史") {
                    manager.clearHistory()
                    currentPage = 0
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        NSSound(named: "Pop")?.play()
    }
}
