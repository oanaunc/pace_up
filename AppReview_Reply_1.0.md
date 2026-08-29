# App Review reply — submission e2c0e931-fe74-46d9-9305-fbf5ae444748

Two-stage. **Send Stage 1 now, without a new build.** Stage 2 goes out only after the
remediation in `Guideline_4.3a_Strategy.md` is actually done.

## Why this replaces the previous draft

The earlier draft answered 4.3(a) by listing what Pace Up does — Journey, the Watch app,
GPS recording, widgets, achievements. That argument was already made once and the same
rejection came back verbatim. 4.3(a) is not a claim that the app is thin; 4.2 is. It is a
claim that the app resembles something else. A feature list does not answer it, and
re-running a rejected argument invites a third rejection.

Do not assert that the previous submission was sufficient. The reviewer has ruled on that.

---

## Stage 1 — ask what the match is

Paste into the Resolution Center. No new build required.

> Thank you for the review.
>
> We would like to resolve this properly rather than resubmit against a guess, so we are
> asking for one piece of information before we make changes.
>
> Guideline 4.3(a) cites similarity to apps submitted by us or by other developers. Could
> you identify what Pace Up was matched against — the app, or the specific binary,
> asset, or metadata field involved? Our previous submission responded by adding
> functionality, which we now understand does not address a similarity finding, and we do
> not want to repeat that mistake.
>
> In the meantime we are reviewing our own catalogue. We have identified two apps on our
> account, AI Fashion and AI Beauty Makeover, that share a substantial portion of their
> source. We are consolidating them into a single app rather than maintaining two bundle
> identifiers for one codebase, and will confirm here when that is complete.
>
> Pace Up itself shares no source or assets with those apps or with any other submission,
> from this account or elsewhere. It is not a purchased template or a repackaged binary.
> If your finding concerns Pace Up specifically rather than our catalogue as a whole, any
> detail you can share will let us address it directly.
>
> Best regards,
> Oana Rinaldi

**Do not send Stage 1 unless you intend to follow through on the consolidation.** Naming
the duplicate pair to App Review and then leaving it in place is worse than not raising it.

---

## Stage 2 — after remediation, with a new build

Fill the brackets in. Every sentence must be true of the build attached to the submission.

> Thank you for your patience. We have made the following changes.
>
> **Catalogue.** AI Fashion and AI Beauty Makeover shared most of their source under two
> bundle identifiers. We have [merged them into a single app, bundle ID
> `com.oanarinaldi.___`, with the second identifier withdrawn / withdrawn
> `com.oanarinaldi.___` from the App Store]. This was completed on [date]. We are also
> spacing our submissions so that each app is reviewed and released before the next is
> submitted.
>
> **Pace Up.** This build adds Terra, which is the app's distinguishing feature and is now
> what the listing leads with. Terra is a map covered in fog that clears only where the
> user has physically been. Each recorded route is folded into a grid of 100-metre squares,
> and those squares are erased from the fog permanently, so over months the map becomes a
> record of the streets that person has actually walked. The app reports the uncovered area
> in square kilometres. It is computed entirely on device from routes already stored
> locally, makes no network requests, and uses no data source beyond Apple's own map tiles.
>
> The subtitle, description, keywords and screenshots have been rewritten around Terra and
> away from the generic step-tracker framing of the previous submission.
>
> **To review, in about two minutes:**
> 1. Grant Location when prompted. Tap Start, choose Walk, tap START.
> 2. With a simulated location route, let it run briefly, then finish and save.
> 3. Open the Journey tab and tap the Terra card at the top.
> 4. The corridor just recorded is clear; everything around it is dark. The header shows
>    the area uncovered.
> 5. Profile › Data & Privacy › Clear Terra Map re-darkens it without touching activities.
>
> Pace Up shares no source code or assets with any other app on our account or elsewhere.
> It has no account system, no backend, no analytics, no advertising and no third-party
> SDKs; all data remains on the device.
>
> Best regards,
> Oana Rinaldi

---

## Before sending Stage 2

- [ ] The fashion app consolidation is done and visible in App Store Connect
- [ ] The build is attached to the submission and finished processing
- [ ] Every walkthrough step works on a clean install with no prior data
- [ ] Screenshots show the differentiating functionality, not the generic tracker screens
- [ ] Name, subtitle, description and keywords all reflect the narrowed concept
- [ ] Background-location and HealthKit review notes are present (see `PaceUp/README.md`)
- [ ] No sentence in the reply describes something the reviewer cannot run

## If Stage 2 is also rejected

You get one appeal to the App Review Board per rejected submission. Spend it only when you
have something new — the consolidation, the repositioning, or an answer from Apple that
turns out not to fit the app. An appeal that restates the reply is the appeal wasted.
