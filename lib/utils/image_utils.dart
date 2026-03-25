import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  /// Comprime una imagen en [inputPath] y guarda el resultado en app documents.
  /// - maxWidth: ancho máximo en px (mantiene aspecto)
  /// - quality: 0..100 (JPEG quality)
  /// Retorna ruta del archivo comprimido.
  static Future<String> compressAndSave(
    String inputPath, {
    int maxWidth = 1600,
    int quality = 80,
    String? prefix,
  }) async {
    final outDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(inputPath).toLowerCase();
    final basename = p.basenameWithoutExtension(inputPath);
    final outName =
        '${prefix ?? 'img'}_${basename}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = p.join(outDir.path, outName);

    // flutter_image_compress acepta archivo o bytes. Usamos compressAndGetFile.
    final result = await FlutterImageCompress.compressAndGetFile(
      inputPath,
      outPath,
      quality: quality,
      minWidth:
          maxWidth, // si la imagen es más pequeña no la escala hacia arriba
      keepExif: true,
      format: CompressFormat.jpeg,
    );

    // Si falla la compresión, fallback a copia simple
    if (result == null) {
      final fallback = File(inputPath);
      final copy = await fallback.copy(outPath);
      return copy.path;
    }

    return result.path;
  }

  /// Genera un thumbnail (menor ancho) y lo guarda; retorna ruta.
  static Future<String> generateThumbnail(
    String inputPath, {
    int width = 300,
    int quality = 70,
  }) async {
    final outDir = await getApplicationDocumentsDirectory();
    final basename = p.basenameWithoutExtension(inputPath);
    final outName =
        'thumb_${basename}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = p.join(outDir.path, outName);

    final result = await FlutterImageCompress.compressAndGetFile(
      inputPath,
      outPath,
      quality: quality,
      minWidth: width,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      final fallback = File(inputPath);
      final copy = await fallback.copy(outPath);
      return copy.path;
    }
    return result.path;
  }
}
