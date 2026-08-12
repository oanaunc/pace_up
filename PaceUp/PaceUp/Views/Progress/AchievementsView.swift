//
//  AchievementsView.swift
//  Pace Up
//

import SwiftUI
import SwiftData

struct AchievementsView: View {

    @Environment(\.modelContext) private var context

    @Query private var unlocks: [AchievementUnlock]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var unlockedDates: [AchievementKind: Date] {
        unlocks.reduce(into: [:]) { result, unlock in
            if let kind = unlock.kind { result[kind] = unlock.unlockedAt }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PaceSpacing.l) {
                Text("\(unlockedDates.count) of \(AchievementKind.allCases.count) unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.paceTextSecondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AchievementKind.allCases) { kind in
                        AchievementBadge(
                            kind: kind,
                            unlockedAt: unlockedDates[kind]
                        )
                    }
                }
            }
            .padding(.horizontal, PaceSpacing.l)
            .padding(.bottom, 100)
        }
        .background(Color.paceInk.ignoresSafeArea())
        .navigationTitle(String(localized: "Achievements"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementBadge: View {
    var kind: AchievementKind
    var unlockedAt: Date?

    private var isUnlocked: Bool { unlockedAt != nil }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? kind.tint.opacity(0.18) : Color.white.opacity(0.05))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Circle()
                            .strokeBorder(isUnlocked ? kind.tint : Color.paceHairline, lineWidth: 1.5)
                    }
                Image(systemName: isUnlocked ? kind.symbolName : "lock.fill")
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? kind.tint : Color.paceTextTertiary)
            }

            Text(kind.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isUnlocked ? Color.paceTextPrimary : Color.paceTextTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(kind.detail)
                .font(.system(size: 9))
                .foregroundStyle(.paceTextTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(.vertical, PaceSpacing.m)
        .paceGlassCard(cornerRadius: PaceRadius.tile)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title), \(isUnlocked ? String(localized: "unlocked") : String(localized: "locked")). \(kind.detail)")
    }
}
