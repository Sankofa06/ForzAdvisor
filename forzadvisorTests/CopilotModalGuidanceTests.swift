import XCTest
@testable import forzadvisor

extension CopilotTests {
    func testStockCatalogContributionGuidanceMatchesCollectionBoundary() {
        let context =
            ModalCopilotDestination.stockCatalogContribution.context
        let engine = CopilotEngine()
        let next = engine.response(to: .nextStep, in: context)

        XCTAssertEqual(engine.defaultResponse(in: context), next)
        for intent in CopilotIntent.allCases {
            let response = engine.response(to: intent, in: context)
            XCTAssertFalse(response.message.isEmpty)
            XCTAssertNil(response.action)
            XCTAssertTrue(
                response.message.contains(
                    "cannot see unsaved field edits"
                ),
                intent.rawValue
            )
        }

        for fragment in [
            "exact untouched-stock car identity",
            "current game build and platform",
            "performance index",
            "source screen",
            "personally read",
            "English units where relevant",
            "all four reuse rights",
            "save locally",
            "canonical export",
            "human collection review"
        ] {
            XCTAssertTrue(
                next.message.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let trust = engine.response(to: .trust, in: context).message
        for fragment in [
            "structural validation",
            "canonical byte binding",
            "human collection review",
            "personal direct reading",
            "does not approve facts",
            "create or change a catalog entry",
            "activate a tune"
        ] {
            XCTAssertTrue(
                trust.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let missing = engine.response(to: .missing, in: context).message
        for fragment in [
            "exact car identity",
            "game build and platform",
            "all stock facts",
            "source-screen attestation",
            "personally-read",
            "English-units-where-relevant",
            "local-storage permission",
            "canonical JSON",
            "direct-receipt confirmation",
            "reuse, curation, and redistribution rights"
        ] {
            XCTAssertTrue(
                missing.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let privacy = engine.response(to: .privacy, in: context).message
        for fragment in [
            "only the Stock Catalog Contribution phase",
            "no access to draft values",
            "field or record counts",
            "pasted or canonical JSON",
            "permission state",
            "contribution payloads",
            "does not call a model or network service",
            "save a transcript",
            "offer an action",
            "stay local",
            "explicitly share",
            "does not alter the catalog or tuning"
        ] {
            XCTAssertTrue(
                privacy.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }
        for exclusion in
            StockCatalogContributionPolicy.privacyExclusions {
            XCTAssertTrue(privacy.contains(exclusion), exclusion)
        }
    }

    func testFH6ValidationReviewCopilotIsPhaseOnlyPayloadBlindAndActionFree()
        throws {
        let context = ModalCopilotDestination
            .fh6ValidationReview(
                carDisplayName: "Private Car",
                gameTitle: "FH6",
                disciplineTitle: "Road"
            )
            .context
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(context)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            Set(object.keys),
            ["phase", "cannotSeeUnsavedEdits"]
        )
        XCTAssertEqual(
            context.phase,
            .fh6ValidationReview
        )

        let engine = CopilotEngine()
        for intent in CopilotIntent.allCases {
            XCTAssertNil(
                engine.response(to: intent, in: context).action,
                intent.rawValue
            )
        }

        let next = engine.response(
            to: .nextStep,
            in: context
        ).message
        for fragment in [
            "transiently inspect",
            "cannot see the pasted JSON",
            "accepted evidence counts",
            "permission identifiers",
            "fingerprints",
            "cannot validate, clear, import, save, apply, rank, or promote"
        ] {
            XCTAssertTrue(
                next.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let privacy = engine.response(
            to: .privacy,
            in: context
        ).message
        for fragment in [
            "only the FH6 Validation Review phase",
            "cannot see pasted JSON",
            "accepted evidence counts",
            "permission identifiers",
            "candidate bindings",
            "packet fingerprints",
            "inspection status",
            "does not call a model or network service",
            "does not",
            "offer an action",
            "cannot validate, clear, import, save, apply, score, rank, or promote"
        ] {
            XCTAssertTrue(
                privacy.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }
    }

    func testFH5CandidateOutcomeReviewCopilotIsPacketBlindAndActionFree()
        throws {
        let context = ModalCopilotDestination
            .fh5CandidateOutcomeReview
            .context
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(context)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            Set(object.keys),
            ["phase", "cannotSeeUnsavedEdits"]
        )
        XCTAssertEqual(context.phase, .fh5CandidateOutcomeReview)

        let engine = CopilotEngine()
        for intent in CopilotIntent.allCases {
            XCTAssertNil(
                engine.response(to: intent, in: context).action,
                intent.rawValue
            )
        }

        let next = engine.response(
            to: .nextStep,
            in: context
        ).message
        for fragment in [
            "prepare a canonical Numeric Promotion Review Packet",
            "transiently inspect",
            "cannot see pasted JSON",
            "accepted evidence counts",
            "candidate bindings",
            "packet fingerprints",
            "cannot validate, clear, import, save, apply, score, rank, promote, register, or activate"
        ] {
            XCTAssertTrue(
                next.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }

        let privacy = engine.response(
            to: .privacy,
            in: context
        ).message
        for fragment in [
            "only the FH5 Candidate Outcome Review phase",
            "cannot see pasted JSON",
            "accepted evidence counts",
            "permission identifiers",
            "candidate bindings",
            "packet fingerprints",
            "prepared-input fingerprints",
            "inspection status",
            "does not call a model or network service",
            "offer an action",
            "cannot validate, clear, import, save, apply, score, rank, promote, register, or activate"
        ] {
            XCTAssertTrue(
                privacy.localizedCaseInsensitiveContains(fragment),
                fragment
            )
        }
    }

}
