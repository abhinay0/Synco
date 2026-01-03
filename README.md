# Synco Desktop - YouTube Video Downloader

A beautiful, modern desktop application for downloading YouTube videos with a sleek dark theme interface.

## ✨ Features

- 🎥 Download single videos or entire playlists
- 🎨 Modern dark theme UI with Google Fonts
- 📊 Real-time download progress tracking
- 🎯 Multiple quality options (4K, 1080p, 720p, 480p, 360p)
- 🎵 Audio-only download option (MP3)
- 📁 Custom output directory selection
- ⚡ Fast downloads using yt-dlp
- 🔄 Auto-update check for yt-dlp (monthly)
- 🎬 Playlist selection - choose which videos to download
- 📋 Clipboard paste support

## 🖥️ Supported Platforms

- macOS (Intel & Apple Silicon)
- Windows (x64)
- Linux (x64)

## 📋 Prerequisites

### Required Software

1. **yt-dlp** - The video downloader
   ```bash
   # macOS
   brew install yt-dlp
   
   # Windows (using winget)
   winget install yt-dlp
   
   # Linux
   pip install yt-dlp
   ```

2. **FFmpeg** - For merging video/audio streams
   ```bash
   # macOS
   brew install ffmpeg
   
   # Windows (using winget)
   winget install ffmpeg
   
   # Linux
   sudo apt install ffmpeg
   ```

## 🚀 Quick Start

### Download Pre-built Releases

**Coming Soon**: Check the [Releases](https://github.com/YOUR_USERNAME/REPO_NAME/releases) page for pre-built binaries.

### Build from Source

1. **Install Flutter** (if not already installed)
   - Download from [flutter.dev](https://flutter.dev)
   - Follow the installation guide for your platform

2. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/REPO_NAME.git
   cd synco
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   # macOS
   flutter run -d macos
   
   # Windows
   flutter run -d windows
   
   # Linux
   flutter run -d linux
   ```

5. **Build release version**
   ```bash
   # macOS
   flutter build macos --release
   
   # Windows
   flutter build windows --release
   
   # Linux
   flutter build linux --release
   ```

## 📖 How to Use

1. **Launch the app**
2. **Enter a YouTube URL**
   - Single video: `https://www.youtube.com/watch?v=...`
   - Playlist: `https://www.youtube.com/playlist?list=...`
3. **Click Paste** to paste from clipboard (optional)
4. **Click Download**
5. **Configure your download**:
   - Select quality (or choose Audio Only for MP3)
   - For playlists: Select which videos to download
   - Choose output directory
6. **Click Start Download**
7. **Watch the progress** in real-time

## 🎨 Screenshots

_Coming soon_

## 🛠️ Tech Stack

- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language
- **yt-dlp** - Video downloader backend
- **FFmpeg** - Media processing
- **Google Fonts** - Typography
- **Provider** - State management

## 📂 Project Structure

```
synco/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   ├── screens/               # UI screens
│   ├── services/              # Business logic
│   ├── utils/                 # Utilities & theming
│   └── widgets/               # Reusable components
├── assets/                    # App icon & resources
├── macos/                     # macOS platform files
├── windows/                   # Windows platform files
├── linux/                     # Linux platform files
└── pubspec.yaml               # Dependencies
```

## 🔄 Auto-Updates

Synco automatically checks for yt-dlp updates once per month to ensure you have the latest features and bug fixes.

## 🐛 Troubleshooting

### "yt-dlp command not found"
Make sure yt-dlp is installed and in your system PATH.

### "FFmpeg not found"
Install FFmpeg using the instructions in the Prerequisites section.

### Download fails
1. Check your internet connection
2. Verify the YouTube URL is valid
3. Try a different quality option
4. Update yt-dlp: `yt-dlp --update`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

[MIT License](LICENSE) - feel free to use this project for personal or commercial purposes.

## ⚠️ Disclaimer

This tool is for personal use only. Please respect YouTube's Terms of Service and copyright laws. Do not use this tool to download copyrighted content without permission.

## 🙏 Acknowledgments

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - The amazing video downloader
- [Flutter](https://flutter.dev) - Beautiful cross-platform framework
- [FFmpeg](https://ffmpeg.org) - Media processing toolkit

## 📮 Support

If you encounter any issues or have questions, please [open an issue](https://github.com/YOUR_USERNAME/REPO_NAME/issues).

---

**Made with ❤️ by [Your Name]**
