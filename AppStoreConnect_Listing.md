# Pace Up — App Store Connect Listing

Everything below is ready to paste into App Store Connect. Character limits are noted next to each field. Anything in **[brackets]** is something only you can fill in.

---

## App information (set once)

| Field | Value |
|---|---|
| **App Name** (30 char max) | `Pace Up` |
| **Subtitle** (30 char max) | `Step counter & run tracker` |
| **Bundle ID** | `com.oanarinaldi.paceup` |
| **SKU** | `paceup001` |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Sports |
| **Price** | Free — no in-app purchases |
| **Age Rating** | 4+ |
| **Copyright** | `2026 Oana Rinaldi` |

**One note on the name.** You picked the brand-only `Pace Up`, which is clean but spends none of the App Store's highest-weighted search field. The subtitle is also indexed, so the recommended subtitle above deliberately carries `step counter` and `run tracker` to recover most of that. Don't repeat those words in the keyword field — Apple indexes name, subtitle and keywords separately and duplicates are wasted characters.

**Subtitle alternatives** (≤30 chars):

- `Step counter & run tracker` ← recommended, 26 chars
- `Walk, run & hike GPS tracker` — 28 chars, leads on walking
- `Steps, runs & routes. Private.` — 30 chars, leads on the privacy angle

---

## Promotional text (170 char max — editable anytime without review)

```
Track your steps, runs, walks and hikes with a live GPS map. No account, no sign-up, no ads. Everything stays on your iPhone, and you decide what to keep.
```

**Alternatives (≤170 chars):**

- `A step counter and run tracker that asks for nothing. No account, no server, no ads. Your routes, splits and records live on your iPhone and nowhere else.`
- `Steps, distance, pace, splits and elevation, on a live Apple map. Works with Apple Health. No sign-up, no subscription, no data collection.`

---

## Description (4000 char max)

```
Pace Up is a private movement coach, step counter and GPS tracker for walks, runs, hikes and rides. Open it, choose your direction, and build a movement rhythm that fits real life. There's no account to create, because there's no server to create one on.

YOUR JOURNEY, NOT A GENERIC SCORE
The Journey hub turns your recent activity into helpful weekly guidance. See your momentum, active days and distance together, then choose a structured path: prepare for your First 5K, make movement a Daily Reset, or build confidence for a Weekend Explorer adventure.

YOUR DAY AT A GLANCE
See your step count against your daily goal in one ring, with distance, calories and active time underneath. Steps come from Apple Health, so the number matches the Health app instead of arguing with it.

RECORD WITH GPS
Start a walk, run, hike or ride and watch your route draw itself on a live Apple map. Pace Up tracks distance, current and average pace, splits, elevation, steps and heart rate. Auto-pause stops the clock at traffic lights and picks it up again when you do. Recording keeps going with your phone locked or in your pocket.

If your phone runs out of battery or iOS shuts the app down mid-run, Pace Up offers the run back the next time you open it. Nothing is written only to memory.

SEE WHAT YOU DID
Every activity gets a full breakdown: your route on the map, per-kilometre splits, a pace chart, an elevation profile and heart rate over time. Add a note, or just tap how it felt.

PROGRESS THAT ADDS UP
Weekly step, distance and active-time charts. Current and longest streaks. Personal records for your fastest 1K, 5K and 10K, your longest run and your biggest climb. Achievements from your first 5K to a million lifetime steps.

WIDGETS
Small, medium and large Home Screen widgets showing your steps, goal progress, distance, calories and the last seven days.

START FROM APPLE WATCH
Start an outdoor walk, run, hike or ride from your wrist. See live time, heart rate and distance, pause or resume, then save the finished workout directly to Apple Health.

WORKS WITH APPLE HEALTH
Pace Up reads steps, distance, heart rate and workouts from Apple Health, and writes your finished activities back as workouts with their routes. That means your history stays in Health even if you delete Pace Up.

PRIVATE BY DESIGN
No account. No sign-up. No server. No ads. No analytics. No in-app purchases. Pace Up makes no network requests at all — your routes and activities are stored on your iPhone and go nowhere else.

You also decide how much to keep. Under Data & Privacy you can export everything as a readable backup file, export any route as GPX, or clear old GPS traces after 30 days while keeping your distances, times, splits, records and streaks intact. Nothing Pace Up deletes ever touches your Apple Health history.

Requires iOS 26 or later. Apple Watch workout recording requires watchOS 10 or later.

Pace Up is a tracking tool, not medical advice. Step, distance, pace and calorie figures are estimates from consumer sensors.
```

*(2,455 characters — comfortably inside the limit.)*

---

## Keywords (100 char max, comma-separated, no spaces after commas)

```
pedometer,walking,running,gps,route,hiking,steps,distance,splits,elevation,workout,healthkit,cardio
```

99 characters, no overlap with the name or subtitle. `pace`, `step counter`, `run` and `tracker` are all deliberately absent because Apple already indexes them from those two fields — repeating them here would waste characters. Don't add competitor names; Apple rejects for it.

---

## What's New (version 1.0)

```
Welcome to Pace Up. This first release includes:
• A daily step ring backed by Apple Health
• GPS recording for walks, runs, hikes and rides, with a live map
• Auto-pause, splits, pace and elevation charts, and heart rate
• Recovery of an activity if your phone dies mid-run
• Streaks, personal records and achievements
• Small, medium and large Home Screen widgets
• Export to a backup file or GPX, and a 30-day cleanup that keeps your stats

No account, no ads, no data collection. Have feedback? We'd love to hear it.
```

---

## URLs & contact

| Field | Value |
|---|---|
| **Support URL** (required) | `https://oanarinaldi.com/apps.html` |
| **Marketing URL** (optional) | leave blank, or `https://oanarinaldi.com/apps.html` |
| **Privacy Policy URL** (required) | `https://oanarinaldi.com/paceupprivacy.html` |
| **Contact email** | `oanarinaldi@gmail.com` |

**The privacy page has been written for you** — `paceupprivacy.html` is now in your `oanarina_website` folder, built from the same template as your PeakInterval and Harsh Comebacks pages. **Deploy the site before you submit.** Apple checks that the privacy URL loads, and a 404 is an automatic rejection.

---

## App Privacy (the nutrition label)

This is the section people get wrong. For Pace Up the answer is genuinely simple.

**First question — "Do you or your third-party partners collect data from this app?"**

> **No**

That's the whole questionnaire. Selecting No gives you **Data Not Collected**, which is accurate: the app has no network code and no analytics SDK.

**Do not** be tempted to declare Health or Location just because the app uses them. Apple's definition of *collect* is "transmit off the device". Reading location and keeping it on the phone is not collection, and over-declaring puts a "Data Linked to You" badge on your listing that you'd then have to justify.

Consistency check: this must agree with `PrivacyInfo.xcprivacy` in the app bundle, which already declares `NSPrivacyTracking = false` and an empty `NSPrivacyCollectedDataTypes`. It does.

---

## Age rating questionnaire

Answer **None** to every question. Result: **4+**.

The only one worth pausing on is the unrestricted web access question — answer **No**. Pace Up opens no web views. (The Settings screen can open the Health app and iOS Settings via URL scheme; that is not web access.)

---

## App Review Information — notes to the reviewer

Paste this into the **Notes** field. This is the single highest-value box on the form for an app like this: background location plus HealthKit is exactly the combination that gets held for questions.

```
No sign-in required. Pace Up has no account system and no server, so there is no demo account to provide.

TO SEE THE APP WORKING
Please grant both permissions when prompted:
• Apple Health — the Today screen shows a step count of zero without it
• Location (While Using) — required to record a route

On a device with no Health data, the Today screen will legitimately show zeros. To exercise the GPS recorder, tap Start, choose Run, then tap START; with a simulated location route the map will draw a polyline and distance, pace and splits will populate.

BACKGROUND LOCATION — WHY IT IS USED
Pace Up records the user's route during a walk, run, hike or ride. The location background mode is enabled only while an activity is actively recording, so tracking continues when the screen is off or the phone is in a pocket — the expected behaviour for a fitness tracker. iOS shows the blue status indicator for the entire recording. Location is never accessed outside an active recording. It is never transmitted anywhere: the app makes no network requests and there is no backend.

HEALTHKIT — WHY IT IS USED
Pace Up reads steps, walking/running and cycling distance, active energy, heart rate, exercise minutes and workouts in order to display the user's own activity, so its figures match the Health app. It writes finished activities back as workouts with their routes, so the user's history survives deleting the app. HealthKit data is never used for advertising or marketing, is never shared with third parties, and never leaves the device. The app does not request Clinical Health Records.

PRIVACY
No account, no server, no analytics SDK, no advertising SDK, no third-party network code, no in-app purchases. All data is stored locally. The Data & Privacy screen lets users export or delete their data at any time.

Contact: oanarinaldi@gmail.com
```

---

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is already in `Config/PaceUp-Info.plist`, so App Store Connect will not ask you the encryption questions on upload. This is correct — the app uses no encryption beyond what iOS provides at rest.

---

## Screenshots

**Required:** 6.9″ display (1320 × 2868 or 1290 × 2796). Apple scales these down for smaller sizes, so one set is enough for iPhone-only apps. Up to 10 per size.

Record a run first — use Xcode's **Debug → Simulate Location → City Run** so the map has a real-looking route rather than a straight line, and let it run long enough to generate splits.

Suggested order, with caption ideas if you add text overlays:

| # | Screen | Caption |
|---|---|---|
| 1 | Today — step ring at ~78% | *Your day, in one ring* |
| 2 | Live run — map with route, distance and pace | *Watch your route draw itself* |
| 3 | Activity detail — map + splits | *Every split, every metre* |
| 4 | Activity detail — Charts tab, pace + elevation | *Pace, elevation and heart rate* |
| 5 | Progress — weekly bars and streak | *Momentum you can see* |
| 6 | Personal Records | *Your bests, kept forever* |
| 7 | Data & Privacy | *No account. No server. Your data.* |

Screenshot 7 is worth including even though settings screens are usually dull — the privacy story is this app's actual differentiator in a category full of subscription trackers.

**App Preview video** is optional. Skip it for 1.0.

---

## Pre-submission checklist

**In Xcode**

- [ ] App Group `group.com.oanarinaldi.paceup` created and ticked on **both** targets
- [ ] HealthKit capability on the app target, **Clinical Health Records unticked**
- [ ] Background Modes → Location updates ticked
- [ ] Version `1.0`, Build `3` — bump the build for **every** upload, including TestFlight; App Store Connect rejects a duplicate. Keep version at `1.0` until the app is actually released.
- [ ] Archive → Distribute App → App Store Connect → Upload
- [ ] Test on a real device first — HealthKit and Core Motion return nothing in the simulator

**In App Store Connect**

- [ ] Name, Subtitle, Keywords, Description, Promotional text, What's New pasted in
- [ ] Price: **Free**
- [ ] Category: **Health & Fitness** / Sports
- [ ] Privacy Policy URL added **and the page is live**
- [ ] Support URL added
- [ ] App Privacy → **Data Not Collected**
- [ ] Age rating → all None → 4+
- [ ] App Review notes pasted (the block above)
- [ ] Screenshots uploaded
- [ ] Build selected for this version
- [ ] Copyright: `2026 Oana Rinaldi`

---

## What is most likely to get this rejected

Ranked by actual likelihood, so you know where to spend your attention.

**1. Background location justification (most likely).** Guideline 2.5.4. Reviewers reject fitness apps that request `location` background mode without a visible, continuous, user-initiated feature. Pace Up qualifies — but the reviewer has to *see* that it qualifies, which is what the review note is for. The code already backs up the claim: `LocationProvider.stop()` disables background updates the moment recording ends.

**2. Privacy URL returning 404.** Trivially avoidable and depressingly common. Deploy the site first, then open the URL in a private browser window to confirm.

**3. Privacy label contradicting the manifest.** Both say "collects nothing." Keep them that way; if you ever add an analytics SDK, both have to change together.

**4. HealthKit purpose.** Guideline 5.1.3. Requires a genuine health or fitness purpose and forbids using Health data for advertising. Pace Up is clearly compliant; the review note states it explicitly.

**5. Guideline 4.2, minimum functionality.** Low risk — this is a complete tracker, not a wrapper — but note that a reviewer testing on a fresh device with no Health data and no location simulation will see a screen of zeros. The review note tells them how to avoid that. This is the failure mode I'd worry about second-most, because it produces a rejection that reads like "the app doesn't work."

---

## After approval

Two things worth doing that most people skip:

- Add Pace Up to `apps.html` on your site, matching the existing entries, once you have the App Store ID.
- Promotional text is editable **without** submitting a new build. Use it for seasonal or feature messaging rather than editing the description, which requires review.
