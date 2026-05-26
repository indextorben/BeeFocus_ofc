//
//  ContentView.swift
//  BeeFocusWatch
//
//  Created by Torben Lehneke on 25.05.26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var session = WatchSessionManager.shared
    @State private var completedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                summarySection
                tasksSection
                focusSection
            }
            .navigationTitle("BeeFocus")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { session.loadSnapshot() }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(session.snapshot.dueTodayCount)")
                        .font(.title2.bold())
                    Text("heute fällig")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if session.snapshot.overdueCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(session.snapshot.overdueCount)")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                        Text("überfällig")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(session.snapshot.completedTodayCount)")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                        Text("erledigt")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Tasks

    private var tasksSection: some View {
        Section("Aufgaben") {
            if session.snapshot.topTasks.isEmpty {
                Label("Alles erledigt 🎉", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
            } else {
                ForEach(session.snapshot.topTasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    private func taskRow(_ task: WatchTask) -> some View {
        let done = completedIDs.contains(task.id)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                completedIDs.insert(task.id)
            }
            session.completeTask(id: task.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(done ? .green : (task.isHighPriority ? .orange : .secondary))
                Text(task.title)
                    .font(.footnote)
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? .secondary : .primary)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .disabled(done)
    }

    // MARK: - Focus

    @ViewBuilder
    private var focusSection: some View {
        if session.snapshot.focusMinutesToday > 0 {
            Section {
                Label(focusLabel, systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var focusLabel: String {
        let m = session.snapshot.focusMinutesToday
        if m >= 60 {
            let h = m / 60; let rem = m % 60
            return rem > 0 ? "\(h)h \(rem)min Fokus" : "\(h)h Fokus heute"
        }
        return "\(m)min Fokus heute"
    }
}

#Preview {
    ContentView()
}
