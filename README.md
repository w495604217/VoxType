# VoxType

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015%2B-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square" />
  <img src="https://img.shields.io/badge/engine-WhisperKit-green?style=flat-square" />
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square" />
  <img src="https://img.shields.io/github/stars/w495604217/VoxType?style=flat-square" />
</p>

<p align="center">
  <strong>Offline voice-to-text for macOS</strong><br/>
  Press a hotkey. Speak. Your words appear at the cursor.<br/>
  No cloud. No subscription. No data leaves your Mac.
</p>

<!-- TODO: replace with actual demo GIF
<p align="center">
  <img src="docs/demo.gif" alt="VoxType Demo" width="600" />
</p>
-->

---

## Why VoxType?

Most dictation tools stream your audio to someone else's server. VoxType keeps everything local. It runs **Whisper Large V3 Turbo** on-device via CoreML — no API keys, no monthly fees, no privacy trade-offs. Just press `*` on your numpad and start talking.

## How It Works

```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Numpad *    │───▶│  AVAudioEngine│───▶│  WhisperKit  │───▶│  Paste ⌘V    │
│  (hotkey)    │    │  (record WAV) │    │  (transcribe)│    │  (at cursor) │
└─────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

---

## Features

| | Feature | Description |
|-|---------|-------------|
| 🎤 | **One-Key Dictation** | Press numpad `*` to start/stop. Text is auto-pasted at the cursor. |
| 🧠 | **100% Offline** | WhisperKit + CoreML. All processing on-device. Nothing uploaded. |
| 📊 | **Dashboard** | Wispr Flow-inspired window — usage stats, history, mic picker, settings. |
| 🌊 | **Floating HUD** | Capsule overlay with live waveform and elapsed time while recording. |
| 📝 | **History** | Auto-saved transcriptions grouped by date. Search, copy, delete. |
| 🎙️ | **Mic Picker** | Switch between USB, Bluetooth, and built-in microphones in one click. |
| 🔤 | **Punctuation** | Commas, periods, and question marks — generated natively by the model. |
| 🌐 | **Multilingual** | Chinese, English, Japanese, plus auto-detect. |
| ⌨️ | **Dual Hotkey** | CGEventTap + NSEvent. Works through Synergy, KVM, and remote desktop. |
| 🔌 | **Socket API** | Unix socket for Hammerspoon, shell scripts, or any automation. |

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon recommended (M1 / M2 / M3 / M4); Intel Macs also work
- ~200 MB disk space for the Whisper model (auto-downloaded on first launch)

## Getting Started

### Build from Source

```bash
git clone https://github.com/w495604217/VoxType.git
cd VoxType

# Generate Xcode project (requires XcodeGen)
brew install xcodegen
xcodegen generate

# Build and run
open VoxType.xcodeproj
# — or —
xcodebuild -scheme VoxType -configuration Release build
```

### Permissions

On first launch, macOS will ask for two things:

1. **Microphone** — prompted automatically.
2. **Accessibility** — go to System Settings → Privacy & Security → Accessibility → enable VoxType.
   *(Needed for the global hotkey and simulated paste.)*

## Usage

### Quick Start

```
Numpad *  →  🔴 Recording
Speak…
Numpad *  →  ⏹ Stop  →  Transcribe  →  ✅ Pasted at cursor
```

### Menu Bar States

| Icon | Meaning |
|------|---------|
| `mic.fill` | Ready |
| `waveform` | Recording |
| `ellipsis.circle` | Transcribing |
| `mic.badge.xmark` | Model not loaded |

### Dashboard

Click the menu bar icon → **Open VoxType** (`⌘O`):

| Tab | Content |
|-----|---------|
| **Home** | Streak, WPM, total word count, model status (downloading / loading / ready / error) |
| **History** | All transcriptions by date — search, copy, delete |
| **Microphone** | Detected input devices — click to switch |
| **Settings** | Language, auto-paste, sound effects, floating panel toggle |

### Socket API

```bash
# Toggle recording on/off
echo "toggle" | nc -U /tmp/voxtype.sock

# Query current state → idle | recording | transcribing | loading
echo "status" | nc -U /tmp/voxtype.sock
```

## Architecture

```
VoxType/
│
│  Entry & State
├── VoxTypeApp.swift              # @main — MenuBarExtra + Window scene
├── VoxTypeState.swift            # @Observable central state
│
│  Core Services
├── AudioRecorder.swift           # AVAudioEngine → WAV + real-time RMS
├── TranscriptionService.swift    # WhisperKit: warm-up + transcribe
├── PasteService.swift            # NSPasteboard → simulated ⌘V
├── HotkeyService.swift           # CGEventTap + NSEvent dual-layer
├── SocketService.swift           # Unix domain socket (toggle / status)
│
│  Dashboard
├── MainWindowView.swift          # Sidebar + detail router
├── HomeView.swift                # Stat cards + model status
├── HistoryView.swift             # Date-grouped transcription list
├── MicrophoneView.swift          # Input device picker
├── SettingsView.swift            # Preferences
│
│  Floating HUD
├── FloatingPanelView.swift       # Capsule: waveform, timer, preview
├── FloatingPanelWindow.swift     # NSPanel (always-on-top, borderless)
│
│  Data
├── TranscriptionRecord.swift     # Codable record model
├── HistoryStore.swift            # JSON persistence + statistics
├── MicrophoneManager.swift       # CoreAudio device enumeration
│
│  Config
├── Info.plist                    # LSUIElement, usage descriptions
├── VoxType.entitlements          # Hardened runtime
└── project.yml                   # XcodeGen project definition
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 6.0 with strict concurrency |
| UI | SwiftUI (macOS 15+) |
| Speech-to-Text | [WhisperKit](https://github.com/argmaxinc/WhisperKit) 0.15.0 — Whisper Large V3 Turbo via CoreML |
| Audio | AVAudioEngine (WAV, real-time RMS metering) |
| Devices | CoreAudio (`AudioObjectGetPropertyData`) |
| Hotkey | CGEventTap (hardware) + NSEvent (Synergy / KVM) |
| Paste | CGEvent keystroke simulation (`⌘V`) |
| Persistence | JSON via `Codable` (Foundation) |
| Project Gen | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

## Model

VoxType uses **Whisper Large V3 Turbo** converted to CoreML:

| | |
|-|-|
| **Size** | ~200 MB |
| **Speed** | 3–4× faster than Large V3 at near-identical accuracy |
| **Languages** | 100+ |
| **Punctuation** | Native — the model predicts punctuation as part of its vocabulary |
| **Download** | Auto-fetched from HuggingFace on first launch; cached locally afterward |

## Roadmap

- [ ] Customizable hotkey binding
- [ ] Real-time streaming transcription
- [ ] iCloud history sync
- [ ] Prompt templates for domain-specific jargon
- [ ] Homebrew Cask distribution
- [ ] Localized UI (English / Chinese / Japanese)

## Contributing

Contributions welcome. Please open an issue before submitting large changes.

```bash
git checkout -b feat/your-feature
git commit -m 'feat: describe your change'
git push origin feat/your-feature
# Then open a Pull Request
```

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax — Swift-native Whisper inference
- [OpenAI Whisper](https://github.com/openai/whisper) — the underlying speech model
- [Wispr Flow](https://wispr.com) — UI inspiration

## License

[MIT](LICENSE)

---

<p align="center">
  Built by <a href="https://github.com/w495604217">ManaLabs</a>
</p>
