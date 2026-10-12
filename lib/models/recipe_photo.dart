class RecipePhoto {
  final int? id;
  final int recipeId;
  final String filePath;
  final bool isCover;
  final String createdAt;

  const RecipePhoto({
    this.id,
    required this.recipeId,
    required this.filePath,
    this.isCover = false,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'recipe_id': recipeId,
      'file_path': filePath,
      'is_cover': isCover ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory RecipePhoto.fromMap(Map<String, Object?> map) {
    return RecipePhoto(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int,
      filePath: map['file_path'] as String,
      isCover: (map['is_cover'] as int? ?? 0) == 1,
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}
