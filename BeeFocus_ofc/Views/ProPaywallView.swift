import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sub = SubscriptionManager.shared
    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var selectedID: String = SubscriptionManager.shared.activeProductID ?? SubscriptionManager.yearlyID
    @State private var showOfferCodeRedemption = false

    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }
    private var accent:  Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : c1 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.3,  green: 0.6,  blue: 1.0) : c2 }
    private func loc(_ key: String) -> String { localizer.localizedString(forKey: key) }

    // Trial-Info aus dem StoreKit Intro-Offer des gewählten Produkts
    private var trialLabel: String? {
        guard selectedID != SubscriptionManager.lifetimeID,
              let product = sub.products.first(where: { $0.id == selectedID }),
              let offer   = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial
        else { return nil }

        let days: Int
        switch offer.period.unit {
        case .day:   days = offer.period.value
        case .week:  days = offer.period.value * 7
        case .month: days = offer.period.value * 30
        case .year:  days = offer.period.value * 365
        @unknown default: days = 0
        }
        return days > 0 ? loc("paywall_trial_days") : nil
    }

    // Fallback wenn Produkte noch nicht geladen
    private var fallbackTrialLabel: String? {
        selectedID == SubscriptionManager.lifetimeID ? nil : loc("paywall_trial_days")
    }

    private var effectiveTrialLabel: String? {
        sub.products.isEmpty ? fallbackTrialLabel : trialLabel
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.13),
                         Color(red: 0.1,  green: 0.06, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 32)
                        .padding(.bottom, 20)

                    // Trial-Banner (nur bei Abo-Plänen mit Trial)
                    if let trial = effectiveTrialLabel {
                        trialBanner(trial)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }

                    featuresSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    plansSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    purchaseButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    // Hinweis unter Button
                    if let _ = effectiveTrialLabel {
                        Text(loc("paywall_trial_footer"))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)
                    }

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
        .offerCodeRedemption(isPresented: $showOfferCodeRedemption)
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

            Text(loc("paywall_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Trial Banner

    private func trialBanner(_ label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(loc("paywall_trial_desc"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accent.opacity(0.4), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: selectedID)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            featureRow(icon: "infinity",                  color: accent,                                  text: loc("paywall_feat_tasks"))
            featureRow(icon: "storefront.fill",           color: .orange,                                 text: loc("paywall_feat_store"))
            featureRow(icon: "speaker.wave.3.fill",       color: .purple,                                 text: loc("paywall_feat_sounds"))
            featureRow(icon: "chart.bar.fill",            color: .indigo,                                 text: loc("paywall_feat_stats"))
            featureRow(icon: "heart.text.clipboard.fill", color: .teal,                                   text: loc("paywall_feat_habits"))
            featureRow(icon: "medal.fill",                color: Color(red: 0.6, green: 0.3, blue: 0.9),  text: loc("paywall_feat_badges"))
            featureRow(icon: "timer",                     color: .cyan,                                   text: loc("paywall_feat_timer"))
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
                planCard(id: SubscriptionManager.monthlyID,  title: loc("paywall_plan_monthly"),  price: "2.99 €",  period: loc("paywall_period_month"), badge: nil,                        savings: nil,                        hasTrial: true)
                planCard(id: SubscriptionManager.yearlyID,   title: loc("paywall_plan_yearly"),   price: "17.99 €", period: loc("paywall_period_year"),  badge: loc("paywall_badge_popular"), savings: loc("paywall_savings_fallback"), hasTrial: true)
                planCard(id: SubscriptionManager.lifetimeID, title: loc("paywall_plan_lifetime"), price: "29.99 €", period: loc("paywall_period_onetime"), badge: nil,                       savings: nil,                        hasTrial: false)
            } else {
                if let m = sub.monthly {
                    planCard(id: m.id, title: loc("paywall_plan_monthly"), price: m.displayPrice, period: loc("paywall_period_month"),
                             badge: nil, savings: nil, hasTrial: hasIntroOffer(m))
                }
                if let y = sub.yearly {
                    planCard(id: y.id, title: loc("paywall_plan_yearly"), price: y.displayPrice, period: loc("paywall_period_year"),
                             badge: loc("paywall_badge_popular"),
                             savings: sub.yearlySavingsPercent().map { "\($0)% savings" },
                             hasTrial: hasIntroOffer(y))
                }
                if let l = sub.lifetime {
                    planCard(id: l.id, title: loc("paywall_plan_lifetime"), price: l.displayPrice, period: loc("paywall_period_onetime"),
                             badge: nil, savings: nil, hasTrial: false)
                }
            }
        }
    }

    private func hasIntroOffer(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private func planCard(id: String, title: String, price: String,
                          period: String, badge: String?, savings: String?, hasTrial: Bool) -> some View {
        let isSelected = selectedID == id
        let isOwned = sub.activeProductID == id
        return Button {
            if !isOwned { selectedID = id }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isOwned ? Color.green.opacity(0.8) : (isSelected ? accent : .white.opacity(0.25)), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isOwned {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                    } else if isSelected {
                        Circle().fill(accent).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isOwned ? .white.opacity(0.5) : .white)
                        if isOwned {
                            Text(loc("paywall_current_plan"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.green.opacity(0.7), in: Capsule())
                        } else if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(accent, in: Capsule())
                        }
                    }
                    HStack(spacing: 6) {
                        if hasTrial && !isOwned {
                            Text(loc("paywall_7_days_free"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                        if let savings, !isOwned {
                            Text(savings)
                                .font(.system(size: 11))
                                .foregroundStyle(accent.opacity(0.9))
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isOwned ? .white.opacity(0.4) : .white)
                    Text(period)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(isOwned ? 0.25 : 0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOwned ? .white.opacity(0.03) : (isSelected ? accent.opacity(0.15) : .white.opacity(0.05)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isOwned ? Color.green.opacity(0.3) : (isSelected ? accent.opacity(0.6) : .white.opacity(0.1)), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - CTA

    private var isSelectedOwned: Bool { sub.activeProductID == selectedID }

    private var purchaseButton: some View {
        Button {
            if isSelectedOwned {
                sub.manageSubscriptions()
            } else {
                Task {
                    guard let product = sub.products.first(where: { $0.id == selectedID }) else { return }
                    await sub.purchase(product)
                    if sub.isPro { dismiss() }
                }
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
                isSelectedOwned
                    ? LinearGradient(colors: [.green.opacity(0.6), .green.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: (isSelectedOwned ? Color.green : accent).opacity(0.4), radius: 12, y: 4)
        }
        .disabled(sub.isLoading)
    }

    private var buttonLabel: String {
        if isSelectedOwned { return loc("paywall_btn_manage") }
        let hasTrial = effectiveTrialLabel != nil
        switch selectedID {
        case SubscriptionManager.lifetimeID: return loc("paywall_btn_lifetime")
        case SubscriptionManager.yearlyID:   return hasTrial ? loc("paywall_btn_trial") : loc("paywall_btn_yearly")
        default:                             return hasTrial ? loc("paywall_btn_trial") : loc("paywall_btn_monthly")
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

            HStack(spacing: 20) {
                Button {
                    Task { await sub.restorePurchases() }
                } label: {
                    Text(loc("paywall_restore"))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .underline()
                }

                Button {
                    showOfferCodeRedemption = true
                } label: {
                    Text(loc("paywall_redeem_code"))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .underline()
                }
            }

            HStack(spacing: 16) {
                Link(loc("privacy_policy"), destination: URL(string: "https://www.torbenlehneke.de/apps/beefocus/datenschutz.html")!)
                Text("·").foregroundStyle(.white.opacity(0.25))
                Link(loc("terms_of_use"), destination: URL(string: "https://www.torbenlehneke.de/apps/beefocus/nutzungsbedingungen.html")!)
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.35))

            Text(loc("paywall_legal"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 2)
        }
    }
}
