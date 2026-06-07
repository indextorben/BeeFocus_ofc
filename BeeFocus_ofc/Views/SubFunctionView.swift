//
//  SubFunctionView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//
import SwiftUI

struct SubFunctionView: View {
    let data: SubFunctionData

    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerCard
                    if let bullets = data.bulletPoints, !bullets.isEmpty {
                        bulletsCard(bullets)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(data.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [themeC1.opacity(isDark ? 0.28 : 0.16), themeC2.opacity(isDark ? 0.12 : 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 72, height: 72)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [themeC1, themeC2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            Text(data.text)
                .font(.subheadline)
                .foregroundStyle(isDark ? .white.opacity(0.65) : .secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.35).delay(0.15), value: appeared)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .themeGlass(cornerRadius: 22)
    }

    // MARK: - Bullets Card

    private func bulletsCard(_ bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeC1)
                Text(String(localized: "summary_title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.55) : .secondary)
            }
            .padding(.leading, 2)

            VStack(spacing: 10) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(themeC1.opacity(isDark ? 0.22 : 0.12))
                                .frame(width: 30, height: 30)
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(themeC1)
                        }

                        Text(point)
                            .font(.system(size: 14))
                            .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .themeGlass(cornerRadius: 14)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -20)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.2 + Double(index) * 0.08), value: appeared)
                }
            }
        }
    }
}
