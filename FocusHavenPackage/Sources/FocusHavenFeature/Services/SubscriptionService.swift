import Foundation
import RevenueCat

@MainActor
@Observable
public final class SubscriptionService: @unchecked Sendable {

    // MARK: - Pro Status

    public private(set) var isPro: Bool = false
    public private(set) var isLoading: Bool = false

    // MARK: - Usage Limits (Free Tier)

    private let maxFreeBuddySessions = 1
    private let maxFreeSessionPlans = 2
    private let maxFreeWakeUpVoices = 1

    // MARK: - Usage Tracking Keys

    private let buddySessionsKey = "subscription_buddySessionsUsed"
    private let sessionPlansKey = "subscription_sessionPlansUsed"
    private let usagePeriodStartKey = "subscription_usagePeriodStart"

    // MARK: - Computed Properties

    public var buddySessionsUsed: Int {
        UserDefaults.standard.integer(forKey: buddySessionsKey)
    }

    public var sessionPlansUsed: Int {
        UserDefaults.standard.integer(forKey: sessionPlansKey)
    }

    public var buddySessionsRemaining: Int {
        isPro ? .max : max(0, maxFreeBuddySessions - buddySessionsUsed)
    }

    public var sessionPlansRemaining: Int {
        isPro ? .max : max(0, maxFreeSessionPlans - sessionPlansUsed)
    }

    public var canStartBuddySession: Bool {
        isPro || buddySessionsUsed < maxFreeBuddySessions
    }

    public var canCreateSessionPlan: Bool {
        isPro || sessionPlansUsed < maxFreeSessionPlans
    }

    public func canSaveWakeUpVoice(currentCount: Int) -> Bool {
        isPro || currentCount < maxFreeWakeUpVoices
    }

    public func canAddWakeUpVoice(currentCount: Int) -> Bool {
        canSaveWakeUpVoice(currentCount: currentCount)
    }

    public var canUseSessionPlanning: Bool {
        canCreateSessionPlan
    }

    // MARK: - Feature Access

    public var canAccessAllSounds: Bool { isPro }
    public var canAccessFullStats: Bool { isPro }
    public var canAccessInsights: Bool { isPro }


    // MARK: - Free Sounds

    public let freeSoundIds: Set<String> = ["silence", "rain"]

    // MARK: - Init

    public init() {
        checkAndResetUsageIfNeeded()
    }

    // MARK: - RevenueCat Configuration

    public func configure(apiKey: String) {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)

        Task {
            await checkProStatus()
        }
    }

    // MARK: - Pro Status Check

    public func checkProStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            isPro = false
        }
    }

    // MARK: - Purchase

    public func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        isPro = result.customerInfo.entitlements["pro"]?.isActive == true
    }

    // MARK: - Restore Purchases

    public func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        let customerInfo = try await Purchases.shared.restorePurchases()
        isPro = customerInfo.entitlements["pro"]?.isActive == true
    }

    // MARK: - Get Offerings

    public func getOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    // MARK: - Usage Tracking

    public func recordBuddySessionUsed() {
        guard !isPro else { return }
        checkAndResetUsageIfNeeded()
        let current = UserDefaults.standard.integer(forKey: buddySessionsKey)
        UserDefaults.standard.set(current + 1, forKey: buddySessionsKey)
    }

    public func recordSessionPlanUsed() {
        guard !isPro else { return }
        checkAndResetUsageIfNeeded()
        let current = UserDefaults.standard.integer(forKey: sessionPlansKey)
        UserDefaults.standard.set(current + 1, forKey: sessionPlansKey)
    }

    // MARK: - Usage Reset Logic

    public var daysUntilReset: Int {
        guard let startDate = UserDefaults.standard.object(forKey: usagePeriodStartKey) as? Date else {
            return 30
        }
        let daysPassed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, 30 - daysPassed)
    }

    private func checkAndResetUsageIfNeeded() {
        let startDate = UserDefaults.standard.object(forKey: usagePeriodStartKey) as? Date

        if startDate == nil {
            // First time - set the start date
            UserDefaults.standard.set(Date(), forKey: usagePeriodStartKey)
            return
        }

        guard let start = startDate else { return }
        let daysPassed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0

        if daysPassed >= 30 {
            // Reset usage counts
            UserDefaults.standard.set(0, forKey: buddySessionsKey)
            UserDefaults.standard.set(0, forKey: sessionPlansKey)
            UserDefaults.standard.set(Date(), forKey: usagePeriodStartKey)
        }
    }

}
