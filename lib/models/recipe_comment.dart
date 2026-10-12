class RecipeComment {
  final int? id;
  final int recipeId;
  final String comment;
  final String createdAt;

  const RecipeComment({
    this.id,
    required this.recipeId,
    required this.comment,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'recipe_id': recipeId,
      'comment': comment,
      'created_at': createdAt,
    };
  }

  factory RecipeComment.fromMap(Map<String, Object?> map) {
    return RecipeComment(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int,
      comment: map['comment'] as String,
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}
