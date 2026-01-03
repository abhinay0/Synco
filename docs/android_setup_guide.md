# Android Development Setup Guide for Synco

This guide will help you set up the Android development environment on your Mac manually.

## 1. Download Android Studio
1.  Go to the official [Android Studio download page](https://developer.android.com/studio).
2.  Click **Download Android Studio**.
3.  Accept the terms and confirm the download.
4.  **Important:** Since you are on a Mac with Apple Silicon (M-series), ensure you download the version optimized for **Mac with Apple chip** (Arm64), usually detected automatically.

## 2. Install Android Studio
1.  Open the downloaded `.dmg` file.
2.  Drag **Android Studio** into your **Applications** folder.
3.  Launch Android Studio from your Applications folder.

## 3. Initial Setup Wizard
1.  On the first run, the **Setup Wizard** will appear.
2.  Choose **Standard** install type (recommended) and click **Next**.
3.  Verify the settings and click **Next**.
4.  Accept the License Agreements for all components (click on each license in the left list and select "Accept").
5.  Click **Finish**.
6.  Android Studio will now download the Android SDK, platform tools, and emulator accelerator. **This may take a while.**

## 4. Install Command Line Tools (Critical for Flutter)
Flutter requires the Android command-line tools to be installed.
1.  On the compiled "Welcome to Android Studio" screen, click **More Actions** (three dots) > **SDK Manager**.
2.  In the SDK Manager window, go to the **SDK Tools** tab (middle tab).
3.  Check the box for **Android SDK Command-line Tools (latest)**.
4.  Click **Apply** and then **OK** to install.

## 5. Configure Flutter to use Android SDK
Once everything is installed:
1.  Open your terminal.
2.  Tell Flutter where your Android SDK is located (default location):
    ```zsh
    flutter config --android-sdk ~/Library/Android/sdk
    ```
3.  Accept Android Licenses:
    ```zsh
    flutter doctor --android-licenses
    ```
    *Review the licenses (press `y` and `Enter` for each one).*

## 6. Verify Installation
Run the following command to make sure everything is green:
```zsh
flutter doctor -v
```
You should now see a green checkmark `[✓]` next to **Android toolchain**.

## 7. Set up a Virtual Device (Emulator) - Optional
If you don't have a physical Android device:
1.  Open **Android Studio**.
2.  Go to **More Actions** > **Virtual Device Manager**.
3.  Click **Create device**.
4.  Select a phone (e.g., Pixel 7) and click **Next**.
5.  Select a System Image (e.g., API 34 or "UpsideDownCake") and download it if needed.
6.  Click **Next** and **Finish**.
7.  Run the emulator by clicking the **Play** button.
