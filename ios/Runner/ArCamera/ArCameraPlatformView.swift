//
//  ArCameraPlatformView.swift
//  Runner
//
//  Created by Mai Atef  on 01/09/2026.
//

import Foundation
import Flutter
import UIKit
import AVFoundation


private final class PreviewContainerView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.forEach { $0.frame = bounds }
    }
}


final class ArCameraPlatformView: NSObject, FlutterPlatformView {
    private let root = PreviewContainerView()

    init(frame: CGRect) {
        super.init()
        root.frame = frame
        root.backgroundColor = .black

        NotificationCenter.default.addObserver(
            self, selector: #selector(onHostPause),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onHostResume),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )

        let previewLayer = AVCaptureVideoPreviewLayer(session: ArCameraController.shared.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = root.bounds
        root.layer.addSublayer(previewLayer)

        ArCameraBridge.previewContainer = root
        ArCameraBridge.previewLayer = previewLayer

        ArCameraController.shared.start()
    }

    func view() -> UIView { root }

    @objc private func onHostPause() {
        ArCameraController.shared.suspendPreview()
    }

    @objc private func onHostResume() {
        ArCameraController.shared.resumePreview()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        ArCameraController.shared.stop()
        ArCameraBridge.clear()
    }
}
