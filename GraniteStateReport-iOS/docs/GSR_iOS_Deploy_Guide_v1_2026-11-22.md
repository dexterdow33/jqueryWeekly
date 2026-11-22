# Granite State Report for iPhone: Build and Deploy Guide

Version 1 · November 22, 2026 · App version 1.0.0 (build 1)

## Read this first

**This code has not been compiled.** It was written on a Linux machine with no Xcode and no Swift compiler. It was reviewed line by line, the Xcode project was generated and validated by tooling, and the article reader was rendered against a live GSR story at phone width. None of that replaces a build. Expect the first build in Xcode to surface a small number of errors. Step 3 says what to do with them.

Everything Apple-side below (prices, required Xcode version, screenshot sizes, review rules) changes without notice. Items marked **VERIFY** were not confirmed against Apple's live pages in full; check them before you rely on them.

## What you need

| Item | Detail |
|---|---|
| A Mac | Running a macOS version that supports Xcode 26 or later. **VERIFY** the macOS minimum on the Xcode page in the Mac App Store. |
| Xcode 26 or later | Free, from the Mac App Store. Apple's Upcoming Requirements page states that since April 28, 2026, uploads to App Store Connect must be built with Xcode 26 or later using the iOS 26 SDK or later. Source: https://developer.apple.com/news/upcoming-requirements/ |
| Apple Developer Program membership | Required for TestFlight and the App Store. $99 per year in the U.S. **VERIFY** at https://developer.apple.com/programs/ . Not required to run the app in the Simulator. |
| An iPhone on iOS 17 or later | Optional but strongly advised. Background audio, alerts and lock screen controls cannot be fully tested in the Simulator. |

You do not need a server, an API key, or any change to granitestatereport.com. The app reads the site's public WordPress REST API.

## Step 1. Get the code onto the Mac

The app lives in the `GraniteStateReport-iOS` folder of the `dexterdow33/jqueryWeekly` repository, on the branch `claude/granitestatereport-ios-app-2kwb87` (or on `main` once the pull request is merged).

```bash
git clone https://github.com/dexterdow33/jqueryWeekly.git
cd jqueryWeekly
git checkout claude/granitestatereport-ios-app-2kwb87
open GraniteStateReport-iOS/GraniteStateReport.xcodeproj
```

Clone it somewhere ordinary such as `~/Developer`. Do not put it inside `~/Library`.

If Xcode offers to "update to recommended settings," accept.

## Step 2. Run it in the Simulator

1. At the top of the Xcode window, pick the **GraniteStateReport** scheme and any iPhone simulator.
2. Press **Cmd-R**.
3. The app should launch to the Today tab and load the latest stories.

## Step 3. If the build fails

Because the code has never been compiled, treat a handful of errors on the first build as expected.

1. Open the Issue navigator (**Cmd-5**).
2. Copy every red error with its file name and line number.
3. Paste them into a new Claude session opened on this repository and ask for fixes. Most will be one-line corrections.

Faster route: if you share a Mac folder outside `~/Library` through Claude's Remote Control (the Claude desktop app: Settings, Claude Code, Remote Control) and clone the repository there, a Claude session can run the build on your Mac and fix the errors directly. The folder currently shared from your Mac, named "GSR," sits inside `~/Library`, and folders there cannot be used.

## Step 4. Run the tests

Press **Cmd-U**. The test target checks the pieces that are easiest to get subtly wrong: HTML entity decoding in headlines, post decoding from the WordPress API, image resizing, link routing (story links open in the reader, support links leave the app), and saved-story storage. All tests should pass before you ship.

## Step 5. Set up signing

1. In Xcode, click the blue **GraniteStateReport** project icon at the top of the left sidebar.
2. Select the **GraniteStateReport** target, then the **Signing & Capabilities** tab.
3. Check **Automatically manage signing**.
4. Under **Team**, choose your Apple Developer team. (Add your Apple ID first under Xcode, Settings, Accounts if it is not listed.)
5. The bundle identifier is `com.granitestatereport.app`. If Apple reports it as taken, change it here to something you control, for example `com.granitestatereport.reader`. The bundle identifier is permanent once the app is on the store.
6. Repeat the Team selection for the **GraniteStateReportTests** target.

No capabilities need to be added by hand. Background audio and background refresh are already declared in `Info.plist`.

## Step 6. Run it on your iPhone

1. Connect the iPhone by cable. On the phone, enable Developer Mode if asked (Settings, Privacy & Security, Developer Mode).
2. Pick the phone in Xcode's device menu and press **Cmd-R**.

Then walk this checklist on the device. This is the real acceptance test.

- [ ] Today loads; pull down to refresh; scrolling to the bottom loads older stories.
- [ ] A story opens and shows the GSR article template correctly: masthead, kicker, headline, dek, byline, charts, tables, fact-check box.
- [ ] Tapping the "Listen to this article" block, or the headphones button, starts narration. The mini player appears above the tab bar.
- [ ] Lock the phone. Audio keeps playing. Lock screen shows title, play/pause, and skip controls.
- [ ] A link to another GSR story opens inside the app. A link to an outside site opens in the in-app browser.
- [ ] Bookmark a story, turn on Airplane Mode, force-quit, reopen: the story opens from Saved.
- [ ] Sections lists every category with correct names (check "Law & Courts" shows an ampersand, not `&amp;`).
- [ ] Search returns results; recent searches appear.
- [ ] Listen tab shows GSR YouTube, Podcast, Articles, Cockpit Reads and State House. Episodes play and advance to the next one.
- [ ] About sheet: every page link opens; "Support Granite State Report" opens Safari, not the in-app browser.
- [ ] Turn on New story alerts and allow notifications.
- [ ] Switch the phone to Dark Mode and to a large text size (Settings, Accessibility) and look at every tab.
- [ ] Turn on VoiceOver and swipe through Today and one story.

To test a new-story alert without waiting for iOS: run from Xcode on a device, send the app to the background, pause in the debugger, and enter
`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.granitestatereport.app.refresh"]`
then resume. An alert appears only if the site has a story newer than the last one you saw in the app.

## Step 7. Create the app record

1. Sign in at https://appstoreconnect.apple.com .
2. **Apps**, then **+**, then **New App**.
3. Platform: **iOS**. Name: **Granite State Report**. Primary language: **English (U.S.)**. Bundle ID: choose the one from Step 5 (it appears after your first signed build; if missing, register it at https://developer.apple.com/account under Identifiers). SKU: any private label, for example `gsr-ios-1`.

If the name is taken on the App Store, use a variant such as "Granite State Report: NH News."

## Step 8. Archive and upload

1. In Xcode's device menu choose **Any iOS Device (arm64)**.
2. **Product, Archive**.
3. When the Organizer window opens: **Distribute App**, **App Store Connect**, **Upload**, and accept the defaults.
4. Processing takes roughly 10 to 30 minutes. You get an email when the build is ready.

For every later upload, raise the build number first: target, **General**, **Build** (1, 2, 3...). Raise **Version** (1.0.0, 1.0.1...) for each public release.

## Step 9. Test with TestFlight

1. In App Store Connect open the app, then the **TestFlight** tab.
2. The app declares that it uses no non-exempt encryption, so there is no export compliance question to answer per build.
3. Add yourself under **Internal Testing**. Install the TestFlight app on your phone and accept the invitation.
4. Run the Step 6 checklist again on the TestFlight build. This is the exact binary Apple will review.

Outside testers (readers, friends) go under **External Testing**, which needs a short Beta App Review first.

## Step 10. Fill in the store listing

Under the **Distribution** tab (labeled App Store in some versions of the site):

| Field | What to enter |
|---|---|
| Name | Granite State Report |
| Subtitle (30 characters max) | Independent New Hampshire news |
| Category | News |
| Price | Free |
| Privacy Policy URL | https://granitestatereport.com/privacy-policy/ |
| Support URL | https://granitestatereport.com/about/ |
| Marketing URL (optional) | https://granitestatereport.com |
| Copyright | 2026 Granite State Report |
| Keywords (100 characters max) | New Hampshire,NH,news,Concord,politics,State House,courts,public records,investigations,podcast |

**Description (draft; edit to your voice before you submit):**

> Granite State Report is independent New Hampshire journalism: documents-first reporting and analysis on the State House, the courts, public records, and the communities of the Granite State.
>
> Read every story in the app as it is published. Listen to article narration and the GSR podcast, with playback that continues when your phone is locked. Save stories to read without a connection. Search the full archive. Browse by section, from Investigations and Right to Know to Law & Courts and History.
>
> The app has no ads, no accounts, and no tracking of its own.
>
> Send a tip, read the Mission Statement, the Code of Ethics and the Corrections Register, and reach the newsroom from the About screen.

**Screenshots.** At least one set is required. Take them in the Simulator on the largest current iPhone (**Cmd-S** saves a screenshot to the Desktop). **VERIFY** the required size on the upload form, which states it. Suggested five: Today, an open story, the player, Sections, Saved.

**Age rating.** Answer the questionnaire truthfully for a news app. News coverage of crime and courts generally means answering "Infrequent/Mild" for the relevant mature-theme questions rather than "None." Your call as editor.

**App Privacy.** Choose **Data Not Collected**. The app itself collects nothing and sends nothing about the reader anywhere. It makes ordinary web requests to granitestatereport.com and its image host, as a browser would. If you later add analytics or accounts to the app, this answer must change.

## Step 11. Submit for review

1. On the version page select the build you tested.
2. **App Review Information**: your name, phone and email. No sign-in is required, so leave the demo account blank and say so in the notes.
3. Suggested review notes:

> This is the official app of Granite State Report (granitestatereport.com), an independent New Hampshire news publication. The submitter is the publication's founder and editor. No account is needed. All content is the publication's own. The app is native: feed, sections, search, offline saved stories, a background audio player for article narration and the publication's podcast, and optional local new-story alerts. Background audio mode is used for that player. The "Support" link opens the publication's website in Safari; the app collects no payments.

4. **Add for Review**, then **Submit**. Review usually takes one to three days. **VERIFY**: Apple does not promise a time.

## Review risks, stated plainly

- **Support and membership links.** App Review Guideline 3.2.2 bars collecting funds for fundraisers inside an app unless the developer is an approved nonprofit, and says such apps "may only collect funds outside of the app, such as via Safari or SMS." The app is built to that rule: `/support`, `/subscribe`, `/sponsor-a-request` and membership pages always open in Safari, never inside the app. This is my reading of the guideline, not legal advice, and not a guarantee of approval. Source: https://developer.apple.com/app-store/review/guidelines/
- **Third-party audio and video.** The site's media catalog includes live radio streams from stations GSR does not produce or carry. The app hides that tab by default, because Apple can ask for proof of rights to third-party streams. To show it, remove `"live"` from `hiddenMediaTabs` in `GraniteStateReport/Core/GSR.swift`. The Cockpit Reads and State House tabs only link out to YouTube.
- **"It's just a website."** Guideline 4.2 rejects thin web wrappers. This app is native apart from the article body, which is shown in GSR's own article template on purpose. The review notes above say so.

## After launch

- **New stories need no app update.** The app reads the site live. Sections, podcast episodes and the About pages follow the site too.
- **If you rename a page or change the phone number or email,** edit `GraniteStateReport/Core/GSR.swift` and `Features/About/AboutView.swift`, then ship an update.
- **If you change the article template's class names** (`gsr-article`, `gsr-audio`), the Listen block in the reader depends on them. The headphones button does not.
- **Shipping an update:** change the code, raise Version and Build, Archive, Upload, add the build to a new version in App Store Connect, submit.

## What version 1 does not do

Stated so nothing surprises you:

- **Alerts are not instant.** They rely on iOS background refresh, which runs when iOS chooses, often hours apart, and not at all if the reader force-quits the app or uses Low Power Mode. True push alerts need a small server and an Apple push key. That is the first upgrade worth making.
- **Stories always show on white.** The article template sets its own colors, so the reader does not go dark in Dark Mode. The rest of the app does.
- **No sign-in.** Member-only features of the site (membership account, saved items on the web, verified-resident downloads) are not in the app.
- **iPhone only.** It runs on iPad in iPhone-size mode. A real iPad layout is a later project and would add iPad screenshots to the listing.
- **Links to GSR stories from Mail or Messages open Safari,** not the app. Opening them in the app needs Universal Links, which means adding one small file to the website and one capability in Xcode.
- **No home screen widget.**
