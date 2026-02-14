import SwiftUI
import RevenueCat

@MainActor
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var offerings: Offerings?
    @State private var selectedPackage: Package?
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Pricing
                    if let offerings = offerings,
                       let packages = offerings.current?.availablePackages {
                        pricingSection(packages: packages)
                    } else if isLoading {
                        ProgressView()
                            .padding()
                    }

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Purchase button
                    purchaseButton

                    // Restore
                    restoreButton

                    // Terms
                    termsSection
                }
                .padding(Theme.spacingM)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("FocusHaven Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadOfferings()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.spacingM) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock Your Full Potential")
                .font(Theme.titleFont)
                .multilineTextAlignment(.center)

            Text("Get unlimited access to all features")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, Theme.spacingM)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: Theme.spacingS) {
            FeatureRow(icon: "person.2.fill", title: "Unlimited Buddy Sessions", description: "Focus with friends anytime")
            FeatureRow(icon: "list.bullet.clipboard", title: "Unlimited Session Plans", description: "Plan your focus days")
            FeatureRow(icon: "waveform", title: "All 7 Ambient Sounds", description: "Rain, ocean, lo-fi & more")
            FeatureRow(icon: "mic.fill", title: "Unlimited Wake-Up Voices", description: "Record custom alerts")
            FeatureRow(icon: "chart.bar.fill", title: "Full Stats & Insights", description: "Track all your progress")

        }
        .padding(Theme.spacingM)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL))
    }

    // MARK: - Pricing

    private func pricingSection(packages: [Package]) -> some View {
        VStack(spacing: Theme.spacingM) {
            ForEach(packages, id: \.identifier) { package in
                PricingCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Group {
                if subscriptionService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(Theme.headlineFont)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingM)
            .background(
                selectedPackage != nil
                    ? Theme.focusGradient
                    : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
        }
        .disabled(selectedPackage == nil || subscriptionService.isLoading)
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            Text("Restore Purchases")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.focusColor)
        }
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: Theme.spacingXS) {
            Text("Subscription auto-renews unless cancelled at least 24 hours before the end of the current period. Manage in Settings > Apple ID > Subscriptions.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: Theme.spacingM) {
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.focusColor)
        }
        .padding(.top, Theme.spacingS)
    }

    // MARK: - Actions

    private func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            offerings = try await subscriptionService.getOfferings()
            // Auto-select yearly by default
            selectedPackage = offerings?.current?.availablePackages.first { $0.packageType == .annual }
                ?? offerings?.current?.availablePackages.first
        } catch {
            errorMessage = "Failed to load pricing"
        }
    }

    private func purchase() async {
        guard let package = selectedPackage else { return }
        errorMessage = nil

        do {
            try await subscriptionService.purchase(package: package)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        errorMessage = nil

        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isPro {
                dismiss()
            } else {
                errorMessage = "No active subscription found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Theme.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Theme.focusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.bodyFont.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(description)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.focusColor)
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void

    private var isAnnual: Bool {
        package.packageType == .annual
    }

    private var savingsText: String? {
        guard isAnnual else { return nil }
        return "Save 44%"
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isAnnual ? "Yearly" : "Monthly")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)

                        if let savings = savingsText {
                            Text(savings)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.focusColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(package.localizedPriceString + (isAnnual ? "/year" : "/month"))
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)

                    if isAnnual {
                        Text("Just \(monthlyEquivalent)/month")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.focusColor)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Theme.focusColor : Theme.textTertiary)
            }
            .padding(Theme.spacingM)
            .background(isSelected ? Theme.focusColor.opacity(0.1) : Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusM)
                    .stroke(isSelected ? Theme.focusColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var monthlyEquivalent: String {
        let price = package.storeProduct.price as Decimal
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale
        return formatter.string(from: monthly as NSDecimalNumber) ?? ""
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionService())
}
