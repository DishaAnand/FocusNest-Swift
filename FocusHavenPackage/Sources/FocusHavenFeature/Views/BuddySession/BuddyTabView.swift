import SwiftUI
import SwiftData

/// The main Buddy tab view - shows landing state or active session
@MainActor
public struct BuddyTabView: View {
    @Environment(SessionService.self) private var sessionService
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showCreateSession = false
    @State private var showJoinSession = false
    @State private var showActiveSession = false
    @State private var showUpgradePrompt = false
    @State private var animateIcons = false
    @State private var pulseGlow = false
    @State private var rotateOrbs = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if sessionService.currentSession != nil {
                    // Active session - show the buddy session view
                    BuddySessionView()
                } else {
                    // No session - show welcoming landing
                    landingView
                }
            }
            .navigationTitle("Buddy")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showCreateSession) {
            CreateSessionSheet(isPresented: $showCreateSession) {
                // Session created — inline BuddySessionView takes over
            }
        }
        .sheet(isPresented: $showJoinSession) {
            BuddyJoinWithCodeSheet(isPresented: $showJoinSession) {
                // Joined — inline BuddySessionView takes over
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showUpgradePrompt = false }
                UpgradePromptView.buddySessionLimit()
            }
            .presentationBackground(.clear)
        }
    }

    // MARK: - Landing View (No Active Session)

    private var landingView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Section
                heroSection
                    .padding(.top, 20)

                // Action Cards
                actionCards
                    .padding(.top, 40)

                // Benefits Section
                benefitsSection
                    .padding(.top, 48)

                // How it Works
                howItWorksSection
                    .padding(.top, 48)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 600)  // iPad: constrain content width
            .frame(maxWidth: .infinity)  // Center on larger screens
        }
        .background(animatedBackground)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateIcons = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotateOrbs = true
            }
        }
    }

    // MARK: - Animated Background with Floating Orbs

    private var animatedBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    Color(.systemGroupedBackground).opacity(0.95),
                    Theme.focusColor.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating orbs
            GeometryReader { geo in
                // Large soft orb - top right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.focusColor.opacity(0.12), Theme.focusColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: geo.size.width * 0.6, y: pulseGlow ? 60 : 80)
                    .blur(radius: 30)

                // Medium orb - left side
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.10), Color.orange.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .offset(x: -40, y: geo.size.height * 0.3 + (pulseGlow ? -20 : 20))
                    .blur(radius: 25)

                // Small accent orb - bottom
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.pink.opacity(0.08), Color.pink.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .offset(x: geo.size.width * 0.7, y: geo.size.height * 0.5 + (pulseGlow ? 10 : -10))
                    .blur(radius: 20)

                // Tiny floating particles
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Theme.focusColor.opacity(0.15))
                        .frame(width: CGFloat(4 + i * 2), height: CGFloat(4 + i * 2))
                        .offset(
                            x: geo.size.width * CGFloat([0.2, 0.5, 0.8, 0.3, 0.7, 0.1][i]),
                            y: geo.size.height * CGFloat([0.15, 0.25, 0.4, 0.55, 0.65, 0.8][i]) + (pulseGlow ? CGFloat(i * 3) : CGFloat(-i * 3))
                        )
                        .blur(radius: 1)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Animated buddy icons with enhanced effects
            ZStack {
                // Pulsing glow layers
                Circle()
                    .fill(Theme.focusColor.opacity(pulseGlow ? 0.15 : 0.08))
                    .frame(width: pulseGlow ? 150 : 130, height: pulseGlow ? 150 : 130)
                    .blur(radius: 25)

                Circle()
                    .fill(Color.orange.opacity(pulseGlow ? 0.12 : 0.06))
                    .frame(width: pulseGlow ? 120 : 100, height: pulseGlow ? 120 : 100)
                    .blur(radius: 20)

                // Two buddy figures
                HStack(spacing: -15) {
                    buddyAvatar(color: Theme.focusColor, delay: 0, isLeft: true)
                    buddyAvatar(color: Color.orange, delay: 0.3, isLeft: false)
                }
            }
            .padding(.bottom, 12)

            Text("Focus Together")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }

    private func buddyAvatar(color: Color, delay: Double, isLeft: Bool) -> some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 78, height: 78)

            // Main circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            // Inner highlight
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 60, height: 60)
                .offset(x: -5, y: -5)
                .blur(radius: 8)

            Image(systemName: "person.fill")
                .font(.system(size: 32))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.3), radius: 4, y: 2)
        }
        .offset(y: animateIcons ? -8 : 8)
        .rotationEffect(.degrees(animateIcons ? (isLeft ? -3 : 3) : (isLeft ? 3 : -3)))
        .animation(
            .easeInOut(duration: 1.4)
            .repeatForever(autoreverses: true)
            .delay(delay),
            value: animateIcons
        )
    }

    // MARK: - Action Cards with Glassmorphism

    private var actionCards: some View {
        VStack(spacing: 16) {
            // Start Session Card (Primary) - with shimmer effect
            Button {
                if subscriptionService.canStartBuddySession {
                    showCreateSession = true
                } else {
                    showUpgradePrompt = true
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        // Animated ring
                        Circle()
                            .strokeBorder(Theme.focusColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 62, height: 62)
                            .scaleEffect(pulseGlow ? 1.1 : 1.0)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.focusColor, Theme.focusColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Theme.focusColor.opacity(0.4), radius: 8, y: 4)

                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start a Session")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Invite a friend to focus with you")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Animated chevron
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.focusColor.opacity(0.3))
                        .offset(x: pulseGlow ? 2 : 0)
                }
                .padding(20)
                .background(
                    ZStack {
                        // Glass effect background
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)

                        // Subtle gradient overlay
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        // Border
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    }
                )
                .shadow(color: Theme.focusColor.opacity(0.1), radius: 20, y: 10)
            }
            .buttonStyle(FloatingCardButtonStyle())

            // Join Session Card (Secondary)
            Button {
                if subscriptionService.canStartBuddySession {
                    showJoinSession = true
                } else {
                    showUpgradePrompt = true
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)

                        Image(systemName: "link")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Join a Session")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Enter a code from your friend")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.orange.opacity(0.3))
                }
                .padding(20)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    }
                )
                .shadow(color: Color.orange.opacity(0.08), radius: 16, y: 8)
            }
            .buttonStyle(FloatingCardButtonStyle())
        }
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Why Focus Together?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                benefitRow(
                    icon: "checkmark.shield.fill",
                    color: .green,
                    title: "Stay Accountable",
                    description: "Your buddy sees when you leave the app",
                    delay: 0
                )

                benefitRow(
                    icon: "flame.fill",
                    color: .orange,
                    title: "Build Momentum",
                    description: "Friendly competition keeps you focused",
                    delay: 0.1
                )

                benefitRow(
                    icon: "heart.fill",
                    color: .pink,
                    title: "Celebrate Together",
                    description: "Share the win when you both finish",
                    delay: 0.2
                )
            }
        }
    }

    private func benefitRow(icon: String, color: Color, title: String, description: String, delay: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                // Glow behind icon
                Circle()
                    .fill(color.opacity(pulseGlow ? 0.2 : 0.1))
                    .frame(width: 48, height: 48)
                    .blur(radius: 4)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(color.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Subtle checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - How It Works Section

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How It Works")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                stepRow(number: 1, text: "Start or join a session", icon: "play.circle.fill", isLast: false)
                stepRow(number: 2, text: "Set your focus duration", icon: "timer", isLast: false)
                stepRow(number: 3, text: "Focus together in real-time", icon: "sparkles", isLast: true)
            }
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.03), radius: 12, y: 6)
        }
    }

    private func stepRow(number: Int, text: String, icon: String, isLast: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                // Outer ring with gradient
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.focusColor, Theme.focusColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 36, height: 36)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.focusColor, Theme.focusColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: Theme.focusColor.opacity(0.3), radius: 4, y: 2)

                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.focusColor.opacity(0.5))
        }
        .padding(.vertical, 14)
        .overlay(alignment: .leading) {
            if !isLast {
                // Animated connecting line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.focusColor.opacity(0.4), Theme.focusColor.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                    .padding(.leading, 17)
                    .offset(y: 32)
            }
        }
    }
}

// MARK: - Floating Card Button Style

private struct FloatingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    BuddyTabView()
        .environment(SessionService())
        .environment(SubscriptionService())
}
