import XCTest
@testable import forzadvisor

extension CopilotTests {
    func testModalCopilotDestinationsExposeOnlyAllowListedFacts() {
        let destinations: [ModalCopilotDestination] = [
            .settings,
            .stockCatalogContribution,
            .betaMissions(savedSetupCount: 7),
            .fh6ValidationReview(
                carDisplayName: "Committed FH6 Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh6CommunityOutcomeReview(
                carDisplayName: "Committed FH6 Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh5ResearchReview(
                carDisplayName: "Committed FH5 Car",
                gameTitle: "FH5"
            ),
            .fh5CandidateOutcomeReview
        ]

        XCTAssertEqual(
            destinations.map(\.buttonIdentifier),
            destinations.map { "copilotButton-\($0.phase.rawValue)" }
        )
        XCTAssertEqual(
            Set(destinations.map(\.buttonIdentifier)).count,
            destinations.count
        )
        XCTAssertEqual(
            Set(destinations.map(\.phase)).count,
            destinations.count
        )
        XCTAssertTrue(destinations.allSatisfy {
            !$0.accessibilityHint.isEmpty
        })

        let settings = destinations[0].context
        XCTAssertEqual(settings.facts, [
            CopilotFact(
                label: "Unsaved fields",
                value: "Not visible to Copilot"
            )
        ])
        XCTAssertTrue(settings.cannotSeeUnsavedEdits)

        let contribution = destinations[1].context
        XCTAssertEqual(
            destinations[1].buttonIdentifier,
            "copilotButton-stockCatalogContribution"
        )
        XCTAssertTrue(
            destinations[1].accessibilityHint.contains(
                "guidance without reading or changing the contribution"
            )
        )
        XCTAssertEqual(contribution.facts, [
            CopilotFact(
                label: "Unsaved fields",
                value: "Not visible to Copilot"
            )
        ])
        XCTAssertTrue(contribution.cannotSeeUnsavedEdits)
        XCTAssertNil(contribution.carDisplayName)
        XCTAssertNil(contribution.gameTitle)
        XCTAssertNil(contribution.disciplineTitle)
        XCTAssertNil(contribution.savedTuneCount)
        XCTAssertNil(contribution.catalogCarCount)
        XCTAssertNil(contribution.projection)
        XCTAssertNil(contribution.fh5CandidateTrialAvailable)

        let beta = destinations[2].context
        XCTAssertEqual(beta.savedTuneCount, 7)
        XCTAssertEqual(beta.facts, [
            CopilotFact(label: "Saved tunes", value: "7")
        ])
        XCTAssertFalse(beta.cannotSeeUnsavedEdits)

        let validationReview = destinations[3].context
        XCTAssertNil(validationReview.carDisplayName)
        XCTAssertNil(validationReview.gameTitle)
        XCTAssertNil(validationReview.disciplineTitle)
        XCTAssertEqual(
            validationReview.facts.map(\.label),
            ["Unsaved fields"]
        )
        XCTAssertTrue(
            validationReview.cannotSeeUnsavedEdits
        )

        let communityReview = destinations[4].context
        XCTAssertEqual(
            communityReview.carDisplayName,
            "Committed FH6 Car"
        )
        XCTAssertEqual(communityReview.gameTitle, "FH6")
        XCTAssertEqual(communityReview.disciplineTitle, "Road")
        XCTAssertEqual(
            communityReview.facts.map(\.label),
            ["Car", "Game", "Discipline", "Unsaved fields"]
        )
        XCTAssertTrue(communityReview.cannotSeeUnsavedEdits)

        let research = destinations[5].context
        XCTAssertEqual(research.carDisplayName, "Committed FH5 Car")
        XCTAssertEqual(research.gameTitle, "FH5")
        XCTAssertNil(research.disciplineTitle)
        XCTAssertEqual(
            research.facts.map(\.label),
            ["Car", "Game", "Unsaved fields"]
        )
        XCTAssertTrue(research.cannotSeeUnsavedEdits)

        let candidate = destinations[6].context
        XCTAssertEqual(candidate.facts, [
            CopilotFact(
                label: "Unsaved fields",
                value: "Not visible to Copilot"
            )
        ])
        XCTAssertTrue(candidate.cannotSeeUnsavedEdits)

        for destination in destinations {
            let context = destination.context
            XCTAssertNil(context.catalogCarCount)
            XCTAssertNil(context.projection)
            XCTAssertNil(context.fh5CandidateTrialAvailable)
            for intent in CopilotIntent.allCases {
                XCTAssertNil(
                    CopilotEngine()
                        .response(to: intent, in: context)
                        .action,
                    "\(destination.phase.rawValue) / \(intent.rawValue)"
                )
            }
        }
    }

    func testModalCopilotContextsDoNotContainDraftOrCredentialFields()
        throws {
        let destinations: [ModalCopilotDestination] = [
            .settings,
            .stockCatalogContribution,
            .betaMissions(savedSetupCount: 4),
            .fh6ValidationReview(
                carDisplayName: "Committed Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh6CommunityOutcomeReview(
                carDisplayName: "Committed Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            ),
            .fh5ResearchReview(
                carDisplayName: "Committed Car",
                gameTitle: "FH5"
            ),
            .fh5CandidateOutcomeReview
        ]
        let forbidden = [
            "apiKey",
            "provider",
            "pastedJSON",
            "permission",
            "tuneValue",
            "notes",
            "thumbnail",
            "fingerprint",
            "draft"
        ]

        for destination in destinations {
            let encoded = try XCTUnwrap(
                String(
                    data: JSONEncoder().encode(destination.context),
                    encoding: .utf8
                )
            )
            for key in forbidden {
                XCTAssertFalse(
                    encoded.localizedCaseInsensitiveContains(key),
                    "\(destination.phase.rawValue) unexpectedly encoded \(key)"
                )
            }
        }
    }

}
