import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/recipe.dart';

class NutritionEstimate {
  final double caloriesPerServing;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String note;

  const NutritionEstimate({
    required this.caloriesPerServing,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.note,
  });

  factory NutritionEstimate.fromJson(Map<String, dynamic> json) {
    return NutritionEstimate(
      caloriesPerServing: (json['calories_per_serving'] as num?)?.toDouble() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0,
      note: (json['note'] as String?) ?? '',
    );
  }
}

class SavedRecipeMatch {
  final int recipeId;
  final String title;
  final String reasonOrTip;

  const SavedRecipeMatch({
    required this.recipeId,
    required this.title,
    required this.reasonOrTip,
  });
}

class SuggestedRecipeIdea {
  final String title;
  final double servings;
  final int prepTimeMins;
  final String tags;
  final String ingredients;
  final String instructions;
  final double caloriesPerServing;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  const SuggestedRecipeIdea({
    required this.title,
    required this.servings,
    required this.prepTimeMins,
    required this.tags,
    required this.ingredients,
    required this.instructions,
    required this.caloriesPerServing,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });

  factory SuggestedRecipeIdea.fromJson(Map<String, dynamic> json) {
    return SuggestedRecipeIdea(
      title: (json['title'] as String?) ?? 'Untitled Idea',
      servings: (json['servings'] as num?)?.toDouble() ?? 2.0,
      prepTimeMins: (json['prep_time_mins'] as num?)?.toInt() ?? 20,
      tags: (json['tags'] as String?) ?? 'ai-idea',
      ingredients: (json['ingredients'] as String?) ?? '',
      instructions: (json['instructions'] as String?) ?? '',
      caloriesPerServing: (json['calories_per_serving'] as num?)?.toDouble() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0,
    );
  }
}

class InspirationResult {
  final List<SavedRecipeMatch> savedMatches;
  final List<SuggestedRecipeIdea> newIdeas;

  const InspirationResult({
    required this.savedMatches,
    required this.newIdeas,
  });
}

class GeminiService {
  static const String modelName = 'gemini-3.5-flash-lite';
  static const String _apiKeyStorageKey = 'gemini_api_key';

  final FlutterSecureStorage _secureStorage;

  GeminiService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<String?> getApiKey() async {
    final key = await _secureStorage.read(key: _apiKeyStorageKey);
    if (key != null && key.trim().isNotEmpty) {
      return key.trim();
    }
    return null;
  }

  Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey.trim());
  }

  Future<GenerativeModel> _createJsonModel(Schema responseSchema) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Gemini API key not configured. Please add your Google AI Studio API key in Settings.',
      );
    }

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: responseSchema,
        temperature: 0.2,
      ),
    );
  }

  /// Estimates calories and macronutrients per serving for a recipe or a freeform meal description.
  Future<NutritionEstimate> estimateNutrition({
    required String title,
    required String ingredients,
    double servings = 1.0,
  }) async {
    final schema = Schema.object(
      properties: {
        'calories_per_serving': Schema.number(
          description: 'Estimated kcal per single serving',
        ),
        'protein_g': Schema.number(
          description: 'Estimated grams of protein per single serving',
        ),
        'carbs_g': Schema.number(
          description: 'Estimated grams of total carbohydrates per single serving',
        ),
        'fat_g': Schema.number(
          description: 'Estimated grams of total fat per single serving',
        ),
        'fiber_g': Schema.number(
          description: 'Estimated grams of dietary fiber per single serving',
        ),
        'note': Schema.string(
          description: 'Brief 1-sentence breakdown or key assumption',
        ),
      },
      requiredProperties: [
        'calories_per_serving',
        'protein_g',
        'carbs_g',
        'fat_g',
        'fiber_g',
        'note',
      ],
    );

    final model = await _createJsonModel(schema);
    final prompt = '''
Estimate the nutrition PER SINGLE SERVING for the following recipe/meal.
Total servings produced by these ingredients: $servings
Title/Meal: $title
Ingredients / Description:
$ingredients
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Empty response from Gemini ($modelName).');
    }
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    return NutritionEstimate.fromJson(decoded);
  }

  /// Searches saved recipes semantically and suggests new recipe ideas based on a natural-language query.
  Future<InspirationResult> getInspiration({
    required String query,
    required List<Recipe> savedRecipes,
  }) async {
    final schema = Schema.object(
      properties: {
        'saved_matches': Schema.array(
          description: 'Up to 5 matching recipes from the user saved recipes list',
          items: Schema.object(
            properties: {
              'recipe_id': Schema.integer(),
              'title': Schema.string(),
              'reason_or_tip': Schema.string(
                description: 'Why this saved recipe fits or how to tweak it for the query',
              ),
            },
            requiredProperties: ['recipe_id', 'title', 'reason_or_tip'],
          ),
        ),
        'new_ideas': Schema.array(
          description: '2 to 3 simple new recipe ideas tailored to the query',
          items: Schema.object(
            properties: {
              'title': Schema.string(),
              'servings': Schema.number(),
              'prep_time_mins': Schema.integer(),
              'tags': Schema.string(
                description: 'Comma-separated lowercase tags',
              ),
              'ingredients': Schema.string(
                description: 'Newline-separated list of ingredients with quantities (one per line)',
              ),
              'instructions': Schema.string(
                description: 'Newline-separated step-by-step instructions',
              ),
              'calories_per_serving': Schema.number(),
              'protein_g': Schema.number(),
              'carbs_g': Schema.number(),
              'fat_g': Schema.number(),
              'fiber_g': Schema.number(),
            },
            requiredProperties: [
              'title',
              'servings',
              'prep_time_mins',
              'tags',
              'ingredients',
              'instructions',
              'calories_per_serving',
              'protein_g',
              'carbs_g',
              'fat_g',
              'fiber_g',
            ],
          ),
        ),
      },
      requiredProperties: ['saved_matches', 'new_ideas'],
    );

    final model = await _createJsonModel(schema);
    final compactCookbook = savedRecipes
        .map((r) => {
              'id': r.id,
              'title': r.title,
              'tags': r.tags,
              'ingredients': r.ingredients,
              'calories_per_serving': r.caloriesPerServing,
            })
        .toList();

    final prompt = '''
User cooking inspiration request: "$query"

Here is the user's personal cookbook JSON:
${jsonEncode(compactCookbook)}

1. Identify any saved recipes from the user's cookbook that match or can be easily adapted to fit the request.
2. Propose 2-3 simple, practical new recipe ideas with complete ingredients (one per line), clear instructions, and estimated nutrition per serving.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Empty response from Gemini ($modelName).');
    }

    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final savedList = (decoded['saved_matches'] as List<dynamic>? ?? [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          return SavedRecipeMatch(
            recipeId: (m['recipe_id'] as num).toInt(),
            title: (m['title'] as String?) ?? '',
            reasonOrTip: (m['reason_or_tip'] as String?) ?? '',
          );
        })
        .toList();

    final ideasList = (decoded['new_ideas'] as List<dynamic>? ?? [])
        .map((e) => SuggestedRecipeIdea.fromJson(e as Map<String, dynamic>))
        .toList();

    return InspirationResult(
      savedMatches: savedList,
      newIdeas: ideasList,
    );
  }
}
