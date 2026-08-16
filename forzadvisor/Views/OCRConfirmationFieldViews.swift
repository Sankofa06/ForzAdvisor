import SwiftUI
import UIKit

struct OCRReviewNumberField: View {
    let title: String
    let placeholder: String
    let text: Binding<String>
    let evidence: OCRFieldEvidence
    let state: OCRFieldReviewState
    let candidates: [OCRFieldCandidate]
    let focus: FocusState<OCRConfirmationUnresolvedField?>.Binding
    let focusValue: OCRConfirmationUnresolvedField
    let onConfirm: () -> Void
    let onCandidate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title) {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focus, equals: focusValue)
            }
            OCRReviewStatusRow(state: state, rawText: evidence.rawText, onConfirm: onConfirm)
            OCRCandidateChipRow(candidates: candidates, onSelect: onCandidate)
        }
        .ocrReviewRow(state: state)
    }
}

struct OCRReviewStatusRow: View {
    let state: OCRFieldReviewState
    var rawText: String?
    let onConfirm: () -> Void

    init(
        state: OCRFieldReviewState,
        rawText: String? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.state = state
        self.rawText = rawText
        self.onConfirm = onConfirm
    }

    var body: some View {
        HStack(spacing: 8) {
            Label(state.rawValue, systemImage: statusImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(state == .needsCheck ? ForzAdvisorTheme.warning : ForzAdvisorTheme.success)
            if let rawText {
                Text("Read as \(rawText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if state == .needsCheck {
                Button("Confirm", action: onConfirm)
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: ForzAdvisorTheme.minimumTouchTarget)
            }
        }
    }

    private var statusImage: String {
        state == .needsCheck ? "questionmark.diamond.fill" : "checkmark.circle.fill"
    }
}

struct OCRCandidateChipRow: View {
    let candidates: [OCRFieldCandidate]
    let onSelect: (String) -> Void

    private var uniqueCandidates: [OCRFieldCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.value).inserted }.prefix(3).map { $0 }
    }

    var body: some View {
        if !uniqueCandidates.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(uniqueCandidates) { candidate in
                        Button(candidate.value) { onSelect(candidate.value) }
                            .font(.caption.weight(.semibold))
                            .frame(minHeight: ForzAdvisorTheme.minimumTouchTarget)
                            .padding(.horizontal, 8)
                            .foregroundStyle(ForzAdvisorTheme.accent)
                            .background(ForzAdvisorTheme.accent.opacity(0.14), in: Capsule())
                    }
                }
            }
        }
    }
}

struct OCRSourceEvidenceView: View {
    let imageData: Data?
    let region: CGRect?

    var body: some View {
        if let image = sourceImage {
            Section("Source image - stored on this device") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Imported Forza source image")
                if let crop = crop(image: image, normalizedRegion: region) {
                    LabeledContent("Relevant area") {
                        Image(uiImage: crop)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180, maxHeight: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .forzAdvisorRowBackground()
        }
    }

    private var sourceImage: UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }

    private func crop(image: UIImage, normalizedRegion: CGRect?) -> UIImage? {
        guard let normalizedRegion, let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let rect = CGRect(
            x: normalizedRegion.minX * width,
            y: (1 - normalizedRegion.maxY) * height,
            width: normalizedRegion.width * width,
            height: normalizedRegion.height * height
        ).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !rect.isEmpty, let cropped = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension View {
    @ViewBuilder
    func ocrReviewRow(state: OCRFieldReviewState) -> some View {
        if state == .needsCheck {
            listRowBackground(ForzAdvisorTheme.warning.opacity(0.13))
        } else {
            forzAdvisorRowBackground()
        }
    }
}
