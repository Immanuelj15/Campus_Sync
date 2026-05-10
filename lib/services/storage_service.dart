import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> uploadImageFile({
    required File file,
    required String postId,
    String? subPath,
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final fileName = subPath != null
          ? '$postId/$subPath.jpg'
          : '$postId/image.jpg';
      final ref = _storage.ref().child('posts/$fileName');
      final uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final totalBytes = snapshot.totalBytes;
        if (totalBytes <= 0) {
          return;
        }
        onProgress?.call(snapshot.bytesTransferred / totalBytes);
      });

      final snapshot = await uploadTask;
      return snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  static Future<String?> pickAndUploadImage({
    required String postId,
    bool useCamera = false,
    String? subPath,
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: useCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null) return null;

      return uploadImageFile(
        file: File(image.path),
        postId: postId,
        subPath: subPath,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }
}
