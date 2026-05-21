//
//  TuneAPIModelTests.swift
//  forzadvisorTests
//
//  Coverage for API DTO encoding/decoding and offline fallback behavior.
//

import XCTest
@testable import forzadvisor

final class TuneAPIModelTests: XCTestCase {
    func testGeneratePayloadUsesPRDKeys() throws {
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .crossCountry)
        let payload = TuneAPIRequestPayload(request: request)
        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let car = try XCTUnwrap(object["car"] as? [String: Any])

        XCTAssertEqual(object["action"] as? String, "generate_tune")
        XCTAssertEqual(object["discipline"] as? String, "cross_country")
        XCTAssertEqual(car["weight_lb"] as? Int, 3_340)
        XCTAssertEqual(car["front_weight_pct"] as? Double, 53)
        XCTAssertEqual(car["class"] as? String, "S1")
        XCTAssertEqual(car["peak_hp"] as? Int, 480)
    }

    func testAPIResponseMapsToTuneSections() {
        let response = TuneAPIResponse(
            tune: TuneAPITune(
                tires: TuneAPITires(frontPsi: 29, rearPsi: 28.5),
                gearing: TuneAPIGearing(finalDrive: 4.05),
                alignment: TuneAPIAlignment(frontCamber: -2.5, rearCamber: -1.5, frontToe: 0, rearToe: 0, caster: 5.5),
                antirollBars: TuneAPIFrontRear(front: 28, rear: 19),
                springs: TuneAPISprings(frontRate: 524, rearRate: 464, frontRideHeight: 4.5, rearRideHeight: 4.7),
                damping: TuneAPIDamping(frontRebound: 6.6, rearRebound: 6.2, frontBump: 4.3, rearBump: 4),
                aero: TuneAPIFrontRear(front: 180, rear: 210),
                brakes: TuneAPIBrakes(balancePercent: 50, pressurePercent: 100),
                differential: TuneAPIDifferential(accelPercent: 55, decelPercent: 30)
            ),
            notes: TuneAPINotes(bias: "neutral", ifPushesWide: "add rotation", ifSnapsOnLift: "add stability", retuneTrigger: "2%")
        )

        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        let tune = response.tuneResult(for: request)

        XCTAssertEqual(tune.sections.map(\.title), [
            "Tires",
            "Gearing",
            "Alignment",
            "Antiroll Bars",
            "Springs",
            "Damping",
            "Aero",
            "Brakes",
            "Differential"
        ])
        XCTAssertEqual(tune.notes.bias, "neutral")
    }

    func testPartialAdjustmentResponseMergesIntoPreviousTune() async throws {
        let previous = try await LocalSampleTuneProvider().generateTune(
            for: TuneRequest(car: SampleTuningData.starterCar, discipline: .touge)
        )
        let response = TuneAPIResponse(
            tune: TuneAPITune(
                antirollBars: TuneAPIFrontRear(front: 24, rear: 26)
            ),
            notes: TuneAPINotes(ifPushesWide: "rear ARB already increased")
        )

        let adjusted = response.mergedTuneResult(updating: previous)

        XCTAssertEqual(adjusted.id, previous.id)
        XCTAssertEqual(adjusted.sections.map(\.title), previous.sections.map(\.title))
        XCTAssertEqual(adjusted.section("Tires")?.number("Front pressure"), previous.section("Tires")?.number("Front pressure"))
        XCTAssertEqual(adjusted.section("Antiroll Bars")?.number("Front"), 24)
        XCTAssertEqual(adjusted.section("Antiroll Bars")?.number("Rear"), 26)
        XCTAssertEqual(adjusted.notes.bias, previous.notes.bias)
        XCTAssertEqual(adjusted.notes.ifPushesWide, "rear ARB already increased")
    }

    func testCompositeProviderFallsBackToLocalWithoutAPIKey() async throws {
        let provider = CompositeTuneProvider(
            configuration: TuneProviderConfiguration(prefersRemoteGeneration: true),
            remoteProvider: TuneAPIClient(keychainStore: KeychainStore(service: "forzadvisor-tests-\(UUID().uuidString)")),
            localProvider: LocalSampleTuneProvider()
        )
        let request = TuneRequest(car: SampleTuningData.starterCar, discipline: .road)

        let tune = try await provider.generateTune(for: request)

        XCTAssertEqual(tune.request, request)
        XCTAssertFalse(tune.sections.isEmpty)
    }
}
