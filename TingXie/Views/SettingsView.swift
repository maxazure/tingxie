import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        VStack(spacing: 20) {
            Text("听写设置")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                Section("通用") {
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
                        Text("使用下方 Groq 设置中的 API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if settings.asrProvider == "openai" {
                        Picker("听写模型", selection: $settings.openaiTranscribeModel) {
                            Text("gpt-4o-mini-transcribe（推荐）").tag("gpt-4o-mini-transcribe")
                            Text("gpt-4o-transcribe").tag("gpt-4o-transcribe")
                            Text("whisper-1").tag("whisper-1")
                        }
                        Text("使用下方 OpenAI 设置中的 API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
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
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("系统提示词")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $settings.customPrompt)
                                .font(.system(size: 12))
                                .frame(height: 120)
                                .border(Color.gray.opacity(0.3))
                        }
                    }
                }
                
                if settings.enableLLMPolish {
                    Section("应用风格提示词") {
                        Text("根据当前应用类型自动切换语气风格。展开可编辑每种风格的详细提示词。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        DisclosureGroup("🔧 技术风格") {
                            Text("用于 IDE、终端、设计工具等技术类应用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $settings.stylePromptTechnical)
                                .font(.system(size: 12))
                                .frame(height: 80)
                                .border(Color.gray.opacity(0.3))
                            Button("恢复默认") {
                                settings.stylePromptTechnical = AppSettings.defaultTechnicalStyle
                            }
                            .font(.caption)
                        }
                        
                        DisclosureGroup("📝 正式风格") {
                            Text("用于邮件、Office、笔记等办公类应用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $settings.stylePromptFormal)
                                .font(.system(size: 12))
                                .frame(height: 80)
                                .border(Color.gray.opacity(0.3))
                            Button("恢复默认") {
                                settings.stylePromptFormal = AppSettings.defaultFormalStyle
                            }
                            .font(.caption)
                        }
                        
                        DisclosureGroup("💬 日常风格") {
                            Text("用于社交、娱乐、游戏等休闲类应用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $settings.stylePromptCasual)
                                .font(.system(size: 12))
                                .frame(height: 80)
                                .border(Color.gray.opacity(0.3))
                            Button("恢复默认") {
                                settings.stylePromptCasual = AppSettings.defaultCasualStyle
                            }
                            .font(.caption)
                        }
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
                
                Section("API Keys") {
                    SecureField("Groq API Key", text: $settings.groqAPIKey)
                        .textFieldStyle(.roundedBorder)
                    SecureField("OpenAI API Key", text: $settings.openaiAPIKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("热词纠错") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("常用词汇，用逗号分隔。ASR 识别错误时 AI 会自动纠正为正确拼写")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $settings.hotWords)
                            .font(.system(size: 12))
                            .frame(height: 60)
                            .border(Color.gray.opacity(0.3))
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
            }
            .formStyle(.grouped)
        }
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
