# TypeWhisper for iOS

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![iOS](https://img.shields.io/badge/iOS-18.0%2B-black.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)

Speech-to-text for iPhone. Transcribe audio using on-device AI models (WhisperKit, Apple Speech). Includes a custom keyboard with voice input - dictate directly into any app without switching.

## Features

### Custom Keyboard

- **Voice input in any app** - Tap the mic on the TypeWhisper keyboard to dictate text directly into any text field. No app switching needed
- **Flow mode** - The main app records audio in the background while the keyboard captures your speech and inserts the transcription
- **Multi-language layout** - Full keyboard with English, German, Spanish, French, and Italian layouts
- **Long-press characters** - Hold keys to access alternative characters and accents
- **Profile switching** - Quickly switch between language and translation profiles from the keyboard
- **Translation** - Translate dictated text on-device using Apple Translate before inserting
- **Snippet expansion** - Text shortcuts with dynamic placeholders (`{{DATE}}`, `{{TIME}}`, `{{CLIPBOARD}}`)

### Main App

- **On-device transcription** - All processing happens locally on your iPhone
- **Two AI engines** - WhisperKit (99+ languages, streaming, translation) and Apple Speech (fast, no model download needed)
- **Streaming preview** - See partial transcription in real-time while speaking
- **Translation** - Translate transcriptions on-device using Apple Translate (20+ languages)
- **File transcription** - Transcribe pre-recorded audio files
- **Whisper mode** - Boosted microphone gain for quiet speech
- **Sound feedback** - Audio cues for recording start, transcription success, and errors

### Profiles

- **Per-context settings** - Save language, translation target, engine, and whisper mode per profile
- **Quick switching** - Activate profiles from the keyboard or main app
- **Synced to keyboard** - Profile changes in the main app are automatically available in the keyboard

### Dictionary & Snippets

- **Terms** - Help Whisper recognize technical and proper nouns
- **Corrections** - Automatic post-transcription find-and-replace for common mistakes
- **Snippets** - Text shortcuts with triggers like `thanks` expanding to a full signature. Supports `{{DATE:yyyy-MM-dd}}`, `{{TIME:HH:mm}}`, `{{DATETIME}}`, and `{{CLIPBOARD}}` placeholders

### History

- **Searchable history** - All transcriptions saved with timestamp, word count, duration, and engine used
- **Raw vs final text** - View both original and post-processed transcription
- **Auto-purge** - Records older than 90 days are automatically removed

## System Requirements

- iOS 18.0 or later
- iPhone with Apple Silicon (A-series) recommended for WhisperKit
- Keyboard requires Full Access for voice input

## Model Recommendations

| Device | Recommended Models |
|--------|-------------------|
| Older iPhones | Whisper Tiny, Whisper Base, Apple Speech |
| iPhone 15+ | Whisper Small, Whisper Large v3 Turbo |

## Build

1. Clone the repository:
   ```bash
   git clone https://github.com/TypeWhisper/typewhisper-ios.git
   cd typewhisper-ios
   ```

2. Generate the Xcode project:
   ```bash
   brew install xcodegen  # if not installed
   xcodegen generate
   ```

3. Open in Xcode 16+:
   ```bash
   open TypeWhisper.xcodeproj
   ```

4. Select the `typewhisper-ios` scheme and build (Cmd+B). Swift Package dependencies (WhisperKit) resolve automatically.

5. Run on a device or simulator. Go to Settings > Models to download a transcription model.

### Keyboard Setup

1. Open **Settings > General > Keyboard > Keyboards > Add New Keyboard**
2. Select **TypeWhisper**
3. Tap **TypeWhisper** again and enable **Allow Full Access** (required for voice input)
4. Switch to the TypeWhisper keyboard in any text field using the globe key

## Architecture

```
TypeWhisper/
├── App/                    # App entry point, dependency injection
├── Models/                 # SwiftData models (Profile, TranscriptionRecord, Snippet, DictionaryEntry)
├── Services/
│   ├── Engine/             # WhisperEngine, AppleSpeechEngine, TranscriptionEngine protocol
│   ├── ModelManagerService # Model download, loading, transcription dispatch
│   ├── AudioRecordingService
│   ├── FlowSessionManager  # Background recording for keyboard Flow mode
│   ├── ProfileService      # Profile persistence and keyboard sync
│   ├── HistoryService      # Transcription history (SwiftData)
│   ├── DictionaryService   # Terms and corrections
│   ├── SnippetService      # Text shortcuts with placeholders
│   └── TranslationService  # On-device translation via Apple Translate
├── ViewModels/             # MVVM view models
└── Views/                  # SwiftUI views

TypeWhisperKeyboard/
├── KeyboardViewController  # UIInputViewController entry point
├── KeyboardViewModel       # Keyboard state machine
├── Views/                  # Keyboard layout, profile selector, long-press popups
├── Services/               # Audio service for Flow recording
└── Models/                 # Key definitions, alternative characters

Shared/                     # Constants, DTOs shared between app and keyboard
```

**Patterns:** MVVM with `ServiceContainer` for dependency injection. App and keyboard communicate via App Group (`group.com.typewhisper.shared`) using UserDefaults and JSON files. Swift 6 strict concurrency throughout.

## License

GPLv3 - see [LICENSE](LICENSE) for details. Commercial licensing available - see [LICENSE-COMMERCIAL.md](LICENSE-COMMERCIAL.md).
