import Foundation

/// Memory-only state for a meaningful New Tune attempt.
struct TuneDraftSession: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        case source
        case manual(ManualEntryDraft, thumbnailData: Data?)
        case ocr(OCRConfirmationDraft)
        case discipline(
            car: CarInput,
            origin: InputOrigin,
            thumbnailData: Data?,
            selection: DrivingDiscipline?
        )
    }

    let id: UUID
    var stage: Stage

    init(id: UUID = UUID(), stage: Stage = .source) {
        self.id = id
        self.stage = stage
    }

    var isMeaningful: Bool {
        if case .source = stage { return false }
        return true
    }

    var selectedDiscipline: DrivingDiscipline? {
        guard case .discipline(_, _, _, let selection) = stage else {
            return nil
        }
        return selection
    }
}

struct SavedTuneRetuneSession: Equatable, Sendable {
    let savedTuneID: UUID
    let baseline: TuneResult
    let draft: SavedTuneEditDraft
    let thumbnailData: Data?
}

enum TuneGenerationReturnContext: Equatable, Sendable {
    case newTune(TuneDraftSession)
    case savedEdit(SavedTuneRetuneSession)
}

/// Frozen at the explicit generation boundary. Later Settings changes cannot
/// change the request, disclosure, or recovery destination for this attempt.
struct TuneGenerationSession: Equatable, Sendable, Identifiable {
    let id: UUID
    let request: TuneRequest
    let origin: InputOrigin
    let thumbnailData: Data?
    let savedTuneID: UUID?
    let playerNotes: String
    let preferredProviderMode: TuneProviderMode
    let providerDisclosure: TuneProviderDisclosure
    let returnContext: TuneGenerationReturnContext
    let completedValidationDraftKind: ValidationDraftKind?

    init(
        id: UUID = UUID(),
        request: TuneRequest,
        origin: InputOrigin,
        thumbnailData: Data?,
        savedTuneID: UUID? = nil,
        playerNotes: String = "",
        preferredProviderMode: TuneProviderMode,
        providerDisclosure: TuneProviderDisclosure,
        returnContext: TuneGenerationReturnContext,
        completedValidationDraftKind: ValidationDraftKind? = nil
    ) {
        self.id = id
        self.request = request
        self.origin = origin
        self.thumbnailData = thumbnailData
        self.savedTuneID = savedTuneID
        self.playerNotes = playerNotes
        self.preferredProviderMode = preferredProviderMode
        self.providerDisclosure = providerDisclosure
        self.returnContext = returnContext
        self.completedValidationDraftKind = completedValidationDraftKind
    }
}
