# Pace Up — App Store Connect Listing

Everything below is ready to paste into App Store Connect. Character limits are noted next to each field. Anything in **[brackets]** is something only you can fill in.

---

## App information (set once)

| Field | Value |
|---|---|
| **App Name** (30 char max) | `Pace Up` |
| **Subtitle** (30 char max) | `Step tracker & exploration map` |
| **Bundle ID** | `com.oanarinaldi.paceup` |
| **SKU** | `paceup001` |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Sports |
| **Price** | Free — no in-app purchases |
| **Age Rating** | 4+ |
| **Copyright** | `2026 Oana Rinaldi` |

**Why the subtitle changed.** The previous recommendation was `Step counter & run tracker`, which is optimal ASO and the worst possible answer to a 4.3(a) rejection: it is the single most cloned phrase in Health & Fitness, and it is one of the few fields a spam reviewer reads before opening the app. The replacement keeps `step tracker` for indexing and spends the rest on the thing no other tracker in the category does.

Read `Guideline_4.3a_Strategy.md` before submitting. The listing is the cheap half of the fix; the duplicate app pair on the developer account is the other half, and this listing does not address it.

**Subtitle alternatives** (≤30 chars):

- `Step tracker & exploration map` ← recommended, 30 chars
- `Walk to uncover your own map` — 28 chars, leads hardest on Terra
- `Steps, routes & a map to clear` — 30 chars, keeps `routes` indexed
- `Private step & GPS tracker` — 26 chars, fallback if you decide Terra should not lead

---

## Promotional text (170 char max — editable anytime without review)

```
Your map starts dark. Every walk, run and hike you record clears a little more of it, permanently. Steps, routes and splits included. No account, no server, no ads.
```

**Alternatives (≤170 chars):**

- `Walk your city out of the fog. Pace Up tracks your steps and routes, and every metre you cover uncovers a map that only you can fill in. Nothing leaves your iPhone.`
- `A tracker that never loses a run and never touches the network. Steps that match Health, routes on a live map, and a world map you uncover on foot.`

---

## Description (4000 char max)

```
Pace Up is a step counter and GPS tracker for walks, runs, hikes and rides. It has one thing no other tracker has: a map that starts dark.

TERRA — UNCOVER THE MAP ON FOOT
Open Terra and the world is under fog. Every route you record clears the ground you actually moved through, and it stays cleared. Come back after a month and your city is the shape of the streets you know, drawn by your own feet. Terra counts what you have uncovered in square kilometres.

It never shrinks. Clearing old GPS traces to save space does not re-darken a single metre — the ground you covered is yours. And Terra needs no connection of any kind; it is built entirely from routes already on your iPhone.

Terra tells you where to go next, too: it finds the nearest ground you have never covered and points you at it — "new ground 800 m north-east, about 0.4 km² waiting there." Every run ends with how much of it was somewhere new. Your steps stop being a number and start being a place.

RECORD WITH GPS
Start a walk, run, hike or ride and watch your route draw itself on a live Apple map. Pace Up tracks distance, current and average pace, splits, elevation, steps and heart rate. Auto-pause stops the clock at traffic lights and picks it up again when you do. Recording keeps going with your phone locked or in your pocket.

IT DOES NOT LOSE YOUR RUN
Every GPS point is written to disk the moment it arrives, not held in memory. If your battery dies or iOS shuts the app down mid-run, Pace Up offers the run back the next time you open it, route intact.

STEPS THAT MATCH THE HEALTH APP
Most trackers quietly double-count, adding your Apple Watch steps to your iPhone steps and handing you a number nobody walked. Pace Up counts in ten-minute buckets and takes exactly one source per bucket, so its totals agree with Health instead of arguing with it.

YOUR DAY AT A GLANCE
Your step count against your daily goal in one ring, with distance, calories and active time underneath. The Journey hub adds weekly guidance and three structured paths: First 5K, Daily Reset, or Weekend Explorer.

SEE WHAT YOU DID
Every activity gets a full breakdown: your route on the map, per-kilometre splits, a pace chart, an elevation profile and heart rate over time.

PROGRESS THAT ADDS UP
Weekly step, distance and active-time charts. Current and longest streaks. Personal records for your fastest 1K, 5K and 10K, your longest run and your biggest climb.

WIDGETS
Small, medium and large Home Screen widgets showing your steps, goal progress, distance, calories and the last seven days — plus a Terra widget that puts the shape of everywhere you have walked on your Home Screen, with the step count that uncovered it.

START FROM APPLE WATCH
Start an outdoor walk, run, hike or ride from your wrist. See live time, heart rate and distance, pause or resume, then save the finished workout directly to Apple Health.

WORKS WITH APPLE HEALTH
Pace Up reads steps, distance, heart rate and workouts from Apple Health, and writes your finished activities back as workouts with their routes. That means your history stays in Health even if you delete Pace Up.

NO NETWORK. NONE.
Pace Up makes no network requests at all. No account, no sign-up, no server, no ads, no analytics, no in-app purchases, no third-party SDKs of any kind. Your routes, your records and your uncovered map are on your iPhone and nowhere else.

You also decide how much to keep. Under Data & Privacy you can export everything as a readable backup file, export any route as GPX, or clear old GPS traces after 30 days while keeping your distances, times, splits, records, streaks — and your Terra map — intact. Nothing Pace Up deletes ever touches your Apple Health history.

Requires iOS 26 or later. Apple Watch workout recording requires watchOS 10 or later.

Pace Up is a tracking tool, not medical advice. Step, distance, pace and calorie figures are estimates from consumer sensors.
```

*(3,923 characters of the 4,000 allowed. Re-count after any edit — this ran over the limit once already.)*

---

## Keywords (100 char max, comma-separated, no spaces after commas)

```
pedometer,walking,running,gps,route,hiking,explore,discovery,distance,splits,elevation,offline
```

93 characters, no overlap with the name or subtitle. `pace`, `step`, `tracker` and `map` are deliberately absent because Apple already indexes them from the name and subtitle — repeating them here wastes characters. `explore`, `discovery` and `offline` are new: they are the terms a Terra user would actually search, and they pull the app out of the pedometer keyword cluster where every competitor sits. Don't add competitor names; Apple rejects for it.

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

TERRA — THE FEATURE THAT DISTINGUISHES THIS APP
Journey tab › the Terra card at the top. Terra is a world map covered in fog that clears only where the user has physically been. Each recorded route is folded into a grid of 100-metre squares and those squares are erased from the fog permanently, so the map becomes a record of the streets that person has actually walked, and the app reports the area uncovered in square kilometres.

To see it during review: record one activity with a simulated location route as described above, save it, then open Journey › Terra. The corridor you just recorded will be clear and everything around it dark. Recording a second route in a different area and returning will show both.

Terra is computed entirely on device from routes already stored locally. It makes no network requests, uses no map data beyond Apple's own tiles, and is not derived from any third-party service. It can be cleared at any time from Profile › Data & Privacy › Clear Terra Map, and is erased automatically when the user deletes all app data.

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
| 1 | **Terra — a city part-cleared, fog still on three sides** | *Walk your city out of the dark* |
| 2 | Live run — map with route, distance and pace | *Watch your route draw itself* |
| 3 | Today — step ring at ~78% | *Your day, in one ring* |
| 4 | Activity detail — map + splits | *Every split, every metre* |
| 5 | Activity detail — Charts tab, pace + elevation | *Pace, elevation and heart rate* |
| 6 | Activity summary — the new-ground card | *How much of it was somewhere new* |
| 7 | Home Screen with the Terra widget | *Your world, on your Home Screen* |
| 8 | Recovery sheet — "Unfinished activity" | *It does not lose your run* |
| 9 | Progress — weekly bars and streak | *Momentum you can see* |
| 10 | Data & Privacy | *No account. No server. Your data.* |

**Screenshot 1 does the most work in this listing.** It is the only frame a browsing user or a spam reviewer cannot mistake for Strava, and it is the reason the description leads with Terra. Get it right: record several routes over a small area first so the cleared region has a recognisable shape with fog still visible around it. A fully cleared screen and an almost fully dark screen are both illegible — you want roughly a third uncovered.

Screenshot 6 is unusual for a store listing but earns its place: crash recovery is a real engineering differentiator that no competitor advertises, and it reads instantly.

Screenshot 9 is worth including even though settings screens are usually dull — the privacy story is this app's other real differentiator in a category full of subscription trackers.

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
