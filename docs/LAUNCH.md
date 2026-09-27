# WEB-CRAWLER launch sheet

Godot **4.7** project. Application name `WEB-CRAWLER`. Version `0.9.0`. Suggested package id **`com.nouh.webcrawler`** (Android `package/unique_name` and iOS `application/bundle_identifier` in `export_presets.cfg`). Scores stay on the device (`user://web_crawler.cfg`). There is no account, no network, and no analytics.

Placeholder icons are in `assets/icons/`. Replace them before you ship. The project icon is `assets/icons/icon.png`. Windows uses `assets/icons/icon.ico`.

## Store page draft

**Title:** WEB-CRAWLER

**One-line hook:** Hold the floor. The house is full of spiders, and she is listening.

**Short description:** A neon horror spider-crawler shooter. Three guns, four rooms, and a scream you only get when the house is lost.

**Long description:**

Spiders drop from the ceiling. If they reach the floor, the house loses a life. At zero, she finds you.

Start in the Attic. The rooms shift: Cellar, Nursery, then the Nest. Every fifth wave is a bug-spider swarm. Clear it without a breach and the gun in your hands levels up. Parts dropped by kills buy the same upgrades between swarms.

Three weapons. The revolver hits hard. The pistol is the hose. The shotgun throws a tight, fair cone. Recoil kicks and settles. Trails fade. A light stick helps touch and mouse when the crosshair is already on a spider. It does not aim for you.

Each calendar day on your device is one seeded run. Beat BEST. Beat TODAY. Then survive long enough to hear her.

**Tags:** horror, shooter, arcade, spiders, pixel, neon, score attack, singleplayer

**TikTok / Shorts lines:**

1. House hits zero. She finds you. That scream is the game over.
2. Wave 12. The Nest. Those sacs on the ceiling are not decoration.
3. Bug swarm. The banner says how many are left. One touch on the floor and the upgrade is gone.
4. Shotgun in the Nursery. The crib does not help them.
5. TODAY on the HUD is the daily seed. Post the score. Same day, same spiders.

## Export presets

`export_presets.cfg` has three stubs. They are not signed builds.

| Preset | Platform | Output | Notes |
| --- | --- | --- | --- |
| Windows Desktop | Steam / desktop | `build/windows/WEB-CRAWLER.exe` | x86_64, embedded pck, icon set, codesign off |
| Android | Google Play | `build/android/web-crawler.aab` | `export_format=1` (AAB), arm64, package `com.nouh.webcrawler`, `package/signed=false` |
| iOS | App Store | `build/ios/web-crawler.ipa` | `export_project_only=true` so Godot writes an Xcode project. Signing is empty on purpose. Runnable is off until you export on a Mac. |

Install export templates that match the editor: **4.7-stable**. Editor → Manage Export Templates, or [Godot 4.7 download archive](https://godotengine.org/download/archive/4.7-stable/).

Before a phone export, Project → Project Settings → Rendering → Renderer can stay as-is for a first Windows build. For Play and App Store, switch **Rendering Method** to **Mobile** (or Compatibility if a device fails Vulkan), then export again. Turn ETC2/ASTC on for that phone preset. The project already enables `textures/vram_compression/import_etc2_astc`.

Window is landscape (`window/handheld/orientation=4`, sensor landscape). Viewport is 1152×648, stretched with `canvas_items` / `expand`.

### Still missing before a store upload

- Godot 4.7 export templates installed on the machine that exports.
- Android **release keystore**. Debug keystore is not acceptable for Play. `package/signed` is false until `keystore/release`, user, and password are set. Keep the keystore out of git.
- Play Console app created with package name `com.nouh.webcrawler`. That name is permanent.
- A **Mac with Xcode** for iOS. This preset does not contain a team id, certificate, or provisioning profile. Set `application/app_store_team_id` and the release signing fields, then archive in Xcode (or turn off `export_project_only` once signing works). Confirm the device family dropdown reads **iPhone & iPad** (`targeted_device_family=2`).
- Final art, not the generated placeholder spider: 1024 master, iOS dark and tinted slots (left blank so Godot falls back), Android adaptive monochrome (`launcher_icons/adaptive_monochrome_432x432`).
- Steam capsule art (header 460×215, small 231×87, main 616×353, vertical 374×448, library 600×900, page background 1438×810). Not in this repo.
- Hosted privacy-policy URL. Draft is below. Paste it onto a page you control.
- Screenshots and a 15–30s trailer. Capture Attic opening, a kill with the muzzle flash, bug-swarm banner, Nest, upgrade banner, and the lady scream.
- Age-rating questionnaires filled from the notes below.

## Steam

1. Create a Steamworks partner account and pay the app fee. Add a new app. Note the App ID.
2. Export the Windows preset to `build/windows/WEB-CRAWLER.exe`. Run that exe on a clean Windows machine, not only in the editor.
3. Install [Steamworks SDK](https://partner.steamgames.com/doc/sdk). For a first build you can ship the exe without the Steam API. Wishlist does not require achievements. Add the API later if you want overlay, achievements, or cloud.
4. Upload with **SteamCMD** or SteamPipe. Set the launch option to `WEB-CRAWLER.exe`. Depot: Windows 64-bit.
5. Store page: title, hook, and long description from above. Capsules from the size list. At least 5 screenshots. Trailer linked or uploaded.
6. Content survey: horror, fantasy violence against spiders, jump scare, loud scream. No gore, no sex, no user chat, no multiplayer.
7. Price and release date. Turn on **Wishlist** before launch. A coming-soon page with the Nest and the scream converts better than a silent page.
8. Set the build live on a beta branch first (`prerelease`), play it through Steam, then default branch.

## Google Play

1. Play Console developer account. Create the app. Package name **`com.nouh.webcrawler`**. Default language English.
2. Install Android build tools / JDK that Godot 4.7's Gradle export expects (the export dialog names the version if it is missing).
3. Create an upload keystore. Point the Android preset at it and set `package/signed=true` only after the paths and passwords are filled. Export the **AAB**, not an APK.
4. Target SDK in the preset is **35**. Raise it if Play Console rejects the upload. Min SDK is **24**.
5. Testing track: internal, then closed, then production. Play App Signing: let Google hold the app signing key; you keep the upload key.
6. Store listing: short description (80 characters) can be the one-line hook trimmed to fit. Full description from above. Icon 512×512 (export from `icon_1024.png`). Feature graphic 1024×500. Phone screenshots, 16:9 or 9:16. Landscape is honest for this game; include a landscape set.
7. Privacy policy URL required if the form asks, and worth hosting even though you collect nothing. Data safety form: **no data collected**, no ads, no account. Scores are local only.
8. Content rating: IARC questionnaire. Category Game. Violence is fantasy (spiders). Horror theme and jump scare. No blood, no gambling, no user content.
9. Ads declaration: none. News / COVID: no. Government: no. Target audience: not directed at children. 16+ or Teen is the likely band; answer the questionnaire literally and accept the result.
10. Pre-registration: once the store listing is approved you can open pre-registration before production. The bug-swarm and scream clips are the ads.

## Apple App Store

1. Apple Developer Program. App Store Connect app with bundle id **`com.nouh.webcrawler`**.
2. Export **on macOS**. Godot writes an Xcode project because `export_project_only` is true. Open it in Xcode, set the team, create an App Store provisioning profile, then Product → Archive → Distribute.
3. Icons: 1024 App Store icon is `assets/icons/icon_1024.png`. No alpha channel on the App Store icon (the placeholder is opaque). Add dark and tinted variants later if you want them distinct.
4. Privacy nutrition labels: Data Not Collected. No tracking. Camera and microphone usage strings are empty because the game does not request them.
5. Age rating: horror / fear, infrequent or frequent depending on how you count the scream and the lady. No unrestricted web, no gambling.
6. Screenshots for 6.7", 6.5", and 12.9" iPad, or the sizes App Store Connect currently requires. Landscape.
7. Review notes: offline game, local high score only, loud jump scare at game over, no account.
8. TestFlight before review. The Mac export is the blocker, not the Godot scene.

## Privacy policy draft

Host this, then paste the URL into Steam, Play, and App Store Connect.

> WEB-CRAWLER does not create accounts and does not send gameplay, device, or contact data to us. High score, best wave, and the daily score are stored only on your device. The daily run is a number derived from your device date. It is not uploaded. There are no ads and no third-party trackers in the game. If you contact us yourself, we use that message only to reply. To erase local scores, clear the game's app data or delete the save file the game writes on your device.

## Age and horror notes

- Fantasy violence: the player shoots spiders. No human blood, no dismemberment.
- Horror: dark house, spiders, a pictured figure, a loud scream at game over, a quieter sting a few seconds after the run starts ("SHE HEARD YOU").
- Audio: the scream is intentionally loud. Mention that in the store description so trailer viewers are not the only warning.
- Not a children's app. Do not list it in a kids category.

## Screenshot and trailer checklist

- [ ] Attic, first spiders, banner `THE ATTIC · KEEP THEM OFF THE FLOOR`
- [ ] Muzzle flash and a kill spark, HUD score / BEST / TODAY readable
- [ ] Weapon upgrade banner (`REVOLVER  LV 1`) and the parts button
- [ ] Bug swarm banner `BUG SWARM · N LEFT` with the small spiders in frame
- [ ] Nest webs and sacs
- [ ] Lady full-frame with `SHE FOUND YOU`, then the score card `NEW BEST` or `THE HOUSE IS LOST` plus map name
- [ ] Trailer order that works in 20 seconds: drop, shot, swarm, Nest, scream, score

## Wishlist and pre-registration

- Steam coming soon with the one-line hook and a 6-second scream clip. Pin the Nest screenshot.
- Play pre-registration once the listing is approved. Use the same clip.
- Post the daily score with the on-screen date. Two players on the same local date share the spawn seed. Say "device local day" so nobody thinks it is a server reset.
- Do not add online leaderboards for the first release. The local BEST / TODAY line is the chase.
