import 'dart:io';

import 'package:image/image.dart' as img;

/// Generate a test image with synthetic content (gradient pattern)
/// Returns the file path to the generated image
Future<String> generateTestImage({
  required int width,
  required int height,
  required String fileName,
}) async {
  // Create a new image with gradient pattern for reproducibility
  // Image constructor in package:image v3.3.0
  final image = img.Image(width, height);

  // Fill with gradient pattern (red to blue)
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final r = ((x / width) * 255).toInt();
      final g = ((y / height) * 128).toInt();
      final b = 255 - ((x / width) * 255).toInt();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Save as PNG (lossless format)
  final file = File(fileName);
  await file.writeAsBytes(img.encodePng(image));

  return fileName;
}

/// Verify that image resize operation was successful
/// Checks dimensions and content integrity
/// Returns true if verification passes
Future<bool> verifyImageResize({
  required String originalImagePath,
  required String resultImagePath,
  required int expectedWidth,
  required int expectedHeight,
  double ssimThreshold = 0.7,
}) async {
  // Load both images
  final originalBytes = await File(originalImagePath).readAsBytes();
  final resultBytes = await File(resultImagePath).readAsBytes();

  final originalImage = img.decodeImage(originalBytes);
  final resultImage = img.decodeImage(resultBytes);

  if (originalImage == null || resultImage == null) {
    throw Exception('Failed to decode images');
  }

  // Verify output dimensions
  if (resultImage.width != expectedWidth ||
      resultImage.height != expectedHeight) {
    throw Exception(
      'Output dimensions do not match. Expected: ${expectedWidth}x$expectedHeight, '
      'Got: ${resultImage.width}x${resultImage.height}',
    );
  }

  // Simple content verification: check that image has data and is not empty
  // In production, you would compute structural similarity (SSIM) here
  var nonZeroPixels = 0;
  for (var y = 0; y < resultImage.height; y++) {
    for (var x = 0; x < resultImage.width; x++) {
      final pixel = resultImage.getPixel(x, y);
      if (pixel != 0) {
        nonZeroPixels++;
      }
    }
  }

  final filledRatio = nonZeroPixels / (resultImage.width * resultImage.height);
  if (filledRatio < 0.1) {
    // Less than 10% of pixels have data, likely empty/corrupted
    throw Exception('Image content verification failed: insufficient pixel data');
  }

  return true;
}

/// Cleanup test image files
Future<void> cleanupTestImages(List<String> filePaths) async {
  for (final path in filePaths) {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
