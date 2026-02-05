import Foundation

public enum ParticipantStatus: String, Codable, Sendable {
    case focused = "focused"
    case away = "away"
    case waiting = "waiting"
}

public struct SessionParticipant: Codable, Sendable, Identifiable, Equatable {
    public var id: String { odid }
    public let odid: String
    public var name: String
    public var taskTitle: String
    public var duration: Int  // Each participant has their own duration
    public var status: ParticipantStatus
    public var violationCount: Int
    public var totalAwayTime: Int  // Total seconds spent away (distracted)
    public var joinedAt: TimeInterval
    public var rating: Int?

    public init(
        odid: String,
        name: String,
        taskTitle: String,
        duration: Int = 25 * 60,
        status: ParticipantStatus = .waiting,
        violationCount: Int = 0,
        totalAwayTime: Int = 0,
        joinedAt: TimeInterval = Date().timeIntervalSince1970,
        rating: Int? = nil
    ) {
        self.odid = odid
        self.name = name
        self.taskTitle = taskTitle
        self.duration = duration
        self.status = status
        self.violationCount = violationCount
        self.totalAwayTime = totalAwayTime
        self.joinedAt = joinedAt
        self.rating = rating
    }
}

public enum SessionState: String, Codable, Sendable {
    case waiting = "waiting"
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"
}

public struct BuddySession: Codable, Sendable, Identifiable, Equatable {
    public var id: String { sessionId }
    public let sessionId: String
    public let creatorId: String
    public var state: SessionState
    public var duration: Int
    public var startTime: TimeInterval?
    public var endTime: TimeInterval?
    public var participants: [String: SessionParticipant]
    public var createdAt: TimeInterval

    public init(
        sessionId: String = UUID().uuidString,
        creatorId: String,
        state: SessionState = .waiting,
        duration: Int = 25 * 60,
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil,
        participants: [String: SessionParticipant] = [:],
        createdAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.sessionId = sessionId
        self.creatorId = creatorId
        self.state = state
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.participants = participants
        self.createdAt = createdAt
    }

    /// Short 4-character code for easy sharing
    public var shortCode: String {
        String(sessionId.prefix(4)).uppercased()
    }

    /// Deep link for direct app opening
    public var deepLink: String {
        "focushaven://buddy/\(sessionId)"
    }

    public var participantCount: Int {
        participants.count
    }

    public var isReadyToStart: Bool {
        participantCount >= 2
    }

    public func participant(withId id: String) -> SessionParticipant? {
        participants[id]
    }

    public func otherParticipants(exceptId: String) -> [SessionParticipant] {
        participants.values.filter { $0.odid != exceptId }
    }

    public func remainingTime(currentTime: TimeInterval) -> Int {
        guard let start = startTime else { return duration }
        let elapsed = Int(currentTime - start)
        return max(0, duration - elapsed)
    }

    public func progress(currentTime: TimeInterval) -> Double {
        guard let start = startTime else { return 0.0 }
        let elapsed = currentTime - start
        return min(1.0, max(0.0, elapsed / Double(duration)))
    }

    /// Get remaining time for a specific participant (independent timers)
    public func remainingTimeForParticipant(_ participantId: String, currentTime: TimeInterval) -> Int {
        guard let start = startTime,
              let participant = participants[participantId] else { return 0 }
        let elapsed = Int(currentTime - start)
        return max(0, participant.duration - elapsed)
    }

    /// Check if a specific participant has completed their timer
    public func isParticipantComplete(_ participantId: String, currentTime: TimeInterval) -> Bool {
        remainingTimeForParticipant(participantId, currentTime: currentTime) <= 0
    }
}
