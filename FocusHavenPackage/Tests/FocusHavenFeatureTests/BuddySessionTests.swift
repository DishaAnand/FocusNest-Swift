import Testing
import Foundation
@testable import FocusHavenFeature

@Suite("BuddySession Tests - Matching RN sessionService.ts")
struct BuddySessionTests {

    // MARK: - SessionParticipant Tests

    @Test("SessionParticipant initializes with correct defaults")
    func participantInitDefaults() {
        let participant = SessionParticipant(odid: "device-123", name: "John", taskTitle: "Study")
        #expect(participant.odid == "device-123")
        #expect(participant.name == "John")
        #expect(participant.taskTitle == "Study")
        #expect(participant.status == .waiting)
        #expect(participant.violationCount == 0)
        #expect(participant.rating == nil)
    }

    @Test("SessionParticipant id returns odid")
    func participantIdIsOdid() {
        let participant = SessionParticipant(odid: "device-456", name: "Jane", taskTitle: "Work")
        #expect(participant.id == "device-456")
    }

    @Test("SessionParticipant toDictionary serializes correctly")
    func participantToDictionary() {
        let participant = SessionParticipant(
            odid: "device-123",
            name: "John",
            taskTitle: "Study",
            status: .focused,
            violationCount: 2,
            joinedAt: 1234567890,
            rating: 5
        )
        let dict = participant.toDictionary()
        #expect(dict["odid"] as? String == "device-123")
        #expect(dict["name"] as? String == "John")
        #expect(dict["taskTitle"] as? String == "Study")
        #expect(dict["status"] as? String == "focused")
        #expect(dict["violationCount"] as? Int == 2)
        #expect(dict["joinedAt"] as? TimeInterval == 1234567890)
        #expect(dict["rating"] as? Int == 5)
    }

    @Test("SessionParticipant init from dictionary works")
    func participantFromDictionary() {
        let dict: [String: Any] = [
            "odid": "device-123",
            "name": "John",
            "taskTitle": "Study",
            "status": "focused",
            "violationCount": 2,
            "joinedAt": 1234567890.0,
            "rating": 5
        ]
        let participant = SessionParticipant(from: dict)
        #expect(participant != nil)
        #expect(participant?.odid == "device-123")
        #expect(participant?.name == "John")
        #expect(participant?.status == .focused)
        #expect(participant?.violationCount == 2)
        #expect(participant?.rating == 5)
    }

    @Test("SessionParticipant init from dictionary fails on missing fields")
    func participantFromDictionaryFailsMissingFields() {
        let incompleteDict: [String: Any] = [
            "odid": "device-123"
            // Missing required fields
        ]
        let participant = SessionParticipant(from: incompleteDict)
        #expect(participant == nil)
    }

    // MARK: - ParticipantStatus Tests

    @Test("ParticipantStatus raw values match RN")
    func participantStatusRawValues() {
        // RN: creatorStatus: "focused" | "away", friendStatus: "waiting" | "focused" | "away"
        #expect(ParticipantStatus.focused.rawValue == "focused")
        #expect(ParticipantStatus.away.rawValue == "away")
        #expect(ParticipantStatus.waiting.rawValue == "waiting")
    }

    // MARK: - SessionState Tests

    @Test("SessionState raw values match RN")
    func sessionStateRawValues() {
        // RN: status: "waiting" | "active" | "complete"
        #expect(SessionState.waiting.rawValue == "waiting")
        #expect(SessionState.active.rawValue == "active")
        #expect(SessionState.completed.rawValue == "completed")
        #expect(SessionState.cancelled.rawValue == "cancelled")
        #expect(SessionState.paused.rawValue == "paused")
    }

    // MARK: - BuddySession Tests

    @Test("BuddySession initializes with correct defaults")
    func sessionInitDefaults() {
        let session = BuddySession(creatorId: "device-123")
        #expect(session.creatorId == "device-123")
        #expect(session.state == .waiting)
        #expect(session.duration == 25 * 60)  // 25 minutes in seconds
        #expect(session.startTime == nil)
        #expect(session.endTime == nil)
        #expect(session.participants.isEmpty)
    }

    @Test("BuddySession id returns sessionId")
    func sessionIdReturnsSessionId() {
        let session = BuddySession(sessionId: "test-session", creatorId: "device-123")
        #expect(session.id == "test-session")
    }

    @Test("BuddySession shareLink generates correct URL")
    func sessionShareLink() {
        // Matches RN deep link format: focushaven://buddy/{sessionId}
        let session = BuddySession(sessionId: "abc123", creatorId: "device-123")
        #expect(session.shareLink == "focushaven://buddy/abc123")
    }

    @Test("BuddySession participantCount returns correct count")
    func sessionParticipantCount() {
        var session = BuddySession(creatorId: "device-1")
        #expect(session.participantCount == 0)

        session.participants["device-1"] = SessionParticipant(odid: "device-1", name: "Creator", taskTitle: "Task1")
        #expect(session.participantCount == 1)

        session.participants["device-2"] = SessionParticipant(odid: "device-2", name: "Friend", taskTitle: "Task2")
        #expect(session.participantCount == 2)
    }

    @Test("BuddySession isReadyToStart requires 2 participants")
    func sessionIsReadyToStart() {
        // Matches RN: session needs creator + friend
        var session = BuddySession(creatorId: "device-1")
        #expect(session.isReadyToStart == false)

        session.participants["device-1"] = SessionParticipant(odid: "device-1", name: "Creator", taskTitle: "Task1")
        #expect(session.isReadyToStart == false)

        session.participants["device-2"] = SessionParticipant(odid: "device-2", name: "Friend", taskTitle: "Task2")
        #expect(session.isReadyToStart == true)
    }

    @Test("BuddySession participant(withId:) returns correct participant")
    func sessionParticipantById() {
        var session = BuddySession(creatorId: "device-1")
        session.participants["device-1"] = SessionParticipant(odid: "device-1", name: "Creator", taskTitle: "Task1")
        session.participants["device-2"] = SessionParticipant(odid: "device-2", name: "Friend", taskTitle: "Task2")

        let creator = session.participant(withId: "device-1")
        #expect(creator?.name == "Creator")

        let friend = session.participant(withId: "device-2")
        #expect(friend?.name == "Friend")

        let notFound = session.participant(withId: "device-3")
        #expect(notFound == nil)
    }

    @Test("BuddySession otherParticipants excludes given id")
    func sessionOtherParticipants() {
        var session = BuddySession(creatorId: "device-1")
        session.participants["device-1"] = SessionParticipant(odid: "device-1", name: "Creator", taskTitle: "Task1")
        session.participants["device-2"] = SessionParticipant(odid: "device-2", name: "Friend", taskTitle: "Task2")

        let others = session.otherParticipants(exceptId: "device-1")
        #expect(others.count == 1)
        #expect(others.first?.name == "Friend")
    }

    @Test("BuddySession remainingTime calculates correctly")
    func sessionRemainingTime() {
        var session = BuddySession(creatorId: "device-1", duration: 25 * 60)

        // No start time, returns full duration
        #expect(session.remainingTime(currentTime: 1000) == 25 * 60)

        // With start time, calculates elapsed
        session.startTime = 1000
        #expect(session.remainingTime(currentTime: 1000) == 25 * 60)  // 0 elapsed
        #expect(session.remainingTime(currentTime: 1060) == 24 * 60)  // 60 seconds elapsed
        #expect(session.remainingTime(currentTime: 1000 + 25 * 60) == 0)  // Full duration elapsed
        #expect(session.remainingTime(currentTime: 1000 + 30 * 60) == 0)  // Past duration, clamped to 0
    }

    @Test("BuddySession progress calculates correctly")
    func sessionProgress() {
        var session = BuddySession(creatorId: "device-1", duration: 100)

        // No start time, returns 0
        #expect(session.progress(currentTime: 1000) == 0.0)

        // With start time
        session.startTime = 1000
        #expect(session.progress(currentTime: 1000) == 0.0)    // 0% elapsed
        #expect(session.progress(currentTime: 1050) == 0.5)    // 50% elapsed
        #expect(session.progress(currentTime: 1100) == 1.0)    // 100% elapsed
        #expect(session.progress(currentTime: 1200) == 1.0)    // Past 100%, clamped
    }

    @Test("BuddySession toDictionary serializes correctly")
    func sessionToDictionary() {
        var session = BuddySession(
            sessionId: "test-123",
            creatorId: "device-1",
            state: .active,
            duration: 1500,
            startTime: 1234567890,
            endTime: nil,
            createdAt: 1234567800
        )
        session.participants["device-1"] = SessionParticipant(
            odid: "device-1",
            name: "Creator",
            taskTitle: "Study",
            status: .focused,
            violationCount: 1,
            joinedAt: 1234567800
        )

        let dict = session.toDictionary()
        #expect(dict["sessionId"] as? String == "test-123")
        #expect(dict["creatorId"] as? String == "device-1")
        #expect(dict["state"] as? String == "active")
        #expect(dict["duration"] as? Int == 1500)
        #expect(dict["startTime"] as? TimeInterval == 1234567890)
        #expect(dict["createdAt"] as? TimeInterval == 1234567800)
        #expect(dict["endTime"] == nil)

        let participants = dict["participants"] as? [String: [String: Any]]
        #expect(participants?["device-1"]?["name"] as? String == "Creator")
    }

    @Test("BuddySession init from dictionary works")
    func sessionFromDictionary() {
        let dict: [String: Any] = [
            "sessionId": "test-123",
            "creatorId": "device-1",
            "state": "active",
            "duration": 1500,
            "createdAt": 1234567800.0,
            "startTime": 1234567890.0,
            "participants": [
                "device-1": [
                    "odid": "device-1",
                    "name": "Creator",
                    "taskTitle": "Study",
                    "status": "focused",
                    "violationCount": 1,
                    "joinedAt": 1234567800.0
                ]
            ]
        ]

        let session = BuddySession(from: dict)
        #expect(session != nil)
        #expect(session?.sessionId == "test-123")
        #expect(session?.creatorId == "device-1")
        #expect(session?.state == .active)
        #expect(session?.duration == 1500)
        #expect(session?.startTime == 1234567890)
        #expect(session?.participants.count == 1)
        #expect(session?.participants["device-1"]?.name == "Creator")
    }

    @Test("BuddySession init from dictionary fails on missing fields")
    func sessionFromDictionaryFailsMissingFields() {
        let incompleteDict: [String: Any] = [
            "sessionId": "test-123"
            // Missing required fields
        ]
        let session = BuddySession(from: incompleteDict)
        #expect(session == nil)
    }

    // MARK: - Duration Unit Tests

    @Test("BuddySession duration is in seconds matching Swift convention")
    func sessionDurationIsInSeconds() {
        // RN stores duration in MINUTES, Swift stores in SECONDS
        // Default is 25 minutes = 1500 seconds
        let session = BuddySession(creatorId: "device-1")
        #expect(session.duration == 25 * 60)  // 1500 seconds

        // 5 minute break would be
        let breakSession = BuddySession(creatorId: "device-1", duration: 5 * 60)
        #expect(breakSession.duration == 300)  // 300 seconds
    }
}

// MARK: - SessionError Tests

@Suite("SessionError Tests")
struct SessionErrorTests {

    @Test("SessionError has correct descriptions")
    func errorDescriptions() {
        #expect(SessionError.notConfigured.errorDescription?.contains("Firebase") == true)
        #expect(SessionError.sessionNotFound.errorDescription?.contains("not be found") == true)
        #expect(SessionError.invalidSessionData.errorDescription?.contains("invalid") == true)
        #expect(SessionError.sessionAlreadyStarted.errorDescription?.contains("already started") == true)
        #expect(SessionError.noActiveSession.errorDescription?.contains("No active") == true)
        #expect(SessionError.notSessionCreator.errorDescription?.contains("creator") == true)
        #expect(SessionError.notEnoughParticipants.errorDescription?.contains("2 participants") == true)
    }
}
