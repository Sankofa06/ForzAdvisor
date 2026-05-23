//
//  CameraPreviewController.swift
//  forzadvisor
//
//  UIKit/AVFoundation bridge that owns the camera session, preview layer, and
//  one-shot photo capture for CameraCaptureView.
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewController: UIViewControllerRepresentable {
    @Binding var captureRequestID: Int

    let onPhotoCaptured: (UIImage) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController(onPhotoCaptured: onPhotoCaptured, onError: onError)
    }

    func updateUIViewController(_ viewController: CameraViewController, context: Context) {
        viewController.capturePhotoIfNeeded(for: captureRequestID)
    }
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.forzadvisor.camera.session")
    private let onPhotoCaptured: (UIImage) -> Void
    private let onError: (String) -> Void

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionConfigured = false
    private var lastCaptureRequestID = 0

    init(onPhotoCaptured: @escaping (UIImage) -> Void, onError: @escaping (String) -> Void) {
        self.onPhotoCaptured = onPhotoCaptured
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        configureAndStartSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    func capturePhotoIfNeeded(for requestID: Int) {
        guard requestID != 0, requestID != lastCaptureRequestID else { return }
        lastCaptureRequestID = requestID

        guard session.isRunning else {
            reportError("Camera is still starting. Try again in a moment.")
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            reportError(error.localizedDescription)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            reportError("Could not read the captured photo.")
            return
        }

        DispatchQueue.main.async {
            self.onPhotoCaptured(image)
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async {
            do {
                try self.configureSessionIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            } catch {
                self.reportError(error.localizedDescription)
            }
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !isSessionConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        else {
            throw CameraCaptureError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.cannotConfigure
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            throw CameraCaptureError.cannotConfigure
        }
        session.addOutput(output)

        isSessionConfigured = true
    }

    private func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async {
            self.onError(message)
        }
    }
}

private enum CameraCaptureError: LocalizedError {
    case unavailable
    case cannotConfigure

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "No camera is available on this device."
        case .cannotConfigure:
            "Could not configure the camera."
        }
    }
}
