import XCTest
@testable import forzadvisor

extension CopilotTests {
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
