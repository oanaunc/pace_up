//
//  RecordingFlowView.swift
//  Pace Up
//
//  The single presentation that owns recording and saving.
//
//  ── Why this exists ────────────────────────────────────────────────────────
//
//  Previously the live screen was a `fullScreenCover` presented by the tab
//  view, and the summary was a *second* `fullScreenCover` presented from inside
//  the first. Tapping Finish mutated two pieces of state in one transaction:
//  the recorder's `state` (which the outer cover's binding reads) and the live
//  screen's local `finished`. SwiftUI updates the outer presentation first, and
//  the inner one — created during that same update — is frequently dropped.
//
//  The visible symptom was the worst kind: Finish stopped the GPS, set the
//  recorder to `.saving`, and then nothing appeared. Because `finish()` guards
//  on `state == .recording || .paused`, every subsequent tap returned nil, so
//  the button was permanently dead and the run sat in limbo.
//
//  There is now exactly one cover. It stays up for the whole flow, and this
//  view swaps its contents. No nesting, so nothing to drop.
//

import SwiftUI

struct RecordingFlowView: View {

    @Environment(ActivityRecorder.self) private var recorder

    var body: some View {
        if let pending = recorder.pendingSummary {
            ActivitySummaryView(finished: pending) { didSave in
                if didSave {
                    recorder.completeSave()
                } else {
                    recorder.cancelPendingSummary()
                }
            }
            .transition(.opacity)
        } else {
            LiveActivityView()
                .transition(.opacity)
        }
    }
}
