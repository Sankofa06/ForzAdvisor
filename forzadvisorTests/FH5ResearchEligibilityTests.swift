import SwiftData
import XCTest
@testable import forzadvisor

final class FH5ResearchEligibilityTests: FH5ResearchTestCase {
    func testEligibilityRequiresSavedUntouchedCatalogPlanAndFailsClosed() async throws {
        let plan = try await makePlan()
        let eligibility = FH5ResearchEligibility()

        XCTAssertSuccess(eligibility.snapshot(for: plan, savedTune: plan, isStreaming: false))
        XCTAssertFailure(
            eligibility.snapshot(for: plan, savedTune: nil, isStreaming: false),
            .notSaved
        )
        XCTAssertFailure(
            eligibility.snapshot(for: plan, savedTune: plan, isStreaming: true),
            .streaming
        )

        var edited = plan
        edited.request.car.weightPounds += 1
        XCTAssertFailure(
            eligibility.snapshot(for: edited, savedTune: edited, isStreaming: false),
            .invalidCapabilitySnapshot
        )

        var manual = plan
        manual.request.car.catalogReference = nil
        manual.request.buildSnapshot?.car.catalogReference = nil
        XCTAssertFailure(
            eligibility.snapshot(for: manual, savedTune: manual, isStreaming: false),
            .missingCatalogIdentity
        )

        var exact = plan
        exact.request.buildSnapshot?.kind = .exactBuildObservation
        XCTAssertFailure(
            eligibility.snapshot(for: exact, savedTune: exact, isStreaming: false),
            .invalidCapabilitySnapshot
        )

        var numeric = plan
        numeric.sections = [TuneSection(
            title: "Forged",
            symbolName: "xmark",
            lines: [TuneLine(label: "Forbidden", value: "31.73", unit: "PSI")]
        )]
        XCTAssertFailure(
            eligibility.snapshot(for: numeric, savedTune: numeric, isStreaming: false),
            .numericOrProviderPayload
        )

        var stale = plan
        stale.generatedAt = capturedAt
        XCTAssertFailure(
            eligibility.snapshot(for: plan, savedTune: stale, isStreaming: false),
            .staleSavedRevision
        )
    }
    func testExpectedControlMatricesAreExactForEveryDrivetrainAndGearCount() {
        for drivetrain in Drivetrain.allCases {
            for gearCount in [1, 6, 10] {
                let expected = TuneFieldID.expectedFields(
                    drivetrain: drivetrain,
                    gearCount: gearCount
                )
                let capture = validCapture(
                    drivetrain: drivetrain,
                    gearCount: gearCount,
                    availability: .notShown
                )
                XCTAssertTrue(
                    FH5ResearchObservationFactory()
                        .validationIssues(capture: capture, drivetrain: drivetrain)
                        .isEmpty
                )
                XCTAssertEqual(capture.controls.map(\.field), expected)
                XCTAssertEqual(Set(capture.controls.map(\.field)).count, expected.count)
                XCTAssertEqual(
                    expected.filter { $0.gearIndex != nil },
                    (1...gearCount).map(TuneFieldID.gearRatio)
                )

                let differential = expected.filter {
                    $0.projectionSectionTitle == "Differential"
                }
                switch drivetrain {
                case .fwd:
                    XCTAssertEqual(differential, [
                        .frontDifferentialAcceleration,
                        .frontDifferentialDeceleration
                    ])
                case .rwd:
                    XCTAssertEqual(differential, [
                        .differentialAcceleration,
                        .differentialDeceleration
                    ])
                case .awd:
                    XCTAssertEqual(differential, [
                        .frontDifferentialAcceleration,
                        .frontDifferentialDeceleration,
                        .rearDifferentialAcceleration,
                        .rearDifferentialDeceleration,
                        .differentialCenterBalance
                    ])
                }
            }
        }
    }
    func testControlValidationRejectsMissingDuplicateUnexpectedAndForbiddenPayloads() {
        let factory = FH5ResearchObservationFactory()
        let valid = validCapture(drivetrain: .rwd, gearCount: 6, availability: .notShown)
        let first = valid.controls[0]

        var controls = valid.controls
        controls.removeFirst()
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.missingField(first.field)))

        controls = valid.controls + [first]
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.duplicateField(first.field)))

        controls = valid.controls + [
            FH5TuneFieldObservation(
                field: .frontDifferentialAcceleration,
                availability: .notShown
            ),
            FH5TuneFieldObservation(field: .gearRatio(7), availability: .notShown)
        ]
        let unexpected = factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        )
        XCTAssertTrue(unexpected.contains(.unexpectedField(.frontDifferentialAcceleration)))
        XCTAssertTrue(unexpected.contains(.unexpectedField(.gearRatio(7))))

        controls = valid.controls
        controls[0] = FH5TuneFieldObservation(
            field: first.field,
            availability: .notShown,
            current: 30,
            unit: first.field.expectedUnit
        )
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.forbiddenNumericPayload(first.field)))

        controls[0] = FH5TuneFieldObservation(
            field: first.field,
            availability: .shownLocked,
            minimum: 15,
            current: 30,
            unit: first.field.expectedUnit
        )
        XCTAssertTrue(factory.validationIssues(
            capture: replacing(valid, controls: controls),
            drivetrain: .rwd
        ).contains(.forbiddenNumericPayload(first.field)))
    }
    func testAdjustableNumericValidationRejectsEveryAdversarialShape() {
        let factory = FH5ResearchObservationFactory()
        let base = validCapture(drivetrain: .rwd, gearCount: 6, availability: .adjustable)
        let field = base.controls[0].field

        func issues(_ observation: FH5TuneFieldObservation) -> [FH5ResearchIssue] {
            var controls = base.controls
            controls[0] = observation
            return factory.validationIssues(
                capture: replacing(base, controls: controls),
                drivetrain: .rwd
            )
        }

        XCTAssertTrue(issues(FH5TuneFieldObservation(
            field: field,
            availability: .adjustable
        )).contains(.missingAdjustablePayload(field)))
        XCTAssertTrue(issues(adjustable(field, minimum: .nan)).contains(.nonFiniteValue(field)))
        XCTAssertTrue(issues(adjustable(field, minimum: 100, maximum: 100)).contains(.invalidRange(field)))
        XCTAssertTrue(issues(adjustable(field, step: 0)).contains(.invalidStep(field)))
        XCTAssertTrue(issues(adjustable(field, current: 101)).contains(.currentOutOfRange(field)))
        XCTAssertTrue(issues(adjustable(field, maximum: 99.5)).contains(.valueOffLattice(field)))
        XCTAssertTrue(issues(adjustable(
            field,
            unit: field.expectedUnit == .psi ? .ratio : .psi
        )).contains(.wrongUnit(field)))

        var invalidGearCount = base
        invalidGearCount = FH5ResearchCapture(
            platform: invalidGearCount.platform,
            gameVersion: invalidGearCount.gameVersion,
            tireCompoundDisplayName: invalidGearCount.tireCompoundDisplayName,
            forwardGearCount: 11,
            controls: invalidGearCount.controls,
            exactUntouchedStockConfirmed: true,
            allSlidersRestoredConfirmed: true,
            personallyReadFromGameConfirmed: true,
            firstPartyAuthorshipConfirmed: true,
            localStoragePermitted: true
        )
        XCTAssertEqual(
            factory.validationIssues(capture: invalidGearCount, drivetrain: .rwd).first,
            .invalidGearCount
        )
    }
}
