import SwiftUI
import UIKit

struct TuneLoadingView: View {
    let request: TuneRequest
    let onCancel: () -> Void

    init(request: TuneRequest, onCancel: @escaping () -> Void = {}) {
        self.request = request
        self.onCancel = onCancel
    }

    var body: some View {
        TuneGenerationStatusView(
            request: request,
            phase: .working,
            onCancel: onCancel
        )
    }
}

struct TuneGenerationStatusView: View {
    let request: TuneRequest
    let phase: TuneGenerationPresentationPhase
    var onCancel: () -> Void = {}
    var onRetry: () -> Void = {}
    var onChangeDiscipline: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                phaseIcon

                Text(phase.title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .multilineTextAlignment(.center)

                Text("\(request.car.displayName) · \(request.discipline.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.disciplineColor(request.discipline))
                    .multilineTextAlignment(.center)

                Text(phase.detail)
                    .font(.subheadline)
                    .foregroundStyle(ForzAdvisorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                if phase.showsRecovery {
                    recoveryActions
                }

                if phase.showsCancel {
                    Button("Cancel", role: .cancel, action: onCancel)
                        .forzAdvisorMinimumTouchTarget()
                        .accessibilityIdentifier("cancelTuneGenerationButton")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForzAdvisorTheme.screenBackground.ignoresSafeArea())
        .tint(ForzAdvisorTheme.accent)
        .navigationTitle("Generation")
        .accessibilityElement(children: .contain)
        .onChange(of: phase) { _, newPhase in
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(newPhase.title). \(newPhase.detail)"
            )
        }
    }

    @ViewBuilder
    private var phaseIcon: some View {
        ZStack {
            Circle()
                .fill(ForzAdvisorTheme.accent.opacity(0.14))
                .frame(width: 72, height: 72)
            if phase.showsProgress {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel(phase.title)
            } else {
                Image(systemName: phase == .failed
                    ? "exclamationmark.triangle.fill"
                    : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(
                        phase == .failed
                            ? ForzAdvisorTheme.warning
                            : ForzAdvisorTheme.secondaryText
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private var recoveryActions: some View {
        VStack(spacing: 10) {
            Button(DisciplineGenerationCopy.retryTitle, action: onRetry)
                .buttonStyle(ForzAdvisorActionButtonStyle(kind: .primary))
                .forzAdvisorMinimumTouchTarget()
                .accessibilityIdentifier("retryTuneGenerationButton")
            Button(
                DisciplineGenerationCopy.changeDisciplineTitle,
                action: onChangeDiscipline
            )
                .buttonStyle(ForzAdvisorActionButtonStyle(kind: .secondary))
                .forzAdvisorMinimumTouchTarget()
                .accessibilityIdentifier("changeGenerationDisciplineButton")
            Button(DisciplineGenerationCopy.backTitle, action: onBack)
                .forzAdvisorMinimumTouchTarget()
                .accessibilityIdentifier("backFromGenerationFailureButton")
        }
    }
}
