
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

    final List<XFile> croppedImages = [];

    for (final image in images) {
      final XFile? cropped = await cropImage(image);

      if (cropped != null) {
        croppedImages.add(cropped);
      }
    }

    return croppedImages;
  }

  Future<XFile?> cropImage(XFile image) async {
    final CroppedFile? croppedFile =
        await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle : '',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black,
          // ignore: deprecated_member_use
          statusBarColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: Colors.blue,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: '',
        ),
      ],
    );

    if (croppedFile == null) return null;

    return XFile(croppedFile.path);
  }
}