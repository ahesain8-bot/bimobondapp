//
//  ArCameraController.swift
//  Runner
//
//  Created by Mai Atef  on 01/09/2026.
//

import Foundation
import AVFoundation
import UIKit


final class ArCameraController: NSObject {

    static let shared = ArCameraController()

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(
        label: "com.dubai.bimobondapp.ar_camera.session"
    )

    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private(set) var isFrontCamera = true
    private var photoCaptureDelegate: PhotoCaptureDelegate?

    private override init() { super.init() }

    // MARK: - Lifecycle

    func start(completion: (() -> Void)? = nil) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginSession(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                self?.beginSession(completion: completion)
            }
        default:
            // Denied/restricted — Dart's permission_handler flow already
            // gates the screen before this is ever reached.
            break
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// Mirrors `onHostPause` — stop the physical camera while the screen is
    /// covered by another route, without tearing the session down.
    func suspendPreview() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// Mirrors `onHostResume`.
    func resumePreview() {
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    // MARK: - Controls

    func flipCamera(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.isFrontCamera.toggle()
            let ok = self.configureInput(front: self.isFrontCamera)
            DispatchQueue.main.async { completion(ok) }
        }
    }

    func toggleTorch(completion: @escaping (Bool, String?) -> Void) {
        sessionQueue.async { [weak self] in
            guard
                let self,
                let device = self.currentInput?.device,
                device.hasTorch
            else {
                DispatchQueue.main.async {
                    completion(false, "torch_unavailable")
                }
                return
            }

            do {
                try device.lockForConfiguration()

                let newState = device.torchMode != .on
                device.torchMode = newState ? .on : .off

                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    completion(newState, nil)
                }

            } catch {
                DispatchQueue.main.async { completion(false, "torch_failed") }
            }
        }
    }

    func setZoom(_ normalized: Double, completion: ((Bool, String?) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else {
                DispatchQueue.main.async { completion?(false, "no_device") }
                return
            }
            let clamped = max(0.0, min(1.0, normalized))
            let range = device.maxAvailableVideoZoomFactor - device.minAvailableVideoZoomFactor
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = device.minAvailableVideoZoomFactor + CGFloat(clamped) * range
                device.unlockForConfiguration()
                DispatchQueue.main.async { completion?(true, nil) }
            } catch {
                DispatchQueue.main.async { completion?(false, "zoom_failed") }
            }
        }
    }

    func takePhoto(completion: @escaping (String?, String?) -> Void) {
        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }
        let delegate = PhotoCaptureDelegate { path in
            completion(path, path == nil ? "photo_failed" : nil)
        }

        // Keep delegate alive until the capture callback fires.
        photoCaptureDelegate = delegate

        photoOutput.capturePhoto(
            with: settings,
            delegate: delegate
        )
    }

    // MARK: - Internal session setup

    private func beginSession(completion: (() -> Void)?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.configureSession()
                self.session.startRunning()
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    /// Must run on sessionQueue. Picks the highest resolution the device
    /// supports — mirrors Android's CameraX target-resolution selection.
    private func configureSession() {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }

        for preset: AVCaptureSession.Preset in [
            .hd4K3840x2160,
            .hd1920x1080,
            .high
        ] {
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
                break
            }
        }

        configureInput(front: isFrontCamera)

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            // Set the maximum photo dimensions for the current camera.
            refreshMaxPhotoDimensions()
        }
    }

    /// Updates the maximum photo dimensions based on the currently active
    /// camera. Called on initial setup and after every camera flip.
    private func refreshMaxPhotoDimensions() {
        guard let device = currentInput?.device else {
            return
        }

        if #available(iOS 16.0, *) {
            photoOutput.maxPhotoDimensions =
                device.activeFormat.supportedMaxPhotoDimensions.last
                ?? photoOutput.maxPhotoDimensions
        } else {
            photoOutput.isHighResolutionCaptureEnabled = true
        }
    }

    @discardableResult
    private func configureInput(front: Bool) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let existing = currentInput {
            session.removeInput(existing)
            currentInput = nil
        }

        let position: AVCaptureDevice.Position =
            front ? .front : .back

        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return false
        }

        session.addInput(input)
        currentInput = input

        // If the photo output is already attached, this is a camera flip.
        // Refresh the maximum photo dimensions for the new camera.
        if session.outputs.contains(photoOutput) {
            refreshMaxPhotoDimensions()
        }

        return true
    }
}

/// Saves the captured photo to a temp file and returns its path.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (String?) -> Void

    init(completion: @escaping (String?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            completion(nil)
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url)
            completion(url.path)
        } catch {
            completion(nil)
        }
    }
}
