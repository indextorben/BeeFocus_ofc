import SwiftUI

struct TagesMotivationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var appeared = false
    @State private var nextQuote = false
    @ObservedObject private var localizer = LocalizationManager.shared

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 1.0, green: 0.5, blue: 0.8) : appThemaFarben(aktivesThema).0
    }

    private static let quotes: [(text: String, author: String)] = [
        ("The only way to do great work is to love what you do.", "Steve Jobs"),
        ("You must be the change you wish to see in the world.", "Mahatma Gandhi"),
        ("Success is the sum of small efforts repeated day after day.", "Robert Collier"),
        ("Believe in yourself and all that you are. Know that there is something inside you that is greater than any obstacle.", "Christian D. Larson"),
        ("The best time to plant a tree was 20 years ago. The second best time is now.", "Chinese Proverb"),
        ("Your attitude determines your direction.", "Unknown"),
        ("Perfection is not attainable. But if we chase perfection, we can catch excellence.", "Vince Lombardi"),
        ("Every expert was once a beginner.", "Helen Hayes"),
        ("The secret of getting ahead is getting started.", "Mark Twain"),
        ("You are more capable than you believe, stronger than you think, and smarter than you imagine.", "Unknown"),
        ("Dream big, start small, act now.", "Robin Sharma"),
        ("Discipline is the bridge between goals and accomplishment.", "Jim Rohn"),
        ("The only difference between a good day and a bad day is your attitude.", "Dennis S. Brown"),
        ("Success has three letters: D-O-I-T.", "Johann Wolfgang von Goethe"),
        ("It is not because things are difficult that we do not dare. It is because we do not dare that they are difficult.", "Seneca"),
        ("What lies behind us and what lies before us are tiny matters compared to what lies within us.", "Ralph Waldo Emerson"),
        ("Whether you think you can or think you can't, you're right.", "Henry Ford"),
        ("Life is 10% what happens to you and 90% how you react to it.", "Charles R. Swindoll"),
        ("A small positive action is better than a thousand positive thoughts.", "Unknown"),
        ("Every day is a new chance to become who you want to be.", "Unknown"),
        ("The difference between ordinary and extraordinary is that little extra.", "Jimmy Johnson"),
        ("Start where you are. Use what you have. Do what you can.", "Arthur Ashe"),
        ("Keep your goals big and your steps small.", "Unknown"),
        ("Energy and persistence conquer all things.", "Benjamin Franklin"),
        ("When you stop getting better, you stop being good.", "Philip Rosenthal"),
        ("The only way to fail is to never try. That is not an option.", "Elon Musk"),
        ("Do not worry about your weaknesses, develop your strengths.", "Unknown"),
        ("The goal is not always to reach it, but to strive toward it.", "Audrey Hepburn"),
        ("Giving up is not an option.", "Michael Schumacher"),
        ("Get up when you fall. Keep going when you are tired.", "Unknown"),
        ("With patience and perseverance you accomplish more than with haste and force.", "Jean de La Fontaine"),
        ("Do something every day that brings you one step closer to your dream.", "Unknown"),
        ("Those who fight can lose. Those who don't fight have already lost.", "Bertolt Brecht"),
        ("Do it with passion or not at all.", "Unknown"),
        ("Today is the day you begin.", "Unknown"),
        ("The path to perfection runs through consistency.", "Unknown"),
        ("Small daily improvements lead to big results.", "Robin Sharma"),
        ("Trust the process. Trust the work.", "Unknown"),
        ("Discipline means doing what needs to be done, even when you don't feel like it.", "Unknown"),
        ("You only have this one chance. Use it.", "Unknown"),
        ("Glory belongs to those who never give up.", "Winston Churchill"),
        ("Greatness comes from consistent action, not words.", "Unknown"),
        ("Decisions made today shape your tomorrow.", "Unknown"),
        ("Motivation gets you started. Habit keeps you going.", "Jim Ryun"),
        ("He who has a clear why can endure almost any how.", "Friedrich Nietzsche"),
        ("Be the best version of yourself.", "Unknown"),
        ("Every morning is a fresh start.", "Unknown"),
        ("Strength does not come from what you accomplish, but from what you overcome.", "Rikki Rogers"),
        ("You are closer to the goal than you were yesterday.", "Unknown"),
        ("Do today what others won't, and live tomorrow the way others can't.", "Jerry Rice"),
        ("Progress, not perfection.", "Unknown"),
        ("Do good and don't forget it.", "Unknown"),
        ("It is never too late to become what you might have been.", "George Eliot"),
        ("The courage to begin is everything.", "Unknown"),
        ("Coming together is a beginning. Keeping together is progress. Working together is success.", "Henry Ford"),
        ("The future belongs to those who believe in the beauty of their dreams.", "Eleanor Roosevelt"),
        ("Design your life or someone else will do it for you.", "John Lennon"),
        ("Keep your eyes on the goal, not the obstacles.", "Unknown"),
        ("Where there is a will, there is a way.", "German Proverb"),
        ("Mistakes are proof that you are trying.", "Unknown"),
        ("Stop imagining what could happen and start shaping your life.", "Unknown"),
        ("One step at a time will get you there.", "Unknown"),
        ("You are stronger than you think.", "Unknown"),
    ]

    private var todayQuote: (text: String, author: String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return Self.quotes[(day - 1) % Self.quotes.count]
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16).padding(.trailing, 20)
                }

                Spacer()

                VStack(spacing: 32) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.15))
                            .frame(width: 90, height: 90)
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(accent)
                    }
                    .scaleEffect(appeared ? 1.0 : 0.6)
                    .opacity(appeared ? 1.0 : 0)

                    // Quote card
                    VStack(spacing: 20) {
                        Text(localizer.localizedString(forKey: "motivation_quote_of_day"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.5)
                            .textCase(.uppercase)

                        VStack(spacing: 16) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 28))
                                .foregroundStyle(accent.opacity(0.5))

                            Text(todayQuote.text)
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 8)

                            Text("— \(todayQuote.author)")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                                .italic()
                        }
                        .padding(28)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.2), lineWidth: 1.5))
                    }
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 30)

                    // Date chip
                    Text(Date().formatted(date: .complete, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(appeared ? 1.0 : 0)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Share button
                Button {
                    let shareText = "\"\(todayQuote.text)\"\n— \(todayQuote.author)"
                    let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let vc = scene.windows.first?.rootViewController {
                        vc.present(av, animated: true)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(localizer.localizedString(forKey: "motivation_share_button"))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.4), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appeared ? 1.0 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}
