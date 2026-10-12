class Recipe {
  final int? id;
  final String title;
  final double servings;
  final int? prepTimeMins;
  final String tags;
  final String ingredients;
  final String instructions;
  final double? caloriesPerServing;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final String? nutritionNote;
  final String createdAt;
  final String updatedAt;
  final String? coverPhotoPath;

  const Recipe({
    this.id,
    required this.title,
    this.servings = 1.0,
    this.prepTimeMins,
    this.tags = '',
    required this.ingredients,
    required this.instructions,
    this.caloriesPerServing,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.nutritionNote,
    required this.createdAt,
    required this.updatedAt,
    this.coverPhotoPath,
  });

  List<String> get tagList => tags
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  List<String> get ingredientLines => ingredients
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  bool get hasNutrition => caloriesPerServing != null;

  Recipe copyWith({
    int? id,
    String? title,
    double? servings,
    int? prepTimeMins,
    String? tags,
    String? ingredients,
    String? instructions,
    double? caloriesPerServing,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    String? nutritionNote,
    String? createdAt,
    String? updatedAt,
    String? coverPhotoPath,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      servings: servings ?? this.servings,
      prepTimeMins: prepTimeMins ?? this.prepTimeMins,
      tags: tags ?? this.tags,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      caloriesPerServing: caloriesPerServing ?? this.caloriesPerServing,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      nutritionNote: nutritionNote ?? this.nutritionNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'servings': servings,
      'prep_time_mins': prepTimeMins,
      'tags': tags,
      'ingredients': ingredients,
      'instructions': instructions,
      'calories_per_serving': caloriesPerServing,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'nutrition_note': nutritionNote,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Recipe.fromMap(Map<String, Object?> map) {
    return Recipe(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      servings: (map['servings'] as num?)?.toDouble() ?? 1.0,
      prepTimeMins: map['prep_time_mins'] as int?,
      tags: (map['tags'] as String?) ?? '',
      ingredients: (map['ingredients'] as String?) ?? '',
      instructions: (map['instructions'] as String?) ?? '',
      caloriesPerServing: (map['calories_per_serving'] as num?)?.toDouble(),
      proteinG: (map['protein_g'] as num?)?.toDouble(),
      carbsG: (map['carbs_g'] as num?)?.toDouble(),
      fatG: (map['fat_g'] as num?)?.toDouble(),
      fiberG: (map['fiber_g'] as num?)?.toDouble(),
      nutritionNote: map['nutrition_note'] as String?,
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      coverPhotoPath: map['cover_photo_path'] as String?,
    );
  }
}
