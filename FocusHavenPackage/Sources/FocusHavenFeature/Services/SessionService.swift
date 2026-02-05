import Foundation
import FirebaseCore
import FirebaseDatabase

@MainActor
@Observable
public final class SessionService: @unchecked Sendable {
    public private(set) var currentSession: BuddySession?
    public private(set) var isLoading: Bool = false
    public private(set) var error: String?
    public let deviceId: String

    /// Firebase server time offset for accurate timer sync
    /// serverTime ≈ Date.now() + serverTimeOffset
    /// Matches RN: listenToServerTimeOffset()
    public private(set) var serverTimeOffset: TimeInterval = 0

    private var database: DatabaseReference?
    private var sessionObserver: DatabaseHandle?
    private var serverTimeOffsetObserver: DatabaseHandle?
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
        // Initialize Firebase if not already configured
        if FirebaseApp.app() == nil {
            // Only configure if GoogleService-Info.plist exists
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
            } else {
                // Firebase not available - buddy sessions won't work
                print("⚠️ FocusHaven: GoogleService-Info.plist not found. Buddy sessions disabled.")
                return
            }
        }
        database = Database.database().reference()
        isFirebaseConfigured = true
        startListeningToServerTimeOffset()
    }

    /// Current server time accounting for offset
    /// Matches RN: serverTime ≈ Date.now() + offset
    public var serverTime: TimeInterval {
        Date().timeIntervalSince1970 + serverTimeOffset
    }

    /// Start listening to Firebase server time offset
    /// Matches RN: listenToServerTimeOffset()
    /// Note: Firebase returns offset in milliseconds, convert to seconds for TimeInterval
    private func startListeningToServerTimeOffset() {
        guard let db = database else { return }
        serverTimeOffsetObserver = db.child(".info/serverTimeOffset").observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                // Firebase returns milliseconds, convert to seconds
                let offsetMs = (snapshot.value as? Double) ?? 0
                self.serverTimeOffset = offsetMs / 1000.0
                print("🔵 [SessionService] Server time offset: \(offsetMs)ms = \(self.serverTimeOffset)s")
            }
        }
    }

    private func stopListeningToServerTimeOffset() {
        if let observer = serverTimeOffsetObserver, let db = database {
            db.child(".info/serverTimeOffset").removeObserver(withHandle: observer)
        }
        serverTimeOffsetObserver = nil
    }

    public func createSession(taskTitle: String, duration: Int, userName: String) async throws -> BuddySession {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }
        isLoading = true
        error = nil
        defer { isLoading = false }

        let sessionId = UUID().uuidString
        let participant = SessionParticipant(odid: deviceId, name: userName, taskTitle: taskTitle, duration: duration)
        let session = BuddySession(sessionId: sessionId, creatorId: deviceId, duration: duration, participants: [deviceId: participant])

        let sessionRef = db.child("sessions").child(sessionId)
        try await sessionRef.setValue(session.toDictionary())
        currentSession = session
        startObservingSession(sessionId: sessionId)
        return session
    }

    /// Find session by short code (first 4 chars of sessionId)
    public func findSessionByCode(_ code: String) async throws -> String {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }

        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.count >= 4 else { throw SessionError.invalidCode }

        // Query sessions that start with this code
        let snapshot = try await db.child("sessions")
            .queryOrderedByKey()
            .queryStarting(atValue: normalizedCode)
            .queryEnding(atValue: normalizedCode + "\u{f8ff}")
            .queryLimited(toFirst: 1)
            .getData()

        guard let dict = snapshot.value as? [String: Any],
              let firstSessionId = dict.keys.first else {
            throw SessionError.sessionNotFound
        }

        return firstSessionId
    }

    public func joinSession(sessionId: String, taskTitle: String, userName: String, duration: Int = 25 * 60) async throws -> BuddySession {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }
        isLoading = true
        error = nil
        defer { isLoading = false }

        print("🔵 [SessionService] Joining session: \(sessionId)")
        let sessionRef = db.child("sessions").child(sessionId)
        let snapshot = try await sessionRef.getData()
        guard snapshot.exists(), let data = snapshot.value as? [String: Any] else { throw SessionError.sessionNotFound }
        guard var session = BuddySession(from: data) else { throw SessionError.invalidSessionData }
        guard session.state == .waiting else { throw SessionError.sessionAlreadyStarted }

        let participant = SessionParticipant(odid: deviceId, name: userName, taskTitle: taskTitle, duration: duration)
        session.participants[deviceId] = participant
        print("🔵 [SessionService] Adding participant to Firebase...")
        try await sessionRef.child("participants").child(deviceId).setValue(participant.toDictionary())
        print("🟢 [SessionService] Participant added successfully. Total participants: \(session.participantCount)")
        currentSession = session
        startObservingSession(sessionId: sessionId)
        return session
    }

    /// Record a distraction (called when user returns after being away 15+ seconds)
    public func recordDistraction(awayDuration: Int) async throws {
        guard let session = currentSession,
              var participant = session.participant(withId: deviceId),
              isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }

        participant.violationCount += 1
        participant.totalAwayTime += awayDuration

        let participantRef = db.child("sessions").child(session.sessionId).child("participants").child(deviceId)
        try await participantRef.updateChildValues([
            "violationCount": participant.violationCount,
            "totalAwayTime": participant.totalAwayTime
        ])
    }

    public func startSession() async throws {
        guard var session = currentSession else { throw SessionError.noActiveSession }
        guard session.creatorId == deviceId else { throw SessionError.notSessionCreator }
        guard session.isReadyToStart else { throw SessionError.notEnoughParticipants }
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }

        // Use server time for accurate sync between devices
        let startTime = serverTime

        // Update session state and set all participants to focused
        var updates: [String: Any] = [
            "state": SessionState.active.rawValue,
            "startTime": startTime
        ]
        for participantId in session.participants.keys {
            updates["participants/\(participantId)/status"] = ParticipantStatus.focused.rawValue
        }

        try await db.child("sessions").child(session.sessionId).updateChildValues(updates)
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
        print("🔵 [SessionService] Starting to observe session: \(sessionId)")
        sessionObserver = db.child("sessions").child(sessionId).observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                print("🔵 [SessionService] Received Firebase update for session")
                guard let self else {
                    print("🔴 [SessionService] Self is nil")
                    return
                }
                guard let data = snapshot.value as? [String: Any] else {
                    print("🔴 [SessionService] Failed to parse snapshot as dictionary")
                    return
                }
                guard let session = BuddySession(from: data) else {
                    print("🔴 [SessionService] Failed to create BuddySession from data: \(data)")
                    return
                }
                print("🟢 [SessionService] Session updated - participants: \(session.participantCount), state: \(session.state), isReady: \(session.isReadyToStart)")
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
        stopListeningToServerTimeOffset()
        currentSession = nil
    }
}

public enum SessionError: LocalizedError, Sendable {
    case notConfigured, sessionNotFound, invalidSessionData, sessionAlreadyStarted, noActiveSession, notSessionCreator, notEnoughParticipants, invalidCode

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Firebase is not configured. Please ensure GoogleService-Info.plist is added."
        case .sessionNotFound: return "No session found with this code. Check the code and try again."
        case .invalidSessionData: return "The session data is invalid."
        case .sessionAlreadyStarted: return "This session has already started."
        case .noActiveSession: return "No active session found."
        case .notSessionCreator: return "Only the session creator can perform this action."
        case .notEnoughParticipants: return "Need at least 2 participants to start."
        case .invalidCode: return "Please enter a valid 4-character session code."
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
        var dict: [String: Any] = [
            "odid": odid,
            "name": name,
            "taskTitle": taskTitle,
            "duration": duration,
            "status": status.rawValue,
            "violationCount": violationCount,
            "totalAwayTime": totalAwayTime,
            "joinedAt": joinedAt
        ]
        if let r = rating { dict["rating"] = r }
        return dict
    }

    init?(from dictionary: [String: Any]) {
        guard let odid = dictionary["odid"] as? String,
              let name = dictionary["name"] as? String,
              let taskTitle = dictionary["taskTitle"] as? String,
              let statusRaw = dictionary["status"] as? String,
              let status = ParticipantStatus(rawValue: statusRaw),
              let joinedAt = dictionary["joinedAt"] as? TimeInterval else { return nil }
        self.odid = odid
        self.name = name
        self.taskTitle = taskTitle
        self.duration = (dictionary["duration"] as? Int) ?? 25 * 60  // Default 25 min for backwards compat
        self.status = status
        self.violationCount = (dictionary["violationCount"] as? Int) ?? 0
        self.totalAwayTime = (dictionary["totalAwayTime"] as? Int) ?? 0
        self.joinedAt = joinedAt
        self.rating = dictionary["rating"] as? Int
    }
}
