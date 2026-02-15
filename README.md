**English** | [中文](README.zh-CN.md)

# 🎙️ TingXie (听写)

> **Bring your own API Key. Zero subscription fees. macOS AI voice input.**

TingXie is a macOS menu bar voice input tool — hold a hotkey to speak, release to get AI-polished text inserted at your cursor. Use your own Groq / OpenAI API Key with **no subscription fees**.

---

## 🏆 Why TingXie?

| | TingXie | Other Voice Input Tools |
|---|---|---|
| 💰 **Cost** | **Free** — use your own API Key (Groq free tier is more than enough) | From $9.99/month |
| 🧠 **AI Polish** | ✅ Auto-removes filler words, fixes speech errors, hot-word correction | Partial |
| 🎯 **Context-Aware** | ✅ Detects current app, switches between technical/formal/casual tone | ❌ |
| 🌐 **Live Translation** | ✅ Speak Chinese, output English (or 6 other languages) | Partial |
| ⚡ **Zero Latency** | ✅ Always-on engine + ring buffer, never misses the first word | Typical 0.5-1s delay |
| 🔒 **Privacy** | ✅ API Keys stored locally, audio deleted after processing | Data uploaded to third-party |

---

## ✨ Key Features

- **🎤 Hold to Speak, Release to Type** — Hold the right Option key to record, release to transcribe and insert.
- **🧹 Smart Polish** — AI automatically removes filler words (um, uh, like), fixes slips of the tongue, and normalizes punctuation.
- **📝 Hot-Word Correction** — Define your own glossary (e.g. "CLAUDE.md", "FastAPI"). The AI auto-corrects ASR misrecognitions to match your terms.
- **🎭 Context-Aware Tone** — Automatically switches to technical style in VS Code, formal style in Mail, casual style in messaging apps. Each style prompt is fully customizable.
- **🌍 Live Translation** — Supports Chinese↔English, Japanese, Korean, French, German, and more.
- **⚡ Zero-Latency Recording** — Always-on audio engine with a ring buffer pre-captures ~0.5s of audio before the hotkey press. No more swallowed first words.
- **📜 History** — Automatically saves the last 50 transcriptions with pagination.

---

## 🚀 Getting Started

### 1. Requirements

- macOS 14.0+
- Xcode 16+ (to build from source)

### 2. Get an API Key (Free)

TingXie uses your own API Key. We recommend **Groq** — generous free tier, blazing fast:

1. Go to [console.groq.com](https://console.groq.com) and sign up
2. Create an API Key
3. Done! Groq's free tier covers both Whisper (ASR) and LLM (text polish)

> 💡 You can also use an OpenAI API Key, but Groq's free tier is usually more than enough for daily use.

### 3. Build & Run

```bash
git clone https://github.com/maxazure/tingxie.git
cd tingxie
open TingXie.xcodeproj
# Press Command + R in Xcode to run
```

### 4. First-Time Setup

1. **Grant Permissions**: macOS will prompt for Microphone and Accessibility access.
2. **Set API Key**: Click the menu bar icon → Settings → enter your Groq API Key under "API Keys".
3. **Start Using**: In any text field, hold right Option to speak → release → text appears!

---

## ⚙️ Settings

| Setting | Description |
|---|---|
| **ASR Provider** | Groq Whisper (recommended), OpenAI Whisper, or self-hosted server |
| **LLM Polish** | Groq or OpenAI, with customizable system prompt |
| **App Style Prompts** | 🔧 Technical / 📝 Formal / 💬 Casual — each with a detailed, editable prompt |
| **Live Translation** | Enable to auto-translate speech output to a target language |
| **Hot Words** | Custom glossary for AI to correct ASR misrecognitions |
| **Hotkey** | Default: right Option key (hold to record, release to transcribe) |

---

## ⚡ Why Groq?

We chose [Groq](https://groq.com) as the default provider because of its **incredible inference speed** — both speech recognition and text polishing complete almost instantly. Combined with the always-on audio engine, the entire pipeline from hotkey press to text appearing at your cursor feels **virtually lag-free**.

Groq offers a generous free tier covering both Whisper ASR and LLM text polishing — more than enough for daily use.

---

## 🆚 How Is This Different from Regular Voice Input?

Traditional voice input tools (like iFlytek, Google Voice Typing, or Apple Dictation) simply convert speech to text as-is — full of filler words, messy punctuation, and informal phrasing.

**TingXie goes further**: Speech → Text → **AI Polish** → Output.

- Automatically cleans up filler words and speech disfluencies
- Corrects slips of the tongue
- Normalizes punctuation and formatting
- Adapts tone to match the app you're using

This makes TingXie especially powerful for **writing prompts, composing emails, and drafting technical docs** — your spoken words come out as clean, publication-ready text.

---

## 🔒 Privacy

- All API Keys are stored locally in macOS `UserDefaults` — never uploaded anywhere.
- Audio files are deleted immediately after processing.
- Your own API Key calls Groq / OpenAI directly; data handling follows their respective privacy policies.

> 💡 For maximum privacy, TingXie also supports **self-hosted ASR servers**, keeping your voice data entirely within your own network.

---

## 🗺️ Roadmap

We're actively exploring integration with **Chinese domestic ASR/LLM providers** that offer highly competitive pricing — far cheaper than subscription-based alternatives. Some providers, such as [ModelScope (魔搭社区)](https://modelscope.cn), even allow **completely free** usage if you have community credits.

- [ ] Integrate Chinese ASR providers (Alibaba Cloud ASR, ModelScope models)
- [ ] Integrate Chinese LLM providers (Qwen, DeepSeek)
- [ ] Speak-to-Edit (voice-edit selected text)
- [ ] Voice commands (delete / undo / clear)
- [ ] Real-time streaming transcription

---

## 🏗️ Architecture

```
Hold Right Option → Record (AAC 16kHz) → Release → ASR → LLM Polish → Paste at Cursor
```

- **Language**: Swift 5 + SwiftUI
- **Recording**: AVAudioEngine (Always-on + Ring Buffer)
- **ASR**: Groq Whisper / OpenAI Whisper
- **LLM**: Groq / OpenAI (configurable models)
- **Hotkey**: CoreGraphics Event Taps
- **Text Insertion**: Clipboard + simulated Cmd+V (auto-saves/restores clipboard)

---

## 📄 License

MIT License — free to use, modify, and distribute.
