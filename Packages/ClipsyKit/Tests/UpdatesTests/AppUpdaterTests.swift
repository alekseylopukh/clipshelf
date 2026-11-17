import Testing
@testable import Updates

@MainActor
struct AppUpdaterTests {
    @Test func `launch with checks off does not start the updater`() throws {
        let driver = FakeUpdaterDriver(automaticallyChecksForUpdates: false)
        let updater = AppUpdater(driver: driver)

        try updater.startIfAutomatic()

        #expect(driver.startCount == 0)
        #expect(updater.isStarted == false)
    }

    @Test func `launch with checks on starts the updater`() throws {
        let driver = FakeUpdaterDriver(automaticallyChecksForUpdates: true)
        let updater = AppUpdater(driver: driver)

        try updater.startIfAutomatic()

        #expect(driver.startCount == 1)
        #expect(updater.isStarted)
    }

    @Test func `turning checks on starts before saving the setting`() throws {
        let driver = FakeUpdaterDriver(automaticallyChecksForUpdates: false)
        let updater = AppUpdater(driver: driver)

        try updater.setAutomaticallyChecksForUpdates(true)

        #expect(driver.events == [.start, .setAutomaticChecks(true)])
        #expect(updater.automaticallyChecksForUpdates)
    }

    @Test func `turning checks off does not start the updater`() throws {
        let driver = FakeUpdaterDriver(automaticallyChecksForUpdates: false)
        let updater = AppUpdater(driver: driver)

        try updater.setAutomaticallyChecksForUpdates(false)

        #expect(driver.events == [.setAutomaticChecks(false)])
    }

    @Test func `manual check starts once then checks`() throws {
        let driver = FakeUpdaterDriver(automaticallyChecksForUpdates: false)
        let updater = AppUpdater(driver: driver)

        try updater.checkForUpdates()
        try updater.checkForUpdates()

        #expect(driver.events == [.start, .check, .check])
        #expect(driver.automaticallyChecksForUpdates == false)
    }

    @Test func `failed start is thrown and retried on the next check`() throws {
        let driver = FakeUpdaterDriver(automaticallyChecksForUpdates: false)
        driver.startError = FakeStartError()
        let updater = AppUpdater(driver: driver)

        #expect(throws: FakeStartError.self) {
            try updater.checkForUpdates()
        }
        driver.startError = nil
        try updater.checkForUpdates()

        #expect(driver.events == [.start, .start, .check])
    }

    @Test func `failed start leaves automatic checks off`() {
        let driver = FakeUpdaterDriver(automaticallyChecksForUpdates: false)
        driver.startError = FakeStartError()
        let updater = AppUpdater(driver: driver)

        #expect(throws: FakeStartError.self) {
            try updater.setAutomaticallyChecksForUpdates(true)
        }
        #expect(updater.automaticallyChecksForUpdates == false)
    }
}

private struct FakeStartError: Error {}

@MainActor
private final class FakeUpdaterDriver: UpdaterDriver {
    enum Event: Equatable {
        case start
        case check
        case setAutomaticChecks(Bool)
    }

    private(set) var events: [Event] = []
    var startError: (any Error)?
    var automaticallyChecksForUpdates: Bool {
        didSet { events.append(.setAutomaticChecks(automaticallyChecksForUpdates)) }
    }

    var startCount: Int {
        events.count(where: { $0 == .start })
    }

    init(automaticallyChecksForUpdates: Bool) {
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    func start() throws {
        events.append(.start)
        if let startError {
            throw startError
        }
    }

    func checkForUpdates() {
        events.append(.check)
    }
}
