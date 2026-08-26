# App Review reply — Submission ID e2c0e931-fe74-46d9-9305-fbf5ae444748

Send in App Store Connect → App Review, **after** uploading build 1.0 (4) and updating the Age Rating.

---

Hello,

Thank you for the detailed review. Both issues have been addressed.

**Guideline 5.1.1(iv) — HealthKit permission request**

You are right that the onboarding screen let the user defer the permission request. The "Not now" button has been removed. The Health screen now explains what Pace Up reads and why, and its only action is a "Continue" button that always presents the system HealthKit authorization sheet. The user's choice is made in the system sheet itself, and onboarding proceeds either way.

The explanatory text was kept because Pace Up requests several read types at once (steps, walking and running distance, workouts, heart rate, active energy) plus write access for finished workouts, and the screen tells the user what each is used for before iOS asks. It no longer offers any way to bypass or postpone the prompt.

Health access is optional to the app's core function: if the user declines in the system sheet, activity recording continues using GPS only, and the app degrades to a zero state rather than blocking. Settings → Apple Health contains an "Open Health Settings" link so the user can change the decision at any time.

This is included in build 1.0 (4).

**Guideline 2.3.6 — Age Rating**

"Health or Wellness Topics" has been set to "Yes" on the App Information page. Pace Up is a fitness tracker that displays steps, distance, active energy and workout history, so the previous selection was incorrect.

Please let us know if anything else is needed.

Best regards,
Oana Rinaldi
Pace Up
