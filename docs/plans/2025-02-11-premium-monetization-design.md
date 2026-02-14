# FocusHaven Premium Monetization Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a freemium subscription model that provides genuine value to free users while offering compelling reasons to upgrade to Pro.

**Architecture:** Hybrid monetization using RevenueCat for subscription management, combining usage-limited features (reset monthly) with feature-locked premium content.

**Tech Stack:** RevenueCat SDK, StoreKit 2, UserDefaults for usage tracking, SwiftData for persistence

---

## Pricing Structure

| Plan | Price | Notes |
|------|-------|-------|
| Monthly | $2.99/month | Low commitment, easy impulse buy |
| Yearly | $19.99/year | ~$1.67/month, 44% savings, reduces churn |

---

## Feature Access Matrix

### Always Free (Unlimited)

| Feature | Details |
|---------|---------|
| Basic timer | Focus/break modes, customizable durations (1-120 min) |
| Task management | Create, edit, complete, delete tasks |
| Auto-start options | Auto-start breaks and focus sessions |
| Haptic feedback | All haptic feedback types |
| Live Activities | Dynamic Island + lock screen widget |
| Streaks tracking | Consecutive day tracking |
| Energy predictions | Pre-session focus level prediction |
| Basic stats | Last 7 days of history |
| 2 ambient sounds | Silence + Rain |

### Usage-Limited (Free with Monthly Limits)

| Feature | Free Limit | Pro |
|---------|------------|-----|
| Buddy sessions | 1/month | Unlimited |
| Session plans | 2/month | Unlimited |
| Wake-up voice recordings | 1 saved | Unlimited |

**Reset Logic:** Limits reset on the 1st of each month (or 30 days from first use).

### Pro Only (Feature-Locked)

| Feature | Details |
|---------|---------|
| All ambient sounds | +5 more: Ocean Waves, Brown Noise, White Noise, Forest, Lo-fi Beats |
| Full stats history | All-time history (beyond 7 days) |
| Insights & charts | Weekly/monthly charts, trends, comparisons |
| Universe visualization | Stars, planets, constellations gamification |

---

## User Experience Flows

### Hitting a Usage Limit

When a free user tries to exceed their limit:

1. Show friendly modal explaining the limit
2. Display current usage: "You've used 1 of 1 buddy sessions this month"
3. Show when limit resets: "Resets in X days"
4. Present upgrade option with value proposition
5. Allow dismissal without pressure

**Example copy:**
> "You've used your free buddy session this month! Upgrade to Pro for unlimited sessions with friends. Resets February 1st."

### Encountering a Locked Feature

When a free user taps a Pro-only feature:

1. Brief explanation of the feature
2. Show preview if possible (e.g., blurred universe view)
3. Present upgrade option
4. Allow dismissal

**Example copy:**
> "Universe unlocks with Pro! Watch your focus sessions become stars and planets. Try Pro free for 7 days."

### Paywall Design

- Show on: Settings Pro badge tap, locked feature tap, limit reached
- Include: Feature comparison, pricing options, free trial option
- Restore purchases button visible
- Easy dismissal (no hard paywall)

---

## Technical Implementation

### RevenueCat Setup

**Products to create in App Store Connect:**
- `focushaven_pro_monthly` - $2.99/month auto-renewable
- `focushaven_pro_yearly` - $19.99/year auto-renewable

**Entitlements:**
- `pro` - Grants access to all premium features

**Offerings:**
- `default` - Contains both monthly and yearly packages

### Usage Tracking

Store in UserDefaults:
```swift
// Keys
"buddySessionsUsedThisMonth" -> Int
"sessionPlansUsedThisMonth" -> Int
"usagePeriodStartDate" -> Date
"savedWakeUpVoicesCount" -> Int
```

Reset logic:
```swift
func checkAndResetUsageIfNeeded() {
    let startDate = UserDefaults.standard.object(forKey: "usagePeriodStartDate") as? Date ?? Date()
    if Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0 >= 30 {
        // Reset counts
        UserDefaults.standard.set(0, forKey: "buddySessionsUsedThisMonth")
        UserDefaults.standard.set(0, forKey: "sessionPlansUsedThisMonth")
        UserDefaults.standard.set(Date(), forKey: "usagePeriodStartDate")
    }
}
```

### Subscription State

Create a SubscriptionService:
```swift
@Observable
class SubscriptionService {
    var isPro: Bool = false

    // Usage limits
    var buddySessionsRemaining: Int
    var sessionPlansRemaining: Int
    var canSaveMoreVoices: Bool

    // Feature access
    var canAccessAllSounds: Bool { isPro }
    var canAccessFullStats: Bool { isPro }
    var canAccessInsights: Bool { isPro }
    var canAccessUniverse: Bool { isPro }

    func checkProStatus() async { ... }
    func purchase(_ package: Package) async throws { ... }
    func restorePurchases() async throws { ... }
}
```

---

## Files to Modify

### New Files
- `Services/SubscriptionService.swift` - RevenueCat integration, entitlement checking
- `Views/Paywall/PaywallView.swift` - Premium upgrade UI
- `Views/Paywall/FeatureLockedView.swift` - Locked feature overlay
- `Views/Paywall/UsageLimitView.swift` - Usage limit modal

### Modified Files
- `FocusHavenApp.swift` - Initialize RevenueCat SDK
- `AmbientSoundService.swift` - Filter sounds based on Pro status
- `BuddySessionView.swift` - Check buddy session limit before creating/joining
- `SessionPlannerView.swift` - Check session plan limit
- `WakeUpVoiceService.swift` - Check voice recording limit
- `ProgressView.swift` - Gate insights/charts behind Pro
- `UniverseView.swift` - Gate behind Pro
- `SettingsView.swift` - Add Pro badge, manage subscription link

---

## App Store Requirements

### Paywall Compliance
- Clearly show pricing before purchase
- Include "Restore Purchases" button
- Show subscription terms (auto-renewal, cancellation)
- Link to Terms of Service and Privacy Policy

### Required Metadata
- In-app purchase descriptions for App Store
- Subscription group setup
- Review notes explaining how to test premium features

---

## Analytics Events (Optional)

Track for optimization:
- `paywall_viewed` - Which trigger showed paywall
- `paywall_dismissed` - User closed without purchasing
- `purchase_started` - User tapped purchase button
- `purchase_completed` - Successful purchase
- `purchase_failed` - Failed purchase with error
- `limit_reached` - Which limit was hit
- `feature_locked_tapped` - Which locked feature was tapped

---

## Testing Checklist

- [ ] Free user can use basic timer unlimited
- [ ] Free user limited to 1 buddy session/month
- [ ] Free user limited to 2 session plans/month
- [ ] Free user limited to 1 wake-up voice
- [ ] Free user sees only 2 ambient sounds
- [ ] Free user sees only 7 days of stats
- [ ] Free user cannot access insights/charts
- [ ] Free user cannot access universe
- [ ] Pro user has unlimited access to everything
- [ ] Usage limits reset after 30 days
- [ ] Paywall displays correctly
- [ ] Purchase flow completes successfully
- [ ] Restore purchases works
- [ ] Subscription status persists across app restarts

---

## Launch Strategy

1. **Soft launch:** Ship with generous 7-day free trial
2. **Monitor:** Track conversion rates and limit-hit events
3. **Iterate:** Adjust limits based on data (can tighten if too generous)
4. **Reviews:** Respond to any paywall complaints quickly

---

## Summary

| Aspect | Decision |
|--------|----------|
| Model | Freemium + Subscription |
| Pricing | $2.99/month or $19.99/year |
| Free tier | Genuinely useful, not crippled |
| Limits | Tight but fair (1 buddy, 2 plans, 1 voice) |
| Locked features | Premium sounds, full stats, insights, universe |
| Tech | RevenueCat + StoreKit 2 |
