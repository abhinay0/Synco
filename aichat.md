# Synco Project Summary & Roadmap

## 📅 Project Status: January 2026

### ✅ Completed
*   **Desktop Application (Core)**:
    *   Successfully implemented a cross-platform desktop application using Flutter.
    *   Features: Video downloading, playlist support, quality selection, dark mode.
    *   Platforms verified: macOS.
*   **Expansion to Mobile & Web**:
    *   Added support for Android, iOS, and Web platforms.
    *   Generated necessary project scaffolding (`android/`, `ios/`, `web/` directories).
*   **Repository Management**:
    *   Pushed desktop version to GitHub.
    *   synced code for mobile and web platforms to the repository.

### 🚧 Works in Progress / To Do
*   **Mobile Testing & Optimization**:
    *   Verify build and run on Android Emulator and Physical Devices.
    *   Verify build and run on iOS Simulator (requires macOS).
    *   Adapt UI for smaller screens (ensure responsive design).
    *   **Crucial**: Handle mobile permissions (Storage, Internet) and file system access as it differs from Desktop.
    *   **Dependency Check**: Ensure `yt-dlp` usage (executing external binary) is handled correctly on mobile. On mobile, generating/bundling executables is harder. We might need to switch to a Dart-native package or a server-side solution for the actual downloading if `yt-dlp` binary cannot be bundled easily on non-rooted phones.
*   **Web Development**:
    *   **Architecture Alert**: The current app relies on `yt-dlp` (an executable). **Flutter Web cannot run executables**.
    *   To make the Web version work, we MUST implement a backend server (Python/Node) to handle the actual downloading, or switch to a solution that works entirely in the browser (though YouTube downloading is difficult purely client-side due to CORS and strict API limits).
*   **App Icons**:
    *   Ensure new icons are correctly applied to iOS and Android builds.

### 📝 Summary
The project started as a desktop video downloader ("Synco"). We have successfully stabilized the macOS desktop version. We have now enabled the codebase for Android, iOS, and Web by generating the platform folders. 

**Immediate Challenge**: The current logic uses `yt-dlp` as a command-line tool. This works great on Desktop (Windows/Mac/Linux). 
- **For Mobile**: We need to verify if we can bundle the binary or if we need a different library.
- **For Web**: This logic **will not work** out of the box. A backend API is recommended.

### 🚀 Next Steps
1.  **Commit & Push**: Sync all new platform files to GitHub (Done).
2.  **Mobile Strategy**: precise "how-to" for running `yt-dlp` on Android/iOS (termux, or FFMpeg kit, or alternative).
3.  **Web Strategy**: Set up a simple backend API if Web support is a priority.
