// lib/models/image_model.dart

class ImageModel {
  final int? id;
  final String url;
  final String? fileKey;
  final bool isVideo;

  ImageModel({
    this.id,
    required this.url,
    this.fileKey,
    this.isVideo = false,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    // ✅ CORREÇÃO APLICADA AQUI
    // Agora ele procura por 'image_url' primeiro, que é o que o seu JSON contém.
    final imageUrl = json['image_url'] ?? json['image_path'] ?? json['url'] ?? '';

    return ImageModel(
      id: json['id'] as int?,
      url: imageUrl,
      fileKey: json['file_key'] as String?,
      isVideo: json['is_video'] as bool? ?? imageUrl.contains('.mp4'),
    );
  }
}