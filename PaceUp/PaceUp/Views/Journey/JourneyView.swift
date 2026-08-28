import SwiftUI
import SwiftData

struct JourneyView: View {
    @Query(sort: \Activity.startDate, order: .reverse) private var activities: [Activity]
    @Environment(AppSettings.self) private var settings
    @AppStorage("activeMovementPlan", store: AppGroup.defaults) private var activePlanRaw = ""
    @AppStorage("completedMovementSessions", store: AppGroup.defaults) private var completedRaw = ""

    private var weekActivities: [Activity] {
        activities.filter { $0.startDate >= Calendar.current.date(byAdding: .day, value: -7, to: .now)! }
    }

    private var weekDistance: Double { weekActivities.reduce(0) { $0 + $1.distance } }
    private var activeDays: Int { Set(weekActivities.map { Calendar.current.startOfDay(for: $0.startDate) }).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PaceSpacing.l) {
                    hero
                    if let activePlan { activePlanCard(activePlan) }
                    weeklyCoach
                    plans
                    library
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background(Color.paceInk.ignoresSafeArea())
            .navigationTitle("Journey")
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("MovementDawn")
                .resizable().scaledToFill()
                .frame(height: 220).clipped()
            LinearGradient(colors: [.clear, .paceInk.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Label("YOUR MOMENTUM", systemImage: "sparkles")
                    .font(.caption.bold()).tracking(1.4).foregroundStyle(.paceLime)
                Text(momentumTitle).font(.title2.bold())
                Text("Small, consistent sessions build a body that wants to move.")
                    .font(.subheadline).foregroundStyle(.paceTextSecondary)
            }.padding(PaceSpacing.l)
        }
        .clipShape(.rect(cornerRadius: PaceRadius.card))
        .overlay { RoundedRectangle(cornerRadius: PaceRadius.card).stroke(Color.white.opacity(0.1)) }
    }

    private var momentumTitle: String {
        activeDays == 0 ? "Your next chapter starts today" : "You moved on \(activeDays) day\(activeDays == 1 ? "" : "s") this week"
    }

    private var activePlan: MovementPlan? { MovementPlan(rawValue: activePlanRaw) }
    private var completedIDs: Set<String> { Set(completedRaw.split(separator: ",").map(String.init)) }

    private func activePlanCard(_ plan: MovementPlan) -> some View {
        let completed = plan.sessions.filter { completedIDs.contains($0.id) }.count
        let next = plan.sessions.first { !completedIDs.contains($0.id) }
        return NavigationLink { MovementPlanView(plan: plan) } label: {
            VStack(alignment: .leading, spacing: PaceSpacing.m) {
                HStack {
                    Label("ACTIVE PLAN", systemImage: "flag.checkered").font(.caption.bold()).tracking(1.3).foregroundStyle(.paceLime)
                    Spacer(); Text("\(completed)/\(plan.sessions.count)").font(.headline.monospacedDigit())
                }
                Text(plan.title).font(.title3.bold())
                ProgressView(value: Double(completed), total: Double(plan.sessions.count)).tint(.paceLime)
                HStack {
                    Text(next.map { "Next: \($0.title) · \($0.duration)" } ?? "All sessions complete").font(.caption).foregroundStyle(.paceTextSecondary)
                    Spacer(); Text("CONTINUE").font(.caption.bold()).foregroundStyle(.paceLime)
                }
            }
            .padding(PaceSpacing.l)
            .background(Color.paceLime.opacity(0.08), in: .rect(cornerRadius: PaceRadius.card))
            .overlay { RoundedRectangle(cornerRadius: PaceRadius.card).stroke(Color.paceLime.opacity(0.22)) }
        }.buttonStyle(.plain)
    }

    private var weeklyCoach: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            HStack {
                Label("Weekly coach", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                Text("ADAPTIVE")
                    .font(.caption2.bold())
                    .foregroundStyle(.paceAmber)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.paceAmber.opacity(0.12), in: .capsule)
            }
            Text(coachMessage).font(.subheadline).foregroundStyle(.paceTextSecondary)
            HStack(spacing: PaceSpacing.s) {
                CoachMetric(value: "\(weekActivities.count)", label: "sessions")
                CoachMetric(value: PaceFormat.distanceValue(weekDistance, units: settings.units), label: settings.units.distanceAbbreviation)
                CoachMetric(value: "\(activeDays)/4", label: "active days")
            }
        }
        .padding(PaceSpacing.l)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [Color.paceOrange.opacity(0.28), Color.paceViolet.opacity(0.18), Color.paceSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.paceAmber.opacity(0.16))
                    .frame(width: 150, height: 150)
                    .blur(radius: 38)
                    .offset(x: 48, y: -64)
            }
        }
        .clipShape(.rect(cornerRadius: PaceRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PaceRadius.card)
                .stroke(Color.paceAmber.opacity(0.18))
        }
    }

    private var coachMessage: String {
        if activeDays == 0 { return "Begin with a relaxed 15-minute walk. Pace Up will shape next week from what you actually complete." }
        if activeDays < 3 { return "You have a good base. One easy movement day will keep the rhythm without overreaching." }
        return "Consistency is trending up. Keep the next session conversational and let recovery lock in the gains."
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            SectionHeader(title: "Movement plans")
            Text("Choose one path, complete each session, and return here to continue where you left off.")
                .font(.caption).foregroundStyle(.paceTextSecondary)
            NavigationLink { MovementPlanView(plan: .firstFiveK) } label: {
                PlanCard(title: "First 5K", subtitle: "3 guided sessions · walk + run", symbol: "figure.run", tint: .paceLime, isActive: activePlan == .firstFiveK)
            }
            NavigationLink { MovementPlanView(plan: .dailyReset) } label: {
                PlanCard(title: "Daily Reset", subtitle: "3 × 10 minutes · low pressure", symbol: "sun.horizon.fill", tint: .paceAmber, isActive: activePlan == .dailyReset)
            }
            NavigationLink { MovementPlanView(plan: .weekendExplorer) } label: {
                PlanCard(title: "Weekend Explorer", subtitle: "3 sessions · hiking endurance", symbol: "mountain.2.fill", tint: .paceViolet, isActive: activePlan == .weekendExplorer)
            }
        }.buttonStyle(.plain)
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            SectionHeader(title: "Your movement library")
            HStack(spacing: PaceSpacing.s) {
                JourneyLink(title: "History", symbol: "clock.arrow.circlepath", destination: AnyView(ActivityListView()))
                JourneyLink(title: "Records", symbol: "trophy.fill", destination: AnyView(PersonalRecordsView()))
                JourneyLink(title: "Badges", symbol: "medal.fill", destination: AnyView(AchievementsView()))
            }
        }
    }
}

private struct CoachMetric: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) { Text(value).font(.headline.monospacedDigit()); Text(label).font(.caption2).foregroundStyle(.paceTextTertiary) }
            .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.05), in: .rect(cornerRadius: 12))
    }
}

private struct PlanCard: View {
    let title: String; let subtitle: String; let symbol: String; let tint: Color; let isActive: Bool
    var body: some View {
        HStack(spacing: PaceSpacing.m) {
            Image(systemName: symbol).font(.title2).foregroundStyle(tint).frame(width: 48, height: 48).background(tint.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.paceTextSecondary) }
            Spacer()
            if isActive { Text("ACTIVE").font(.caption2.bold()).foregroundStyle(.paceLime) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.paceTextTertiary)
        }.padding(PaceSpacing.m).paceGlassCard(cornerRadius: PaceRadius.tile)
    }
}

private struct JourneyLink: View {
    let title: String; let symbol: String; let destination: AnyView
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 9) { Image(systemName: symbol).font(.title3).foregroundStyle(.paceLime); Text(title).font(.caption.bold()) }
                .frame(maxWidth: .infinity).padding(.vertical, PaceSpacing.l).paceGlassCard(cornerRadius: PaceRadius.tile)
        }.buttonStyle(.plain)
    }
}
