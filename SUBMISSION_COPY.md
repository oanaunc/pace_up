# Pace Up — everything to paste, in order

One file, four boxes. Fuller notes live in `AppStoreConnect_Listing.md`;
the 4.3(a) reasoning lives in `Guideline_4.3a_Strategy.md`.

---

## Read this before pasting anything

**1. This copy describes Terra. Terra has never been compiled.**
The description below leads with a feature that exists only as source. Submitting it
against a build without Terra would be describing an app that does not exist — which is
its own rejection, and a worse one than 4.3(a). Build it, run it, record a walk, open
Journey → Terra, and confirm it works before any of this goes near App Store Connect.

**2. Nothing here fixes the actual 4.3(a) trigger.**
Measured across the six projects on this machine: Pace Up shares 2.0% of its lines with
the fashion apps, all of it generic SwiftUI boilerplate, with zero duplicate files.
AI Fashion and AI Beauty Makeover share **79.5% / 83.1%** — 1,561 substantive lines, and
17 byte-identical files. That pair is the 4.3(a) exposure on team `HBD3XXQK45`. Merge or
withdraw one of them first. A polished Pace Up listing submitted while that sits on the
account is a well-dressed app walking into the same wall.

---

## 1 · App Store Connect — the listing

### Subtitle (30 max)

```
Step tracker & exploration map
```

### Promotional text (170 max — editable later without review)

```
Your map starts dark. Every walk, run and hike you record clears a little more of it, permanently. Steps, routes and splits included. No account, no server, no ads.
```

### Description (3,923 of 4,000 — re-count after any edit)

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

### Keywords (100 max, no spaces after commas)

```
pedometer,walking,running,gps,route,hiking,explore,discovery,distance,splits,elevation,offline
```

---

## 2 · App Review Information — the Notes box

The highest-value field on the form for this app. Background location plus HealthKit is
the combination that gets a submission held for questions.

```
No sign-in required. Pace Up has no account system and no server, so there is no demo account to provide.

TO SEE THE APP WORKING
Please grant both permissions when prompted:
• Apple Health — the Today screen shows a step count of zero without it
• Location (While Using) — required to record a route

On a device with no Health data the Today screen will legitimately show zeros. To exercise the GPS recorder, tap Start, choose Run, then tap START; with a simulated location route the map draws a polyline and distance, pace and splits populate.

TERRA — THE FEATURE THAT DISTINGUISHES THIS APP
Journey tab › the Terra card at the top. Terra is a world map covered in fog that clears only where the user has physically been. Each recorded route is folded into a grid of 100-metre squares and those squares are erased from the fog permanently, so the map becomes a record of the streets that person has actually walked, and the app reports the area uncovered in square kilometres. It also finds the nearest ground the user has never covered and points them at it.

To see it during review: record one activity with a simulated location route as described above, save it, then open Journey › Terra. The corridor just recorded will be clear and everything around it dark. Recording a second route in a different area and returning will show both.

Terra is computed entirely on device from routes already stored locally. It makes no network requests, uses no map data beyond Apple's own tiles, and is not derived from any third-party service. It can be cleared at any time from Profile › Data & Privacy › Clear Terra Map, and is erased automatically when the user deletes all app data.

BACKGROUND LOCATION — WHY IT IS USED
Pace Up records the user's route during a walk, run, hike or ride. The location background mode is enabled only while an activity is actively recording, so tracking continues when the screen is off or the phone is in a pocket — the expected behaviour for a fitness tracker. iOS shows the blue status indicator for the entire recording. Location is never accessed outside an active recording. It is never transmitted anywhere: the app makes no network requests and there is no backend.

HEALTHKIT — WHY IT IS USED
Pace Up reads steps, walking/running and cycling distance, active energy, heart rate, exercise minutes and workouts in order to display the user's own activity, so its figures match the Health app. It writes finished activities back as workouts with their routes, so the user's history survives deleting the app. HealthKit data is never used for advertising or marketing, is never shared with third parties, and never leaves the device. The app does not request Clinical Health Records.

PRIVACY
No account, no server, no analytics SDK, no advertising SDK, no third-party network code, no in-app purchases. All data is stored locally. The Data & Privacy screen lets users export or delete their data at any time.

Contact: manuelrinaldi86@gmail.com
```

---

## 3 · Resolution Center — Stage 1, send now, no new build

Ask what the match was before rebuilding against a guess. Send this only if you intend to
follow through on the consolidation it promises.

```
Thank you for the review.

We would like to resolve this properly rather than resubmit against a guess, so we are asking for one piece of information before we make changes.

Guideline 4.3(a) cites similarity to apps submitted by us or by other developers. Could you identify what Pace Up was matched against — the app, or the specific binary, asset, or metadata field involved? Our previous submission responded by adding functionality, which we now understand does not address a similarity finding, and we do not want to repeat that mistake.

In the meantime we have reviewed our own catalogue. Two of our apps, AI Fashion and AI Beauty Makeover, share a substantial portion of their source. We are consolidating them into a single app rather than maintaining two bundle identifiers for one codebase, and will confirm here when that is complete.

Pace Up itself shares no source or assets with those apps or with any other submission, from this account or elsewhere. It is not a purchased template or a repackaged binary. If your finding concerns Pace Up specifically rather than our catalogue as a whole, any detail you can share will let us address it directly.

Best regards,
Oana Rinaldi
```

---

## 4 · Resolution Center — Stage 2, after remediation, with a new build

Fill the brackets. Every sentence must be true of the build attached to the submission.

```
Thank you for your patience. We have made the following changes.

CATALOGUE
AI Fashion and AI Beauty Makeover shared most of their source under two bundle identifiers. We have [merged them into a single app, bundle ID com.oanarinaldi.____, and withdrawn the second identifier / withdrawn com.oanarinaldi.____ from the App Store]. This was completed on [date]. We are also spacing our submissions so each app is reviewed and released before the next is submitted.

PACE UP
This build adds Terra, which is the app's distinguishing feature and what the listing now leads with. Terra is a map covered in fog that clears only where the user has physically been. Each recorded route is folded into a grid of 100-metre squares, and those squares are erased permanently, so over months the map becomes a record of the streets that person has actually walked. The app reports the uncovered area in square kilometres, shows how much of each run was new ground, and points the user toward the nearest ground they have never covered. It is computed entirely on device from routes already stored locally, makes no network requests, and uses no data source beyond Apple's own map tiles.

The subtitle, description, keywords and screenshots have been rewritten around Terra and away from the generic step-tracker framing of the previous submission.

TO REVIEW, IN ABOUT TWO MINUTES
1. Grant Location when prompted. Tap Start, choose Walk, tap START.
2. With a simulated location route, let it run briefly, then finish and save.
3. The summary screen shows how much of that route was ground never covered before.
4. Open the Journey tab and tap the Terra card at the top.
5. The corridor just recorded is clear; everything around it is dark. The header shows the area uncovered and the steps that uncovered it.
6. Profile › Data & Privacy › Clear Terra Map re-darkens it without touching activities.

Pace Up shares no source code or assets with any other app on our account or elsewhere. It has no account system, no backend, no analytics, no advertising and no third-party SDKs; all data remains on the device.

Best regards,
Oana Rinaldi
```

---

## Before you send Stage 2

- [ ] The app builds and Terra works on a real device
- [ ] The fashion consolidation is done and visible in App Store Connect
- [ ] The build is attached to the submission and finished processing
- [ ] Every numbered walkthrough step works on a clean install with no prior data
- [ ] Screenshot 1 is Terra, part-cleared, with fog still visible around it
- [ ] Description re-counted after any edit (limit 4,000)
- [ ] No sentence in the reply describes something the reviewer cannot run

You get one App Review Board appeal per rejected submission. Spend it only when you have
something new — the consolidation, or an answer from Apple that turns out not to fit the
app. An appeal that restates the reply is the appeal wasted.
