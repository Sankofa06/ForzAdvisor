//
//  FH6ValidationReviewPresentation.swift
//  forzadvisor
//

import Foundation

enum FH6ValidationReviewHubDestination: String, CaseIterable, Identifiable {
    case importSharedSession
    case reviewedSessions
    case localReviewQueue
    case independentReviewFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importSharedSession: "Import Shared Session"
        case .reviewedSessions: "Reviewed Sessions"
        case .localReviewQueue: "Local Review Queue"
        case .independentReviewFiles: "Independent Review Files"
        }
    }

    var systemImage: String {
        switch self {
        case .importSharedSession: "square.and.arrow.down"
        case .reviewedSessions: "list.bullet.clipboard"
        case .localReviewQueue: "tray.full"
        case .independentReviewFiles: "doc.badge.gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "fh6ValidationReview.\(rawValue)"
    }
}

struct FH6ValidationImportPresentationState {
    var pastedJSON = ""
    var validatedJSON: Data?
    var directReceiptAndPermissionConfirmed = false
    var statusMessage: String?
    var technicalMessage: String?
    var statusIsError = false

    var hasUnimportedText: Bool {
        !pastedJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func pastedTextChanged() {
        validatedJSON = nil
        directReceiptAndPermissionConfirmed = false
        statusMessage = nil
        technicalMessage = nil
        statusIsError = false
    }

    mutating func clear() {
        self = Self()
    }
}

struct FH6IndependentReviewPresentationState {
    var preparedPacket: String?
    var preparationMessage: String?
    var preparationTechnicalMessage: String?
    var pastedPacketJSON = ""
    var validatedPacket: FH6IndependentValidationReviewPacket?
    var inspectionMessage: String?
    var inspectionTechnicalMessage: String?
    var inspectionIsError = false

    var hasPastedPacketText: Bool {
        !pastedPacketJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func clearPreparedFile() {
        preparedPacket = nil
        preparationMessage = nil
        preparationTechnicalMessage = nil
    }

    mutating func pastedPacketChanged() {
        validatedPacket = nil
        inspectionMessage = nil
        inspectionTechnicalMessage = nil
        inspectionIsError = false
    }

    mutating func clearInspection() {
        pastedPacketJSON = ""
        validatedPacket = nil
        inspectionMessage = nil
        inspectionTechnicalMessage = nil
        inspectionIsError = false
    }

    mutating func clearAll() {
        self = Self()
    }
}
