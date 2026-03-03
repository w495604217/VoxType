# VoxType

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2015%2B-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square" />
  <img src="https://img.shields.io/badge/engine-WhisperKit-green?style=flat-square" />
  <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square" />
</p>

<p align="center">
  <strong>macOS 本地离线语音转文字输入工具</strong><br/>
  按下热键，说话，文字自动粘贴到光标位置。完全离线，零延迟，隐私优先。
</p>

---

## 功能特性

| 功能 | 描述 |
|------|------|
| 🎤 **一键语音输入** | 按小键盘 `*` 开始/停止录音，转录结果自动粘贴到当前光标位置 |
| 🧠 **完全离线** | 基于 WhisperKit + CoreML，所有处理在本地完成，无需联网，隐私安全 |
| 📊 **可视化面板** | Wispr Flow 风格主窗口：首页统计、历史记录、麦克风选择、设置 |
| 🌊 **浮动状态条** | 录音时屏幕底部显示胶囊形悬浮面板，实时波形 + 计时器 |
| 📝 **历史记录** | 所有转录自动保存，按日期分组，支持搜索、一键复制、删除 |
| 🎙️ **麦克风管理** | 列出所有音频输入设备，一键切换，支持 USB/蓝牙/内建麦克风 |
| 🔤 **自动标点** | Whisper 模型原生支持，离线生成逗号、句号、问号等标点符号 |
| 🌐 **多语言** | 支持中文、英文、日文及自动检测 |
| ⌨️ **双重热键捕获** | CGEventTap + NSEvent 双层监听，兼容 Synergy/KVM/远程桌面 |
| 🔌 **Socket 控制** | Unix domain socket 接口，支持 Hammerspoon/CLI 外部触发 |

## 系统要求

- macOS 15.0 (Sequoia) 或更高版本
- Apple Silicon (M1/M2/M3/M4) 推荐，Intel 也可运行
- 首次启动需联网下载 Whisper 模型（约 200MB），之后完全离线

## 安装

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/w495604217/VoxType.git
cd VoxType

# 生成 Xcode 项目（需要 XcodeGen）
brew install xcodegen
xcodegen generate

# 打开并构建
open VoxType.xcodeproj
# 或命令行构建
xcodebuild -scheme VoxType -configuration Release build
```

### 权限设置

首次运行后需要授予以下权限：

1. **麦克风** — 系统会自动弹窗请求
2. **辅助功能** — 系统设置 → 隐私与安全 → 辅助功能 → 勾选 VoxType（用于全局热键和模拟粘贴）

## 使用方法

### 基本流程

```
按下小键盘 * → 开始录音 🔴
说话...
再按小键盘 * → 停止录音 → 自动转录 → 粘贴到光标位置 ✅
```

### 菜单栏图标

| 图标 | 状态 |
|------|------|
| 🎤 `mic.fill` | 就绪，等待录音 |
| 🌊 `waveform` | 录音中 |
| ⏳ `ellipsis.circle` | 转录中 |
| ❌ `mic.badge.xmark` | 模型未加载 |

### 主窗口

点击菜单栏图标 → "打开 VoxType"（Cmd+O）打开主窗口：

- **首页** — 使用统计（连续天数、WPM、总字数）+ 模型状态
- **历史** — 全部转录记录，按日期分组，支持搜索和复制
- **麦克风** — 选择音频输入设备
- **设置** — 语言、自动粘贴、提示音、浮动面板开关

### Socket 控制

```bash
# 触发录音/停止
echo "toggle" | nc -U /tmp/voxtype.sock

# 查询状态
echo "status" | nc -U /tmp/voxtype.sock
# 返回: idle / recording / transcribing / loading
```

## 项目结构

```
VoxType/
├── VoxTypeApp.swift            # App 入口：MenuBarExtra + 主窗口
├── VoxTypeState.swift          # 中央状态管理（@Observable）
│
├── AudioRecorder.swift         # AVAudioEngine 录音 + RMS 音量采样
├── TranscriptionService.swift  # WhisperKit 封装：模型加载 + 转录
├── PasteService.swift          # 剪贴板写入 + 模拟 Cmd+V
├── HotkeyService.swift         # 全局热键（CGEventTap + NSEvent 双层）
├── SocketService.swift         # Unix domain socket 服务
│
├── MainWindowView.swift        # 主窗口：侧边栏 + 内容区
├── HomeView.swift              # 首页：统计卡片 + 模型状态
├── HistoryView.swift           # 历史记录列表
├── MicrophoneView.swift        # 麦克风选择界面
├── SettingsView.swift          # 设置页面
│
├── FloatingPanelView.swift     # 浮动胶囊面板 UI
├── FloatingPanelWindow.swift   # NSPanel 悬浮窗口管理
│
├── TranscriptionRecord.swift   # 转录记录数据模型
├── HistoryStore.swift          # 历史持久化（JSON）
├── MicrophoneManager.swift     # CoreAudio 设备管理
│
├── Info.plist                  # App 配置（LSUIElement 等）
├── VoxType.entitlements        # 权限声明
└── project.yml                 # XcodeGen 项目定义
```

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 6.0 |
| UI 框架 | SwiftUI |
| 语音识别 | [WhisperKit](https://github.com/argmaxinc/WhisperKit) v0.15.0 (Whisper Large V3 Turbo) |
| 音频录制 | AVAudioEngine |
| 设备管理 | CoreAudio |
| 全局热键 | CGEventTap + NSEvent |
| 粘贴模拟 | CGEvent (Cmd+V) |
| 数据持久化 | JSON (Foundation) |
| 项目管理 | XcodeGen |

## 模型说明

VoxType 使用 **Whisper Large V3 Turbo** 模型：

- 大小：约 200MB（CoreML 优化版）
- 精度：接近完整 Large V3（1.5GB），但速度快 3-4 倍
- 支持：100+ 种语言
- 标点：模型原生生成，无需额外处理
- 首次运行会从 HuggingFace 自动下载，之后完全离线

## 鸣谢

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax — Swift 原生 Whisper 推理引擎
- [OpenAI Whisper](https://github.com/openai/whisper) — 语音识别模型
- [Wispr Flow](https://wispr.com) — UI 设计灵感

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/w495604217">ManaLabs</a>
</p>
