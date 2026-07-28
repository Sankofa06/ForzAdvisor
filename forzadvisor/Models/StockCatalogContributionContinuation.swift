//
//  StockCatalogContributionContinuation.swift
//  forzadvisor
//
//  One-shot authority to begin another capture after a durable save.
//

import Foundation

struct StockCatalogContributionContinuationToken:
    Equatable,
    Sendable
{
    let persistedRecordID: UUID
    let exactPostSaveDraft: StockCatalogContributionDraft
}

struct StockCatalogContributionContinuationState:
    Equatable,
    Sendable
{
    private(set) var token:
        StockCatalogContributionContinuationToken?

    var hasToken: Bool {
        token != nil
    }

    mutating func clearForSaveAttempt() {
        token = nil
    }

    mutating func recordSuccessfulSave(
        recordID: UUID,
        exactPostSaveDraft: StockCatalogContributionDraft
    ) {
        token = StockCatalogContributionContinuationToken(
            persistedRecordID: recordID,
            exactPostSaveDraft: exactPostSaveDraft
        )
    }

    func isEligible(
        currentDraft: StockCatalogContributionDraft,
        snapshot: StockCatalogContributionStoreSnapshot
    ) -> Bool {
        guard let token else {
            return false
        }
        return currentDraft == token.exactPostSaveDraft
            && snapshot.captured.contains {
                $0.id == token.persistedRecordID
            }
    }

    mutating func consumeIfEligible(
        currentDraft: StockCatalogContributionDraft,
        snapshot: StockCatalogContributionStoreSnapshot
    ) -> StockCatalogContributionDraft? {
        guard isEligible(
            currentDraft: currentDraft,
            snapshot: snapshot
        ) else {
            return nil
        }
        token = nil
        return StockCatalogContributionDraft(game: currentDraft.game)
    }
}
