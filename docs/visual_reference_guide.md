# UniDownloader - Visual Design Reference (Seal App)

## 📸 Reference Screenshots from Seal App

Below are the screenshots you provided showing the Seal app's UI design that we'll use as inspiration for UniDownloader.

---

## Screenshot 1: Main Interface & Playlist Download

![Seal app main interface showing URL input, active download, and playlist selection with checkboxes](./uploaded_image_0_1767398141603.png)

### Key UI Elements Shown:

1. **Left Panel - Active Download**:
   - Green loading spinner indicating download in progress
   - Clean card design with rounded corners
   - YouTube video thumbnail preview
   - Download text: "Download in progress, click to cancel"
   - Prominent yellow clipboard icon (paste from clipboard)
   - Lime green download button

2. **Right Panel - Playlist Selection**:
   - Header showing "6 selected" with Download button
   - Playlist title: "sasakure. UK VOCALOID-UTAU"
   - Individual video cards with:
     - Thumbnails
     - Video titles in Japanese
     - Channel name (sasakure. UK)
     - Checkboxes for selection
   - "Select all" toggle at bottom
   - Filter/sort icon

---

## Screenshot 2: Download Configuration & Format Selection

![Seal app showing playlist download progress, format selection modal, and download history](./uploaded_image_1_1767398141603.png)

### Key Features Illustrated:

1. **Left Panel - Downloads Section**:
   - "Downloads" page with filter chips (Audio, Video, Youtube, BiliBili, Niconico)
   - List of downloaded items with thumbnails
   - Each item shows:
     - Thumbnail
     - Title (Japanese text)
     - Channel name
     - File size (18.84 M, 51.71 M)
   - "Remove" and "Open link" action buttons

2. **Middle Panel - Playlist Download Progress**:
   - Progress indicator: "Downloading playlist (1/2), click to stop"
   - Video preview while downloading
   - Modal: "Configure before downloading"
     - **General** section:
       - "Download playlist" button
       - "Embed subtitles" toggle
     - **Advanced** section:
       - "Custom command" input
       - "+ New template" option
     - **Additional settings**:
       - Video format selector
       - Video quality selector
       - More options icons
     - Cancel and Download buttons (green)

3. **Right Panel - Format Selection**:
   - Modal title: "Format selection"
   - Video thumbnail with duration (03:16)
   - **Suggested** format (highlighted in lime green):
     - "399 - 1920x1080 (1080p)+251 - audio only (medium)"
     - Size: 18.91 M, Bitrate: 809.2 Kbps
     - Format: WEBM (AV01 OPUS)
   - **Video** options:
     - Multiple resolution choices (720p, 360p)
     - File sizes and bitrates shown
     - Format codecs (MP4 AVC1 MP4A)
   - **Audio** options:
     - Audio-only downloads
     - Different formats (WEBM OPUS, M4A MP4A)
     - Bitrate information

---

## Screenshot 3: Custom Commands, Display Settings & Themes

![Seal app showing custom command templates and display theme options](./uploaded_image_2_1767398141603.png)

### Advanced Features Shown:

1. **Left Panel - Custom Command Templates**:
   - Toggle: "Use custom command" (enabled, lime green)
   - **Predefined Templates**:
     - "Smallest Video" with command: `-v -S +size`
     - "Audio Template Sample" with command snippet starting with `-x --no-mtime...`
     - "List Subtitles" command
     - "List Format" command
     - "Download subtitles" command
     - "Parse metadata" command
   - "+ New template" button
   - "Edit shortcuts" option at bottom

2. **Middle Panel - Display Settings (Light Theme)**:
   - Video preview cards with modern, clean design
   - Sample text: "Video title sample text" and "Video creator sample text"
   - Color theme selector showing 4 color options
   - **Dynamic color** toggle (enabled)
     - Description: "Apply colors from wallpapers to the app theme"
   - **Dark theme** toggle (off)
     - Shows "System" setting
   - **Display language**: System

3. **Right Panel - Display Settings (Dark Theme)**:
   - Same layout as middle panel but in dark mode
   - Background: Deep slate/navy color
   - Cards with elevated appearance
   - Color theme options adapted for dark mode
   - All toggles and text in light colors for contrast

---

## 🎨 Design Principles Extracted from Seal:

### Visual Style:
1. **Modern Material Design**: Cards with elevation, rounded corners (16px+)
2. **Lime/Green Accent Color**: Used for primary actions (#a4d96c or similar)
3. **Clean Typography**: Readable fonts, good hierarchy
4. **Generous Spacing**: Not cramped, breathable layouts
5. **Subtle Shadows**: Depth without being heavy
6. **Dynamic Theming**: System wallpaper color integration option

### Interaction Patterns:
1. **Progressive Disclosure**: Advanced options hidden in modals
2. **Inline Actions**: Quick buttons (Download, Cancel, Remove)
3. **Visual Feedback**: Progress states, loading spinners
4. **Batch Operations**: Select multiple items with checkboxes
5. **Preset Management**: Save custom templates for reuse

### Information Architecture:
1. **Main Actions Front & Center**: Big download button
2. **Settings Organized by Category**: General, Advanced, Display
3. **Format Selection is Detailed**: All available formats shown with tech specs
4. **Download History Visible**: Easy access to past downloads

---

## 🚀 How UniDownloader Will Adapt This:

1. **Keep the clean, card-based layout** ✅
2. **Use similar color scheme** with our own brand colors (cyan/purple gradient) ✅
3. **Implement the same playlist selection UI** with checkboxes ✅
4. **Add format selection modal** with detailed information ✅
5. **Create custom command/template system** for advanced users ✅
6. **Support dark/light themes** with dynamic colors ✅
7. **Improve upon**:
   - Add more platform support (Spotify, SoundCloud, Instagram, Reddit, etc.)
   - Better folder organization (channel folders, playlists)
   - Web version for browser-based downloading
   - Cross-platform support (one codebase for all platforms)

---

**These screenshots perfectly showcase a mature, polished downloader app UI that we'll use as our north star for UniDownloader!**
