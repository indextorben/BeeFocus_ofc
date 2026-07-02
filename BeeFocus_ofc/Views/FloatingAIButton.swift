import SwiftUI

struct FloatingAIButton: View {

    // MARK: - State

    @AppStorage("floatingAIY")           private var savedY: Double = 0
    @AppStorage("floatingAIOnRight")     private var onRight: Bool = true
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("floatingAIEnabled")     private var isEnabled: Bool = true

    @State private var posY: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var isDragging = false
    @State private var showKI = false
    @State private var showQuickAdd = false
    @State private var isPressing = false

    @EnvironmentObject var todoStore: TodoStore

    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    private let buttonSize: CGFloat = 52
    private let edgePadding: CGFloat = 12

    // MARK: - Body

    var body: some View {
        guard isEnabled else { return AnyView(EmptyView()) }
        return AnyView(
            GeometryReader { geo in
                let screen = geo.size
                let liveY = (posY + dragOffsetY)
                    .clamped(to: (buttonSize / 2 + 60)...(screen.height - buttonSize / 2 - 34))
                let posX: CGFloat = onRight
                    ? screen.width - buttonSize / 2 - edgePadding
                    : buttonSize / 2 + edgePadding

                mainButton
                    .position(x: posX, y: liveY)
                    .gesture(dragGesture(screen: screen))
                    .shadow(color: .black.opacity(isPressing ? 0.1 : 0.25), radius: isPressing ? 4 : 8, y: isPressing ? 2 : 4)
                    .scaleEffect(isPressing ? 0.92 : 1.0)
                    .animation(isDragging ? .none : .spring(response: 0.4, dampingFraction: 0.75), value: liveY)
                    .animation(.easeInOut(duration: 0.15), value: isPressing)
                    .onAppear {
                        posY = savedY == 0 ? screen.height - 120 : savedY
                    }
            }
            .ignoresSafeArea()
            .sheet(isPresented: $showKI) {
                KITagesplanSheet(
                    todos: todoStore.todos,
                    selectedDate: Date(),
                    themeC1: themeC1,
                    themeC2: themeC2
                )
                .environmentObject(todoStore)
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(themeC1: themeC1, themeC2: themeC2)
                    .environmentObject(todoStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        )
    }

    // MARK: - Main button

    private var mainButton: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [themeC1, themeC2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: buttonSize, height: buttonSize)

            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
        .contentShape(Circle())
        .onTapGesture {
            guard !isDragging else { return }
            showKI = true
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            guard !isDragging else { return }
            isPressing = pressing
        }, perform: {
            guard !isDragging else { return }
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            showQuickAdd = true
        })
    }

    // MARK: - Drag gesture

    private func dragGesture(screen: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                isDragging = true
                isPressing = false
                dragOffsetY = value.translation.height
                let liveX = value.startLocation.x + value.translation.width
                onRight = liveX > screen.width / 2
            }
            .onEnded { value in
                let half = buttonSize / 2
                let newY = (posY + value.translation.height)
                    .clamped(to: (half + 60)...(screen.height - half - 34))
                let liveX = value.startLocation.x + value.translation.width
                onRight = liveX > screen.width / 2

                posY = newY
                dragOffsetY = 0
                savedY = newY

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isDragging = false
                }
            }
    }
}

// MARK: - Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
