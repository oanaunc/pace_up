import SwiftUI

struct MovementPlanSession: Identifiable {
    let id: String
    let title: String
    let duration: String
    let detail: String
}

enum MovementPlan: String, CaseIterable {
    case firstFiveK, dailyReset, weekendExplorer

    var title: String { switch self { case .firstFiveK: "First 5K"; case .dailyReset: "Daily Reset"; case .weekendExplorer: "Weekend Explorer" } }
    var summary: String { switch self { case .firstFiveK: "Build from comfortable walks to a confident 5K with gradual run intervals."; case .dailyReset: "A gentle ten-minute ritual designed to restore energy and clear your head."; case .weekendExplorer: "Develop the time-on-feet and climbing confidence for longer outdoor days." } }
    var activityType: ActivityType { switch self { case .firstFiveK: .run; case .dailyReset: .walk; case .weekendExplorer: .hike } }
    var sessions: [MovementPlanSession] {
        let content: [(String, String, String)] = switch self {
        case .firstFiveK: [("Easy foundation", "20 min", "Walk naturally and finish fresh"), ("Run introductions", "24 min", "6 × 1 min easy run"), ("Long easy day", "30 min", "Relaxed continuous movement")]
        case .dailyReset: [("Unwind", "10 min", "Easy walk + long exhales"), ("Energise", "10 min", "Brisk middle five minutes"), ("Restore", "10 min", "Gentle, screen-free movement")]
        case .weekendExplorer: [("Climbing legs", "35 min", "Seek a gently rolling route"), ("Steady base", "45 min", "Comfortable continuous effort"), ("Adventure day", "60 min", "Explore somewhere new")]
        }
        return content.enumerated().map { index, item in
            MovementPlanSession(id: "\(rawValue)-\(index)", title: item.0, duration: item.1, detail: item.2)
        }
    }
}

struct MovementPlanView: View {
    let plan: MovementPlan
    @AppStorage("activeMovementPlan", store: AppGroup.defaults) private var activePlan = ""
    @AppStorage("completedMovementSessions", store: AppGroup.defaults) private var completedRaw = ""

    private var isActive: Bool { activePlan == plan.rawValue }
    private var completedIDs: Set<String> { Set(completedRaw.split(separator: ",").map(String.init)) }
    private var completedCount: Int { plan.sessions.filter { completedIDs.contains($0.id) }.count }
    private var nextSession: MovementPlanSession? { plan.sessions.first { !completedIDs.contains($0.id) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaceSpacing.xl) {
                header
                if isActive { progressCard }
                VStack(alignment: .leading, spacing: PaceSpacing.s) {
                    Text(isActive ? "YOUR SESSIONS" : "PLAN PREVIEW").font(.caption.bold()).tracking(1.5).foregroundStyle(.paceTextTertiary)
                    ForEach(Array(plan.sessions.enumerated()), id: \.element.id) { index, session in sessionRow(session, number: index + 1) }
                }
                if isActive, let nextSession {
                    NavigationLink { ActivitySetupView(type: plan.activityType) } label: {
                        Label("START \(nextSession.title.uppercased())", systemImage: plan.activityType.symbolName)
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .foregroundStyle(Color.paceInk).background(Color.paceLime, in: .rect(cornerRadius: PaceRadius.tile))
                    }.buttonStyle(.plain)
                } else if !isActive {
                    PrimaryButton(title: "START THIS PLAN") { withAnimation(.snappy) { activePlan = plan.rawValue } }
                }
                if isActive {
                    Button("Leave this plan", role: .destructive) { activePlan = "" }.font(.subheadline).frame(maxWidth: .infinity)
                }
            }.padding(PaceSpacing.l)
        }.background(Color.paceInk.ignoresSafeArea()).navigationTitle(plan.title).navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.s) {
            Text("PACE UP PLAN").font(.caption.bold()).tracking(1.8).foregroundStyle(.paceLime)
            Text(plan.title).font(.title.bold())
            Text(plan.summary).font(.body).foregroundStyle(.paceTextSecondary)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.s) {
            HStack {
                Text(completedCount == plan.sessions.count ? "Plan complete" : "Plan in progress").font(.headline)
                Spacer(); Text("\(completedCount)/\(plan.sessions.count)").font(.headline.monospacedDigit()).foregroundStyle(.paceLime)
            }
            ProgressView(value: Double(completedCount), total: Double(plan.sessions.count)).tint(.paceLime)
            Text(nextSession.map { "Next: \($0.title) · \($0.duration)" } ?? "You completed every session. Beautiful work.")
                .font(.caption).foregroundStyle(.paceTextSecondary)
        }.padding(PaceSpacing.l).paceGlassCard(cornerRadius: PaceRadius.tile)
    }

    private func sessionRow(_ session: MovementPlanSession, number: Int) -> some View {
        let isComplete = completedIDs.contains(session.id)
        return Button {
            guard isActive else { return }; toggle(session.id)
        } label: {
            HStack(alignment: .top, spacing: PaceSpacing.m) {
                ZStack {
                    Circle().fill(isComplete ? Color.paceLime : Color.white.opacity(0.08))
                    Image(systemName: isComplete ? "checkmark" : "\(number).circle.fill").font(.headline).foregroundStyle(isComplete ? Color.paceInk : Color.paceLime)
                }.frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title).font(.headline).strikethrough(isComplete)
                    Text("\(session.duration) · \(session.detail)").font(.subheadline).foregroundStyle(.paceTextSecondary)
                }
                Spacer()
            // The row is mostly `Spacer()`, which renders nothing and so hit-tests
            // as nothing. Tapping the empty right-hand half of a session row has
            // to toggle it like the left-hand half does.
            }.padding(PaceSpacing.m).contentShape(.rect).paceGlassCard(cornerRadius: PaceRadius.tile)
        }.buttonStyle(.plain).accessibilityHint(isActive ? "Marks this session complete or incomplete" : "Activate the plan to track this session")
    }

    private func toggle(_ id: String) {
        var ids = completedIDs
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        completedRaw = ids.sorted().joined(separator: ",")
    }
}
