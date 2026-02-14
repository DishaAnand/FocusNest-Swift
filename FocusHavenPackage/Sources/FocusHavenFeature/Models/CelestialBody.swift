import Foundation
import SwiftData
import SwiftUI

/// Types of celestial objects in the user's personal universe
public enum CelestialType: String, Codable, Sendable {
    case star
    case planet
    case moon
}

/// A celestial body representing focus sessions in the user's personal universe
@Model
public final class CelestialBody: @unchecked Sendable {
    public var id: UUID
    public var type: CelestialType
    public var taskId: UUID?
    public var taskName: String
    public var position: CelestialPosition
    public var size: Double
    public var colorHex: String
    public var glowColorHex: String
    public var createdAt: Date
    public var sessionIds: [UUID]
    public var constellationId: UUID?
    public var constellationName: String?
    /// Weight toward planet formation (based on session duration)
    /// < 15 min = 0.5, 15-29 min = 1.0, 30-44 min = 1.5, 45+ min = 2.0
    public var weight: Double
    /// Whether this star was earned after a fully recharged break (100%)
    public var isRecharged: Bool
    /// Recharge level from the break before this session (0-100)
    public var rechargeLevel: Double

    public init(
        id: UUID = UUID(),
        type: CelestialType = .star,
        taskId: UUID? = nil,
        taskName: String = "",
        position: CelestialPosition = CelestialPosition(x: 0.5, y: 0.5),
        size: Double = 8,
        colorHex: String = "#FFFFFF",
        glowColorHex: String = "#FFFFFF",
        createdAt: Date = Date(),
        sessionIds: [UUID] = [],
        constellationId: UUID? = nil,
        constellationName: String? = nil,
        weight: Double = 1.0,
        isRecharged: Bool = false,
        rechargeLevel: Double = 0.0
    ) {
        self.id = id
        self.type = type
        self.taskId = taskId
        self.taskName = taskName
        self.position = position
        self.size = size
        self.colorHex = colorHex
        self.glowColorHex = glowColorHex
        self.createdAt = createdAt
        self.sessionIds = sessionIds
        self.constellationId = constellationId
        self.constellationName = constellationName
        self.weight = weight
        self.isRecharged = isRecharged
        self.rechargeLevel = rechargeLevel
    }
}

// MARK: - Glow Opacity Based on Recharge Level

extension CelestialBody {
    /// Glow opacity scales with recharge level (brighter = better recharged)
    public var glowOpacity: Double {
        switch rechargeLevel {
        case 0..<25: return 0.3
        case 25..<50: return 0.5
        case 50..<75: return 0.7
        case 75..<100: return 0.9
        default: return 1.0  // 100%
        }
    }

    /// Minimum 5 minutes (300 seconds) to earn a star
    public static func shouldCreateStar(duration: Int) -> Bool {
        return duration >= 300
    }
}

// MARK: - Position (Codable for SwiftData storage)

public struct CelestialPosition: Codable, Sendable, Hashable {
    public var x: Double  // 0-1 normalized
    public var y: Double  // 0-1 normalized

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Star Creation from Focus Session

extension CelestialBody {

    /// Create a star from a completed focus session
    /// - Parameter record: The focus record to create a star from
    /// - Parameter previousRechargeLevel: Recharge % from the break before this session (0-100)
    /// - Returns: A new CelestialBody representing the focus session, or nil if duration too short
    public static func createStar(from record: FocusRecord, previousRechargeLevel: Double = 0) -> CelestialBody? {
        // Minimum 5 minutes to earn a star
        guard shouldCreateStar(duration: record.duration) else { return nil }

        let position = generatePosition(for: record.id)
        let size = calculateSize(duration: record.duration)
        let weight = calculateWeight(duration: record.duration)
        let (color, glow) = determineColors(for: record.date)
        let rechargeLevel = record.wasFullyRecharged ? 100.0 : previousRechargeLevel

        return CelestialBody(
            id: UUID(),
            type: .star,
            taskId: record.taskId,
            taskName: record.taskTitle ?? "Focus",
            position: position,
            size: size,
            colorHex: color,
            glowColorHex: glow,
            createdAt: record.date,
            sessionIds: [record.id],
            weight: weight,
            isRecharged: record.wasFullyRecharged,
            rechargeLevel: rechargeLevel
        )
    }

    /// Calculate weight toward planet formation based on session duration
    /// < 15 min = 0.5, 15-29 min = 1.0, 30-44 min = 1.5, 45+ min = 2.0
    private static func calculateWeight(duration: Int) -> Double {
        let minutes = duration / 60
        switch minutes {
        case 0..<15:
            return 0.5
        case 15..<30:
            return 1.0
        case 30..<45:
            return 1.5
        default:
            return 2.0
        }
    }

    /// Generate deterministic position from session ID
    /// Creates organic distribution that's consistent across app launches
    private static func generatePosition(for sessionId: UUID) -> CelestialPosition {
        let hash = sessionId.uuidString.utf8.reduce(0) { $0 &+ Int($1) }

        // Use golden ratio for better distribution
        let goldenRatio = 0.618033988749895
        let x = Double(hash % 1000) / 1000.0
        let y = (x + goldenRatio).truncatingRemainder(dividingBy: 1.0)

        // Add some variance based on different parts of the hash
        let variance1 = Double((hash >> 8) % 100) / 500.0 - 0.1
        let variance2 = Double((hash >> 16) % 100) / 500.0 - 0.1

        // Keep within bounds with padding
        let finalX = min(max(x + variance1, 0.05), 0.95)
        let finalY = min(max(y + variance2, 0.05), 0.95)

        return CelestialPosition(x: finalX, y: finalY)
    }

    /// Calculate star size based on session duration
    /// 5-14 min: 4pt, 15-24 min: 8pt, 25-44 min: 12pt, 45+ min: 16pt
    private static func calculateSize(duration: Int) -> Double {
        let minutes = duration / 60
        switch minutes {
        case 0..<15:
            return 4.0
        case 15..<25:
            return 8.0
        case 25..<45:
            return 12.0
        default:
            return 16.0
        }
    }

    /// Determine star colors based on time of day
    private static func determineColors(for date: Date) -> (color: String, glow: String) {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<11:
            // Morning: Warm white with golden halo
            return ("#FFF8E7", "#FFD700")
        case 11..<17:
            // Afternoon: Pure white
            return ("#FFFFFF", "#FFFFFF")
        case 17..<21:
            // Evening: Soft amber
            return ("#FFB347", "#FF8C00")
        default:
            // Night: Cool blue-white
            return ("#E6F0FF", "#87CEEB")
        }
    }
}

// MARK: - Color Utilities

extension CelestialBody {

    public var color: Color {
        Color(hex: colorHex) ?? .white
    }

    public var glowColor: Color {
        Color(hex: glowColorHex) ?? .white
    }
}

// MARK: - Milestone Planet Creation

extension CelestialBody {

    /// Milestone types for hour-based progression
    public enum MilestoneType: String, Codable, Sendable {
        case smallPlanet      // 3 hours
        case mediumPlanet     // 7 hours
        case planetWithMoon   // 15 hours
        case planetWithRings  // 30 hours
        case gasGiant         // 50 hours
        case sun              // 100 hours
    }

    /// Hour milestones and their rewards
    public static let milestones: [(hours: Double, type: MilestoneType, name: String, color: String, glow: String)] = [
        (3, .smallPlanet, "First Light", "#4A90D9", "#6BB3F0"),         // Blue
        (7, .mediumPlanet, "Rising World", "#7B5BB7", "#9B7DD4"),       // Purple
        (15, .planetWithMoon, "Companion", "#E8A838", "#FFD700"),       // Gold
        (30, .planetWithRings, "Ringed Wonder", "#D85A3D", "#FF6B4A"), // Orange
        (50, .gasGiant, "Giant", "#2E8B57", "#3CB371"),                 // Green
        (100, .sun, "Your Sun", "#FFD700", "#FFA500")                   // Golden sun
    ]

    /// Calculate total focus hours from records
    public static func totalFocusHours(from records: [FocusRecord]) -> Double {
        let focusSessions = records.filter { !$0.isBreak }
        let totalSeconds = focusSessions.reduce(0) { $0 + $1.duration }
        return Double(totalSeconds) / 3600.0
    }

    /// Get unlocked milestone indices based on total hours
    public static func unlockedMilestoneCount(totalHours: Double) -> Int {
        return milestones.filter { $0.hours <= totalHours }.count
    }

    /// Sync milestone planets - creates any missing planets based on total hours
    @MainActor
    public static func syncMilestonePlanets(
        totalHours: Double,
        existingBodies: [CelestialBody],
        modelContext: ModelContext
    ) {
        let unlockedCount = unlockedMilestoneCount(totalHours: totalHours)
        let existingPlanets = existingBodies.filter { $0.type == .planet }.sorted { $0.createdAt < $1.createdAt }

        // Create any missing milestone planets
        for index in existingPlanets.count..<unlockedCount {
            let milestone = milestones[index]
            let planet = createMilestonePlanet(milestone: milestone, index: index)
            modelContext.insert(planet)
        }

        try? modelContext.save()
    }

    /// Create a milestone planet with nice positioning
    private static func createMilestonePlanet(
        milestone: (hours: Double, type: MilestoneType, name: String, color: String, glow: String),
        index: Int
    ) -> CelestialBody {
        // Position planets in a nice arc across the universe
        let angle = Double(index) * 0.5 + 0.8  // Spread across upper area
        let radius = 0.2 + Double(index) * 0.06
        let x = 0.5 + cos(angle * .pi) * radius
        let y = 0.35 + sin(angle * .pi) * radius * 0.4  // Keep in upper half

        let size = planetSize(for: milestone.type)

        return CelestialBody(
            id: UUID(),
            type: .planet,
            taskId: nil,
            taskName: milestone.name,
            position: CelestialPosition(x: min(max(x, 0.1), 0.9), y: min(max(y, 0.1), 0.5)),
            size: size,
            colorHex: milestone.color,
            glowColorHex: milestone.glow,
            createdAt: Date(),
            sessionIds: [],
            weight: milestone.hours
        )
    }

    /// Planet size based on milestone type
    private static func planetSize(for type: MilestoneType) -> Double {
        switch type {
        case .smallPlanet: return 14.0
        case .mediumPlanet: return 18.0
        case .planetWithMoon: return 20.0
        case .planetWithRings: return 24.0
        case .gasGiant: return 28.0
        case .sun: return 32.0
        }
    }

    /// Check if this planet should have moons (15+ hours milestone)
    public var hasMoons: Bool {
        guard type == .planet else { return false }
        return weight >= 15
    }

    /// Check if this planet should have rings (30+ hours milestone)
    public var hasRings: Bool {
        guard type == .planet else { return false }
        return weight >= 30
    }

    /// Check if this is the sun (100+ hours milestone)
    public var isSun: Bool {
        guard type == .planet else { return false }
        return weight >= 100
    }
}

