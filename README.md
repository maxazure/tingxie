# 🎙️ TingXie (听写)

> **自带 API Key，零月费的 macOS AI 语音输入工具。**

TingXie 是一款 macOS 菜单栏语音输入工具——按住快捷键说话，松开后 AI 自动润色、纠错、输入到光标位置。使用你自己的 Groq / OpenAI API Key，**不收任何订阅费**。

---

## 🏆 为什么选 TingXie？

| | TingXie | 其他语音输入工具 |
|---|---|---|
| 💰 **费用** | **免费** — 用自己的 API Key（Groq 免费额度足够日常使用） | $9.99/月起 |
| 🧠 **AI 润色** | ✅ 自动去除"嗯啊那个"、纠正口误、热词纠错 | 部分支持 |
| 🎯 **场景感知** | ✅ 自动识别当前 App，切换技术/正式/日常语气 | ❌ |
| 🌐 **实时翻译** | ✅ 说中文输出英文（或其他 6 种语言） | 部分支持 |
| ⚡ **零延迟** | ✅ Always-on 引擎 + 环形缓冲区，不吞首字 | 常见 0.5-1s 延迟 |
| 🔒 **隐私** | ✅ API Key 仅存本地，音频处理后即删 | 数据上传至第三方 |

---

## ✨ 核心特性

- **🎤 按住说话，松开即得** — 按住右 Option 键录音，松开自动识别并输入。
- **🧹 智能润色** — AI 自动清理语气词（嗯、啊、那个）、修复口误、规范标点。
- **📝 热词纠错** — 自定义专有名词表（如 "CLAUDE.md"、"FastAPI"），ASR 识别错误时自动纠正。
- **🎭 场景感知语气** — 在 VS Code 中自动切换技术风格，在邮件中切换正式风格，在微信中切换日常风格。每种风格的提示词均可自定义。
- **🌍 实时翻译** — 支持中→英、英→中、日语、韩语、法语、德语等多种语言。
- **⚡ 零延迟录音** — 采用 Always-on 音频引擎 + 环形缓冲区，按下热键前 0.5 秒的音频已在缓存中，彻底消除"吞首字"问题。
- **📜 历史记录** — 自动保存最近 50 条转写记录，支持分页浏览。

---

## 🚀 快速上手

### 1. 系统要求

- macOS 14.0+
- Xcode 16+（用于编译）

### 2. 获取 API Key（免费）

TingXie 使用你自己的 API Key，推荐使用 **Groq**（免费额度充足）：

1. 前往 [console.groq.com](https://console.groq.com) 注册账号
2. 创建一个 API Key
3. 完成！Groq 提供慷慨的免费额度，覆盖语音识别（Whisper）和文本润色（LLM）

> 💡 也可以使用 OpenAI API Key，但 Groq 免费额度通常已足够。

### 3. 编译运行

```bash
git clone https://github.com/maxazure/tingxie.git
cd tingxie
open TingXie.xcodeproj
# 在 Xcode 中按 Command + R 运行
```

### 4. 首次设置

1. **授权权限**：首次运行会提示授权「麦克风」和「辅助功能」权限。
2. **配置 API Key**：点击菜单栏图标 → 设置 → 在 "API Keys" 区域填入你的 Groq API Key。
3. **开始使用**：在任意文本框中，按住右 Option 键说话 → 松开 → 文字自动输入！

---

## ⚙️ 设置说明

| 设置项 | 说明 |
|---|---|
| **ASR 语音识别** | 选择 Groq Whisper（推荐）、OpenAI Whisper 或自建服务器 |
| **LLM 文本润色** | 选择 Groq 或 OpenAI，可自定义系统提示词 |
| **应用风格提示词** | 🔧 技术 / 📝 正式 / 💬 日常 三种风格，每种均可展开编辑详细提示词 |
| **实时翻译** | 开启后，说一种语言自动翻译为目标语言输出 |
| **热词纠错** | 添加常用专有名词，AI 自动纠正 ASR 识别错误 |
| **快捷键** | 默认右 Option 键，按住录音松开识别 |

---

## 🏗️ 技术架构

```
按住右 Option → 录音 (AAC 16kHz) → 松开 → ASR 识别 → LLM 润色 → 粘贴到光标
```

- **语言**: Swift 5 + SwiftUI
- **录音**: AVAudioEngine (Always-on + Ring Buffer)
- **ASR**: Groq Whisper / OpenAI Whisper
- **LLM**: Groq / OpenAI (可选模型)
- **热键**: CoreGraphics Event Taps
- **文本插入**: 剪贴板 + 模拟 Cmd+V（自动保存/恢复剪贴板内容）

---

## 📄 License

MIT License — 自由使用、修改和分发。
