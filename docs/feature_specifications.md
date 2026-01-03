# UniDownloader - Detailed Feature Specifications

## 📋 Core Features

### 1. URL Input & Clipboard Integration
- **Text input field** with hint: "Paste video/audio URL from any platform..."
- **"Paste" button** that reads from system clipboard
- **Auto-detection** of URL type (video, playlist, channel, audio)
- **Supported platforms**:
  - YouTube (videos, playlists, channels, shorts)
  - Reddit (videos, images from posts)
  - Instagram (reels, posts, stories)
  - Twitter/X (videos, GIFs)
  - SoundCloud (audio tracks, playlists)
  - Spotify (requires special handling - metadata only)
  - Amazon Music (requires authentication)
  - Facebook (videos)
  - TikTok (videos)
  - Vimeo
  - Dailymotion
  - And 1000+ more via yt-dlp

---

### 2. Playlist Management (Matching Seal App)

#### UI Layout:
```
┌─────────────────────────────────────────────────┐
│  Playlist: "sasakure. UK VOCALOID-UTAU"         │
│  6 selected                              Download│
├─────────────────────────────────────────────────┤
│  Select videos to download from the playlist    │
│                                                  │
│  ☑ [Thumbnail] トンデモワンダーズ feat...          │
│     sasakure. UK                                │
│                                                  │
│  ☑ [Thumbnail] AMARA(大未来電脳) feat...          │
│     sasakure. UK                                │
│                                                  │
│  ☐ [Thumbnail] FUTURE EVE feat...               │
│     sasakure. UK                                │
│                                                  │
│  ☑ [Thumbnail] ぼくらの16bit戦争(Remas...)        │
│     sasakure. UK                                │
│                                                  │
│                        Select all      [Filter] │
└─────────────────────────────────────────────────┘
```

#### Features:
- ✅ Fetch and display all videos with metadata
- ✅ Show thumbnail, title, and channel for each video
- ✅ Individual checkboxes for each video
- ✅ "Select All" / "Deselect All" toggle button
- ✅ Display count of selected videos
- ✅ Filter/search within playlist
- ✅ Display total duration and size estimate
- ✅ Sort options (date, duration, title)

---

### 3. Download Configuration (Before Download)

Matching the Seal app's configuration modal:

#### General Settings:
- **Download type**:
  - ☑ Video (with quality selector)
  - ☐ Audio only (MP3, M4A, OPUS, etc.)
  - ☐ Subtitle/Caption
- **Video quality options**:
  - 4K (2160p)
  - 1080p (Full HD) - **Default**
  - 720p (HD)
  - 480p
  - 360p
  - 240p
  - Best available
- **Audio quality** (for audio-only mode):
  - 320 kbps
  - 192 kbps
  - 128 kbps
  - Best available
- **Format preference**:
  - MP4 (video)
  - WEBM (video)
  - MP3 (audio)
  - M4A (audio)
  - WAV (audio)

#### Advanced Options:
- ☐ Embed metadata (title, artist, album, thumbnail)
- ☐ Embed subtitles (if available)
- ☐ Auto-generate subtitles (YouTube only)
- ☐ Download thumbnail separately
- ☐ Limit download speed (KB/s)
- Custom yt-dlp commands (for advanced users)

---

### 4. Smart Folder Organization

#### Folder Structure:

```
📁 UniDownloader/                    ← Main folder (user-selected)
├── 📁 Singles/                      ← Individual videos/tracks
│   ├── 🎥 tutorial_video.mp4
│   └── 🎵 song.mp3
│
├── 📁 Playlists/
│   ├── 📁 sasakure. UK VOCALOID-UTAU/
│   │   ├── 🎥 video1.mp4
│   │   └── 🎥 video2.mp4
│   └── 📁 My Favorite Songs/
│       ├── 🎵 track1.mp3
│       └── 🎵 track2.mp3
│
└── 📁 Channels/
    └── 📁 @channel_name/
        ├── 📁 Playlist_A/
        └── 📁 Playlist_B/
```

#### Behavior:
1. **First-time setup**: Prompt user to select main download folder
2. **Remember preference**: Save in app settings
3. **Single video/audio**: Save directly to main folder or `Singles/` subfolder
4. **Playlist download**: 
   - Create folder with playlist name
   - Sanitize folder name (remove special characters)
   - Add numbering prefix if enabled (01_video.mp4, 02_video.mp4)
5. **Channel download**: 
   - Create channel folder
   - Create playlist subfolders inside
6. **Settings option**: "Ask me every time" vs "Always use default location"

---

### 5. Download Progress UI

#### During Download:

```
┌─────────────────────────────────────────────────┐
│  ⏸ Downloading "トンデモワンダーズ feat. 初音ミク"  │
│                                                  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░  65%                     │
│  18.4 MB / 28.2 MB     ↓ 2.3 MB/s    ETA: 4s   │
│                                                  │
│  Video 1 of 6 from playlist                     │
│                                        [Cancel]  │
└─────────────────────────────────────────────────┘
```

#### Queue Management:
- Show progress for current download
- Display queue of pending downloads
- Allow pause/resume individual downloads
- Cancel button for each download
- Overall progress if downloading multiple files
- Download history (recent downloads)

---

### 6. Settings Panel

#### Categories:

**General**:
- Default download location
- Auto-paste from clipboard when app opens
- Dark/Light theme toggle
- Language selection
- Notification preferences

**Download Defaults**:
- Preferred video quality (1080p default)
- Preferred audio format (MP3 default)
- Auto-download subtitles
- Embed metadata
- Filename template: `{title}` or `{playlist_index}_{title}` or custom

**Advanced**:
- yt-dlp binary path (auto-detected or custom)
- FFmpeg path (auto-detected or custom)
- Maximum concurrent downloads (1-5)
- Proxy settings (HTTP/SOCKS5)
- Custom user-agent
- Cookies file path (for authenticated downloads)

**Storage**:
- Auto-create playlist folders: ON/OFF
- Auto-create channel folders: ON/OFF
- Delete incomplete downloads: ON/OFF
- Keep download history: 30 days / 90 days / Forever

---

### 7. Format & Quality Selection (Seal-style)

#### Format Selection Modal:

```
┌─────────────────────────────────────────────────┐
│  Format selection                       Download│
│                                                  │
│  Video title with thumbnail                     │
│  Channel name                          03:45    │
│                                                  │
│  Suggested                                       │
│  ┌──────────────────────────────────────────┐  │
│  │ 399 - 1920x1080 (1080p)+251 - audio     │  │
│  │ 18.91 M  809.2 Kbps                      │  │
│  │ WEBM (AV01 OPUS)                         │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  Video                                           │
│  ┌──────────────────────┐ ┌─────────────────┐  │
│  │ 22 - 1280x720 (720p)│ │ 18 - 640x360    │  │
│  │ 9.73 M  406.6 Kbps  │ │ 6.00 M  251 Kbps│  │
│  │ MP4 (AVC1 MP4A)     │ │ MP4 (AVC1 MP4A) │  │
│  └──────────────────────┘ └─────────────────┘  │
│                                                  │
│  Audio                                           │
│  ┌──────────────────────┐ ┌─────────────────┐  │
│  │ 251 - audio only    │ │ 140 - audio only│  │
│  │ 3.16 M  135.2 Kbps  │ │ 3.03 M  129.5   │  │
│  │ WEBM (OPUS)         │ │ M4A (MP4A)      │  │
│  └──────────────────────┘ └─────────────────┘  │
│                                                  │
│                      [Cancel]      [Download]   │
└─────────────────────────────────────────────────┘
```

---

### 8. Platform-Specific Features

#### Desktop (macOS, Windows, Linux):
- ✅ System tray icon with quick actions
- ✅ Native file picker for folder selection
- ✅ Drag-and-drop URL support
- ✅ Keyboard shortcuts (Cmd/Ctrl+V to paste, Cmd/Ctrl+D to download)
- ✅ Auto-update mechanism
- ✅ Open download folder in Finder/Explorer
- ✅ Menubar controls

#### Mobile (Android, iOS):
- ✅ Share sheet integration (share from YouTube app → UniDownloader)
- ✅ Background downloads
- ✅ Download notifications
- ✅ Files saved to app's document directory
- ✅ "Open in" file sharing
- ✅ Widget for quick paste+download

#### Web:
- ✅ Progressive Web App (PWA) - installable
- ✅ Download via server (server fetches, user downloads)
- ✅ No folder organization (browser handles downloads)
- ✅ Share to social features

---

## 🎨 UI Design Guidelines

### Color Scheme (Modern & Premium):

#### Light Theme:
- **Primary**: `#6366f1` (Indigo)
- **Secondary**: `#8b5cf6` (Purple)
- **Accent**: `#06b6d4` (Cyan)
- **Background**: `#ffffff`
- **Surface**: `#f9fafb`
- **Text**: `#111827`

#### Dark Theme:
- **Primary**: `#818cf8` (Soft Indigo)
- **Secondary**: `#a78bfa` (Soft Purple)
- **Accent**: `#22d3ee` (Bright Cyan)
- **Background**: `#0f172a` (Slate 900)
- **Surface**: `#1e293b` (Slate 800)
- **Text**: `#f1f5f9`

### Typography:
- **Heading**: Inter Bold, 24px
- **Body**: Inter Regular, 16px
- **Caption**: Inter Medium, 14px

### Components:
- **Buttons**: Rounded corners (8px), shadow on hover
- **Input fields**: Border radius 12px, subtle shadow
- **Cards**: Elevation 2, border radius 16px
- **Animations**: Smooth transitions (200ms ease)

---

## 🔐 Privacy & Security

1. **No data collection**: All processing happens locally (desktop/mobile)
2. **No account required**: Pure download tool
3. **Open source**: Transparent codebase
4. **Secure connections**: HTTPS only
5. **Cookie handling**: Optional, user-provided for authenticated content
6. **No tracking**: Zero analytics or telemetry

---

## 📱 App Icon Design

Suggested icon concept:
- **Symbol**: Downward arrow with play button
- **Colors**: Gradient from cyan to purple
- **Style**: Modern, flat design with subtle 3D effect
- **Sizes**: All required (Desktop: 512x512, Mobile: 1024x1024, Web: favicon)

---

## 🚀 MVP (Minimum Viable Product) Features

### Phase 1 - Core Functionality:
1. ✅ URL input + paste button
2. ✅ Single video/audio download
3. ✅ Quality selection (Best, 1080p, 720p, Audio only)
4. ✅ Download progress bar
5. ✅ Basic settings (download location)

### Phase 2 - Playlist Support:
1. ✅ Playlist detection
2. ✅ Video list with checkboxes
3. ✅ Select all/none
4. ✅ Auto-create playlist folder

### Phase 3 - Polish:
1. ✅ Format selection modal
2. ✅ Download history
3. ✅ Dark/Light theme
4. ✅ Custom templates
5. ✅ Queue management

---

**This specification matches the Seal app UI you provided while adding UniDownloader-specific features!**
