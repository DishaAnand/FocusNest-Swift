import Foundation
import RevenueCat

@MainActor
@Observable
public final class SubscriptionService: @unchecked Sendable {

    // MARK: - Pro Status

    public var isPro: Bool {
        get { _isPro }
        set { _isPro = newValue }
    }
    private var _isPro: Bool = false
    public private(set) var isLoading: Bool = false

    // MARK: - Usage Limits (Free Tier)

    private let maxFreeBuddySessions = 1
    private let maxFreeSessionPlans = 2
    private let maxFreeWakeUpVoices = 1

    // MARK: - Usage Tracking Keys

    private let buddySessionsKey = "subscription_buddySessionsUsed"
    private let sessionPlansKey = "subscription_sessionPlansUsed"
    private let usagePeriodStartKey = "subscription_usagePeriodStart"

    /// iCloud key-value store — persists across app delete/reinstall
    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard

    // MARK: - Tracked Usage Counters
    // These stored properties let @Observable track changes so SwiftUI
    // re-evaluates gate checks (canUseSessionPlanning etc.) after recording usage.

    private var _cachedBuddySessions: Int = 0
    private var _cachedSessionPlans: Int = 0

    // MARK: - Dual Storage Helpers

    /// Read the higher of iCloud or local value (handles iCloud sync delays)
    private func readInt(forKey key: String) -> Int {
        let cloudVal = Int(cloud.longLong(forKey: key))
        let localVal = defaults.integer(forKey: key)
        return max(cloudVal, localVal)
    }

    /// Write to both iCloud and local storage
    private func writeInt(_ value: Int, forKey key: String) {
        cloud.set(Int64(value), forKey: key)
        cloud.synchronize()
        defaults.set(value, forKey: key)
    }

    /// Read date from iCloud with local fallback
    private func readDate(forKey key: String) -> Date? {
        (cloud.object(forKey: key) as? Date) ?? (defaults.object(forKey: key) as? Date)
    }

    /// Write date to both stores
    private func writeDate(_ date: Date, forKey key: String) {
        cloud.set(date, forKey: key)
        cloud.synchronize()
        defaults.set(date, forKey: key)
    }

    /// Sync cached counters from persistent storage
    private func syncCachedCounters() {
        _cachedBuddySessions = readInt(forKey: buddySessionsKey)
        _cachedSessionPlans = readInt(forKey: sessionPlansKey)
    }

    // MARK: - Computed Properties

    public var buddySessionsUsed: Int {
        checkAndResetUsageIfNeeded()
        return _cachedBuddySessions
    }

    public var sessionPlansUsed: Int {
        checkAndResetUsageIfNeeded()
        return _cachedSessionPlans
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
        cloud.synchronize()
        checkAndResetUsageIfNeeded()
        syncCachedCounters()
    }

    // MARK: - RevenueCat Configuration

    public func configure(apiKey: String) {
        Purchases.logLevel = .error
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
            // Keep previous isPro state on network errors
            // so paying users aren't downgraded while offline
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
        let current = readInt(forKey: buddySessionsKey)
        let newValue = current + 1
        writeInt(newValue, forKey: buddySessionsKey)
        _cachedBuddySessions = newValue
        print("[SubscriptionService] Recorded buddy session: \(newValue)/\(maxFreeBuddySessions)")
    }

    public func recordSessionPlanUsed() {
        guard !isPro else { return }
        checkAndResetUsageIfNeeded()
        let current = readInt(forKey: sessionPlansKey)
        let newValue = current + 1
        writeInt(newValue, forKey: sessionPlansKey)
        _cachedSessionPlans = newValue
        print("[SubscriptionService] Recorded session plan: \(newValue)/\(maxFreeSessionPlans)")
    }

    // MARK: - Usage Reset Logic

    public var daysUntilReset: Int {
        guard let startDate = readDate(forKey: usagePeriodStartKey) else {
            return 30
        }
        let daysPassed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, 30 - daysPassed)
    }

    private func checkAndResetUsageIfNeeded() {
        let startDate = readDate(forKey: usagePeriodStartKey)

        if startDate == nil {
            writeDate(Date(), forKey: usagePeriodStartKey)
            syncCachedCounters()
            return
        }

        guard let start = startDate else { return }
        let daysPassed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0

        if daysPassed >= 30 {
            writeInt(0, forKey: buddySessionsKey)
            writeInt(0, forKey: sessionPlansKey)
            writeDate(Date(), forKey: usagePeriodStartKey)
            _cachedBuddySessions = 0
            _cachedSessionPlans = 0
        } else {
            syncCachedCounters()
        }
    }

    // MARK: - Debug Reset

    #if DEBUG
    /// Reset all usage counters (for testing only)
    public func resetUsage() {
        writeInt(0, forKey: buddySessionsKey)
        writeInt(0, forKey: sessionPlansKey)
        writeDate(Date(), forKey: usagePeriodStartKey)
        _cachedBuddySessions = 0
        _cachedSessionPlans = 0
        print("[SubscriptionService] Usage reset. Plans: 0/\(maxFreeSessionPlans), Buddy: 0/\(maxFreeBuddySessions)")
    }
    #endif
}
