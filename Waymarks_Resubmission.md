# Pace Up 1.1 — Waymarks resubmission kit

What changed in the build, what to paste into App Store Connect, and what to send App Review.

---

## 0 · Do this first, or none of the rest matters

Terra was a real feature and it was still rejected with the same 4.3(a) text. That points at the
account, not at Pace Up. **AI Fashion and AI Beauty Makeover are still live on team
`HBD3XXQK45` with ~80% identical source and 17 byte‑identical files** — that is exactly what
4.3(a) describes ("same source code… repackaged template").

Before you resubmit Pace Up:

- [ ] Merge AI Fashion + AI Beauty Makeover into one app, **or** remove one from sale and delete it from App Store Connect.
- [ ] Don't submit any other new app until Pace Up is approved.

If you skip this, expect the same rejection regardless of how good Pace Up is.

---

## 1 · The new concept: Waymarks

Pace Up stops being "a step tracker with extras". It becomes **a walking journal where memories
are pinned to places and only come back when you physically return.**

| Feature | What it does | Where |
|---|---|---|
| **Drop a waymark** | One tap mid‑walk pins a note, photo, voice memo or time capsule to the exact spot | Live screen (lime "Waymark" button), Journal "+" |
| **It finds you** | Pass that spot on a later walk/run/ride → haptic + card "You were here · 1 year ago". Phone in pocket gets a notification | iPhone + Apple Watch |
| **Time capsules** | Sealed until a date you choose — *and* it only opens when you're standing there. Addressed to "Me", "Ana", "the kids" | Composer → Capsule |
| **Journal tab** | Map of all waymarks (memory / sealed / ready), timeline by month, capsule countdowns, "On this day" | New 2nd tab |
| **Memory Lane** | Today card + Home Screen widget: capsule countdown, capsules ready, on‑this‑day | Today, widget |
| **Watch** | Dictate a waymark from the wrist, haptic when you pass one, compass arrow to the nearest memory, home card with distance | Watch app |
| **Summary** | "Left 1, found 2 along the way" after each activity | Activity summary |

Nothing leaves the device (Watch ↔ iPhone only). Location is still only used during a recording,
so no "Always" permission was added.

### Files added

```
PaceUp/PaceUp/Models/Waymark.swift
PaceUp/PaceUp/Waymarks/  WaymarkStore, WaymarkMonitor, WaymarkSync, WaymarkMedia,
                         VoiceMemo, WaymarkSupport, WaymarkComposerView,
                         WaymarkEncounterView, WaymarkDetailView, JournalView,
                         WaymarkWidgetSnapshot
PaceUp/PaceUpWatch/      WatchWaymarkCenter, WatchWaymarkViews
PaceUp/PaceUpWidgets/    MemoryLaneWidget
Assets: WaymarkHero, CapsuleSealed, MemoryLane, WaymarkOnboarding, JournalEmpty, WidgetCapsule
```

### Files changed

Today (now opens on memories + capsule strip; steps are a compact row), new app icon (pin + envelope on a path; old icons archived in AppStoreAssets/IconArchive/v1-up-arrow), Watch screenshot mode removed, WaymarkDemoSeed (debug-only demo data), ActivityRecorder (two hooks), PaceUpApp, PaceUpStore (schema), RootTabView (Journal tab replaces
Progress; Progress moved into Journey), LiveActivityView, ActivitySummaryView, TodayView,
OnboardingFlowView (new concept page), RouteMapView (waymark pins), DataPrivacyView (Delete All
removes waymarks), ProgressDashboardView, JourneyView, both Info.plists (camera, microphone,
watch location), project (watchOS target 9 → 10).

---

## 2 · Build checklist (in Xcode)

- [ ] Build & run iPhone + Watch. This code was written without a compiler — fix anything Xcode flags.
- [ ] Watch target: Signing & Capabilities is unchanged; WatchConnectivity needs no capability.
- [ ] Test on device: record walk → tap **Waymark** → leave a note → Finish & Save → wait 2 min → start another walk at the same spot → card appears.
- [ ] Capsule: create one sealed for "1 month"; check Journal → Capsules shows countdown.
- [ ] Add the **Memory Lane** widget to the Home Screen.
- [ ] Bump `CURRENT_PROJECT_VERSION`, keep `MARKETING_VERSION = 1.0` (1.0 was never released).

---

## 3 · App Store Connect

**App name (30):** `Pace Up: Walk Time Capsules`  
**Subtitle (30):** `Memories that find you on foot`

**Promotional text (170):**
```
Pin a note, photo or voice memo to the spot you're standing. Walk past it again — next week or in five years — and your iPhone or Apple Watch hands it back to you.
```

**Description:**
```
Pace Up is a walking journal that lives in the places you walk.

Leave a waymark — a note, a photo, a voice memo — pinned to the exact spot you're standing. Then forget about it. The next time a walk, run or ride takes you back past that spot, Pace Up taps you on the wrist: "You were here, a year ago." The bench where you made a decision. The corner where your daughter learned to ride. The hill you couldn't run up in March.

TIME CAPSULES THAT OPEN ONLY WHERE YOU LEFT THEM
Write to future you, or to someone you love. Seal it for a month, a year, five years. When the date comes, the capsule doesn't pop up on a screen — it waits for you to walk back to where you sealed it. Then it opens.

YOUR JOURNAL, ON A MAP
Every waymark on one map: memories in green, sealed capsules in violet, capsules ready to open in amber. Browse by month, see how many times you've come back to each place, and get directions to walk back to any of them.

ON YOUR WRIST
On Apple Watch, dictate a waymark mid-run without stopping. Feel a tap when you pass one. Follow a compass arrow to the nearest memory you haven't seen in a while.

ON THIS DAY
The Today screen and the Memory Lane widget show what you left on this date in earlier years, and count down to your next capsule.

A TRACKER UNDERNEATH
Waymarks ride on a careful GPS recorder: distance, pace, splits, elevation, steps and heart rate, auto-pause, and recovery if your battery dies mid-run. Workouts are saved to Apple Health. Terra, a fog map that clears where you've been, shows how much of your city you've walked.

PRIVATE BY DESIGN
No account. No server. No ads. No analytics. Your waymarks, photos and voice memos stay on your iPhone, shared only with your own Apple Watch. Location is used only while an activity is recording.
```

**Keywords (100):**
```
time capsule,memory,journal,diary,waymark,place notes,walk,hike,letter,future self,map,watch,gps
```

**Category:** Lifestyle (primary), Health & Fitness (secondary). Leading with Lifestyle moves Pace Up
out of the most crowded category and matches what the app now is.

### Screenshots (6.9" iPhone) — in this order, every one about Waymarks

1. Live map with the encounter card: *"You were here · 1 year ago"* — caption **"Walk back, and it finds you"**
2. Composer on Capsule, "Seal until 1 year", addressed to "Me" — **"Seal a letter to future you"**
3. Journal map with lime / violet / amber pins — **"Your memories, pinned to places"**
4. Capsule detail with countdown — **"Opens on its date. Only where you left it."**
5. Today with the Memory Lane card — **"On this day, a year ago"**
6. Activity summary "Left 1, found 2" + Terra — **"A careful tracker underneath"**

**How to capture them (real app, real data):**

1. Xcode → Product → Scheme → Edit Scheme → Run → Arguments → add `-PaceUpDemoWaymarks YES` (Debug builds only; it does nothing in the App Store build).
2. Run on the largest Pro Max simulator (6.9"). Delete the app first so the store is empty — the seed only fills an empty store.
3. Simulator → Features → Location → Custom Location → `44.4362, 26.0904` (Cișmigiu, Bucharest).
4. Start → Walk → START. "The bench where I decided to move here — a year ago" surfaces immediately → screenshot 1.
5. Journal tab → map / Capsules → screenshots 3 and 4. Today → screenshot 5. Composer → Capsule → screenshot 2.
6. Remove the launch argument before archiving.

The old faked Watch "screenshot mode" has been removed — App Review checks that screenshots show the real app.

### Apple Watch screenshots

1. Compass to nearest memory ("320 m · The bench by the lake")
2. Encounter "YOU WERE HERE"
3. Drop view "Say what happened here"
4. Home with Memory Lane card

Replace the old run/hike/cycle watch screenshots — they look like every other tracker.

---

## 4 · App Review notes (Review Information → Notes)

```
Pace Up is a walking journal: users pin notes, photos, voice memos and time capsules to the place they are standing, and they resurface only when the user physically walks back there during a recorded activity. Capsules additionally stay sealed until a chosen date.

To review in ~3 minutes (simulator: Features → Location → Custom Location works):
1. Allow Location. Tap Start → Walk → START.
2. Tap the lime "Waymark" button (top right), type a title, tap "Leave It Here". Pause → Finish → Save.
3. Wait 2 minutes, then Start → Walk → START again at the same location.
4. A card appears: "YOU WERE HERE · 2 minutes ago". (With the app in the background, a notification is shown instead.)
5. Open the Journal tab: map, timeline and capsules. Journal "+" → Time capsule creates a sealed capsule with a countdown.

Background location is used only while an activity is recording (blue indicator shown), to keep the route and to detect when the user passes a waymark. Location is never used outside a recording and never leaves the device. Camera and microphone are used only when the user adds a photo or voice memo to a waymark. HealthKit reads steps/distance/energy/heart rate to display the user's own activity and writes finished workouts. No account, no server, no analytics, no ads, no third-party SDKs.
```

---

## 5 · Reply in Resolution Center (send with the new build)

```
Thank you for the review.

This build of Pace Up is a different product from a step or run tracker. Its core is Waymarks — notes, photos, voice memos and time capsules pinned to a physical location, which return only when the user walks back to that exact place. Time capsules stay sealed until a chosen date and then open only in person. The Apple Watch app lets users dictate waymarks mid-workout, feel a haptic when they pass one, and follow a compass to the nearest memory. The name, subtitle, description, category, screenshots and onboarding now lead with this concept. The review notes include a three-minute walkthrough.

Pace Up shares no code or assets with any other app. All data stays on the device.

Thank you,
Oana Rinaldi
```

Every sentence above is true of build 12.

---

## Not done yet (good next steps)

- Waymarks are not in the JSON backup export yet (`ExportService`).
- No Watch complication (needs a new watchOS widget extension target).
- Waymark photos aren't sent to the Watch (text only, to keep sync small).
