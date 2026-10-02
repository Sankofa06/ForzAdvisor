#if DEBUG
import SwiftUI

struct OCRManualValuesUITestHarness: View {
    @State private var outcome: String?

    var body: some View {
        NavigationStack {
            if let outcome {
                Text(outcome)
            } else {
                OCRConfirmationView(
                    draft: draft,
                    onBack: {},
                    onUseManualEntry: { _ in },
                    onContinue: { car, confirmedDraft in
                        let fallback = confirmedDraft.manualEntryFallback()
                        outcome = "Input: \(car.peakHorsepower ?? 0) hp, \(car.peakTorqueFootPounds ?? 0) lb-ft; fallback: \(fallback.peakHorsepower ?? 0) hp, \(fallback.peakTorqueFootPounds ?? 0) lb-ft"
                    }
                )
            }
        }
    }

    private var draft: OCRConfirmationDraft {
        var draft = OCRTextParser.confirmationDraft(from: [
            OCRTextObservation(text: "Weight 3400 lb", confidence: 0.95),
            OCRTextObservation(text: "Front 51%", confidence: 0.95),
            OCRTextObservation(text: "Class A 700", confidence: 0.95),
            OCRTextObservation(text: "RWD", confidence: 0.95)
        ])
        draft.year = 2020
        draft.make = "Toyota"
        draft.model = "Supra"
        return draft
    }
}
#endif
