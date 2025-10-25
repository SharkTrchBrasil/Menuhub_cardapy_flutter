// lib/models/image_model.dart

import 'package:equatable/equatable.dart';

class ImageModel extends Equatable {
  final int? id;
  final String url;
  final bool isVideo;

  const ImageModel({
    this.id,
    required this.url,
    this.isVideo = false,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    // O backend envia 'image_url' para imagens da galeria.
    final imageUrl = json['image_url'] ?? json['url'] ?? '';
    return ImageModel(
      id: json['id'],
      url: imageUrl,
      // O admin não envia 'isVideo', então deduzimos ou assumimos false.
      // Uma lógica mais robusta poderia verificar a extensão do arquivo se necessário.
      isVideo: imageUrl.contains('.mp4'),
    );
  }

  @override
  List<Object?> get props => [id, url, isVideo];
}