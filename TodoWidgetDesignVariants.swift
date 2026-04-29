//
//  TodoWidgetDesignVariants.swift
//  BeeFocus_ofc
//
//  Alternative Design-Varianten für Widgets
//  Created on 15.04.26.
//

import SwiftUI
import WidgetKit

// MARK: - Design-Variante 1: Minimalistisch (Schwarz-Weiß)

struct TodoWidgetMinimalistView: View {
    let entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        ZStack {
            Color.white
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                    Text("Aufgaben")
                        .font(.headline)
                        .foregroundColor(.black)
                    Spacer()
                }
                
                Divider()
                    .background(Color.black)
                
                // Stats
                HStack(spacing: 16) {
                    VStack {
                        Text("\(entry.dueTodayCount)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                        Text("Heute")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if widgetFamily != .systemSmall {
                        VStack {
                            Text("\(entry.overdueCount)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(entry.overdueCount > 0 ? .red : .black)
                            Text("Überfällig")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Design-Variante 2: Glassmorphismus

struct TodoWidgetGlassView: View {
    let entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        ZStack {
            // Hintergrund-Gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glaseffekt
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Aufgaben")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Spacer()
                
                // Große Zahl mit Glow
                Text("\(entry.dueTodayCount)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                
                Text("fällig heute")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Design-Variante 3: Bunt & Verspielt

struct TodoWidgetColorfulView: View {
    let entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        ZStack {
            // Mehrfarbiger Gradient
            LinearGradient(
                colors: [
                    Color.pink,
                    Color.orange,
                    Color.yellow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // Emoji-Header
                Text("✨")
                    .font(.system(size: 32))
                
                Text("\(entry.dueTodayCount)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text(entry.dueTodayCount == 1 ? "Aufgabe" : "Aufgaben")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                if entry.overdueCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("\(entry.overdueCount) überfällig")
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.6))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

// MARK: - Design-Variante 4: Dark Mode / Neon

struct TodoWidgetNeonView: View {
    let entry: TodoWidgetEntry
    
    var body: some View {
        ZStack {
            // Dunkler Hintergrund
            Color.black
            
            VStack(spacing: 16) {
                // Neon-Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                    .frame(maxWidth: .infinity)
                    .overlay(
                        VStack(spacing: 8) {
                            Text("AUFGABEN")
                                .font(.caption.bold())
                                .foregroundColor(.cyan)
                                .tracking(2)
                            
                            Text("\(entry.dueTodayCount)")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan, radius: 10)
                                .shadow(color: .cyan, radius: 20)
                            
                            Text("HEUTE")
                                .font(.caption2.bold())
                                .foregroundColor(.cyan.opacity(0.8))
                                .tracking(1)
                        }
                        .padding()
                    )
            }
            .padding()
        }
    }
}

// MARK: - Design-Variante 5: Produktivitäts-Fortschrittsbalken

struct TodoWidgetProgressView: View {
    let entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var progressPercentage: Double {
        let total = Double(entry.totalOpenCount + 5) // Annahme: 5 heute erledigt
        return total > 0 ? (5.0 / total) : 0
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.white)
                    Text("Produktivität")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Fortschrittsring oder Balken
                VStack(spacing: 8) {
                    // Heute-Aufgaben
                    HStack {
                        Text("Heute")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(entry.dueTodayCount)")
                            .font(.title.bold())
                            .foregroundColor(.white)
                    }
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * progressPercentage, height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                    
                    if widgetFamily != .systemSmall {
                        // Überfällig
                        HStack {
                            Text("Überfällig")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("\(entry.overdueCount)")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Design-Variante 6: iOS-Stil (System-Look)

struct TodoWidgetSystemStyleView: View {
    let entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        VStack(spacing: 0) {
            // Header wie iOS Settings
            HStack {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
                
                Text("Aufgaben")
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            Divider()
            
            // Content
            VStack(spacing: 12) {
                HStack {
                    Label {
                        Text("Heute fällig")
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Text("\(entry.dueTodayCount)")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                }
                
                if widgetFamily != .systemSmall {
                    Divider()
                    
                    HStack {
                        Label {
                            Text("Überfällig")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                        }
                        Spacer()
                        Text("\(entry.overdueCount)")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            
            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Preview für alle Varianten

#if DEBUG

// Minimalistisch
#Preview("Minimalistisch", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 5, overdueCount: 2, totalOpenCount: 15)
}

// Glas
#Preview("Glassmorphismus", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 3, overdueCount: 1, totalOpenCount: 10)
}

// Bunt
#Preview("Bunt & Verspielt", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 7, overdueCount: 3, totalOpenCount: 20)
}

// Neon
#Preview("Neon Dark", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 4, overdueCount: 0, totalOpenCount: 12)
}

// Progress
#Preview("Fortschritt", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 6, overdueCount: 1, totalOpenCount: 18)
}

// System Style
#Preview("iOS System", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 3, overdueCount: 2, totalOpenCount: 11)
}

#endif

// MARK: - Verwendung

/*
 
 Um eine dieser Design-Varianten zu verwenden:
 
 1. Kopieren Sie den gewünschten View-Code (z.B. TodoWidgetNeonView)
 
 2. Ersetzen Sie in TodoWidget.swift die entsprechende View:
 
    Zum Beispiel für Small Widget:
    
    struct TodoWidgetSmallView: View {
        let entry: TodoWidgetEntry
        
        var body: some View {
            TodoWidgetNeonView(entry: entry) // ← Neue Design-Variante
        }
    }
 
 3. Oder erstellen Sie mehrere Widgets mit verschiedenen Designs:
 
    @main
    struct TodoWidgetBundle: WidgetBundle {
        var body: some Widget {
            TodoWidget()              // Standard
            TodoWidgetNeon()          // Neon-Variante
            TodoWidgetMinimalist()    // Minimal-Variante
        }
    }
 
 */
