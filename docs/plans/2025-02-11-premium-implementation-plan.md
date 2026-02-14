# FocusHaven Premium - Implementation Plan

## Task 1: Add RevenueCat SDK
- Add to Package.swift: `RevenueCat/purchases-ios`
- Initialize in FocusHavenApp.swift

## Task 2: Create SubscriptionService
- Pro status checking via RevenueCat
- Usage limit tracking (buddy sessions, plans, voices)
- Monthly reset logic

## Task 3: Create PaywallView
- Show monthly/yearly options
- Feature comparison
- Purchase and restore buttons

## Task 4: Gate Ambient Sounds
- Free: Silence + Rain only
- Pro: All 7 sounds

## Task 5: Gate Buddy Sessions
- Track usage count
- Check limit before create/join
- Show upgrade prompt at limit

## Task 6: Gate Session Plans
- Track usage count
- Check limit before creating plan
- Show upgrade prompt at limit

## Task 7: Gate Wake-Up Voices
- Limit to 1 saved recording
- Check before saving new voice

## Task 8: Gate Stats & Insights
- Free: 7 days only
- Pro: Full history + charts

## Task 9: Gate Universe
- Pro only feature
- Show locked state for free users

## Task 10: Add Pro Badge to Settings
- Show subscription status
- Manage subscription link
