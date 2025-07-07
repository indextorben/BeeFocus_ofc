//
//  Event.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 06.07.25.
//

import Foundation
import EventKit

class EventManager {
    static let shared = EventManager()
    let eventStore = EKEventStore()
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func createEvent(for todo: TodoItem) {
        guard let dueDate = todo.dueDate else { return }
        let event = EKEvent(eventStore: eventStore)
        event.title = todo.title
        event.notes = todo.description
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(3600) // 1h default Dauer
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("❌ Fehler beim Speichern des Events: \(error)")
        }
    }
    
    func deleteEvents(matching todo: TodoItem) {
        guard let dueDate = todo.dueDate else { return }
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return }
        
        let oneDay: TimeInterval = 86400
        let predicate = eventStore.predicateForEvents(
            withStart: dueDate.addingTimeInterval(-oneDay),
            end: dueDate.addingTimeInterval(oneDay),
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate).filter { $0.title == todo.title }
        
        for event in events {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch {
                print("❌ Fehler beim Löschen des Events: \(error)")
            }
        }
    }
}
