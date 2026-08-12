# Pace Up

iOS step and GPS activity tracker. No account, no server, no analytics. Everything is recorded and stored on the device.

**Stack:** SwiftUI (iOS 26, Liquid Glass) · SwiftData · HealthKit · Core Location · Core Motion · MapKit · Swift Charts · WidgetKit

---

## Open it

```
open PaceUp/PaceUp.xcodeproj
```

Requires Xcode 26 or later and a Mac. It will not build in a simulator-only CI without signing changes (see below).

**This project has never been compiled.** It was generated on Linux where no Swift toolchain or iOS SDK exists. Expect to fix some compile errors on first open — most likely candidates are listed under [Known risks](#known-risks).

---

## Before your first build

Three things must change, all in Xcode's target settings.

### 1. Bundle identifiers — already set

`com.oanarinaldi.paceup` and `com.oanarinaldi.paceup.widget`, matching the convention used by harsh_comebacks, ai_home_makeover and MyLists on this machine.

### 2. Signing team — already set

`DEVELOPMENT_TEAM = HBD3XXQK45` on all four build configurations.

### 3. App Group — register it once in the developer portal

`group.com.oanarinaldi.paceup` appears in **four** places and all four already match:

| Where | File |
|---|---|
| App entitlements | `Config/PaceUp.entitlements` |
| Widget entitlements | `Config/PaceUpWidgets.entitlements` |
| App source | `PaceUp/Models/AppSettings.swift` → `AppGroup.identifier` |
| Widget source | `PaceUpWidgets/SharedSnapshot.swift` → `WidgetAppGroup.identifier` |

The group does **not** yet exist in your developer account. The easiest way to create it is
from Xcode: select the app target → Signing & Capabilities → **+ Capability** → App Groups →
**+** → type `group.com.oanarinaldi.paceup`. Xcode registers it in the portal for you. Then
repeat on the widget target and tick the same group (it will already be in the list).

Failing that, create it manually at
[Certificates, Identifiers & Profiles → Identifiers → App Groups](https://developer.apple.com/account/resources/identifiers/list/applicationGroup).

If these four ever drift apart, the app builds and runs but the widget silently shows placeholder data forever — there is no error.

### Capabilities checklist

- **App target:** HealthKit, App Groups, Background Modes → Location updates
- **Widget target:** App Groups

Leave **HealthKit → Clinical Health Records** unticked. That is a separate entitlement
(`com.apple.developer.healthkit.access`) for reading medical records from health providers,
it must be granted by Apple on request, and Pace Up has no use for it. Ticking it makes every
build fail with *"HealthKit Access (Verifiable Health Records) capability needs to be assigned
to your team and bundle identifier by Apple."*

---

## Architecture

```
HealthKit    ──▶ steps, distance, active energy, heart rate, workouts (read + write)
Core Location ─▶ GPS fixes during an activity
Core Motion   ─▶ live step count during an activity
MapKit        ─▶ renders the route Pace Up recorded
SwiftData     ─▶ activities, achievements   (App Group container)
UserDefaults  ─▶ preferences + widget snapshot (App Group suite)
WidgetKit     ─▶ home screen widgets
```

### The schema is split on purpose

```
Activity          PERMANENT   summary, splits, ~60-point thumbnail route, bounding box   ~1 KB
  └─ detail       PURGEABLE   full GPS trace + heart-rate series                       ~115 KB/hour
```

Everything the Progress, Personal Records, Achievements and Profile screens display is derived from `Activity` alone. This is what lets the 30-day cleanup delete 99% of the bytes without breaking a single number in the UI. A 16.4 km longest run stays a personal record forever; only its map disappears.

`RetentionService.purgeDetail` deletes the `ActivityDetail` **object** — nulling the relationship alone would orphan the row and free nothing, because SwiftData's cascade rule fires on deleting the parent, not on nullifying the link.

### Three problems the code solves explicitly

**HealthKit double counting.** HealthKit does not deduplicate across sources. A naive `cumulativeSum` over step count returns iPhone steps *plus* Watch steps. `HealthKitManager` collects statistics in ten-minute buckets with `.separateBySource` and counts exactly one source per bucket, ranked Apple Watch → iPhone → third party → Pace Up. Bucketing matters: a whole-day priority choice would discard an afternoon of iPhone steps from someone who wore their Watch only in the morning.

**Termination mid-run.** iOS can kill a backgrounded app at any time. Every accepted GPS fix is appended to a file the moment it arrives (`RecordingJournal`, a serial `DispatchQueue` — not an actor, because unstructured `Task`s into an actor give no ordering guarantee and an out-of-order append produces a zig-zag route). An unfinished journal is offered back on the next launch and is only deleted once the recovered activity has actually been written.

**GPS noise.** `ActivityRecorder.accept(_:)` drops fixes worse than 30 m accuracy, movement under 2 m (standing still otherwise adds tens of metres a minute), and jumps implying impossible speed. Elevation deltas under 1 m are ignored — summing raw altitude noise over an hour invents hundreds of phantom metres of climb.

---

## Layout

```
PaceUp/
├── PaceUp.xcodeproj
├── Config/                      Info.plists and entitlements (outside the synced groups)
├── PaceUp/
│   ├── PaceUpApp.swift
│   ├── Models/                  SwiftData schema, codecs, settings
│   ├── Health/                  HealthKit read/write + source dedup
│   ├── Location/                GPS recorder, journal, route maths
│   ├── Services/                retention, stats, achievements, export/import
│   ├── DesignSystem/            palette, Liquid Glass wrappers, formatters
│   ├── Views/                   every screen from the comps
│   ├── Assets.xcassets/         app icon (from logo.png), wordmark, colours
│   └── Resources/               PrivacyInfo.xcprivacy
└── PaceUpWidgets/               widget extension (self-contained module)
```

The project uses Xcode 16+ **synchronized file groups**: files added to `PaceUp/` or `PaceUpWidgets/` on disk join the target automatically. There is no file list in the `.pbxproj` to maintain.

All Liquid Glass calls funnel through `DesignSystem/GlassStyle.swift`. If an API signature shifts in a future SDK, that is the one file to fix.

---

## Known risks

Ranked by how likely they are to bite on first build.

1. **`Glass.clear`** (`GlassStyle.swift`, `paceGlassPanel`). If it doesn't resolve, use `.regular`.
2. **`.chartYScale(domain: [upper, lower])`** (`Charts.swift`, `PaceChart`). This is the array-domain trick for inverting a continuous axis so faster reads as higher. If it fails, drop to `.chartYScale(domain: yDomain)` and accept a non-inverted pace chart.
3. **`.clipShape(.rect(cornerRadius:))` on `BarMark`** (`Charts.swift`). Swap for `.cornerRadius(5)`.
4. **`MainActor.assumeIsolated`** in `LocationProvider`. Correct as long as `CLLocationManager` was created on the main thread, which it is. If it ever traps, replace with `DispatchQueue.main.async`.
5. **Swift language mode.** Targets are set to Swift 5 with `SWIFT_STRICT_CONCURRENCY = minimal` deliberately. Switching to Swift 6 will surface a number of actor-isolation errors around `AppSettings.shared` and `HealthKitManager.shared` that are warnings today.

---

## What you cannot test in the simulator

- **HealthKit** returns nothing useful. Add sample data in the simulator's Health app, or test on device.
- **Core Motion step counting** is unavailable. `steps` stays at 0 during a simulated run; the HealthKit read at save time is what fills it in on device.
- **GPS** needs Debug → Simulate Location, or Xcode's *City Run* / *Freeway Drive* GPX presets. The scheme already has `allowLocationSimulation = "YES"`.
- **Background termination recovery** — reproduce by starting a run, backgrounding, then stopping the app from Xcode. Relaunch should offer the run back.
- **Widgets** show placeholder data until the app has run once and written a snapshot.

---

## App Store submission

### Already done in the project

- `PrivacyInfo.xcprivacy` declares no tracking, no collected data types, and the three required API-usage reasons (UserDefaults, file timestamp, disk space).
- All five purpose strings are in `Config/PaceUp-Info.plist`.
- `ITSAppUsesNonExemptEncryption = false`.
- App icon is 1024×1024 with no alpha, plus dark and tinted variants.

### You still need to do

**1. Version and build number.** `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`. Bump the build for every upload.

**2. Privacy nutrition label** in App Store Connect. Given this architecture the honest answer to every question is *not collected* — Health, Location, Fitness, Identifiers, everything. Nothing leaves the device. Do not tick "Health & Fitness → Linked to You"; there is no account to link to.

**3. Background location justification.** This is where fitness apps get rejected. In App Review Notes, state plainly:

> Pace Up records the user's route during a walk, run, hike or ride. Background location is enabled only while an activity is actively recording, so tracking continues when the screen is off or the phone is in a pocket — the standard behaviour for a fitness tracker. The blue status indicator is shown for the entire recording. Location is never accessed outside an active recording, is never transmitted anywhere, and there is no server.

**4. HealthKit review notes.** Apple checks that HealthKit data is not used for advertising and that the app has a real fitness purpose. State that Pace Up reads steps, distance, energy, heart rate and workouts to display the user's own activity, writes finished workouts back so history survives app deletion, and has no advertising or third-party SDKs of any kind.

**5. Screenshots.** 6.9" and 6.5" iPhone are required. Record a run with a GPX simulation to get a real-looking route.

**6. Demo account.** Not applicable — say so in the review notes so the reviewer doesn't stall on it. Do note that the reviewer must grant Health and Location permission to see the app work, and that the simulator shows an empty Today screen without Health data.

**7. Age rating.** 4+.

**8. Support and privacy policy URLs** are mandatory. A single page stating "Pace Up stores all data on your device and transmits nothing" satisfies the privacy policy requirement.

### Likely rejection reasons, in order

| Risk | Mitigation |
|---|---|
| Background location not justified | The review note above; make sure the app genuinely stops updates when not recording (it does — `LocationProvider.stop()`) |
| HealthKit permission requested without obvious purpose | The Connect Health onboarding screen lists every type and why |
| Privacy label contradicts the privacy manifest | Both say "collects nothing"; keep them consistent |
| Guideline 4.2 (minimum functionality) | Unlikely — this is a full tracker, not a wrapper |

---

## Design decisions worth knowing before you change things

**Why 30-day cleanup keeps summaries.** The original spec deleted whole activities. That would have silently destroyed the lifetime totals, streaks and personal records the app's own Progress screen advertises. Splitting the schema keeps the privacy promise and the numbers.

**Why export is not "your only backup".** The app container is included in iCloud and encrypted device backups, so restoring a new phone restores Pace Up's data. Deleting the app is what loses it. The Settings copy says exactly that rather than implying the data is otherwise at risk.

**Why workouts are written to HealthKit.** It is the thing that makes local-only defensible. Delete Pace Up and your workouts and routes remain in Health; only Pace Up's notes, achievements and settings go.

**Why no music control.** The comps show a music button on the live run screen. MusicKit is a meaningful chunk of work with its own entitlement and review surface, and it was cut from v1. The button is not implemented.

**Why the app icon is just "Up".** The full wordmark is illegible at 60 pt. The arrow-through-U mark is the distinctive part and survives the shrink.

**Why no CloudKit.** Turning on `cloudKitDatabase` requires every model property to be optional or defaulted and forbids `@Attribute(.unique)` — a schema migration, not a checkbox. It is off deliberately.
