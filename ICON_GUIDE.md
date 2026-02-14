# App Icon Setup Guide

## Quick Steps

1. **Create your icon image** (1024x1024 PNG recommended)
   - Theme: 80s neon Pong style
   - Colors: Cyan (#00FFFF), Magenta (#FF00FF), Dark blue background (#0a0a2e)
   - Design ideas:
     - Simple white paddle and ball with neon glow
     - Retro "PONG" text with arcade font
     - Pixel art style paddle vs ball

2. **Create these files:**
   - `assets/icon/icon.png` - Full square icon (1024x1024)
   - `assets/icon/icon_foreground.png` - Just the icon graphic, no background (1024x1024)

3. **Generate app icons:**
   ```powershell
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

4. **Rebuild your APK:**
   ```powershell
   flutter build apk
   ```
   APK will be at: `build\app\outputs\flutter-apk\app-release.apk`

## Icon Design Tools

### Online Generators (Easy):
- **[Canva](https://canva.com)** - Free templates, search "app icon"
- **[Figma](https://figma.com)** - Professional design tool
- **[Pixlr](https://pixlr.com)** - Free online photo editor

### AI Generators:
- **[DALL-E](https://openai.com/dall-e)** - "80s neon pong game icon, cyan and magenta"
- **[Midjourney](https://midjourney.com)** - "retro arcade pong app icon, neon style"

### Simple DIY Option:
Create a basic icon with these elements:
- Dark blue (#0a0a2e) background
- White vertical paddle bar on left (100px × 300px)
- White circle for ball (80px diameter)
- Cyan (#00FFFF) glow effect around objects

## Example Icon Concept:
```
┌──────────────────────┐
│   ╔═╗    •          │  Cyan/magenta neon
│   ║ ║               │  Dark blue BG
│   ║ ║    •          │  White paddle + ball
│   ╚═╝               │  Glowing edges
└──────────────────────┘
```

## Current Setup:
- Icon paths configured in `pubspec.yaml`
- Adaptive icon enabled for Android
- Background color: #0a0a2e (dark blue, matches menu)
