import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    static let monthlyID  = "com.TorbenLehneke.BeeFocus.pro.monthly"
    static let yearlyID   = "com.TorbenLehneke.BeeFocus.pro.yearly"
    static let lifetimeID = "com.TorbenLehneke.BeeFocus.pro.lifetime"
    static let allIDs     = [monthlyID, yearlyID, lifetimeID]

    // MARK: - Published
    @Published var isPro: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil

    private var listenerTask: Task<Void, Never>?

    init() {
        listenerTask = Task { await listenForTransactions() }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { listenerTask?.cancel() }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Self.allIDs)
            // monthly → yearly → lifetime
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
            case .userCancelled:
                break
            case .pending:
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

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if (try? checkVerified(result)) != nil {
                active = true
            }
        }
        isPro = active
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

    func yearlySavingsPercent() -> Int? {
        guard let m = monthly, let y = yearly else { return nil }
        let monthlyYear = m.price * 12
        guard monthlyYear > 0 else { return nil }
        let saving = (monthlyYear - y.price) / monthlyYear * 100
        return Int(NSDecimalNumber(decimal: saving).rounding(accordingToBehavior: nil).intValue)
    }
}
