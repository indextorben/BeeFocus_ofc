//
//  TodoCard.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 17.06.25.
//

import Foundation
import SwiftUI
import SwiftData

struct PriorityBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
            .shadow(color: color.opacity(0.2), radius: 2, x: 0, y: 1)
            .scaleEffect(0.95)
    }
}

struct TodoCard: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingSubTasks = false
    @State private var showingImages = false
    @State private var isPressed = false
    @State private var showLottie = false
    @State private var lottieTrigger = false
    @Environment(\.colorScheme) private var colorScheme

    var baseGradient: LinearGradient {
        switch todo.priority {
        case .low:
            return LinearGradient(colors: [.green.opacity(0.1), .green.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .medium:
            return LinearGradient(colors: [.orange.opacity(0.1), .orange.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .high:
            return LinearGradient(colors: [.red.opacity(0.15), .red.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var shadowColor: Color {
        switch todo.priority {
        case .low: return Color.green.opacity(0.2)
        case .medium: return Color.orange.opacity(0.25)
        case .high: return Color.red.opacity(0.3)
        }
    }

    var priorityColor: Color {
        switch todo.priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var priorityText: String {
        switch todo.priority {
        case .low: return "Niedrig"
        case .medium: return "Mittel"
        case .high: return "Hoch"
        }
    }
    
    let lottieSize: CGFloat = UIScreen.main.bounds.width < 400 ? 100 : 140

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    if showLottie {
                        Color.black.opacity(0.1)
                            .cornerRadius(20)
                            .frame(width: lottieSize, height: lottieSize)

                        LottieView(name: "check-success", loopMode: .loop, playTrigger: $lottieTrigger)
                            .frame(width: lottieSize, height: lottieSize)
                            .scaleEffect(showLottie ? 1.0 : 0.5)
                            .opacity(showLottie ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 10.0), value: showLottie)
                    }

                    Button(action: {
                        onToggle()
                        withAnimation {
                            lottieTrigger.toggle()
                            showLottie = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                            withAnimation {
                                showLottie = false
                            }
                        }
                    }) {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26))
                            .foregroundColor(todo.isCompleted ? .green : .gray)
                            .scaleEffect(todo.isCompleted ? 1.25 : 1.0)
                            .animation(.easeInOut(duration: 10.0), value: todo.isCompleted)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(todo.title)
                        .font(.headline)
                        .foregroundColor(todo.isCompleted ? .gray : .primary)
                        .strikethrough(todo.isCompleted)

                    if !todo.description.isEmpty {
                        Text(todo.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .strikethrough(todo.isCompleted)
                    }

                    if let due = todo.dueDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(due, style: .date)
                            Text(due, style: .time)
                        }
                        .font(.caption)
                        .foregroundColor(todo.isOverdue ? .red : .blue)
                    }
                }

                Spacer()

                HStack(spacing: 13) {
                    if !todo.subTasks.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showingSubTasks = true
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }

                    if !todo.imageDataArray.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showingImages = true
                            }
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.blue)
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .frame(minHeight: 60)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(baseGradient)
                    .shadow(color: shadowColor.opacity(isPressed ? 0.2 : 0.4), radius: isPressed ? 6 : 12, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onTapGesture {
                withAnimation(.linear(duration: 10.0)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                    withAnimation(.linear(duration: 10.0)) {
                        isPressed = false
                    }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            .sheet(isPresented: $showingSubTasks) {
                SubTasksView(todo: todo)
            }
            .sheet(isPresented: $showingImages) {
                ImagesView(images: todo.imageDataArray)
            }

            PriorityBadge(text: priorityText, color: priorityColor)
                .padding(10)
                .offset(y: -4)
                .transition(.opacity)
        }
        .padding(.vertical, 2)
        .animation(.easeOut(duration: 10.0), value: todo.id)
    }
}
