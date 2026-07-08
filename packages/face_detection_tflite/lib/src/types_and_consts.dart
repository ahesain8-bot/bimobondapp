part of face_detection_tflite;

enum FaceIndex { leftEye, rightEye, noseTip, mouth, leftEyeTragion, rightEyeTragion }
/// Slim package keeps only [frontCamera]; other names remain for API compatibility
/// but all resolve to the front-camera model asset.
enum FaceDetectionModel { frontCamera, backCamera, shortRange, full, fullSparse }
enum FaceDetectionMode { fast, standard, full }

const _modelNameFront = 'face_detection_front.tflite';

const _rawScoreLimit = 80.0;
const _minScore = 0.5;
const _minSuppressionThreshold = 0.3;

const _ssdFront = {
  'num_layers': 4,
  'input_size_height': 128,
  'input_size_width': 128,
  'anchor_offset_x': 0.5,
  'anchor_offset_y': 0.5,
  'strides': [8, 16, 16, 16],
  'interpolated_scale_aspect_ratio': 1.0,
};

class FaceResult {
  final Detection detection;
  final List<math.Point<double>> mesh;
  final List<math.Point<double>> irises;
  final Size originalSize;

  FaceResult({
    required this.detection,
    required this.mesh,
    required this.irises,
    required this.originalSize,
  });

  List<math.Point<double>> get bboxCorners {
    final r = detection.bbox;
    final w = originalSize.width.toDouble();
    final h = originalSize.height.toDouble();
    return [
      math.Point<double>(r.xmin * w, r.ymin * h),
      math.Point<double>(r.xmax * w, r.ymin * h),
      math.Point<double>(r.xmax * w, r.ymax * h),
      math.Point<double>(r.xmin * w, r.ymax * h),
    ];
  }

  Map<FaceIndex, math.Point<double>> get landmarks => detection.landmarks;
}

class PipelineResult {
  final List<FaceResult> faces;
  final Size originalSize;
  PipelineResult({required this.faces, required this.originalSize});

  List<FaceResult> get perFace => faces;
}

class RectF {
  final double xmin, ymin, xmax, ymax;
  const RectF(this.xmin, this.ymin, this.xmax, this.ymax);
  double get w => xmax - xmin;
  double get h => ymax - ymin;
  RectF scale(double sx, double sy) => RectF(xmin * sx, ymin * sy, xmax * sx, ymax * sy);
  RectF expand(double frac) {
    final cx = (xmin + xmax) * 0.5;
    final cy = (ymin + ymax) * 0.5;
    final hw = (w * (1.0 + frac)) * 0.5;
    final hh = (h * (1.0 + frac)) * 0.5;
    return RectF(cx - hw, cy - hh, cx + hw, cy + hh);
  }
}

class Detection {
  final RectF bbox;
  final double score;
  final List<double> keypointsXY;
  final Size? imageSize;

  Detection({
    required this.bbox,
    required this.score,
    required this.keypointsXY,
    this.imageSize,
  });

  double operator [](int i) => keypointsXY[i];

  Map<FaceIndex, math.Point<double>> get landmarks {
    final sz = imageSize;
    if (sz == null) {
      throw StateError('Detection.imageSize is null; cannot produce pixel landmarks.');
    }
    final w = sz.width.toDouble(), h = sz.height.toDouble();
    final map = <FaceIndex, math.Point<double>>{};
    for (final idx in FaceIndex.values) {
      final xn = keypointsXY[idx.index * 2];
      final yn = keypointsXY[idx.index * 2 + 1];
      map[idx] = math.Point<double>(xn * w, yn * h);
    }
    return map;
  }
}

class ImageTensor {
  final Float32List tensorNHWC;
  final List<double> padding;
  final int width, height;
  ImageTensor(this.tensorNHWC, this.padding, this.width, this.height);
}

class _DecodedBox {
  final RectF bbox;
  final List<double> keypointsXY;
  _DecodedBox(this.bbox, this.keypointsXY);
}

extension DetectionPoints on Detection {
  Map<FaceIndex, math.Point<double>> get landmarksPoints => landmarks;
}

extension FaceResultPoints on FaceResult {
  List<math.Point<double>> get bboxCornersPoints => bboxCorners;
  List<math.Point<double>> get meshPoints => mesh;
  List<math.Point<double>> get irisesPoints => irises;
}
