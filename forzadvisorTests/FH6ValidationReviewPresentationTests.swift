//
//  FH6ValidationReviewPresentationTests.swift
//  forzadvisorTests
//

import Foundation
import XCTest
@testable import forzadvisor

final class FH6ValidationReviewPresentationTests: XCTestCase {
    func testHubExposesFourSeparatePlainLanguageDestinations() {
        XCTAssertEqual(
            FH6ValidationReviewHubDestination.allCases.map(\.title),
            [
                "Import Shared Session",
                "Reviewed Sessions",
                "Local Review Queue",
                "Independent Review Files"
            ]
        )
        XCTAssertEqual(
            Set(FH6ValidationReviewHubDestination.allCases.map(\.id)).count,
            4
        )
    }

    func testImportDraftIsTransientAndClearsAllPermissionState() {
        var state = FH6ValidationImportPresentationState()
        state.pastedJSON = "  { shared session }  "
        state.validatedJSON = Data("accepted".utf8)
        state.directReceiptAndPermissionConfirmed = true
        state.statusMessage = "Accepted"
        state.technicalMessage = "Technical result"
        state.statusIsError = true

        XCTAssertTrue(state.hasUnimportedText)

        state.clear()

        XCTAssertFalse(state.hasUnimportedText)
        XCTAssertNil(state.validatedJSON)
        XCTAssertFalse(state.directReceiptAndPermissionConfirmed)
        XCTAssertNil(state.statusMessage)
        XCTAssertNil(state.technicalMessage)
        XCTAssertFalse(state.statusIsError)
    }

    func testEditingPastedSessionRevokesPriorValidationAndPermission() {
        var state = FH6ValidationImportPresentationState()
        state.pastedJSON = "changed"
        state.validatedJSON = Data("previous".utf8)
        state.directReceiptAndPermissionConfirmed = true
        state.statusMessage = "Previous result"
        state.technicalMessage = "Previous technical result"

        state.pastedTextChanged()

        XCTAssertNil(state.validatedJSON)
        XCTAssertFalse(state.directReceiptAndPermissionConfirmed)
        XCTAssertNil(state.statusMessage)
        XCTAssertNil(state.technicalMessage)
    }

    func testIndependentFileStateClearsPastedAndPreparedData() {
        var state = FH6IndependentReviewPresentationState()
        state.preparedPacket = "prepared"
        state.preparationMessage = "ready"
        state.preparationTechnicalMessage = "prepared details"
        state.pastedPacketJSON = "{ packet }"
        state.inspectionMessage = "checked"
        state.inspectionTechnicalMessage = "inspection details"
        state.inspectionIsError = true

        XCTAssertTrue(state.hasPastedPacketText)

        state.clearAll()

        XCTAssertNil(state.preparedPacket)
        XCTAssertNil(state.preparationMessage)
        XCTAssertNil(state.preparationTechnicalMessage)
        XCTAssertFalse(state.hasPastedPacketText)
        XCTAssertNil(state.validatedPacket)
        XCTAssertNil(state.inspectionMessage)
        XCTAssertNil(state.inspectionTechnicalMessage)
        XCTAssertFalse(state.inspectionIsError)
    }

    func testWhitespaceOnlyPasteDoesNotRequireDiscardWarning() {
        var importState = FH6ValidationImportPresentationState()
        importState.pastedJSON = " \n\t "
        var packetState = FH6IndependentReviewPresentationState()
        packetState.pastedPacketJSON = "  "

        XCTAssertFalse(importState.hasUnimportedText)
        XCTAssertFalse(packetState.hasPastedPacketText)
    }
}
