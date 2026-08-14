import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Non-web fallback. Never actually called — [upload_screen.dart] only
/// routes to the in-browser camera capture flow when `kIsWeb` is true, so
/// this exists purely so the conditional export resolves on non-web builds.
Future<Uint8List?> showWebCameraCapture(BuildContext context) async {
  throw UnsupportedError('Web camera capture is only available on web.');
}
