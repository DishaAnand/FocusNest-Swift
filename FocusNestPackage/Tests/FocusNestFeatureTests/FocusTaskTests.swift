import Testing
import Foundation
@testable import FocusNestFeature

@Suite("FocusTask Model Tests")
struct FocusTaskTests {
    @Test("Task initializes with correct defaults")
    func taskInitializesWithCorrectDefaults() async throws {
        let task = FocusTask(title: "Test Task")

        #expect(task.title == "Test Task")
        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)
        #expect(task.totalFocusTime == 0)
        #expect(task.id != UUID())  // ID should be generated
    }

    @Test("Task initializes with custom values")
    func taskInitializesWithCustomValues() async throws {
        let customId = UUID()
        let customDate = Date()
        let completedDate = Date()

        let task = FocusTask(
            id: customId,
            title: "Custom Task",
            isCompleted: true,
            createdAt: customDate,
            completedAt: completedDate,
            totalFocusTime: 3600
        )

        #expect(task.id == customId)
        #expect(task.title == "Custom Task")
        #expect(task.isCompleted == true)
        #expect(task.createdAt == customDate)
        #expect(task.completedAt == completedDate)
        #expect(task.totalFocusTime == 3600)
    }

    @Test("Mark completed sets completedAt date")
    func markCompletedSetsCompletedAtDate() async throws {
        let task = FocusTask(title: "Test Task")

        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)

        let beforeCompletion = Date()
        task.markCompleted()
        let afterCompletion = Date()

        #expect(task.isCompleted == true)
        #expect(task.completedAt != nil)

        // Verify completedAt is within the expected time range
        if let completedAt = task.completedAt {
            #expect(completedAt >= beforeCompletion)
            #expect(completedAt <= afterCompletion)
        }
    }

    @Test("Mark incomplete clears completedAt")
    func markIncompleteClearsCompletedAt() async throws {
        let task = FocusTask(title: "Test Task")

        // First mark as completed
        task.markCompleted()
        #expect(task.isCompleted == true)
        #expect(task.completedAt != nil)

        // Then mark as incomplete
        task.markIncomplete()
        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)
    }

    @Test("Mark incomplete on already incomplete task")
    func markIncompleteOnAlreadyIncompleteTask() async throws {
        let task = FocusTask(title: "Test Task")

        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)

        // Calling markIncomplete on already incomplete task should be safe
        task.markIncomplete()
        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)
    }

    @Test("Add focus time accumulates correctly")
    func addFocusTimeAccumulatesCorrectly() async throws {
        let task = FocusTask(title: "Test Task")

        #expect(task.totalFocusTime == 0)

        task.addFocusTime(60)  // Add 1 minute
        #expect(task.totalFocusTime == 60)

        task.addFocusTime(120)  // Add 2 more minutes
        #expect(task.totalFocusTime == 180)

        task.addFocusTime(3600)  // Add 1 hour
        #expect(task.totalFocusTime == 3780)
    }

    @Test("Add focus time with zero value")
    func addFocusTimeWithZeroValue() async throws {
        let task = FocusTask(title: "Test Task")
        task.addFocusTime(100)

        #expect(task.totalFocusTime == 100)

        task.addFocusTime(0)
        #expect(task.totalFocusTime == 100)
    }

    @Test("Formatted focus time shows seconds only")
    func formattedFocusTimeShowsSecondsOnly() async throws {
        let task = FocusTask(title: "Test Task")

        #expect(task.formattedFocusTime == "0s")

        task.addFocusTime(30)
        #expect(task.formattedFocusTime == "30s")

        task.addFocusTime(29)  // Total: 59 seconds
        #expect(task.formattedFocusTime == "59s")
    }

    @Test("Formatted focus time shows minutes only")
    func formattedFocusTimeShowsMinutesOnly() async throws {
        let task = FocusTask(title: "Test Task")

        task.addFocusTime(60)  // 1 minute
        #expect(task.formattedFocusTime == "1m")

        task.addFocusTime(60)  // 2 minutes
        #expect(task.formattedFocusTime == "2m")

        task.addFocusTime(30)  // 2 minutes 30 seconds (shows as 2m)
        #expect(task.formattedFocusTime == "2m")
    }

    @Test("Formatted focus time shows hours and minutes")
    func formattedFocusTimeShowsHoursAndMinutes() async throws {
        let task = FocusTask(title: "Test Task")

        task.addFocusTime(3600)  // 1 hour
        #expect(task.formattedFocusTime == "1h 0m")

        task.addFocusTime(1800)  // 1 hour 30 minutes
        #expect(task.formattedFocusTime == "1h 30m")

        task.addFocusTime(5400)  // 3 hours total
        #expect(task.formattedFocusTime == "3h 0m")
    }

    @Test("Formatted focus time handles large values")
    func formattedFocusTimeHandlesLargeValues() async throws {
        let task = FocusTask(title: "Test Task")

        // 10 hours and 45 minutes
        task.addFocusTime(10 * 3600 + 45 * 60)
        #expect(task.formattedFocusTime == "10h 45m")

        // Add more to get to 24 hours
        task.addFocusTime(13 * 3600 + 15 * 60)  // 24 hours total
        #expect(task.formattedFocusTime == "24h 0m")
    }

    @Test("Multiple tasks have unique IDs")
    func multipleTasksHaveUniqueIds() async throws {
        let task1 = FocusTask(title: "Task 1")
        let task2 = FocusTask(title: "Task 2")
        let task3 = FocusTask(title: "Task 3")

        #expect(task1.id != task2.id)
        #expect(task2.id != task3.id)
        #expect(task1.id != task3.id)
    }

    @Test("Task creation sets createdAt to current date")
    func taskCreationSetsCreatedAtToCurrentDate() async throws {
        let beforeCreation = Date()
        let task = FocusTask(title: "Test Task")
        let afterCreation = Date()

        #expect(task.createdAt >= beforeCreation)
        #expect(task.createdAt <= afterCreation)
    }
}
