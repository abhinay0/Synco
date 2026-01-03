# Synco - Project Documentation

Welcome to the **Synco** project documentation (formerly UniDownloader). This file serves as the central hub for all project details.

## 📂 Documentation Index

All detailed documentation is located in this `docs/` directory.

### 1. [Feature Specifications](feature_specifications.md)
Detailed breakdown of Synco's features, including Smart Folder Organization, Playlist Management, and platform-specific behaviors.
*Key Features:*
- URL Paste & Clipboard Integration
- Playlist & Channel Downloading (with folder organization)
- Video/Audio Quality Selection
- Smart Folder Management

### 2. [Visual Reference Guide](visual_reference_guide.md)
Visual guide based on the 'Seal' app, defining the UI aesthetics, including:
- Main Interface & Playlist Selection
- Download Configuration
- Dark/Light Theme & Dynamic Colors

### 3. [Technology Stack](technology_stack_recommendation.md)
Analysis and decision to use **Flutter** for this project to achieve true cross-platform support (macOS, Windows, Linux, Android, iOS, Web) from a single codebase.

### 4. [Implementation Roadmap](implementation_roadmap.md)
A 6-week step-by-step plan to build Synco:
- **Week 1:** Foundation & Setup (Current)
- **Week 2:** Desktop Download Functionality
- **Week 3:** Playlist Support
- **Week 4:** Format & Quality Options
- **Week 5:** Multi-Platform Builds
- **Week 6:** Deployment & Polish

### 5. [Deployment Guide](deployment_guide.md)
Instructions on how to build and distribute Synco for all platforms, including GitHub Releases, App Stores, and Web Hosting.

### 6. [Android Setup Guide](android_setup_guide.md)
Manual instructions for setting up Android Studio/SDK to enable mobile development.

---

## 🚀 Quick Start
To run the project on macOS Desktop:
```bash
flutter run -d macos
```

To run on Web (Chrome):
```bash
flutter run -d chrome
```

## 🛠 Project Structure
- `lib/`: Source code
    - `main.dart`: Entry point
- `documents/`: Planning and design docs
- `references/`: Legacy reference code (Seal/VidBee)
