// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker picker = ImagePicker();

  Future<XFile?> pickFromCamera() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null) return null;

    return cropImage(image);
  }

  Future<XFile?> pickFromGallery() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return null;

    return cropImage(image);
  }
  Future<List<XFile>> pickMultipleFromGallery() async {
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 85,
    );

    return images;
  }

  Future<XFile?> cropImage(XFile image) async {
    final CroppedFile? croppedFile =
        await ImageCropper().cropImage(
      sourcePath: image.path,

      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Document',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black,
          statusBarColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: Colors.blue,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),

        IOSUiSettings(
          title: 'Crop Document',
        ),
      ],
    );

    if (croppedFile == null) return null;

    return XFile(croppedFile.path);
  }
}