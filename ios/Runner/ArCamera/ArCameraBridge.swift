//
//  ArCameraBridge.swift
//  Runner
//
//  Created by Mai Atef  on 01/09/2026.
//

import Foundation
import UIKit
import AVFoundation


enum ArCameraBridge {
    static weak var previewContainer: UIView?
    static weak var previewLayer: AVCaptureVideoPreviewLayer?

    static var controller: ArCameraController { .shared }

    static func clear() {
        previewContainer = nil
        previewLayer = nil
    }
}
