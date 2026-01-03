# UniDownloader - Deployment & Distribution Guide

## 🚀 Deployment Strategy Overview

This guide covers how to build, package, and distribute UniDownloader across all platforms once development is complete.

---

## 1️⃣ Web Deployment

### Architecture:
```
┌──────────────────┐         ┌──────────────────┐
│  Flutter Web App │ ───────▶│  Backend API     │
│  (Vercel/Netlify)│  HTTP   │  (Railway/Render)│
└──────────────────┘         └──────────────────┘
         │                            │
         │                            │
         ▼                            ▼
   User's Browser              yt-dlp + FFmpeg
```

### Frontend (Flutter Web App):

#### Build Command:
```bash
flutter build web --release --web-renderer canvaskit
```

#### Deployment to Vercel (Recommended):

1. **Install Vercel CLI**:
```bash
npm install -g vercel
```

2. **Create `vercel.json`** in project root:
```json
{
  "version": 2,
  "builds": [
    {
      "src": "build/web/**",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/build/web/$1"
    }
  ]
}
```

3. **Deploy**:
```bash
vercel --prod
```

**Custom Domain**: Add your domain in Vercel dashboard (`unidownloader.app`)

---

### Backend (Python FastAPI Server):

#### Project Structure:
```
backend/
├── main.py              # FastAPI app
├── requirements.txt     # Dependencies
├── Dockerfile          # Container config
└── .env               # Environment variables
```

#### `requirements.txt`:
```
fastapi==0.109.0
uvicorn[standard]==0.27.0
yt-dlp==2024.1.1
python-multipart==0.0.6
```

#### `main.py` (Simplified):
```python
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import yt_dlp

app = FastAPI()

# CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://unidownloader.app"],  # Your frontend URL
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/api/extract-info")
async def extract_info(url: str):
    ydl_opts = {'quiet': True, 'extract_flat': 'in_playlist'}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
    return info

@app.post("/api/download")
async def download_video(url: str, quality: str = "1080p"):
    # Implementation here - download and return file URL
    pass
```

#### Deployment to Railway:

1. **Install Railway CLI**:
```bash
npm install -g @railway/cli
```

2. **Login**:
```bash
railway login
```

3. **Initialize**:
```bash
railway init
```

4. **Deploy**:
```bash
railway up
```

**Environment Variables** (set in Railway dashboard):
- `ALLOWED_ORIGINS`: Your frontend URL
- `MAX_FILE_SIZE`: 500MB (or your limit)

**Cost**: Free tier includes 500 hours/month (enough for low-medium traffic)

---

## 2️⃣ Desktop Deployment

### macOS Build:

#### Requirements:
- Xcode installed
- Valid Apple Developer ID (for signing, optional)

#### Build Commands:
```bash
# Build app bundle
flutter build macos --release

# Output: build/macos/Build/Products/Release/UniDownloader.app
```

#### Create DMG Installer:
```bash
# Install create-dmg
brew install create-dmg

# Create DMG
create-dmg \
  --volname "UniDownloader" \
  --volicon "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "UniDownloader.app" 200 190 \
  --hide-extension "UniDownloader.app" \
  --app-drop-link 600 185 \
  "UniDownloader-1.0.0.dmg" \
  "build/macos/Build/Products/Release/UniDownloader.app"
```

#### Code Signing (Optional but Recommended):
```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "build/macos/Build/Products/Release/UniDownloader.app"
```

#### Notarization (for Gatekeeper):
```bash
# Submit for notarization
xcrun notarytool submit UniDownloader-1.0.0.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAM_ID" \
  --wait

# Staple notarization ticket
xcrun stapler staple UniDownloader-1.0.0.dmg
```

**Distribution**: Upload DMG to GitHub Releases

---

### Windows Build:

#### Requirements:
- Visual Studio 2022 (Community Edition)

#### Build Commands:
```bash
# Build Windows app
flutter build windows --release

# Output: build/windows/runner/Release/
```

#### Create Installer (Using Inno Setup):

1. **Install Inno Setup**: Download from https://jrsoftware.org/isdl.php

2. **Create `installer.iss`**:
```ini
[Setup]
AppName=UniDownloader
AppVersion=1.0.0
DefaultDirName={pf}\UniDownloader
DefaultGroupName=UniDownloader
OutputDir=installers
OutputBaseFilename=UniDownloader-Setup-1.0.0
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\UniDownloader"; Filename: "{app}\unidownloader.exe"
Name: "{commondesktop}\UniDownloader"; Filename: "{app}\unidownloader.exe"

[Run]
Filename: "{app}\unidownloader.exe"; Description: "Launch UniDownloader"; Flags: postinstall nowait skipifsilent
```

3. **Compile**:
```bash
iscc installer.iss
```

**Output**: `installers/UniDownloader-Setup-1.0.0.exe`

---

### Linux Build:

#### AppImage (Universal):
```bash
# Build Linux app
flutter build linux --release

# Create AppImage (using appimagetool)
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage

# Package
./appimagetool-x86_64.AppImage build/linux/x64/release/bundle UniDownloader-1.0.0-x86_64.AppImage
```

#### Snap Package:
```bash
# Create snapcraft.yaml
snapcraft init
snapcraft
```

#### Flatpak:
```bash
# Using flatpak-builder
flatpak-builder --repo=repo --force-clean build-dir com.unidownloader.app.yml
```

---

## 3️⃣ Mobile Deployment

### Android Build:

#### Requirements:
- Android Studio
- Java JDK 11+

#### Build APK (for testing/direct distribution):
```bash
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Build App Bundle (for Google Play):
```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

#### Key Signing (required for release):

1. **Create keystore**:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

2. **Create `android/key.properties`**:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/Users/you/upload-keystore.jks
```

3. **Update `android/app/build.gradle`**:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### Google Play Console Upload:
1. Create app listing
2. Upload AAB file
3. Fill in store details (description, screenshots, icon)
4. Submit for review

**Cost**: $25 one-time registration fee

---

### iOS Build:

#### Requirements:
- Mac with Xcode
- Apple Developer Program membership ($99/year)

#### Build Commands:
```bash
# Build for iOS
flutter build ios --release

# Or create archive in Xcode
open ios/Runner.xcworkspace
# Product → Archive
```

#### App Store Connect Upload:

1. **Create App ID** in Apple Developer Portal
2. **Create App Store Connect listing**
3. **Archive app** in Xcode
4. **Upload via Xcode Organizer** or Transporter app
5. **Submit for review**

**TestFlight** (beta testing):
- Upload build
- Add external testers (up to 10,000)
- Get feedback before public release

**Cost**: $99/year for Apple Developer Program

---

## 4️⃣ Continuous Deployment (CI/CD)

### GitHub Actions Workflow:

Create `.github/workflows/release.yml`:

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build web --release
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}

  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build macos --release
      - run: create-dmg ...
      - uses: actions/upload-artifact@v3
        with:
          name: macos-dmg
          path: '*.dmg'

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build windows --release
      # Add Inno Setup steps

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build linux --release
      # Add AppImage creation

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --release
      - run: flutter build appbundle --release
      - uses: actions/upload-artifact@v3

  create-release:
    needs: [build-macos, build-windows, build-linux, build-android]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v3
      - uses: softprops/action-gh-release@v1
        with:
          files: |
            **/*.dmg
            **/*.exe
            **/*.AppImage
            **/*.apk
```

**Trigger**: Push a git tag `v1.0.0` → Automatic builds for all platforms

---

## 5️⃣ Distribution Channels

### Free Distribution:
1. **GitHub Releases**: Host all desktop binaries + APK
2. **Direct Download**: Link on your website
3. **F-Droid** (Android): Open-source app store (requires FOSS compliance)

### Paid/Official Stores:
1. **Google Play Store**: $25 one-time
2. **Apple App Store**: $99/year
3. **Microsoft Store** (Windows): $19 one-time
4. **Mac App Store**: $99/year (same as iOS)
5. **Snap Store** (Linux): Free
6. **Flathub** (Linux): Free

---

## 6️⃣ Marketing & User Acquisition

### Launch Strategy:

1. **Product Hunt Launch**: Create a listing, get community votes
2. **Reddit Posts**: r/software, r/youtube, r/opensource
3. **Hacker News**: "Show HN: UniDownloader – Download from any video/audio platform"
4. **Twitter/X**: Tweet with demo video
5. **GitHub README**: Comprehensive documentation with screenshots
6. **Blog Post**: Write about the tech stack and challenges

### SEO Keywords:
- YouTube downloader
- Video downloader for Mac/Windows/Linux
- SoundCloud downloader
- Instagram reel downloader
- Reddit video downloader
- Cross-platform media downloader

### Landing Page Essentials:
- **Hero Image**: Screenshot of app in action
- **Feature List**: Platform support, formats, quality options
- **Download Buttons**: For each platform
- **Privacy Statement**: "No data collection, all local processing"
- **Open Source Badge**: Link to GitHub repo

---

## 7️⃣ Monetization (Optional)

### Free & Open Source (Recommended):
- No cost to users
- Build community and goodwill
- Accept donations (GitHub Sponsors, Ko-fi, Buy Me a Coffee)

### Freemium Model:
- **Free Tier**: Single videos, max 720p
- **Pro Tier** ($2.99/month or $19.99/year):
  - Unlimited playlist downloads
  - 4K quality
  - Batch processing
  - No ads (if you add ads)
  - Priority support

### One-Time Purchase:
- Desktop app: $4.99
- Mobile app: $2.99
- Web service: Free with backend rate limits

---

## 8️⃣ Post-Launch Maintenance

### Update Frequency:
- **Bug fixes**: As needed (patch releases)
- **yt-dlp updates**: Monthly (to support new platforms/fix extractors)
- **Feature updates**: Quarterly (new features, UI improvements)

### Support Channels:
- GitHub Issues for bug reports
- Discussion forum for questions
- Email support for pro users
- Discord community (optional)

---

## 📊 Cost Summary

| Item | One-Time | Annual | Notes |
|------|----------|--------|-------|
| **Development** | $0 | $0 | Free tools |
| **Domain** | $15 | $15 | .app domain |
| **Web Hosting** | $0 | $0-120 | Free tier or $10/mo for backend |
| **Apple Developer** | $0 | $99 | Required for iOS/macOS App Store |
| **Google Play** | $25 | $0 | One-time only |
| **Code Signing Cert** | $0-200 | $0 | Optional for Windows |
| **Total (Minimum)** | $40 | $114 | With App Store + Play Store |
| **Total (Maximum)** | $240 | $234 | All stores + premium hosting |

---

## 🎯 Launch Checklist

### Pre-Launch:
- [ ] Complete all MVP features
- [ ] Test on all target platforms
- [ ] Create app icons (all sizes)
- [ ] Write comprehensive README
- [ ] Create demo video (60 seconds)
- [ ] Prepare screenshots for stores
- [ ] Set up analytics (optional)
- [ ] Create landing page
- [ ] Register domain
- [ ] Set up social media accounts

### Launch Day:
- [ ] Deploy web version
- [ ] Upload to GitHub Releases
- [ ] Submit to Google Play
- [ ] Submit to App Store
- [ ] Post on Product Hunt
- [ ] Share on Reddit/HN/Twitter
- [ ] Send to tech blogs
- [ ] Monitor for issues

### Post-Launch (Week 1):
- [ ] Respond to user feedback
- [ ] Fix critical bugs
- [ ] Update documentation based on FAQs
- [ ] Thank early adopters
- [ ] Plan next feature update

---

**You're now equipped to deploy UniDownloader to the world! 🚀**
