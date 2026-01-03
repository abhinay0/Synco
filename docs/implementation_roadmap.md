# UniDownloader - Implementation Roadmap

## 🗺️ 6-Week Development Plan (Using Flutter)

This roadmap assumes ~20-30 hours of development per week. Adjust timeline based on your availability.

---

## Week 1: Foundation & Setup ✅

### Day 1-2: Project Initialization
**Goal**: Set up Flutter project with proper architecture

**Tasks**:
- [ ] Create new Flutter project: `flutter create unidownloader`
- [ ] Set up folder structure:
  ```
  lib/
  ├── main.dart
  ├── screens/
  │   ├── home_screen.dart
  │   ├── settings_screen.dart
  │   └── downloads_screen.dart
  ├── widgets/
  │   ├── url_input_field.dart
  │   └── download_progress_card.dart
  ├── models/
  │   ├── download_task.dart
  │   └── video_info.dart
  ├── services/
  │   ├── download_service.dart
  │   └── clipboard_service.dart
  └── utils/
      ├── constants.dart
      └── theme.dart
  ```
- [ ] Add dependencies to `pubspec.yaml`:
  ```yaml
  dependencies:
    provider: ^6.1.0
    path_provider: ^2.1.0
    clipboard: ^0.1.3
    http: ^1.2.0
    file_picker: ^6.0.0
    shared_preferences: ^2.2.0
  ```
- [ ] Set up Git repository
- [ ] Create `.gitignore` (exclude build files, keys)

**Deliverable**: Running Flutter app with basic navigation

---

### Day 3-4: UI Theme & Design System
**Goal**: Implement beautiful UI theme matching Seal app aesthetics

**Tasks**:
- [ ] Create `lib/utils/theme.dart`:
  - Light theme with cyan/purple gradient accent
  - Dark theme with slate background
  - Custom card styles (rounded, elevated)
- [ ] Design app icon (use Figma or generate with AI)
- [ ] Create color constants
- [ ] Set up custom fonts (Inter from Google Fonts)
- [ ] Implement responsive layout helpers

**Deliverable**: Beautiful theme applied to empty app

---

### Day 5-7: Core UI - Home Screen
**Goal**: Build main interface with URL input

**Tasks**:
- [ ] Create `home_screen.dart`:
  - AppBar with settings icon
  - URL input text field (custom styled)
  - "Paste from Clipboard" button
  - "Download" button (disabled until valid URL)
- [ ] Implement URL validation (regex for YouTube, Reddit, etc.)
- [ ] Add placeholder empty state illustration
- [ ] Test on macOS desktop

**Deliverable**: Fully functional home screen UI (no download logic yet)

**Screenshot Checkpoint**: Compare with Seal app screenshot

---

## Week 2: Download Functionality (Desktop First) ⚙️

### Day 8-9: yt-dlp Integration
**Goal**: Get basic video download working on macOS

**Options**:
1. **Option A**: Use yt-dlp Python (via subprocess)
2. **Option B**: Use Dart wrapper package (if exists)

**Recommended**: Option A for maximum compatibility

**Tasks**:
- [ ] Install yt-dlp on system: `pip3 install yt-dlp`
- [ ] Create `lib/services/download_service.dart`
- [ ] Implement `extractVideoInfo(String url)`:
  ```dart
  Future<VideoInfo> extractVideoInfo(String url) async {
    final result = await Process.run('yt-dlp', [
      '-J',  // JSON output
      url,
    ]);
    return VideoInfo.fromJson(jsonDecode(result.stdout));
  }
  ```
- [ ] Implement `downloadVideo(String url, String outputPath)`
- [ ] Test with single YouTube video

**Deliverable**: Can download a single YouTube video to default directory

---

### Day 10-11: Download Progress & UI Updates
**Goal**: Show real-time download progress

**Tasks**:
- [ ] Parse yt-dlp progress output (percentage, speed, ETA)
- [ ] Create `DownloadProgressCard` widget
- [ ] Use `StreamBuilder` to update UI in real-time
- [ ] Add cancel functionality
- [ ] Show download completion notification

**Deliverable**: Live progress bar during download

---

### Day 12-14: Settings & Folder Selection
**Goal**: Allow user to customize download location

**Tasks**:
- [ ] Create `settings_screen.dart`
- [ ] Implement folder picker using `file_picker` package
- [ ] Save preference with `shared_preferences`
- [ ] Add settings options:
  - Default download folder
  - Default video quality (dropdown: Best, 1080p, 720p, 480p, Audio Only)
  - Create playlist folders (toggle)
- [ ] Add "Open Downloads Folder" button

**Deliverable**: Fully functional settings page

---

## Week 3: Playlist Support & Advanced Features 📋

### Day 15-16: Playlist Detection & Info Extraction
**Goal**: Detect playlists and list all videos

**Tasks**:
- [ ] Detect if URL is a playlist (check `_type` in yt-dlp JSON)
- [ ] Extract playlist info: title, uploader, video count
- [ ] Fetch all video entries with thumbnails
- [ ] Create `PlaylistSelectionScreen`
- [ ] Display video list with thumbnails (use `cached_network_image` package)

**Deliverable**: Playlist videos displayed in a list

---

### Day 17-18: Video Selection UI
**Goal**: Implement checkboxes and "Select All" functionality

**Tasks**:
- [ ] Add checkbox to each video tile
- [ ] Implement state management (use Provider):
  - Selected videos list
  - Select all / Deselect all methods
- [ ] Add "Select All" button in AppBar
- [ ] Show selected count (e.g., "6 selected")
- [ ] Disable unavailable videos (private, deleted)

**Deliverable**: Can select/deselect individual playlist videos

---

### Day 19-21: Playlist Download with Folder Organization
**Goal**: Download selected videos into a dedicated playlist folder

**Tasks**:
- [ ] Create folder with playlist name (sanitize special characters)
- [ ] Download selected videos sequentially (or in parallel with limit)
- [ ] Update progress for each video
- [ ] Add overall playlist progress (e.g., "Video 3 of 10")
- [ ] Handle errors gracefully (skip failed videos, log errors)
- [ ] Show completion summary

**Deliverable**: Playlist downloads work perfectly with auto-folder creation

**Testing**: Download a YouTube playlist with 10+ videos

---

## Week 4: Format Selection & Quality Options 🎬

### Day 22-23: Format Detection
**Goal**: Show available formats for a video

**Tasks**:
- [ ] Extract all formats from yt-dlp JSON (`formats` array)
- [ ] Parse format details:
  - Resolution (1080p, 720p, etc.)
  - Video codec (H.264, VP9, AV1)
  - Audio codec (AAC, OPUS)
  - File size estimate
  - FPS
- [ ] Group by type: Video+Audio, Video-only, Audio-only
- [ ] Create `FormatSelectionModal` widget

**Deliverable**: Modal showing all available formats

---

### Day 24-25: Format Selection UI (Seal-style)
**Goal**: Beautiful format selection dialog

**Tasks**:
- [ ] Design card-based format display
- [ ] Highlight recommended format (best quality+size ratio)
- [ ] Show technical details (codec, bitrate, file size)
- [ ] Add "Suggested", "Video", "Audio" sections
- [ ] Implement selection mechanism
- [ ] Pass selected format to download service

**Deliverable**: Pixel-perfect format selection modal

---

### Day 26-28: Quality Presets & Audio Extraction
**Goal**: Quick quality selection

**Tasks**:
- [ ] Add quality preset buttons:
  - Best Quality
  - 1080p
  - 720p
  - Audio Only (MP3)
- [ ] Implement audio extraction with `yt-dlp -x --audio-format mp3`
- [ ] Add format conversion options (if needed)
- [ ] Allow custom yt-dlp arguments (advanced users)
- [ ] Save user's preferred quality in settings

**Deliverable**: One-click quality selection working

---

## Week 5: Multi-Platform Builds 📱💻

### Day 29-30: Desktop - Windows & Linux
**Goal**: Build and test on Windows and Linux

**Tasks**:
- [ ] Build Windows version: `flutter build windows`
- [ ] Test on Windows VM or PC:
  - URL input works
  - Downloads save correctly
  - Folder picker works
- [ ] Build Linux version: `flutter build linux`
- [ ] Test on Ubuntu/Linux Mint
- [ ] Fix platform-specific bugs (file paths, permissions)

**Deliverable**: Working Windows and Linux builds

---

### Day 31-32: Mobile - Android
**Goal**: Build and test Android version

**Tasks**:
- [ ] Update `AndroidManifest.xml`:
  - Add internet permission
  - Add storage permission
- [ ] Build APK: `flutter build apk`
- [ ] Test on Android device or emulator:
  - UI scales correctly for mobile
  - Downloads save to app directory
  - Clipboard works
- [ ] Add "Share to UniDownloader" intent handler
- [ ] Optimize layout for small screens

**Deliverable**: Working Android APK

---

### Day 33-34: Mobile - iOS
**Goal**: Build and test iOS version

**Tasks**:
- [ ] Open in Xcode: `open ios/Runner.xcworkspace`
- [ ] Configure bundle identifier
- [ ] Add permissions to `Info.plist`:
  - NSPhotoLibraryUsageDescription
  - NSMicrophoneUsageDescription (if needed)
- [ ] Build for simulator: `flutter build ios`
- [ ] Test on iPhone simulator
- [ ] Test clipboard access (requires user permission)

**Deliverable**: Working iOS build on simulator

**Note**: Requires Mac + Xcode

---

### Day 35: Web Version Planning
**Goal**: Decide web implementation strategy

**Decision Point**:
- **Option A**: Build web UI only, require backend API (separate Python server)
- **Option B**: Skip web for now, focus on desktop/mobile

**If choosing Option A**:
- [ ] Build Flutter web: `flutter build web`
- [ ] Create Python FastAPI backend (see deployment guide)
- [ ] Deploy web app to Vercel
- [ ] Deploy backend to Railway

**Deliverable**: Decision made and initial web build tested

---

## Week 6: Polish, Testing & Deployment 🚀

### Day 36-37: UI Polish & Bug Fixes
**Goal**: Make everything beautiful and smooth

**Tasks**:
- [ ] Add loading animations (skeleton screens)
- [ ] Implement error handling UI (friendly error messages)
- [ ] Add empty states for all screens
- [ ] Polish animations (page transitions, button hover effects)
- [ ] Test edge cases:
  - Invalid URLs
  - Network errors
  - Disk full scenarios
  - Very long playlists (100+ videos)
- [ ] Fix all discovered bugs

**Deliverable**: Bug-free, polished app

---

### Day 38-39: Feature Completeness
**Goal**: Add final touches

**Tasks**:
- [ ] Implement download history screen
- [ ] Add "Remove" and "Open file" actions
- [ ] Create about page (version, credits, license)
- [ ] Add dark/light theme toggle in settings
- [ ] Implement app update checker (optional)
- [ ] Write comprehensive README.md

**Deliverable**: All MVP features complete

---

### Day 40-42: Deployment & Release
**Goal**: Ship to users!

**Tasks**:
- [ ] **Desktop**:
  - Create DMG installer (macOS)
  - Create EXE installer (Windows)
  - Create AppImage (Linux)
  - Upload to GitHub Releases
- [ ] **Mobile**:
  - Upload APK to GitHub Releases
  - (Optional) Submit to Google Play Store
  - (Optional) Submit to Apple App Store
- [ ] **Web**:
  - Deploy to Vercel/Netlify
  - Set up custom domain
- [ ] **Marketing**:
  - Create demo video
  - Post on Product Hunt
  - Share on Reddit, HN, Twitter
- [ ] **Documentation**:
  - User guide
  - FAQ
  - Known issues

**Deliverable**: UniDownloader live and available for download! 🎉

---

## Post-Launch (Ongoing)

### Week 7+: Community & Iteration

**Tasks**:
- [ ] Monitor GitHub issues
- [ ] Respond to user feedback
- [ ] Fix reported bugs
- [ ] Plan feature updates based on requests
- [ ] Update yt-dlp regularly (monthly)
- [ ] Add support for new platforms as requested

---

## 🎯 Milestones Checklist

| Milestone | Target Date | Status |
|-----------|-------------|--------|
| ✅ Project setup | End of Week 1 | [ ] |
| ✅ Basic download (single video) | End of Week 2 | [ ] |
| ✅ Playlist support | End of Week 3 | [ ] |
| ✅ Format selection | End of Week 4 | [ ] |
| ✅ Multi-platform builds | End of Week 5 | [ ] |
| ✅ Public release | End of Week 6 | [ ] |

---

## 🚨 Risk Mitigation

### Potential Blockers:
1. **yt-dlp breaks**: Sites change their APIs
   - **Mitigation**: Stay updated with yt-dlp releases, use stable version
2. **iOS signing issues**: Apple Developer setup is complex
   - **Mitigation**: Use TestFlight for beta testing, delay App Store submission if needed
3. **Web backend costs**: Server costs for high traffic
   - **Mitigation**: Start with free tier, add rate limiting, consider freemium model

---

## 📊 Success Metrics

### Launch Goals:
- [ ] 100+ GitHub stars in first month
- [ ] 1,000+ downloads across all platforms
- [ ] <5 critical bugs reported
- [ ] 4.5+ star rating (if on stores)

### 6-Month Goals:
- [ ] 10,000+ total downloads
- [ ] Support for 20+ platforms (YouTube, Reddit, etc.)
- [ ] Active community (Discord, GitHub Discussions)
- [ ] Feature parity with Seal + UniDownloader-specific innovations

---

## 🤝 Collaboration & Feedback

**During Development**:
- I'll provide weekly progress updates
- We'll review UI together before moving to next week
- You can test each milestone on your macOS
- We'll iterate based on your feedback

**Decision Points**:
- Week 1: Confirm theme/colors
- Week 3: Approve playlist UI
- Week 5: Decide on web version scope
- Week 6: Review before launch

---

## 💡 Next Steps

**Ready to start?**

1. **Confirm approach**: Do you want to proceed with Flutter?
2. **Set timeline**: Is 6 weeks realistic for your schedule?
3. **Define scope**: 
   - MVP only (desktop + basic download)?
   - Full features (playlists, formats, all platforms)?
4. **Choose starting point**:
   - Fresh Flutter project from scratch?
   - Or improve your existing Python/Flet project?

**Let me know your decision and we'll begin Week 1! 🚀**
