//
//  ArCameraPlatformViewFactory.swift
//  Runner
//
//  Created by Mai Atef  on 01/09/2026.
//

import Foundation
import Flutter
import UIKit


final class ArCameraPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return ArCameraPlatformView(frame: frame)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
