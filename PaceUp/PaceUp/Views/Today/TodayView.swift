//
//  TodayView.swift
//  Pace Up
//

import SwiftUI
import SwiftData
import CoreLocation

struct TodayView: View {

    @Environment(HealthKitManager.self) private var health
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query(sort: \Activity.startDate, order: .reverse)
    private var activities: [Activity]

    @State private var showsMap = false

    @Query(sort: \Waymark.createdAt, order: .reverse)
    private var waymarks: [Waymark]

    private var todaysActivities: [Activity] {
        activities.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    /// The route shown in the "Today's movement" card: the most recent activity
    /// today that still has a trace.
    private var featuredRoute: [CLLocationCoordinate2D] {
        todaysActivities.first(where: { $0.hasRoute })?.thumbnailCoordinates ?? []
    }

    private var remainingSteps: Int {
        max(0, settings.dailyStepGoal - health.todaySteps)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PaceSpacing.l) {
                    // Memories first. Steps are still here, but they are the
                    // supporting cast: Pace Up is a walking journal, and the
                    // first thing it shows is what is waiting for you out there.
                    greeting
                    memoryLaneCard
                    capsuleStrip
                    compactStepCard
                    movementCard
                    if !todaysActivities.isEmpty {
                        todaysActivityList
                    }
                }
                .padding(.horizontal, PaceSpacing.l)
                .padding(.bottom, 100)
            }
            .background {
                ZStack(alignment: .top) {
                    Color.paceInk
                    FillImage(image: Image("WaymarkHero")).frame(height: 330).clipped().opacity(0.30)
                    LinearGradient(colors: [.clear, .paceInk.opacity(0.72), .paceInk], startPoint: .top, endPoint: .bottom).frame(height: 380)
                }.ignoresSafeArea()
            }
            .navigationDestination(isPresented: $showsMap) {
                TodaysMapView(activities: todaysActivities)
            }
            .refreshable {
                await health.refreshToday()
            }
            .task {
                await health.refreshAuthorizationState()
                if health.authorizationState == .authorized {
                    await health.refreshToday()
                }
            }
        }
    }

    // MARK: Pieces

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greetingText)
                .font(.title2.bold())
            Text(PaceFormat.longDate(.now))
                .font(.subheadline)
                .foregroundStyle(.paceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PaceSpacing.s)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12:  return String(localized: "Good morning")
        case 12..<18: return String(localized: "Good afternoon")
        default:      return String(localized: "Good evening")
        }
    }

    private var ringCard: some View {
        VStack(spacing: PaceSpacing.l) {
            ProgressRing(progress: goalProgress) {
                VStack(spacing: 0) {
                    Text(PaceFormat.steps(health.todaySteps))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("STEPS")
                        .font(.caption.weight(.semibold))
                        .tracking(2.5)
                        .foregroundStyle(.paceTextSecondary)
                    Text("\(Int(goalProgress * 100))% of \(PaceFormat.steps(settings.dailyStepGoal))")
                        .font(.caption2)
                        .foregroundStyle(.paceTextTertiary)
                        .padding(.top, 4)
                }
            }
            .frame(width: 210, height: 210)
            .padding(.top, PaceSpacing.s)

            HStack(spacing: 0) {
                MetricColumn(
                    value: PaceFormat.distanceValue(health.todayDistance, units: settings.units),
                    caption: settings.units.distanceAbbreviation
                )
                MetricColumn(
                    value: PaceFormat.energy(health.todayActiveEnergy),
                    caption: String(localized: "kcal")
                )
                MetricColumn(
                    value: PaceFormat.duration(TimeInterval(health.todayActiveMinutes * 60)),
                    caption: String(localized: "active")
                )
            }
        }
        .padding(.vertical, PaceSpacing.l)
        .frame(maxWidth: .infinity)
        .paceGlassCard()
        .overlay(alignment: .top) {
            if health.authorizationState != .authorized {
                healthPrompt
            }
        }
    }

    private var goalProgress: Double {
        guard settings.dailyStepGoal > 0 else { return 0 }
        return min(Double(health.todaySteps) / Double(settings.dailyStepGoal), 1)
    }

    // MARK: Memory lane

    private var memoryLaneCard: some View {
        NavigationLink {
            JournalScreen()
        } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let data = onThisDay?.photoData, let image = UIImage(data: data) {
                        FillImage(image: Image(uiImage: image))
                    } else {
                        FillImage(image: Image("MemoryLane"))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()

                LinearGradient(colors: [.clear, .paceInk.opacity(0.4), .paceInk.opacity(0.97)],
                               startPoint: .top, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 6) {
                    Label(memoryLaneEyebrow.uppercased(), systemImage: onThisDay != nil ? "sparkles" : "mappin.and.ellipse")
                        .font(.caption.bold())
                        .tracking(1.4)
                        .foregroundStyle(capsulesReady > 0 && onThisDay == nil ? .paceAmber : .paceLime)
                    Text(memoryLaneTitle)
                        .font(.title2.bold())
                        .multilineTextAlignment(.leading)
                    Text(memoryLaneSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.paceTextSecondary)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(waymarks.isEmpty ? "How it works" : "Open your journal")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.paceLime)
                    .padding(.top, 4)
                }
                .padding(PaceSpacing.l)
            }
            .clipShape(.rect(cornerRadius: PaceRadius.card))
            .overlay { RoundedRectangle(cornerRadius: PaceRadius.card).stroke(Color.white.opacity(0.1)) }
        }
        .buttonStyle(.plain)
    }

    /// Sealed capsules counting down, and any that are ready to be walked
    /// back to. Hidden when there are none.
    @ViewBuilder
    private var capsuleStrip: some View {
        let capsules = waymarks
            .filter { $0.isSealed() || $0.isWaitingToBeOpened() }
            .sorted { ($0.sealedUntil ?? .distantPast) < ($1.sealedUntil ?? .distantPast) }
        if !capsules.isEmpty {
            VStack(alignment: .leading, spacing: PaceSpacing.s) {
                SectionHeader(title: String(localized: "Time capsules"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PaceSpacing.s) {
                        ForEach(capsules.prefix(8)) { capsule in
                            NavigationLink {
                                WaymarkDetailView(waymark: capsule)
                            } label: {
                                capsuleTile(capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func capsuleTile(_ capsule: Waymark) -> some View {
        let ready = capsule.isWaitingToBeOpened()
        let days = capsule.sealedUntil.map {
            max(0, Calendar.current.dateComponents([.day], from: .now, to: $0).day ?? 0)
        } ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: ready ? "envelope.open.fill" : "lock.fill")
                .foregroundStyle(ready ? .paceAmber : .paceViolet)
            Text(ready ? String(localized: "Ready") : String(localized: "\(days) days"))
                .font(.title3.bold().monospacedDigit())
            Text(capsule.addressedTo.map { String(localized: "To \($0)") } ?? String(localized: "Time capsule"))
                .font(.caption)
                .foregroundStyle(.paceTextSecondary)
                .lineLimit(1)
        }
        .frame(width: 128, alignment: .leading)
        .padding(PaceSpacing.m)
        .background((ready ? Color.paceAmber : Color.paceViolet).opacity(0.10), in: .rect(cornerRadius: PaceRadius.tile))
        .overlay {
            RoundedRectangle(cornerRadius: PaceRadius.tile)
                .stroke((ready ? Color.paceAmber : Color.paceViolet).opacity(0.25))
        }
    }

    /// Steps, kept but demoted to a single compact row.
    private var compactStepCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: PaceSpacing.l) {
                ProgressRing(progress: goalProgress, lineWidth: 9) {
                    Text("\(Int(goalProgress * 100))%")
                        .font(.caption.bold().monospacedDigit())
                }
                .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 2) {
                    Text(PaceFormat.steps(health.todaySteps))
                        .font(.title2.bold().monospacedDigit())
                        .contentTransition(.numericText())
                    Text(remainingSteps > 0
                         ? String(localized: "steps · \(PaceFormat.steps(remainingSteps)) to go")
                         : String(localized: "steps · goal reached"))
                        .font(.caption)
                        .foregroundStyle(.paceTextSecondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(PaceFormat.distanceValue(health.todayDistance, units: settings.units)) \(settings.units.distanceAbbreviation)")
                    Text("\(PaceFormat.energy(health.todayActiveEnergy)) kcal")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.paceTextSecondary)
            }
            .padding(PaceSpacing.l)

            if health.authorizationState != .authorized {
                healthPrompt
            }
        }
        .paceGlassCard()
    }

    private var onThisDay: Waymark? {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day, .year], from: .now)
        return waymarks.first {
            let c = calendar.dateComponents([.month, .day, .year], from: $0.createdAt)
            return c.month == today.month && c.day == today.day && c.year != today.year && $0.isReadable()
        }
    }

    private var capsulesReady: Int { waymarks.filter { $0.isWaitingToBeOpened() }.count }

    private var memoryLaneEyebrow: String {
        if onThisDay != nil { return String(localized: "On this day") }
        if capsulesReady > 0 { return String(localized: "Capsules unlocked") }
        return String(localized: "Memory lane")
    }

    private var memoryLaneTitle: String {
        if let memory = onThisDay { return memory.title }
        if capsulesReady > 0 { return String(localized: "\(capsulesReady) capsule\(capsulesReady == 1 ? "" : "s") waiting for you") }
        if waymarks.isEmpty { return String(localized: "Leave a memory on today's walk") }
        return String(localized: "\(waymarks.count) memories out there")
    }

    private var memoryLaneSubtitle: String {
        if let memory = onThisDay {
            return String(localized: "You left this \(WaymarkFormat.ago(memory.createdAt)). Walk back and it will find you.")
        }
        if capsulesReady > 0 { return String(localized: "Their dates have come. Walk back to where you sealed them to open.") }
        if waymarks.isEmpty { return String(localized: "Pin a note, photo or voice memo to a place. It comes back when you do.") }
        return String(localized: "Take a route past one of them today.")
    }

    private var dailyInvitation: some View {
        EditorialImageCard(
            image: "TodayInvitation",
            eyebrow: "Your next move",
            title: remainingSteps > 0 ? "Make the day yours" : "You showed up today",
            subtitle: remainingSteps > 0
                ? "A short walk is enough to change the shape of your day."
                : "Enjoy the feeling—and move again only if it feels good."
        )
    }

    private var healthPrompt: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.text.square")
            Text("Connect Apple Health to see your steps")
                .font(.caption)
            Spacer(minLength: 0)
            Button(String(localized: "Connect")) {
                Task { await health.requestAuthorization() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.paceLime)
        }
        .padding(.horizontal, PaceSpacing.m)
        .padding(.vertical, 10)
        .background(Color.paceAmber.opacity(0.12), in: .rect(cornerRadius: 12))
        .padding(PaceSpacing.m)
    }

    @ViewBuilder
    private var goalNudge: some View {
        if health.authorizationState == .authorized {
            HStack(spacing: 10) {
                Image(systemName: remainingSteps > 0 ? "figure.walk" : "checkmark.seal.fill")
                    .foregroundStyle(.paceLime)
                Text(remainingSteps > 0
                     ? String(localized: "\(PaceFormat.steps(remainingSteps)) steps to your goal")
                     : String(localized: "Daily goal reached. Nice work."))
                    .font(.subheadline)
                Spacer()
            }
            .padding(PaceSpacing.l)
            .paceGlassCard(cornerRadius: PaceRadius.tile)
        }
    }

    private var movementCard: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.m) {
            HStack {
                Text("Today's movement")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if !featuredRoute.isEmpty {
                    Button {
                        showsMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.paceTextSecondary)
                }
            }

            if featuredRoute.count > 1 {
                RouteThumbnail(coordinates: featuredRoute, lineWidth: 3)
                    .frame(height: 120)
                    .contentShape(.rect)
                    .onTapGesture { showsMap = true }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.title3)
                            .foregroundStyle(.paceTextTertiary)
                        Text("No route recorded today")
                            .font(.caption)
                            .foregroundStyle(.paceTextTertiary)
                    }
                    Spacer()
                }
                .frame(height: 120)
            }
        }
        .padding(PaceSpacing.l)
        .paceGlassCard()
    }

    private var todaysActivityList: some View {
        VStack(alignment: .leading, spacing: PaceSpacing.s) {
            SectionHeader(title: String(localized: "Today's activities"))
            ForEach(todaysActivities) { activity in
                NavigationLink {
                    ActivityDetailView(activity: activity)
                } label: {
                    ActivityRow(activity: activity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var motivationCard: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let quote = motivationQuotes[Int(context.date.timeIntervalSince1970 / 10) % motivationQuotes.count]
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [Color.paceOrange.opacity(0.32), Color.paceViolet.opacity(0.20), Color.paceSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.paceAmber.opacity(0.18))
                    .frame(width: 150, height: 150)
                    .blur(radius: 35)
                    .offset(x: 45, y: -55)

                Text("“")
                    .font(.system(size: 100, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.08))
                    .offset(x: -10, y: -22)

                VStack(alignment: .leading, spacing: PaceSpacing.m) {
                    HStack {
                        Label("A little momentum", systemImage: "sparkles")
                            .font(.caption.bold())
                            .foregroundStyle(.paceAmber)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(motivationQuotes.indices, id: \.self) { index in
                                Capsule()
                                    .fill(index == motivationQuotes.firstIndex(of: quote) ? Color.paceAmber : Color.white.opacity(0.22))
                                    .frame(width: index == motivationQuotes.firstIndex(of: quote) ? 14 : 4, height: 4)
                            }
                        }
                    }
                    Text(quote)
                        .font(.title3.weight(.semibold))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("NEW THOUGHT EVERY 10 SECONDS")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.42))
                }
                .padding(PaceSpacing.l)
            }
            .id(quote)
            .transition(.opacity)
            .clipShape(.rect(cornerRadius: PaceRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: PaceRadius.card)
                    .stroke(Color.paceAmber.opacity(0.20))
            }
        }
        .accessibilityLabel("Motivation: \(motivationQuotes[0])")
    }

    private var motivationQuotes: [String] {
        [
            String(localized: "You do not need a perfect day—just one honest step forward."),
            String(localized: "Move gently enough to return tomorrow."),
            String(localized: "Consistency makes ordinary days powerful."),
            String(localized: "Your pace is valid. Keep it yours."),
            String(localized: "Ten quiet minutes can change the shape of a day.")
        ]
    }
}

#Preview {
    TodayView()
        .environment(AppSettings.shared)
        .environment(HealthKitManager.shared)
        .modelContainer(PaceUpStore.makePreviewContainer())
        .preferredColorScheme(.dark)
}
