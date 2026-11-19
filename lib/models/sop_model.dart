import '../services/image_service.dart';

/// Kategori SOP — pengelompokan panduan (mis. Buka Toko, Kebersihan).
class SopCategoryModel {
  final int id;
  final String name;
  final String? icon;
  final int sopsCount;

  SopCategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.sopsCount = 0,
  });

  factory SopCategoryModel.fromJson(Map<String, dynamic> json) {
    return SopCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'],
      sopsCount: json['sops_count'] ?? 0,
    );
  }
}

/// Satu langkah SOP: judul, deskripsi, dan gambar panduan opsional.
class SopStepModel {
  final int id;
  final String title;
  final String? description;
  final String? image;

  /// Reserved fase eksekusi checklist (fase C) — diparsing, belum dipakai UI.
  final bool requiresPhoto;

  SopStepModel({
    required this.id,
    required this.title,
    this.description,
    this.image,
    this.requiresPhoto = false,
  });

  String? get imageUrl => ImageService.buildUrl(image);

  factory SopStepModel.fromJson(Map<String, dynamic> json) {
    return SopStepModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      image: json['image'],
      requiresPhoto: json['requires_photo'] == true,
    );
  }
}

/// SOP terstruktur: judul, deskripsi, cover, dan langkah-langkahnya.
class SopModel {
  final int id;
  final String title;
  final String? description;
  final String? coverImage;
  final int? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int revision;

  /// Hanya terisi dari endpoint list (`steps_count`); detail mengisi [steps].
  final int stepCount;

  final List<SopStepModel> steps;

  SopModel({
    required this.id,
    required this.title,
    this.description,
    this.coverImage,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.revision = 1,
    this.stepCount = 0,
    this.steps = const [],
  });

  String? get coverImageUrl => ImageService.buildUrl(coverImage);

  bool get hasSteps => steps.isNotEmpty;

  int get totalStepCount => steps.isNotEmpty ? steps.length : stepCount;

  factory SopModel.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List? ?? [])
        .map((e) => SopStepModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return SopModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      coverImage: json['cover_image'],
      categoryId: json['sop_category_id'] ?? json['category']?['id'],
      categoryName: json['category']?['name'],
      categoryIcon: json['category']?['icon'],
      revision: json['revision'] ?? 1,
      stepCount: json['steps_count'] ?? steps.length,
      steps: steps,
    );
  }
}
