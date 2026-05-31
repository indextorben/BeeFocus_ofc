import StoreKit
import SwiftUI
import UIKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    static let monthlyID  = "com.TorbenLehneke.BeeFocus.pro.monthly"
    static let yearlyID   = "com.TorbenLehneke.BeeFocus.pro.yearly"
    static let lifetimeID = "com.TorbenLehneke.BeeFocus.pro.lifetime"
    static let allIDs     = [monthlyID, yearlyID, lifetimeID]

    // iCloud KV keys
    private static let kvIsProKey     = "beefocus_isPro"
    private static let kvExpiryKey    = "beefocus_expirationDate"

    // MARK: - Published
    @Published var isPro: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil
    @Published var expirationDate: Date? = nil

    private var listenerTask: Task<Void, Never>?
    private var foregroundTask: Task<Void, Never>?
    private var iCloudTask: Task<Void, Never>?
    private let kvStore = NSUbiquitousKeyValueStore.default

    init() {
        // Sofort iCloud-Cache lesen für schnelle UI
        isPro = kvStore.bool(forKey: Self.kvIsProKey)
        if let ts = kvStore.object(forKey: Self.kvExpiryKey) as? Double {
            expirationDate = Date(timeIntervalSince1970: ts)
        }

        listenerTask = Task { await listenForTransactions() }

        // iCloud KV Änderungen beobachten (anderes Gerät hat gekauft)
        iCloudTask = Task {
            for await _ in NotificationCenter.default
                .notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification) {
                await self.refreshEntitlements()
            }
        }

        // Vordergrund → StoreKit-Verifikation
        foregroundTask = Task {
            for await _ in NotificationCenter.default
                .notifications(named: UIApplication.willEnterForegroundNotification) {
                await self.refreshEntitlements()
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }

        kvStore.synchronize()
    }

    deinit {
        listenerTask?.cancel()
        foregroundTask?.cancel()
        iCloudTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Self.allIDs)
            products = fetched.sorted {
                let order = [Self.monthlyID, Self.yearlyID, Self.lifetimeID]
                return (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlements (StoreKit 2 + iCloud Sync)

    func refreshEntitlements() async {
        var active = false
        var expiry: Date? = nil

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                active = true
                if let exp = transaction.expirationDate {
                    // Immer das späteste Ablaufdatum (falls mehrere Käufe)
                    expiry = expiry.map { max($0, exp) } ?? exp
                }
            }
        }

        isPro = active
        expirationDate = expiry

        // iCloud KV aktualisieren → andere Geräte merken es sofort
        kvStore.set(active, forKey: Self.kvIsProKey)
        if let exp = expiry {
            kvStore.set(exp.timeIntervalSince1970, forKey: Self.kvExpiryKey)
        } else {
            kvStore.removeObject(forKey: Self.kvExpiryKey)
        }
        kvStore.synchronize()
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }

    // MARK: - Helpers

    var monthly:  Product? { products.first { $0.id == Self.monthlyID  } }
    var yearly:   Product? { products.first { $0.id == Self.yearlyID   } }
    var lifetime: Product? { products.first { $0.id == Self.lifetimeID } }

    func manageSubscriptions() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    func yearlySavingsPercent() -> Int? {
        guard let m = monthly, let y = yearly else { return nil }
        let monthlyYear = m.price * 12
        guard monthlyYear > 0 else { return nil }
        let saving = (monthlyYear - y.price) / monthlyYear * 100
        return Int(NSDecimalNumber(decimal: saving).rounding(accordingToBehavior: nil).intValue)
    }
}
