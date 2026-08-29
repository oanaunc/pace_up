# Guideline 4.3(a) — audit findings and remediation plan

Submission `e2c0e931-fe74-46d9-9305-fbf5ae444748` · Pace Up 1.0 · rejected 28 Aug 2026

---

## Summary

Pace Up is not a code clone of your other apps. The 4.3(a) flag is almost certainly
account-level, and the concrete violation on team `HBD3XXQK45` is the
**AI Fashion / AI Beauty Makeover pair**, which are the same codebase shipped under two
bundle identifiers.

Adding features to Pace Up does not address this. That approach was already tried —
the Journey hub, the Watch companion and the commissioned artwork were built between
26 and 28 August in response to an earlier 4.3(a), and Apple returned the identical
boilerplate.

---

## What the audit found

### 1. AI Fashion and AI Beauty Makeover are one app under two bundle IDs

| | AI Fashion | AI Beauty Makeover |
|---|---|---|
| Path | `~/Desktop/AI_Fashion_Dress_me_up/AIFashion` | `~/Desktop/ai_beauty_makeover` |
| Xcode project | `AI Fashion.xcodeproj` | `AI Fashion.xcodeproj` |
| Bundle ID | `com.oanarinaldi.aifashion` | `com.oanarinaldi.aibeautymakeover` |
| Team | `HBD3XXQK45` | `HBD3XXQK45` |
| Swift files | 43 | 45 |

File-level comparison of the 43 shared filenames:

- **17 files are byte-identical**, including `AIFashionApp.swift` — the Beauty Makeover
  app still ships the AI Fashion app struct, unrenamed.
- **23 more are 85–100% identical** (`KeychainService`, `LookDetailView` and
  `StyleQuizView` differ by rounding error alone).
- **3 files differ substantially.**
- Only 2 files are new in Beauty Makeover: `AppLinks.swift`, `DataSharingConsentView.swift`
  — and the second was added to satisfy a *privacy* rejection, not to differentiate.

Both share the same product concept: upload a photo, send it to OpenAI's
`/v1/images/edits` with the user's own key, show a before/after slider.

Apple's own list of 4.3(a) triggers includes *"Creating and submitting multiple similar
apps using a repackaged app template"* and *"Submitting an app with the same source code
or assets as other apps already submitted."* This pair matches both, literally.

### 2. Six apps, one team, three weeks

First commit dates: `my_lists` 4 Jul · `pace_up` 12 Aug · `AI_Fashion` 15 Aug ·
`daily_check_widget` 17 Aug · `ai_beauty_makeover` 19 Aug. Five iOS apps initiated in
eight days, all on `com.oanarinaldi.*` / `HBD3XXQK45`. Independent of any single app's
merits, that submission cadence is the pattern 4.3(a) enforcement is built to catch.

### 3. Pace Up itself is clean

Three filenames overlap with the fashion apps, and all three are substantially rewritten:

| File | Pace Up | AI Fashion | Lines differing |
|---|---|---|---|
| `AppSettings.swift` | 209 | 187 | 74% |
| `GlassStyle.swift` | 75 | 62 | 80% |
| `SettingsView.swift` | 110 | 403 | 86% |

Generic SwiftUI filenames with independent implementations. Nothing here would trip a
binary or asset similarity match. Pace Up's `Info.plist`, entitlements and
`PrivacyInfo.xcprivacy` are all app-specific and correctly filled in.

**Conclusion: Pace Up is collateral damage from an account-level pattern, plus a
commodity concept.** Both need addressing; the account issue is the larger of the two.

---

## What is known, assumed, and unknown

**Established from the repository:**
The file-identity numbers above. The rejection sequence (reply doc predates the
rejected submission). The shared team ID.

**Assumed, with reason:**
That Apple's match was against your own apps rather than a third party's. The rejection
text says "by you or other developers" and leaves it open, but the AI Fashion pair is a
textbook match sitting on the same team ID, so it is the most probable trigger.

**Unknown:**
Which app Apple actually matched against — Apple does not disclose this unless asked, and
often not then. Whether both fashion apps are live, in review, or withdrawn. Whether the
account carries an internal flag beyond the individual rejections.

Ask App Review to name the match. It costs nothing and it is the only way to replace the
assumption above with a fact.

---

## Remediation, in priority order

### Priority 1 — resolve the duplicate pair

This is the concrete, provable violation. Nothing done to Pace Up compensates for leaving
it in place. Three options:

**(a) Merge into one app.** Apple's stated preference: one binary, with makeover *mode*
(fashion / beauty) chosen in-app. Given the codebases are already 90%+ identical this is
days of work, not weeks — mostly a mode enum, two prompt templates, and one asset set.
Keep the bundle ID with the better standing and withdraw the other.

**(b) Withdraw one outright.** Fastest. Removes the violation without engineering work.

**(c) Genuinely differentiate them.** Weakest option. They would need to diverge in
concept, not just prompt text and colour, and you would be arguing that case against a
reviewer who has already seen the resemblance.

Recommend (a) or (b). Whichever you choose, do it *before* resubmitting Pace Up, and say
so in the Pace Up reply — voluntary consolidation is the strongest signal available that
the account is not running a template farm.

### Priority 2 — slow the submission cadence

Five apps in eight days is itself evidence for a spam determination. Ship one app, get it
approved, then start the next. This costs time and nothing else.

### Priority 3 — narrow Pace Up's concept

`Step counter & run tracker` is the most cloned subtitle on the App Store. Even with a
clean account, that positioning invites the concept half of 4.3(a). The fix is a narrower
audience, not more features — the Journey hub and Watch app made Pace Up look *more* like
Strava and Nike Run Club, not less.

Three candidates, using code that already exists:

**A. Adaptive athletes / wheelchair users** — *recommended*

The asset catalogue already contains `ActivityWheelchair`. Push tracking is a real,
underserved category; Apple weights accessibility favourably; and no reviewer will call it
a clone of Strava. Requires: push-count instead of step-count via Core Motion, HealthKit
`.wheelchair` workout type and `pushCount` quantity, grade/surface annotation on routes,
and an accessible-route note field. Roughly two weeks. Rename to something like
*Push Up* / *Roll Log*, new icon, new screenshots.

**B. Return-to-movement after injury**

Conservative weekly progression, an HR ceiling with an alert, a clinician-shareable PDF
export built on the existing `ExportService`. Distinctive and defensible. Carries a
medical-claims review surface — copy must stay descriptive, never advisory, or you trade
4.3(a) for a 1.4.1 problem.

**C. Zero-network as the whole product**

You already make no network requests. Remove any networking capability entirely and make
verifiable offline-only the identity — name, icon, listing, screenshots. Cheapest to
execute, but it is a *claim* rather than functionality, and a reviewer may read it as
positioning rather than differentiation. Weakest of the three.

Whichever you pick: the app name, subtitle, icon, description and all screenshots change
with it. A narrowed concept behind a generic listing reads as a generic app.

---

## Sequence

1. Reply in the Resolution Center asking Apple to identify the specific match. Do not
   resubmit yet.
2. Merge or withdraw one of the fashion apps.
3. Choose a direction for Pace Up and rebuild the listing around it.
4. Resubmit Pace Up with a reply that states the consolidation as a fact already done.
5. Space subsequent submissions out.

Realistic assessment: 4.3(a) is among the hardest rejections to reverse, and a repeat with
unchanged boilerplate is a poor signal. Steps 1 and 2 are worth doing regardless of what
you decide about Pace Up, because an unresolved duplicate pair on the account puts every
future submission — and, with enough repeats, the developer account itself — at risk.
