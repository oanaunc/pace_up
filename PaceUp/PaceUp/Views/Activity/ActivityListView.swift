//
//  ActivityListView.swift
//  Pace Up
//

import SwiftUI
import SwiftData

struct ActivityListView: View {

    enum Filter: String, CaseIterable, Identifiable {
        case all, runs, walks, hikes
        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:   return String(localized: "All")
            case .runs:  return String(localized: "Runs")
            case .walks: return String(localized: "Walks")
            case .hikes: return String(localized: "Hikes")
            }
        }

        var type: ActivityType? {
            switch self {
            case .all:   return nil
            case .runs:  return .run
            case .walks: return .walk
            case .hikes: return .hike
            }
        }
    }

    @Query(sort: \Activity.startDate, order: .reverse)
    private var activities: [Activity]

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var showsMap = false

    private var filtered: [Activity] {
        activities.filter { activity in
            let matchesType = filter.type == nil || activity.type == filter.type
            let matchesSearch = searchText.isEmpty
                || activity.title.localizedCaseInsensitiveContains(searchText)
                || (activity.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesType && matchesSearch
        }
    }

    private var grouped: [(key: Date, values: [Activity])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.startDate) }
        return groups.sorted { $0.key > $1.key }.map { (key: $0.key, values: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    EmptyStateView(
                        symbolName: "figure.run",
                        title: String(localized: "No activities yet"),
                        message: String(localized: "Your recorded walks, runs and hikes will appear here.")
                    )
                } else if filtered.isEmpty {
                    EmptyStateView(
                        symbolName: "line.3.horizontal.decrease.circle",
                        title: String(localized: "Nothing matches"),
                        message: String(localized: "Try a different filter or search term.")
                    )
                } else {
                    list
                }
            }
            .background(Color.paceInk.ignoresSafeArea())
            .navigationTitle(String(localized: "Activity"))
            .searchable(text: $searchText, prompt: String(localized: "Search activities"))
            .safeAreaInset(edge: .top) {
                PillPicker(options: Filter.allCases, title: \.title, selection: $filter)
                    .padding(.horizontal, PaceSpacing.l)
                    .padding(.bottom, PaceSpacing.s)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsMap = true
                    } label: {
                        Image(systemName: "map")
                    }
                    .accessibilityLabel(String(localized: "Activity map"))
                }
            }
            .navigationDestination(isPresented: $showsMap) {
                ActivityMapView(activities: filtered)
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PaceSpacing.l, pinnedViews: [.sectionHeaders]) {
                ForEach(grouped, id: \.key) { group in
                    Section {
                        VStack(spacing: PaceSpacing.s) {
                            ForEach(group.values) { activity in
                                NavigationLink {
                                    ActivityDetailView(activity: activity)
                                } label: {
                                    ActivityRow(activity: activity)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        ActivityStore(context: context).delete(activity)
                                    } label: {
                                        Label(String(localized: "Delete"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(PaceFormat.relativeDay(group.key))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.paceTextSecondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, PaceSpacing.m)
                            .background(.ultraThinMaterial, in: .capsule)
                    }
                }
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, 100)
        }
    }
}

#Preview {
    ActivityListView()
        .environment(AppSettings.shared)
        .modelContainer(PaceUpStore.makePreviewContainer())
        .preferredColorScheme(.dark)
}
