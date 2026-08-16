import XCTest
@testable import forzadvisor

@MainActor
final class APIKeySettingsControllerTests: XCTestCase {
    func testRefreshUsesPresenceOnlyStatusVocabulary() {
        let store = SettingsKeyStore(hasKey: true)
        let controller = APIKeySettingsController(store: store)

        controller.refresh()

        XCTAssertEqual(controller.status, .storedOnDeviceNotTested)
        XCTAssertEqual(controller.status.title, "Stored on this device - not tested")
        XCTAssertEqual(store.presenceQueryCount, 1)
        XCTAssertNil(store.savedKey)
    }

    func testUnavailablePresenceFailsClosedWithoutChangingCredential() {
        let store = SettingsKeyStore(hasKey: true)
        store.failure = TestFailure.status
        let controller = APIKeySettingsController(store: store)

        controller.refresh()

        XCTAssertEqual(controller.status.title, "Status unavailable")
        XCTAssertTrue(controller.message?.contains("not changed") == true)
    }

    func testReplacingStoredKeyRequiresConfirmation() {
        let store = SettingsKeyStore(hasKey: true)
        let controller = APIKeySettingsController(store: store)
        controller.refresh()

        XCTAssertTrue(controller.requestSave("  replacement  "))
        XCTAssertEqual(controller.pendingAction, .replace("replacement"))
        XCTAssertNil(store.savedKey)

        controller.confirmPendingAction()

        XCTAssertEqual(store.savedKey, "replacement")
        XCTAssertEqual(controller.status, .storedOnDeviceNotTested)
    }

    func testFailedReplacementPreservesPriorStatus() {
        let store = SettingsKeyStore(hasKey: true)
        let controller = APIKeySettingsController(store: store)
        controller.refresh()
        _ = controller.requestSave("replacement")
        store.failure = TestFailure.save

        controller.confirmPendingAction()

        XCTAssertEqual(controller.status, .storedOnDeviceNotTested)
        XCTAssertTrue(controller.message?.contains("preserved") == true)
    }

    func testClearRequiresConfirmationAndFailurePreservesStatus() {
        let store = SettingsKeyStore(hasKey: true)
        let controller = APIKeySettingsController(store: store)
        controller.refresh()
        controller.requestClear()
        XCTAssertEqual(controller.pendingAction, .clear)
        XCTAssertEqual(store.deleteCount, 0)

        store.failure = TestFailure.delete
        controller.confirmPendingAction()

        XCTAssertEqual(controller.status, .storedOnDeviceNotTested)
        XCTAssertEqual(store.deleteCount, 1)
        XCTAssertTrue(controller.message?.contains("preserved") == true)
    }

    func testUnavailableStatusAlsoRequiresReplaceConfirmation() {
        let store = SettingsKeyStore(hasKey: true)
        store.failure = TestFailure.status
        let controller = APIKeySettingsController(store: store)
        controller.refresh()
        store.failure = nil

        XCTAssertTrue(controller.requestSave("replacement"))
        XCTAssertEqual(controller.pendingAction, .replace("replacement"))
        XCTAssertNil(store.savedKey)
    }

    func testSettingsCapabilitiesDriveTheSharedDisclosure() {
        let capabilities = SettingsProviderCapabilities(
            onDeviceAvailability: .modelNotReady,
            apiKeyStatus: .storedOnDeviceNotTested
        ).value
        let remote = TuneProviderDisclosure(
            preferredMode: .anthropicAPI,
            capabilities: capabilities
        )
        let localModel = TuneProviderDisclosure(
            preferredMode: .onDeviceFoundationModel,
            capabilities: capabilities
        )

        XCTAssertEqual(remote.readiness, .storedOnDeviceNotTested)
        XCTAssertEqual(remote.dataBoundary, .remoteGeneration)
        XCTAssertEqual(localModel.readiness, .unavailable(.modelNotReady))
        XCTAssertEqual(localModel.route.expectedFirstMode, .offlineFormula)
    }
}

private final class SettingsKeyStore: APIKeySettingsStoring {
    var hasKey: Bool
    var failure: Error?
    var presenceQueryCount = 0
    var savedKey: String?
    var deleteCount = 0

    init(hasKey: Bool) {
        self.hasKey = hasKey
    }

    func containsAPIKey() throws -> Bool {
        presenceQueryCount += 1
        if let failure { throw failure }
        return hasKey
    }

    func saveAPIKey(_ key: String) throws {
        if let failure { throw failure }
        savedKey = key
        hasKey = true
    }

    func deleteAPIKey() throws {
        deleteCount += 1
        if let failure { throw failure }
        hasKey = false
    }
}

private enum TestFailure: Error {
    case status
    case save
    case delete
}
