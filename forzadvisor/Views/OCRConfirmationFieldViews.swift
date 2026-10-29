import SwiftUI
import UIKit

struct OCRReviewNumberField: View {
    let title: String
    let placeholder: String
    let text: Binding<String>
    let evidence: OCRFieldEvidence
    let state: OCRFieldReviewState
    let candidates: [OCRFieldCandidate]
    let focus: FocusState<InputFieldFocus?>.Binding
    let focusValue: InputFieldFocus
    let onConfirm: () -> Void
    let onCandidate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("\(title) (\(placeholder))") {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focus, equals: focusValue)
                    .accessibilityLabel("\(title), \(placeholder)")
            }
            OCRReviewStatusRow(
                state: state,
                fieldTitle: title,
                rawText: evidence.rawText,
                normalizedValue: evidence.normalizedValue,
                normalizedUnit: placeholder,
                requiresManualCorrection: evidence.requiresManualCorrection,
                onConfirm: onConfirm
            )
            OCRCandidateChipRow(fieldTitle: title, candidates: candidates, onSelect: onCandidate)
        }
        .ocrReviewRow(state: state)
    }
}

struct OCRReviewStatusRow: View {
    let state: OCRFieldReviewState
    let fieldTitle: String
    var rawText: String?
    var normalizedValue: String?
    var normalizedUnit: String?
    var requiresManualCorrection: Bool
    let onConfirm: () -> Void

    init(
        state: OCRFieldReviewState,
        fieldTitle: String,
        rawText: String? = nil,
        normalizedValue: String? = nil,
        normalizedUnit: String? = nil,
        requiresManualCorrection: Bool = false,
        onConfirm: @escaping () -> Void
    ) {
        self.state = state
        self.fieldTitle = fieldTitle
        self.rawText = rawText
        self.normalizedValue = normalizedValue
        self.normalizedUnit = normalizedUnit
        self.requiresManualCorrection = requiresManualCorrection
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Label(state.rawValue, systemImage: statusImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state == .needsCheck ? ForzAdvisorTheme.warning : ForzAdvisorTheme.success)
                if state == .needsCheck && !requiresManualCorrection {
                    Button("Confirm \(fieldTitle)", action: onConfirm)
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: ForzAdvisorTheme.minimumTouchTarget)
                }
            }
            if let rawText {
                Text("Source: \(rawText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let normalizedValue, let normalizedUnit {
                Text("Normalized by OCR: \(normalizedValue) \(normalizedUnit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if requiresManualCorrection {
                Text("Unit is missing or unclear. Enter the value from the game in \(normalizedUnit ?? "the displayed unit").")
                    .font(.caption)
                    .foregroundStyle(ForzAdvisorTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusImage: String {
        state == .needsCheck ? "questionmark.diamond.fill" : "checkmark.circle.fill"
    }
}

struct OCRCandidateChipRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let fieldTitle: String
    let candidates: [OCRFieldCandidate]
    let onSelect: (String) -> Void

    private var uniqueCandidates: [OCRFieldCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.value).inserted }.prefix(3).map { $0 }
    }

    var body: some View {
        if !uniqueCandidates.isEmpty {
            Group {
                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 6) {
                    ForEach(uniqueCandidates) { candidate in
                        Button(candidate.value) { onSelect(candidate.value) }
                            .accessibilityLabel("Use \(candidate.value) for \(fieldTitle)")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
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
