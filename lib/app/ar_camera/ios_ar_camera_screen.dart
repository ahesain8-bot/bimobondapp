import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';

class IosArCameraScreen extends StatelessWidget {
  const IosArCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: UiKitView(
              viewType: ArCameraConstants.viewType,
              layoutDirection: TextDirection.ltr,
              creationParamsCodec: StandardMessageCodec(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
