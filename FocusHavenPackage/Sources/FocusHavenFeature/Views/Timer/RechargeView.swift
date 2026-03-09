import SwiftUI

/// Full-screen break experience that encourages movement
struct RechargeView: View {
    @Environment(MotionService.self) private var motionService
    @Environment(TimerService.self) private var timerService
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var finalRechargeLevel: Double = 0
    @State private var backgroundGlow: CGFloat = 0
    @State private var appeared = false
    @State private var showEarlyExitButton = false

    var body: some View {
        ZStack {
            // Animated background
            RechargeBackground(intensity: backgroundGlow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button (top-right)
                HStack {
                    Spacer()
                    Button {
                        soundService.lightImpact(settings: settings)
                        handleSkip()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .opacity(appeared ? 1 : 0)

                Spacer()

                // Timer remaining
                VStack(spacing: 4) {
                    Text("Break Time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text(timerService.formattedTime)
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer()
                    .frame(height: 40)

                // Energy Orb
                EnergyOrbView(
                    rechargePercentage: motionService.rechargePercentage,
                    movementIntensity: motionService.movementIntensity
                )
                .frame(width: 280, height: 280)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)

                Spacer()
                    .frame(height: 24)

                // Unlock Progress Bar
                UnlockProgressBar(progress: motionService.rechargePercentage)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer()
                    .frame(height: 24)

                // Early Exit Button (appears at 100%)
                if showEarlyExitButton {
                    Button {
                        soundService.successHaptic(settings: settings)
                        handleEarlyExit()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Continue to Focus")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.pink, Color(red: 0.9, green: 0.4, blue: 0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .pink.opacity(0.4), radius: 12, x: 0, y: 4)
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()
                    .frame(height: 20)

                // Activity indicator (walking mode only, not on iPad)
                if settings.rechargeDetectionMode == .walkingOnly && UIDevice.current.userInterfaceIdiom != .pad {
                    HStack(spacing: 12) {
                        Image(systemName: activityIcon)
                            .font(.system(size: 20))
                            .foregroundStyle(activityColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(motionService.currentActivity.capitalized)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("\(motionService.stepsTaken) steps")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.1))
                    )
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 16)
                }

                // Encouragement text
                Text(encouragementMessage)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeInOut(duration: 0.3), value: encouragementMessage)

                Spacer()
            }
        }
        .onAppear {
            setupRechargeMode()
        }
        .onDisappear {
            motionService.stopTracking()
        }
        .onChange(of: timerService.state) { oldState, newState in
            // When break ends (timer was running, now idle)
            // Note: We don't check timerService.isBreak because the mode may have
            // already transitioned to .focus by the time this onChange fires.
            // RechargeView is only shown during breaks, so if we were running and now idle,
            // the break ended.
            if oldState == .running && newState == .idle {
                handleBreakComplete()
            }
        }
        .onChange(of: motionService.rechargePercentage) { _, newValue in
            // Show early exit button when 75% is reached (don't make user wait for 100%)
            if newValue >= 75 && !showEarlyExitButton {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showEarlyExitButton = true
                }
                soundService.successHaptic(settings: settings)
            }
        }
    }

    // MARK: - Activity Display (Walking Mode)

    private var activityIcon: String {
        switch motionService.currentActivity {
        case "walking": return "figure.walk"
        case "running": return "figure.run"
        case "cycling": return "figure.outdoor.cycle"
        case "stationary": return "figure.stand"
        default: return "questionmark.circle"
        }
    }

    private var activityColor: Color {
        switch motionService.currentActivity {
        case "walking": return .green
        case "running": return .orange
        case "cycling": return .blue
        case "stationary": return .gray
        default: return .white
        }
    }

    // MARK: - Encouragement Messages

    private var encouragementMessage: String {
        let percentage = motionService.rechargePercentage
        let isWalkingMode = settings.rechargeDetectionMode == .walkingOnly && UIDevice.current.userInterfaceIdiom != .pad

        if isWalkingMode {
            // Walking-specific messages
            switch percentage {
            case 0..<10:
                return "Start walking to recharge!"
            case 10..<25:
                return "Great start! Keep those steps coming"
            case 25..<50:
                return "You're on a roll! \(motionService.stepsTaken) steps"
            case 50..<75:
                return "Halfway there! Keep walking"
            case 75..<100:
                return "Almost fully recharged!"
            default:
                return "Full recharge! Great walk! 🚶‍♂️"
            }
        } else {
            // Any movement messages
            switch percentage {
            case 0..<10:
                return "Get up and move to recharge!"
            case 10..<25:
                return "Keep going, you're warming up!"
            case 25..<50:
                return "Great! Your energy is building"
            case 50..<75:
                return "Fantastic movement!"
            case 75..<100:
                return "Almost fully recharged!"
            default:
                return "You're fully recharged! 🎉"
            }
        }
    }

    // MARK: - Setup

    private func setupRechargeMode() {
        // Reset and start tracking with user's preferred mode
        // iPad doesn't have pedometer, so force anyMovement mode
        let effectiveMode: RechargeDetectionMode = UIDevice.current.userInterfaceIdiom == .pad ? .anyMovement : settings.rechargeDetectionMode
        motionService.reset()
        motionService.startTracking(mode: effectiveMode)

        // Set up milestone haptics
        motionService.onMilestoneReached = { milestone in
            switch milestone {
            case 25:
                soundService.lightImpact(settings: settings)
            case 50:
                soundService.mediumImpact(settings: settings)
            case 75:
                soundService.heavyImpact(settings: settings)
            case 100:
                soundService.successHaptic(settings: settings)
            default:
                break
            }
        }

        // Animate appearance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            appeared = true
            backgroundGlow = 1.0
        }
    }

    // MARK: - Actions

    private func handleSkip() {
        motionService.stopTracking()
        dismiss()
    }

    private func handleBreakComplete() {
        finalRechargeLevel = motionService.rechargePercentage
        motionService.stopTracking()
        // Skip the break report — just dismiss and go to focus
        dismiss()
    }

    private func handleEarlyExit() {
        // User earned early exit by reaching 100% recharge
        finalRechargeLevel = motionService.rechargePercentage
        motionService.stopTracking()

        // Force-complete the break so onComplete fires and session plans advance properly.
        // Using pause()+reset() would skip onComplete, breaking the session plan flow.
        timerService.forceComplete()

        dismiss()
    }
}

// MARK: - Recharge Background

private struct RechargeBackground: View {
    let intensity: CGFloat
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base dark color
            Color(red: 0.02, green: 0.04, blue: 0.08)

            // Animated gradient blobs
            GeometryReader { geometry in
                ZStack {
                    // Blue/cyan blob (break colors)
                    Circle()
                        .fill(Theme.breakColor.opacity(0.15 * intensity))
                        .frame(width: 350, height: 350)
                        .blur(radius: 100)
                        .offset(
                            x: animateGradient ? 60 : -60,
                            y: animateGradient ? -120 : -180
                        )

                    // Cyan accent blob
                    Circle()
                        .fill(Color.cyan.opacity(0.12 * intensity))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(
                            x: animateGradient ? -100 : 100,
                            y: animateGradient ? 250 : 180
                        )

                    // Subtle teal accent
                    Circle()
                        .fill(Color(red: 0.2, green: 0.6, blue: 0.6).opacity(0.1 * intensity))
                        .frame(width: 250, height: 250)
                        .blur(radius: 70)
                        .offset(
                            x: animateGradient ? 120 : 70,
                            y: animateGradient ? 80 : 140
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RechargeView()
        .environment(MotionService())
        .environment(TimerService(settings: UserSettings(), liveActivityService: LiveActivityService(), notificationService: NotificationService(), wakeUpVoiceService: WakeUpVoiceService()))
        .environment(SoundService())
        .environment(UserSettings())
}
