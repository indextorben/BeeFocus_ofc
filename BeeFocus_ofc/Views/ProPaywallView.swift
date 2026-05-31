import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sub = SubscriptionManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var selectedID: String = SubscriptionManager.yearlyID

    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : c1 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.3, green: 0.6, blue: 1.0) : c2 }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.13),
                         Color(red: 0.1, green: 0.06, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 32)
                        .padding(.bottom, 24)

                    // Features
                    featuresSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                    // Plans
                    plansSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // CTA Button
                    purchaseButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    // Restore + legal
                    footerSection
                        .padding(.bottom, 32)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .task { await sub.loadProducts() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent2],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .shadow(color: accent.opacity(0.5), radius: 20)
                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("BeeFocus Pro")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("Hol das Beste aus deiner Produktivität heraus")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            featureRow(icon: "infinity",           color: accent,                  text: "Unbegrenzte Kategorien")
            featureRow(icon: "storefront.fill",    color: .orange,                 text: "Alle Focus-Store Items sofort freigeschaltet")
            featureRow(icon: "sparkles",           color: .purple,                 text: "KI-Assistent, Focus Coach & Wochenrückblick")
            featureRow(icon: "mic.fill",           color: .teal,                   text: "Spracheingabe & KI-Sprachausgabe")
            featureRow(icon: "chart.bar.fill",     color: .indigo,                 text: "Erweiterte Statistiken & Heatmap")
            featureRow(icon: "medal.fill",         color: Color(red: 0.6, green: 0.3, blue: 0.9), text: "Abzeichen, Streak & Achievement-System")
            featureRow(icon: "timer",              color: .cyan,                   text: "Alle Timer-Modi & Premium-Themes")
        }
        .padding(4)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 10) {
            if sub.products.isEmpty {
                // Loading / Unavailable state
                ForEach([("Monatlich", "2,99 €", SubscriptionManager.monthlyID),
                         ("Jährlich", "17,99 €", SubscriptionManager.yearlyID),
                         ("Lifetime", "29,99 €", SubscriptionManager.lifetimeID)],
                        id: \.2) { plan in
                    planCard(id: plan.2, title: plan.0, price: plan.1,
                             period: plan.2 == SubscriptionManager.lifetimeID ? "einmalig" : "/ Monat",
                             badge: plan.2 == SubscriptionManager.yearlyID ? "Beliebteste Wahl" : nil,
                             savings: plan.2 == SubscriptionManager.yearlyID ? "~50% sparen" : nil)
                }
            } else {
                if let m = sub.monthly {
                    planCard(id: m.id,
                             title: "Monatlich",
                             price: m.displayPrice,
                             period: "/ Monat",
                             badge: nil, savings: nil)
                }
                if let y = sub.yearly {
                    let pct = sub.yearlySavingsPercent()
                    planCard(id: y.id,
                             title: "Jährlich",
                             price: y.displayPrice,
                             period: "/ Jahr",
                             badge: "Beliebteste Wahl",
                             savings: pct.map { "\($0)% sparen" })
                }
                if let l = sub.lifetime {
                    planCard(id: l.id,
                             title: "Lifetime",
                             price: l.displayPrice,
                             period: "einmalig",
                             badge: nil, savings: nil)
                }
            }
        }
    }

    private func planCard(id: String, title: String, price: String,
                          period: String, badge: String?, savings: String?) -> some View {
        let isSelected = selectedID == id
        return Button { selectedID = id } label: {
            HStack(spacing: 12) {
                // Radio
                ZStack {
                    Circle()
                        .stroke(isSelected ? accent : .white.opacity(0.25), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(accent)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(accent, in: Capsule())
                        }
                    }
                    if let savings {
                        Text(savings)
                            .font(.system(size: 12))
                            .foregroundStyle(accent.opacity(0.9))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(period)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(0.15) : .white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? accent.opacity(0.6) : .white.opacity(0.1), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - CTA

    private var purchaseButton: some View {
        Button {
            Task {
                let product = sub.products.first { $0.id == selectedID }
                if let p = product { await sub.purchase(p) }
                if sub.isPro { dismiss() }
            }
        } label: {
            ZStack {
                if sub.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(colors: [accent, accent2],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: accent.opacity(0.4), radius: 12, y: 4)
        }
        .disabled(sub.isLoading)
    }

    private var buttonLabel: String {
        switch selectedID {
        case SubscriptionManager.lifetimeID: return "Lifetime kaufen"
        case SubscriptionManager.yearlyID:   return "Jährlich abonnieren"
        default:                              return "Monatlich abonnieren"
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            if let error = sub.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button {
                Task { await sub.restorePurchases() }
            } label: {
                Text("Käufe wiederherstellen")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .underline()
            }

            Text("Abos verlängern sich automatisch. Kündigung jederzeit in den App Store Einstellungen.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
    }
}
