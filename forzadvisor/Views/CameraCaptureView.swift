//
//  CameraCaptureView.swift
//  forzadvisor
//
//  AVFoundation still-photo capture surface used by NewTuneStartView before
//  handing the captured image to Vision OCR confirmation.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraCaptureView: View {
    let onCancel: () -> Void
    let onUseManualEntry: () -> Void
    let onPhotoCaptured: (UIImage) -> Void

    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var captureRequestID = 0
    @State private var errorMessage: String?

    private var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !hasCamera {
                CameraStateView(
                    title: "Camera unavailable",
                    message: "This device cannot take a photo right now. Import a screenshot or enter the values manually.",
                    primaryTitle: "Enter Manually",
                    primaryAction: onUseManualEntry,
                    secondaryTitle: "Cancel",
                    secondaryAction: onCancel
                )
            } else {
                switch authorizationStatus {
                case .authorized:
                    authorizedCameraView
                case .notDetermined:
                    CameraStateView(
                        title: "Camera Access",
                        message: "Allow camera access to photograph the Forza performance screen.",
                        primaryTitle: "Continue",
                        primaryAction: requestCameraAccess,
                        secondaryTitle: "Cancel",
                        secondaryAction: onCancel
                    )
                case .denied, .restricted:
                    CameraStateView(
                        title: "Camera access denied",
                        message: "Enable camera access in Settings, import a saved screenshot, or enter the values manually.",
                        primaryTitle: "Enter Manually",
                        primaryAction: onUseManualEntry,
                        secondaryTitle: "Cancel",
                        secondaryAction: onCancel
                    )
                @unknown default:
                    CameraStateView(
                        title: "Camera unavailable",
                        message: "The camera is not available on this device.",
                        primaryTitle: "Enter Manually",
                        primaryAction: onUseManualEntry,
                        secondaryTitle: "Cancel",
                        secondaryAction: onCancel
                    )
                }
            }
        }
        .task {
            if authorizationStatus == .notDetermined {
                requestCameraAccess()
            }
        }
    }

    private var authorizedCameraView: some View {
        ZStack {
            CameraPreviewController(
                captureRequestID: $captureRequestID,
                onPhotoCaptured: onPhotoCaptured,
                onError: { errorMessage = $0 }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.borderedProminent)
                        .tint(.black.opacity(0.65))

                    Spacer()
                }
                .padding()

                Spacer()

                CameraCaptureGuide()
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.65), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 18)
                }

                Button {
                    errorMessage = nil
                    captureRequestID += 1
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 5)
                            .frame(width: 76, height: 76)
                        Circle()
                            .fill(.white)
                            .frame(width: 58, height: 58)
                    }
                    .accessibilityLabel("Take Photo")
                }
                .padding(.bottom, 34)
            }
        }
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                authorizationStatus = granted ? .authorized : .denied
            }
        }
    }
}

private struct CameraCaptureGuide: View {
    private let labels = ["Weight", "Front %", "PI/Class", "Drivetrain"]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.16), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.65), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    Text("Performance panel")
                        .font(.caption.weight(.semibold))
                        .padding(8)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: 360)
        }
        .padding(10)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CameraStateView: View {
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: 320)
            }

            VStack(spacing: 10) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                Button(secondaryTitle, action: secondaryAction)
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)
        }
        .padding()
    }
}
