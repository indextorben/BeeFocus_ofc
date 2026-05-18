//
//  CalendarPickerView.swift
//  BeeFocus_ofc
//
//  Created by Assistant on 15.04.26.
//

import SwiftUI
import EventKit

struct CalendarPickerView: View {
    @ObservedObject private var localizer = LocalizationManager.shared
    @Binding var selectedCalendar: EKCalendar?
    @State private var availableCalendars: [EKCalendar] = []
    @State private var isLoading = true
    
    private let eventStore = EKEventStore()
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if availableCalendars.isEmpty {
                Text(localizer.localizedString(forKey: "no_calendars_available"))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Picker(localizer.localizedString(forKey: "select_calendar"), selection: $selectedCalendar) {
                    // Option für Standard-Kalender
                    Text(localizer.localizedString(forKey: "default_calendar"))
                        .tag(nil as EKCalendar?)
                    
                    // Alle verfügbaren Kalender
                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 12, height: 12)
                            Text(calendar.title)
                        }
                        .tag(calendar as EKCalendar?)
                    }
                }
            }
        }
        .onAppear {
            loadCalendars()
        }
    }
    
    private func loadCalendars() {
        eventStore.requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    // Nur Kalender laden, die beschreibbar sind
                    availableCalendars = eventStore.calendars(for: .event)
                        .filter { $0.allowsContentModifications }
                        .sorted { $0.title < $1.title }
                } else {
                    availableCalendars = []
                }
                isLoading = false
            }
        }
    }
}

// MARK: - EKCalendar Extension für Equatable/Hashable
extension EKCalendar {
    static func == (lhs: EKCalendar, rhs: EKCalendar) -> Bool {
        lhs.calendarIdentifier == rhs.calendarIdentifier
    }
}
