import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Pushes a full-screen live camera view (getUserMedia + <video>) and
/// resolves with the captured frame's PNG bytes, or null if the user backed
/// out. Desktop browsers don't honor image_picker's camera "capture" hint —
/// it just opens a file browser there — so this is the only way to get an
/// actual live camera on web.
Future<Uint8List?> showWebCameraCapture(BuildContext context) {
  return Navigator.of(context).push<Uint8List?>(
    MaterialPageRoute(
      builder: (_) => const _WebCameraCaptureScreen(),
      fullscreenDialog: true,
    ),
  );
}

class _WebCameraCaptureScreen extends StatefulWidget {
  const _WebCameraCaptureScreen();

  @override
  State<_WebCameraCaptureScreen> createState() =>
      _WebCameraCaptureScreenState();
}

class _WebCameraCaptureScreenState extends State<_WebCameraCaptureScreen> {
  late final String _viewType;
  final html.VideoElement _video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..style.objectFit = 'cover'
    ..style.width = '100%'
    ..style.height = '100%';
  html.MediaStream? _stream;
  String? _error;
  bool _ready = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'camera-capture-view-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      setState(
        () => _error = "This browser doesn't support camera access.",
      );
      return;
    }
    try {
      final stream = await mediaDevices.getUserMedia({
        'video': {'facingMode': 'environment'},
        'audio': false,
      });
      _stream = stream;
      _video.srcObject = stream;
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not access the camera. Check your browser permissions and try again.',
      );
    }
  }

  Future<void> _capture() async {
    if (!_ready || _capturing) return;
    setState(() => _capturing = true);

    final width = _video.videoWidth;
    final height = _video.videoHeight;
    if (width == 0 || height == 0) {
      setState(() => _capturing = false);
      return;
    }

    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImage(_video, 0, 0);
    final blob = await canvas.toBlob('image/png');

    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;
    final bytes = (reader.result as ByteBuffer).asUint8List();

    _stopStream();
    if (mounted) Navigator.of(context).pop(bytes);
  }

  void _stopStream() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Take Photo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        HtmlElementView(viewType: _viewType),
                        if (!_ready)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
            ),
            if (_error == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ElevatedButton(
                    onPressed: _ready && !_capturing ? _capture : null,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white38,
                      padding: EdgeInsets.zero,
                    ),
                    child: _capturing
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 32,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
