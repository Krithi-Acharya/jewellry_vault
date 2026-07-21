import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/closet_service.dart';

class UploadProvider extends ChangeNotifier {
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageSize;
  bool _isUploading = false;
  String? _error;

  Uint8List? get imageBytes => _imageBytes;
  String? get imageName => _imageName;
  String? get imageSize => _imageSize;
  bool get isUploading => _isUploading;
  String? get error => _error;
  bool get hasImage => _imageBytes != null;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage(ImageSource source) async {
    _error = null;
    notifyListeners();

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final length = bytes.length;
        final sizeMB = (length / (1024 * 1024)).toStringAsFixed(1);
        
        _imageBytes = bytes;
        _imageName = pickedFile.name;
        _imageSize = '$sizeMB MB';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to pick image: $e';
      notifyListeners();
    }
  }

  void clearImage() {
    _imageBytes = null;
    _imageName = null;
    _imageSize = null;
    _error = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> uploadImage() async {
    if (_imageBytes == null) return null;
    
    _isUploading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await ClosetService.instance.uploadItemBytes(_imageBytes!, _imageName ?? 'image.jpg');
      _isUploading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isUploading = false;
      _error = 'Upload failed: $e';
      notifyListeners();
      return null;
    }
  }
}
