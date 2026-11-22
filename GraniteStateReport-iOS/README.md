# Granite State Report for iPhone

Native SwiftUI app for [granitestatereport.com](https://granitestatereport.com). Reads the site's public WordPress REST API. No server, no keys, no third-party packages.

**Status: written and reviewed, not yet compiled.** See `docs/GSR_iOS_Deploy_Guide_v1_2026-11-22.md` for build and App Store steps.

## What it does

- **Today.** Latest stories with a lead story, pull to refresh, endless scroll, last feed kept for offline launch, live-stream banner when GSR is live.
- **Sections.** The site's full category tree.
- **Reader.** Stories in GSR's own article template, reading progress bar, text size control, story-to-story links that stay in the app.
- **Listen.** Article narration, the podcast and video lists from the site's media catalog, with a background audio player, lock screen controls, playback speed and a queue.
- **Saved.** Bookmarked stories stored with full text for offline reading.
- **Search.** Full archive search with recent searches.
- **Alerts.** Optional new-story notifications through background refresh. No push server.
- **About.** Tip line, contact, mission, constitution, ethics, corrections, legal pages.

## Requirements

Xcode 26 or later. iOS 17.0 or later. iPhone.

## Layout

```
GraniteStateReport/
  App/        entry point, tabs, notification delegate
  Core/       site config, models, API client, storage, theme
  Audio/      player and player views
  Features/   Today, Sections, Listen, Saved, Search, Article, About
  Resources/  assets, Info.plist, privacy manifest
GraniteStateReportTests/
generate_project.rb   rebuilds the .xcodeproj after files are added or removed outside Xcode
```

Site-specific values (URLs, contact details, hidden media tabs, pages that must open in Safari) are in `GraniteStateReport/Core/GSR.swift`.
