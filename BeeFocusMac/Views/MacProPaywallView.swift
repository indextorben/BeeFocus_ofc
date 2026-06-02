import SwiftUI
import StoreKit

struct MacProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sub: MacSubscriptionManager
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var selectedID: String = MacSubscriptionManager.yearlyID

    private var accent:  Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.3,  green: 0.6,  blue: 1.0) : appThemaFarben(aktivesThema).1 }

    private var hasTrial: Bool {
        guard selectedID != MacSubscriptionManager.lifetimeID,
              let product = sub.products.first(where: { $0.id == selectedID })
        else { return false }
        return product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private var buttonLabel: String {
        switch selectedID {
        case MacSubscriptionManager.lifetimeID: return "Lifetime kaufen"
        case MacSubscriptionManager.yearlyID:   return hasTrial ? "7 Tage gratis starten" : "Jährlich abonnieren"
        default:                                 return hasTrial ? "7 Tage gratis starten" : "Monatlich abonnieren"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.13),
                         Color(red: 0.10, green: 0.06, blue: 0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [accent, accent2],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                    .shadow(color: accent.opacity(0.5), radius: 10)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BeeFocus Pro")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Hol das Beste aus deiner Produktivität heraus")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)

                Divider().background(.white.opacity(0.08))

                // Two-column body
                HStack(alignment: .top, spacing: 0) {
                    // Left: Features
                    featuresColumn
                        .frame(maxWidth: .infinity)
                        .padding(24)

                    Divider().background(.white.opacity(0.08))

                    // Right: Plans + CTA
                    plansColumn
                        .frame(width: 300)
                        .padding(24)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 480)
        .task { await sub.loadProducts() }
    }

    // MARK: - Features

    private var featuresColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Was du bekommst")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.bottom, 4)

            featureRow(icon: "infinity",        color: accent,   text: "Unbegrenzte Kategorien & Aufgaben")
            featureRow(icon: "storefront.fill", color: .orange,  text: "Alle Focus-Store Items freigeschaltet")
            featureRow(icon: "sparkles",        color: .purple,  text: "KI-Assistent, Focus Coach & Wochenrückblick")
            featureRow(icon: "mic.fill",        color: .teal,    text: "Spracheingabe & KI-Sprachausgabe")
            featureRow(icon: "chart.bar.fill",  color: .indigo,  text: "Erweiterte Statistiken & Heatmap")
            featureRow(icon: "medal.fill",      color: Color(red: 0.6, green: 0.3, blue: 0.9),
                                                                 text: "Abzeichen & Achievement-System")
            featureRow(icon: "timer",           color: .cyan,    text: "Alle Timer-Modi & Premium-Themes")
            featureRow(icon: "desktopcomputer", color: accent2,  text: "Mac-App vollständig freigeschaltet")
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
        }
        .padding(.vertical, 5)
    }

    // MARK: - Plans

    private var plansColumn: some View {
        VStack(spacing: 10) {
            if hasTrial {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("7 Tage kostenlos testen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.35), lineWidth: 1))
                )
            }

            // Plan cards
            if sub.products.isEmpty {
                planCard(id: MacSubscriptionManager.monthlyID,  title: "Monatlich", price: "2,99 €",  period: "/ Monat",  badge: nil,               savings: nil)
                planCard(id: MacSubscriptionManager.yearlyID,   title: "Jährlich",  price: "17,99 €", period: "/ Jahr",   badge: "Beliebteste Wahl", savings: "~50% sparen")
                planCard(id: MacSubscriptionManager.lifetimeID, title: "Lifetime",  price: "29,99 €", period: "einmalig", badge: nil,               savings: nil)
            } else {
                if let m = sub.monthly {
                    planCard(id: m.id, title: "Monatlich", price: m.displayPrice, period: "/ Monat", badge: nil, savings: nil)
                }
                if let y = sub.yearly {
                    planCard(id: y.id, title: "Jährlich", price: y.displayPrice, period: "/ Jahr",
                             badge: "Beliebteste Wahl",
                             savings: sub.yearlySavingsPercent().map { "\($0)% sparen" })
                }
                if let l = sub.lifetime {
                    planCard(id: l.id, title: "Lifetime", price: l.displayPrice, period: "einmalig", badge: nil, savings: nil)
                }
            }

            Spacer()

            // CTA
            Button {
                Task {
                    guard let product = sub.products.first(where: { $0.id == selectedID }) else { return }
                    await sub.purchase(product)
                    if sub.isPro { dismiss() }
                }
            } label: {
                ZStack {
                    if sub.isLoading {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Text(buttonLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .shadow(color: accent.opacity(0.4), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(sub.isLoading)

            // Footer
            VStack(spacing: 6) {
                if let error = sub.purchaseError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                Button { Task { await sub.restorePurchases() } } label: {
                    Text("Käufe wiederherstellen")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .underline()
                }
                .buttonStyle(.plain)

                Text("Abos verlängern sich automatisch. Kündigung jederzeit möglich.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func planCard(id: String, title: String, price: String,
                          period: String, badge: String?, savings: String?) -> some View {
        let isSelected = selectedID == id
        return Button { selectedID = id } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(isSelected ? accent : .white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected { Circle().fill(accent).frame(width: 10, height: 10) }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(accent, in: Capsule())
                        }
                    }
                    if let savings {
                        Text(savings)
                            .font(.system(size: 10))
                            .foregroundStyle(accent.opacity(0.9))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(period)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accent.opacity(0.15) : .white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? accent.opacity(0.6) : .white.opacity(0.08), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}
