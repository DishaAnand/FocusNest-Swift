import Foundation
import FirebaseDatabase

@MainActor
@Observable
public final class SessionService: @unchecked Sendable {
    public private(set) var currentSession: BuddySession?
    public private(set) var isLoading: Bool = false
    public private(set) var error: String?
    public let deviceId: String

    private var database: DatabaseReference?
    private var sessionObserver: DatabaseHandle?
    private var isFirebaseConfigured: Bool = false

    public init() {
        if let existingId = UserDefaults.standard.string(forKey: "deviceId") {
            self.deviceId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "deviceId")
            self.deviceId = newId
        }
    }

    public func configure() {
        database = Database.database().reference()
        isFirebaseConfigured = true
    }

    public func createSession(taskTitle: String, duration: Int, userName: String) async throws -> BuddySession {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }
        isLoading = true
        error = nil
        defer { isLoading = false }

        let sessionId = UUID().uuidString
        let participant = SessionParticipant(odid: deviceId, name: userName, taskTitle: taskTitle)
        let session = BuddySession(sessionId: sessionId, creatorId: deviceId, duration: duration, participants: [deviceId: participant])

        let sessionRef = db.child("sessions").child(sessionId)
        try await sessionRef.setValue(session.toDictionary())
        currentSession = session
        startObservingSession(sessionId: sessionId)
        return session
    }

    public func joinSession(sessionId: String, taskTitle: String, userName: String) async throws -> BuddySession {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }
        isLoading = true
        error = nil
        defer { isLoading = false }

        let sessionRef = db.child("sessions").child(sessionId)
        let snapshot = try await sessionRef.getData()
        guard snapshot.exists(), let data = snapshot.value as? [String: Any] else { throw SessionError.sessionNotFound }
        guard var session = BuddySession(from: data) else { throw SessionError.invalidSessionData }
        guard session.state == .waiting else { throw SessionError.sessionAlreadyStarted }

        let participant = SessionParticipant(odid: deviceId, name: userName, taskTitle: taskTitle)
        session.participants[deviceId] = participant
        try await sessionRef.child("participants").child(deviceId).setValue(participant.toDictionary())
        currentSession = session
        startObservingSession(sessionId: sessionId)
        return session
    }

    public func startSession() async throws {
        guard var session = currentSession else { throw SessionError.noActiveSession }
        guard session.creatorId == deviceId else { throw SessionError.notSessionCreator }
        guard session.isReadyToStart else { throw SessionError.notEnoughParticipants }
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }

        let startTime = Date().timeIntervalSince1970
        try await db.child("sessions").child(session.sessionId).updateChildValues(["state": SessionState.active.rawValue, "startTime": startTime])
        session.state = .active
        session.startTime = startTime
        currentSession = session
    }

    public func updateStatus(_ status: ParticipantStatus) async throws {
        guard let session = currentSession, isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }
        try await db.child("sessions").child(session.sessionId).child("participants").child(deviceId).child("status").setValue(status.rawValue)
    }

    public func incrementViolation() async throws {
        guard let session = currentSession, let participant = session.participant(withId: deviceId), isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }
        try await db.child("sessions").child(session.sessionId).child("participants").child(deviceId).child("violationCount").setValue(participant.violationCount + 1)
    }

    public func completeSession() async throws {
        guard var session = currentSession, isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }
        try await db.child("sessions").child(session.sessionId).updateChildValues(["state": SessionState.completed.rawValue, "endTime": Date().timeIntervalSince1970])
        session.state = .completed
        session.endTime = Date().timeIntervalSince1970
        currentSession = session
    }

    public func rateBuddy(buddyId: String, rating: Int) async throws {
        guard let session = currentSession, isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }
        try await db.child("sessions").child(session.sessionId).child("participants").child(buddyId).child("rating").setValue(rating)
    }

    public func leaveSession() async throws {
        guard let session = currentSession, isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }
        stopObservingSession()
        if session.participantCount <= 1 || (session.creatorId == deviceId && session.state == .waiting) {
            try await db.child("sessions").child(session.sessionId).child("state").setValue(SessionState.cancelled.rawValue)
        } else {
            try await db.child("sessions").child(session.sessionId).child("participants").child(deviceId).removeValue()
        }
        currentSession = nil
    }

    private func startObservingSession(sessionId: String) {
        guard isFirebaseConfigured, let db = database else { return }
        stopObservingSession()
        sessionObserver = db.child("sessions").child(sessionId).observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self, let data = snapshot.value as? [String: Any], let session = BuddySession(from: data) else { return }
                self.currentSession = session
            }
        }
    }

    private func stopObservingSession() {
        if let observer = sessionObserver, let db = database, let session = currentSession {
            db.child("sessions").child(session.sessionId).removeObserver(withHandle: observer)
        }
        sessionObserver = nil
    }

    public func cleanup() {
        stopObservingSession()
        currentSession = nil
    }
}

public enum SessionError: LocalizedError, Sendable {
    case notConfigured, sessionNotFound, invalidSessionData, sessionAlreadyStarted, noActiveSession, notSessionCreator, notEnoughParticipants

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Firebase is not configured. Please ensure GoogleService-Info.plist is added."
        case .sessionNotFound: return "This session could not be found. It may have expired."
        case .invalidSessionData: return "The session data is invalid."
        case .sessionAlreadyStarted: return "This session has already started."
        case .noActiveSession: return "No active session found."
        case .notSessionCreator: return "Only the session creator can perform this action."
        case .notEnoughParticipants: return "Need at least 2 participants to start."
        }
    }
}

extension BuddySession {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["sessionId": sessionId, "creatorId": creatorId, "state": state.rawValue, "duration": duration, "createdAt": createdAt]
        if let start = startTime { dict["startTime"] = start }
        if let end = endTime { dict["endTime"] = end }
        dict["participants"] = participants.mapValues { $0.toDictionary() }
        return dict
    }

    init?(from dictionary: [String: Any]) {
        guard let sessionId = dictionary["sessionId"] as? String,
              let creatorId = dictionary["creatorId"] as? String,
              let stateRaw = dictionary["state"] as? String, let state = SessionState(rawValue: stateRaw),
              let duration = dictionary["duration"] as? Int,
              let createdAt = dictionary["createdAt"] as? TimeInterval else { return nil }

        self.sessionId = sessionId
        self.creatorId = creatorId
        self.state = state
        self.duration = duration
        self.createdAt = createdAt
        self.startTime = dictionary["startTime"] as? TimeInterval
        self.endTime = dictionary["endTime"] as? TimeInterval
        var participants: [String: SessionParticipant] = [:]
        if let participantsDict = dictionary["participants"] as? [String: [String: Any]] {
            for (key, value) in participantsDict {
                if let p = SessionParticipant(from: value) { participants[key] = p }
            }
        }
        self.participants = participants
    }
}

extension SessionParticipant {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["odid": odid, "name": name, "taskTitle": taskTitle, "status": status.rawValue, "violationCount": violationCount, "joinedAt": joinedAt]
        if let r = rating { dict["rating"] = r }
        return dict
    }

    init?(from dictionary: [String: Any]) {
        guard let odid = dictionary["odid"] as? String, let name = dictionary["name"] as? String,
              let taskTitle = dictionary["taskTitle"] as? String, let statusRaw = dictionary["status"] as? String,
              let status = ParticipantStatus(rawValue: statusRaw), let violationCount = dictionary["violationCount"] as? Int,
              let joinedAt = dictionary["joinedAt"] as? TimeInterval else { return nil }
        self.odid = odid; self.name = name; self.taskTitle = taskTitle; self.status = status
        self.violationCount = violationCount; self.joinedAt = joinedAt; self.rating = dictionary["rating"] as? Int
    }
}
