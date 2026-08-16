import XCTest
@testable import forzadvisor

final class TuneProviderDisclosureTests: XCTestCase {
    private let fullyReady = TuneProviderCapabilities(
        onDeviceModel: .ready,
        anthropicAPI: .storedOnDeviceNotTested
    )

    func testOfflinePreferenceIsDirectAndLocal() {
        let disclosure = TuneProviderDisclosure(
            preferredMode: .offlineFormula,
            capabilities: fullyReady
        )

        XCTAssertEqual(disclosure.readiness, .ready)
        XCTAssertEqual(disclosure.route.expectedFirstMode, .offlineFormula)
        XCTAssertNil(disclosure.route.fallbackMode)
        XCTAssertTrue(disclosure.route.preferredModeWillBeAttempted)
        XCTAssertEqual(disclosure.dataBoundary, .localOnly)
    }

    func testReadyOnDevicePreferenceNamesExpectedFallback() {
        let disclosure = TuneProviderDisclosure(
            preferredMode: .onDeviceFoundationModel,
            capabilities: fullyReady
        )

        XCTAssertEqual(
            disclosure.route,
            TuneProviderRouteExpectation(
                preferredMode: .onDeviceFoundationModel,
                expectedFirstMode: .onDeviceFoundationModel,
                fallbackMode: .offlineFormula,
                preferredModeWillBeAttempted: true
            )
        )
        XCTAssertEqual(disclosure.dataBoundary, .localOnly)
    }

    func testStoredRemoteCredentialIsPresenceOnlyAndNotClaimedTested() {
        let disclosure = TuneProviderDisclosure(
            preferredMode: .anthropicAPI,
            capabilities: fullyReady
        )

        XCTAssertEqual(
            disclosure.readiness.readinessTitle,
            "Stored on this device - not tested"
        )
        XCTAssertEqual(disclosure.route.expectedFirstMode, .anthropicAPI)
        XCTAssertEqual(disclosure.route.fallbackMode, .offlineFormula)
        XCTAssertTrue(disclosure.route.preferredModeWillBeAttempted)
        XCTAssertEqual(disclosure.dataBoundary, .remoteGeneration)
    }

    func testUnavailablePreferencePredictsLocalRouteWithoutRemoteBoundary() {
        let capabilities = TuneProviderCapabilities(
            onDeviceModel: .unavailable(.modelNotReady),
            anthropicAPI: .setupRequired(.apiKey)
        )

        for mode in [
            TuneProviderMode.onDeviceFoundationModel,
            .anthropicAPI
        ] {
            let disclosure = TuneProviderDisclosure(
                preferredMode: mode,
                capabilities: capabilities
            )
            XCTAssertEqual(
                disclosure.route.expectedFirstMode,
                .offlineFormula
            )
            XCTAssertEqual(disclosure.route.fallbackMode, .offlineFormula)
            XCTAssertFalse(disclosure.route.preferredModeWillBeAttempted)
            XCTAssertEqual(disclosure.dataBoundary, .localOnly)
        }
    }

    func testResultActualProviderVocabularyUsesRecordedActualMode() {
        let info = TuneProviderInfo(
            requestedMode: .anthropicAPI,
            actualMode: .offlineFormula,
            fallbackReason: .providerError
        )

        XCTAssertEqual(info.requestedMode, .anthropicAPI)
        XCTAssertEqual(info.actualProviderMode, .offlineFormula)
    }
}
