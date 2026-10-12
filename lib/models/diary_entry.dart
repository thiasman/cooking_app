class DiaryEntry {
  final int? id;
  final String date; // YYYY-MM-DD
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final int? recipeId;
  final String title;
  final double servingsEaten;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final String createdAt;

  const DiaryEntry({
    this.id,
    required this.date,
    required this.mealType,
    this.recipeId,
    required this.title,
    this.servingsEaten = 1.0,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'meal_type': mealType,
      'recipe_id': recipeId,
      'title': title,
      'servings_eaten': servingsEaten,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'created_at': createdAt,
    };
  }

  factory DiaryEntry.fromMap(Map<String, Object?> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      date: map['date'] as String,
      mealType: (map['meal_type'] as String?) ?? 'Meal',
      recipeId: map['recipe_id'] as int?,
      title: map['title'] as String,
      servingsEaten: (map['servings_eaten'] as num?)?.toDouble() ?? 1.0,
      calories: (map['calories'] as num?)?.toDouble(),
      proteinG: (map['protein_g'] as num?)?.toDouble(),
      carbsG: (map['carbs_g'] as num?)?.toDouble(),
      fatG: (map['fat_g'] as num?)?.toDouble(),
      fiberG: (map['fiber_g'] as num?)?.toDouble(),
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}

class DailyMacroSummary {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  const DailyMacroSummary({
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG = 0,
  });
}
