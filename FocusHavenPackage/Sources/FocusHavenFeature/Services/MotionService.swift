import Foundation
import CoreMotion

/// Detection mode for recharge during breaks
public enum RechargeDetectionMode: String, CaseIterable, Sendable {
    case anyMovement = "anyMovement"
    case walkingOnly = "walkingOnly"

    public var displayName: String {
        switch self {
        case .anyMovement: return "Any Movement"
        case .walkingOnly: return "Walking Only"
        }
    }

    public var description: String {
        switch self {
        case .anyMovement: return "Shake or move your phone"
        case .walkingOnly: return "Actual steps required"
        }
    }

    public var icon: String {
        switch self {
        case .anyMovement: return "iphone.radiowaves.left.and.right"
        case .walkingOnly: return "figure.walk"
        }
    }
}

/// Service for tracking device motion during breaks to encourage movement
@MainActor
@Observable
public final class MotionService: @unchecked Sendable {
    // MARK: - Published State

    /// Current movement intensity normalized to 0.0-1.0
    public private(set) var movementIntensity: Double = 0

    /// Accumulated recharge percentage from 0-100
    public private(set) var rechargePercentage: Double = 0

    /// Whether motion tracking is available on this device
    public var isAvailable: Bool {
        motionManager.isAccelerometerAvailable || CMMotionActivityManager.isActivityAvailable()
    }

    /// Whether activity detection (walking) is available
    public var isActivityAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable() && CMPedometer.isStepCountingAvailable()
    }

    /// Whether we're currently tracking motion
    public private(set) var isTracking: Bool = false

    /// Current detected activity (for walking mode)
    public private(set) var currentActivity: String = "stationary"

    /// Steps taken during this tracking session
    public private(set) var stepsTaken: Int = 0

    // MARK: - Callbacks

    /// Called when recharge reaches milestones (25%, 50%, 75%, 100%)
    public var onMilestoneReached: ((Int) -> Void)?

    /// Called when activity changes (walking mode only)
    public var onActivityChanged: ((String) -> Void)?

    // MARK: - Private State

    private let motionManager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    private var smoothedMovement: Double = 0
    private var lastMilestone: Int = 0
    private let updateInterval: TimeInterval = 1.0 / 30.0 // 30Hz

    private var trackingStartDate: Date?
    private var currentMode: RechargeDetectionMode = .anyMovement

    // Movement algorithm constants (accelerometer mode)
    private let gravityBaseline: Double = 1.0
    private let smoothingAlpha: Double = 0.3
    private let activeMovementThreshold: Double = 0.3  // Lowered: easier to reach higher intensity
    private let rechargeAccumulationRate: Double = 0.06  // Increased 4x: ~1.8%/sec at max, 100% in ~2 min active movement
    private let minimumMovementThreshold: Double = 0.1 // Lowered: more responsive to light movement

    // Walking mode constants
    private let stepsForFullRecharge: Int = 100 // Reduced: ~1-2 min of walking for full recharge
    private let rechargePerStep: Double = 1.0 // 100% / 100 steps

    // Track verified steps (only counted when actually walking)
    private var lastVerifiedSteps: Int = 0
    private var isActuallyWalking: Bool = false
    private var lastWalkingTime: Date?
    private let walkingGracePeriod: TimeInterval = 3.0 // seconds to wait before discarding steps
    private var trackingSessionID: UUID?  // Guard against stale pedometer callbacks after reset

    // MARK: - Instant Walking Detection (Accelerometer Pattern Recognition)

    /// Whether accelerometer detects walking-like pattern (instant detection)
    private var isProbablyWalking: Bool = false

    /// Whether CMMotionActivityManager has confirmed activity (delayed but accurate)
    private var hasActivityConfirmation: Bool = false

    // Walking pattern detection using peak analysis
    private var recentPeakTimes: [Date] = []
    private var lastPeakMagnitude: Double = 0
    private var isRising: Bool = false
    private let peakHistorySize: Int = 10

    // Walking frequency range: 1.3 - 2.5 Hz (78-150 steps/min is normal walking range)
    private let minWalkingFrequency: Double = 1.3  // Hz
    private let maxWalkingFrequency: Double = 2.5  // Hz
    private let walkingPeakThreshold: Double = 0.12 // Minimum peak magnitude to count
    private let rhythmConsistencyThreshold: Double = 0.3 // How consistent peaks must be (lower = stricter)

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Start tracking device motion with specified mode
    public func startTracking(mode: RechargeDetectionMode = .anyMovement) {
        guard !isTracking else { return }

        currentMode = mode
        isTracking = true
        trackingStartDate = Date()
        trackingSessionID = UUID()

        switch mode {
        case .anyMovement:
            startAccelerometerTracking()
        case .walkingOnly:
            startActivityTracking()
        }
    }

    /// Stop tracking device motion
    public func stopTracking() {
        guard isTracking else { return }

        motionManager.stopAccelerometerUpdates()
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()

        isTracking = false
        trackingStartDate = nil
        trackingSessionID = nil
    }

    /// Reset all tracking state
    public func reset() {
        smoothedMovement = 0
        movementIntensity = 0
        rechargePercentage = 0
        lastMilestone = 0
        stepsTaken = 0
        currentActivity = "stationary"
        lastVerifiedSteps = 0
        isActuallyWalking = false
        lastWalkingTime = nil
        // Reset instant walking detection
        isProbablyWalking = false
        hasActivityConfirmation = false
        recentPeakTimes = []
        lastPeakMagnitude = 0
        isRising = false
    }

    // MARK: - Accelerometer Mode (Any Movement)

    private func startAccelerometerTracking() {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = updateInterval

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self, let data else { return }

            Task { @MainActor in
                self.processAccelerometerData(data)
            }
        }
    }

    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z

        // Calculate magnitude and subtract gravity baseline
        let magnitude = sqrt(x * x + y * y + z * z)
        let netMovement = abs(magnitude - gravityBaseline)

        // Apply exponential moving average for smoothing
        smoothedMovement = smoothingAlpha * netMovement + (1 - smoothingAlpha) * smoothedMovement

        // Normalize to 0-1 range (threshold ~0.5g for active movement)
        movementIntensity = min(1.0, smoothedMovement / activeMovementThreshold)

        // BUG FIX: Only accumulate recharge if movement is above minimum threshold
        // This prevents tiny residual movements from slowly increasing percentage
        if rechargePercentage < 100 && movementIntensity > minimumMovementThreshold {
            rechargePercentage = min(100, rechargePercentage + movementIntensity * rechargeAccumulationRate)
            checkMilestones()
        }
    }

    // MARK: - Activity Mode (Walking Only)

    private func startActivityTracking() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            // Fall back to accelerometer if activity not available
            startAccelerometerTracking()
            return
        }

        // Start accelerometer for real-time visual feedback (orb animation)
        // This gives instant response while pedometer provides accurate step counting
        startAccelerometerForVisualFeedback()

        // Start activity updates for activity type display
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }

            Task { @MainActor in
                self.processActivity(activity)
            }
        }

        // Start pedometer for step counting (this drives recharge percentage)
        guard let startDate = trackingStartDate else { return }

        let sessionID = trackingSessionID
        pedometer.startUpdates(from: startDate) { [weak self] pedometerData, error in
            guard let self, let data = pedometerData else { return }

            Task { @MainActor in
                // Ignore stale callbacks from a previous tracking session
                guard self.trackingSessionID == sessionID else { return }
                self.processSteps(data)
            }
        }
    }

    /// Accelerometer for visual feedback only (doesn't affect recharge in walking mode)
    private func startAccelerometerForVisualFeedback() {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = updateInterval

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self, let data else { return }

            Task { @MainActor in
                self.processAccelerometerForVisualFeedback(data)
            }
        }
    }

    /// Process accelerometer data for visual feedback AND instant walking detection
    /// Updates movementIntensity for orb animation and detects walking pattern
    private func processAccelerometerForVisualFeedback(_ data: CMAccelerometerData) {
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z

        // Calculate magnitude and subtract gravity baseline
        let magnitude = sqrt(x * x + y * y + z * z)
        let netMovement = abs(magnitude - gravityBaseline)

        // Apply exponential moving average for smoothing
        smoothedMovement = smoothingAlpha * netMovement + (1 - smoothingAlpha) * smoothedMovement

        // Normalize to 0-1 range for visual feedback
        movementIntensity = min(1.0, smoothedMovement / activeMovementThreshold)

        // INSTANT WALKING DETECTION: Detect walking pattern from accelerometer
        detectWalkingPattern(magnitude: netMovement)
    }

    /// Detects walking pattern by analyzing rhythmic peaks in acceleration
    /// Walking creates a characteristic bounce pattern at 1.3-2.5 Hz
    private func detectWalkingPattern(magnitude: Double) {
        let now = Date()

        // Peak detection: detect when magnitude transitions from rising to falling
        if magnitude > lastPeakMagnitude {
            isRising = true
        } else if isRising && magnitude < lastPeakMagnitude {
            // We just passed a peak
            isRising = false

            // Only count significant peaks (filters out noise)
            if lastPeakMagnitude > walkingPeakThreshold {
                recentPeakTimes.append(now)

                // Keep only recent peaks
                if recentPeakTimes.count > peakHistorySize {
                    recentPeakTimes.removeFirst()
                }

                // Analyze rhythm if we have enough peaks
                if recentPeakTimes.count >= 4 {
                    analyzeWalkingRhythm()
                }
            }
        }

        lastPeakMagnitude = magnitude

        // Decay: if no peaks for 1.5 seconds, probably stopped walking
        if let lastPeak = recentPeakTimes.last {
            if now.timeIntervalSince(lastPeak) > 1.5 {
                isProbablyWalking = false
            }
        }
    }

    /// Analyzes peak timing to determine if pattern matches walking rhythm
    private func analyzeWalkingRhythm() {
        guard recentPeakTimes.count >= 4 else { return }

        // Calculate intervals between consecutive peaks
        var intervals: [TimeInterval] = []
        for i in 1..<recentPeakTimes.count {
            let interval = recentPeakTimes[i].timeIntervalSince(recentPeakTimes[i - 1])
            intervals.append(interval)
        }

        // Calculate average interval and frequency
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let frequency = 1.0 / avgInterval

        // Check if frequency is in walking range
        let isWalkingFrequency = frequency >= minWalkingFrequency && frequency <= maxWalkingFrequency

        // Check rhythm consistency (standard deviation / mean)
        let mean = avgInterval
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)
        let coefficientOfVariation = stdDev / mean

        // Walking has consistent rhythm (low variation)
        let isConsistentRhythm = coefficientOfVariation < rhythmConsistencyThreshold

        // Update probable walking status
        isProbablyWalking = isWalkingFrequency && isConsistentRhythm
    }

    private func processActivity(_ activity: CMMotionActivity) {
        let previousActivity = currentActivity

        // Mark that we've received confirmation from CMMotionActivityManager
        hasActivityConfirmation = true

        if activity.walking {
            currentActivity = "walking"
            isActuallyWalking = true
            lastWalkingTime = Date()
        } else if activity.running {
            currentActivity = "running"
            isActuallyWalking = true  // Running also counts
            lastWalkingTime = Date()
        } else if activity.cycling {
            currentActivity = "cycling"
            isActuallyWalking = false
            // CMMotionActivityManager says not walking - override accelerometer guess
            isProbablyWalking = false
        } else if activity.stationary {
            currentActivity = "stationary"
            isActuallyWalking = false
            // CMMotionActivityManager confidently says stationary - override accelerometer
            // But only if confidence is high (stationary is definitive)
            if activity.confidence == .high {
                isProbablyWalking = false
            }
        } else if isProbablyWalking {
            currentActivity = "walking"
            isActuallyWalking = true
            lastWalkingTime = Date()
        } else {
            currentActivity = "stationary"
            isActuallyWalking = false
        }

        if currentActivity != previousActivity {
            onActivityChanged?(currentActivity)
        }
    }

    private func processSteps(_ data: CMPedometerData) {
        let totalSteps = data.numberOfSteps.intValue

        // Simply count ALL pedometer steps — the pedometer is accurate enough
        // and already filters out non-walking motion internally.
        // Previous approach of discarding steps when "not walking" caused
        // resumed walking after a pause to not be counted.
        let newSteps = totalSteps - lastVerifiedSteps

        if newSteps > 0 {
            stepsTaken += newSteps
            lastVerifiedSteps = totalSteps

            // Calculate recharge based on total steps
            let newRechargePercentage = min(100, Double(stepsTaken) * rechargePerStep)

            if newRechargePercentage > rechargePercentage {
                rechargePercentage = newRechargePercentage
                checkMilestones()
            }
        }
    }

    // MARK: - Milestones

    private func checkMilestones() {
        let currentPercentage = Int(rechargePercentage)

        // Check each milestone threshold
        let milestones = [25, 50, 75, 100]

        for milestone in milestones {
            if currentPercentage >= milestone && lastMilestone < milestone {
                lastMilestone = milestone
                onMilestoneReached?(milestone)
            }
        }
    }
}
