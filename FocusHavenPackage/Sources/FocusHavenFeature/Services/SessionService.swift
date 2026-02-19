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

    // MARK: - Code Generation

    private static let codeLetters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ") // no I or O to avoid confusion with 1/0

    private func generateUniqueCode() -> String {
        String((0..<4).map { _ in Self.codeLetters.randomElement()! })
    }

    /// Reserve a unique short code in Firebase using a transaction to prevent collisions
    private func reserveUniqueCode(db: DatabaseReference, sessionId: String) async throws -> String {
        for _ in 0..<10 { // max 10 attempts
            let code = generateUniqueCode()
            let codeRef = db.child("codes").child(code)

            // Atomic check-and-set: only write if the code doesn't exist yet
            let (committed, _) = try await codeRef.runTransactionBlock { currentData in
                if currentData.value is NSNull || currentData.value == nil {
                    // Code is free — claim it
                    currentData.value = [
                        "sessionId": sessionId,
                        "createdAt": ServerValue.timestamp()
                    ] as [String: Any]
                    return .success(withValue: currentData)
                } else {
                    // Code already taken — abort
                    return .abort()
                }
            }

            if committed {
                return code
            }
            // Code was taken, try again with a new one
        }

        // Extremely unlikely: 10 collisions in a row (24^4 = 331,776 combos)
        throw SessionError.codeGenerationFailed
    }

    /// Release a short code from the codes index
    private func releaseCode(_ code: String) async {
        guard let db = database else { return }
        try? await db.child("codes").child(code).removeValue()
    }

    // MARK: - Create Session

    public func createSession(taskTitle: String, duration: Int, userName: String) async throws -> BuddySession {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }
        isLoading = true
        error = nil
        defer { isLoading = false }

        let sessionId = UUID().uuidString
        let shortCode = try await reserveUniqueCode(db: db, sessionId: sessionId)

        let participant = SessionParticipant(odid: deviceId, name: userName, taskTitle: taskTitle, duration: duration)
        let session = BuddySession(sessionId: sessionId, creatorId: deviceId, shortCode: shortCode, duration: duration, participants: [deviceId: participant])

        let sessionRef = db.child("sessions").child(sessionId)
        try await sessionRef.setValue(session.toDictionary())
        currentSession = session
        startObservingSession(sessionId: sessionId)
        return session
    }

    // MARK: - Find Session by Code (O(1) lookup)

    public func findSessionByCode(_ code: String) async throws -> String {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }

        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.count == 4 else { throw SessionError.invalidCode }

        // Direct O(1) lookup in the codes index
        let snapshot = try await db.child("codes").child(normalizedCode).getData()

        guard let data = snapshot.value as? [String: Any],
              let sessionId = data["sessionId"] as? String else {
            throw SessionError.sessionNotFound
        }

        // Verify session is still in waiting state
        let sessionSnapshot = try await db.child("sessions").child(sessionId).child("state").getData()
        guard let stateRaw = sessionSnapshot.value as? String else {
            // Session was deleted — clean up stale code
            await releaseCode(normalizedCode)
            throw SessionError.sessionNotFound
        }

        guard stateRaw == SessionState.waiting.rawValue else {
            throw SessionError.sessionAlreadyStarted
        }

        return sessionId
    }

    public func joinSession(sessionId: String, taskTitle: String, userName: String, duration: Int = 25 * 60) async throws -> BuddySession {
        guard isFirebaseConfigured, let db = database else { throw SessionError.notConfigured }
        isLoading = true
        error = nil
        defer { isLoading = false }

        print("🔵 [SessionService] Joining session: \(sessionId)")
        let sessionRef = db.child("sessions").child(sessionId)
        let snapshot = try await sessionRef.getData()
        guard snapshot.exists(), let data = snapshot.value as? [String: Any] else {
            print("🔴 [SessionService] Session not found or empty data")
            throw SessionError.sessionNotFound
        }
        print("🔵 [SessionService] Session data retrieved: \(data)")
        guard var session = BuddySession(from: data) else {
            print("🔴 [SessionService] Failed to parse session data")
            throw SessionError.invalidSessionData
        }
        print("🔵 [SessionService] Session state: \(session.state.rawValue), participants: \(session.participantCount)")
        // Allow joining if session is waiting OR if this device is already a participant (rejoin case)
        guard session.state == .waiting || session.participants[deviceId] != nil else {
            print("🔴 [SessionService] Session state is \(session.state.rawValue), not waiting. Cannot join.")
            throw SessionError.sessionAlreadyStarted
        }

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
        guard let session = currentSession, isFirebaseConfigured, let db = database else {
            NSLog("[SessionService] updateStatus FAILED - no active session. currentSession=%@, firebase=%@", String(describing: currentSession != nil), String(describing: isFirebaseConfigured))
            throw SessionError.noActiveSession
        }
        NSLog("[SessionService] updateStatus writing '%@' for device '%@' to session '%@'", status.rawValue, deviceId, session.sessionId)
        try await db.child("sessions").child(session.sessionId).child("participants").child(deviceId).child("status").setValue(status.rawValue)
        NSLog("[SessionService] updateStatus SUCCESS - wrote '%@'", status.rawValue)
    }

    public func incrementViolation() async throws {
        guard let session = currentSession, let participant = session.participant(withId: deviceId), isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }
        try await db.child("sessions").child(session.sessionId).child("participants").child(deviceId).child("violationCount").setValue(participant.violationCount + 1)
    }

    public func completeSession() async throws {
        guard var session = currentSession, isFirebaseConfigured, let db = database else { throw SessionError.noActiveSession }
        try await db.child("sessions").child(session.sessionId).updateChildValues(["state": SessionState.completed.rawValue, "endTime": Date().timeIntervalSince1970])
        // Release the short code so it can be reused
        await releaseCode(session.shortCode)
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
            // Release the short code so it can be reused
            await releaseCode(session.shortCode)
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
                // Log participant statuses to trace support mode
                let statusList = session.participants.map { "\($0.key.prefix(4))=\($0.value.status.rawValue)" }.joined(separator: ", ")
                NSLog("[SessionService] Session updated - participants: %d, state: %@, statuses: [%@]", session.participantCount, session.state.rawValue, statusList)
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

    // MARK: - Stale Session Cleanup

    /// Purge sessions and codes older than 24 hours. Run on app launch.
    public func cleanupStaleSessions() async {
        guard isFirebaseConfigured, let db = database else { return }

        let cutoff = Date().timeIntervalSince1970 - (24 * 60 * 60) // 24 hours ago

        do {
            // Find old sessions
            let snapshot = try await db.child("sessions")
                .queryOrdered(byChild: "createdAt")
                .queryEnding(atValue: cutoff)
                .queryLimited(toLast: 50)
                .getData()

            guard let sessions = snapshot.value as? [String: [String: Any]] else { return }

            for (sessionId, data) in sessions {
                let shortCode = data["shortCode"] as? String
                // Delete the session
                try? await db.child("sessions").child(sessionId).removeValue()
                // Delete its code mapping
                if let code = shortCode {
                    try? await db.child("codes").child(code).removeValue()
                }
            }

            if !sessions.isEmpty {
                print("🔵 [SessionService] Cleaned up \(sessions.count) stale sessions")
            }
        } catch {
            // Cleanup is best-effort, don't crash
            print("⚠️ [SessionService] Stale session cleanup failed: \(error.localizedDescription)")
        }
    }
}

public enum SessionError: LocalizedError, Sendable {
    case notConfigured, sessionNotFound, invalidSessionData, sessionAlreadyStarted, noActiveSession, notSessionCreator, notEnoughParticipants, invalidCode, codeGenerationFailed

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
        case .codeGenerationFailed: return "Unable to generate a unique session code. Please try again."
        }
    }
}

extension BuddySession {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["sessionId": sessionId, "creatorId": creatorId, "shortCode": shortCode, "state": state.rawValue, "duration": duration, "createdAt": createdAt]
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
        // Use stored shortCode, fallback to first 4 chars of sessionId for backwards compat
        self.shortCode = (dictionary["shortCode"] as? String) ?? String(sessionId.prefix(4)).uppercased()
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
