import 'dart:io';
import 'package:cooking_app/data/backup_service.dart';
import 'package:cooking_app/data/database_helper.dart';
import 'package:cooking_app/data/diary_repository.dart';
import 'package:cooking_app/data/recipe_repository.dart';
import 'package:cooking_app/models/diary_entry.dart';
import 'package:cooking_app/models/recipe.dart';
import 'package:cooking_app/services/gemini_service.dart';
import 'package:cooking_app/services/ingredient_scaler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('IngredientScaler', () {
    test('scales whole numbers, decimals, and fractions cleanly', () {
      final baseLines = [
        '200g chicken breast',
        '1/2 cup jasmine rice',
        '1 1/2 tbsp olive oil',
        'Pinch of sea salt',
      ];

      final doubled = IngredientScaler.scaleIngredients(
        baseLines,
        baseServings: 2,
        targetServings: 4,
      );

      expect(doubled, [
        '400g chicken breast',
        '1 cup jasmine rice',
        '3 tbsp olive oil',
        'Pinch of sea salt',
      ]);

      final halved = IngredientScaler.scaleIngredients(
        baseLines,
        baseServings: 2,
        targetServings: 1,
      );

      expect(halved, [
        '100g chicken breast',
        '1/4 cup jasmine rice',
        '3/4 tbsp olive oil',
        'Pinch of sea salt',
      ]);
    });
  });

  group('GeminiService model configuration', () {
    test('uses gemini-3.5-flash-lite', () {
      expect(GeminiService.modelName, 'gemini-3.5-flash-lite');
    });
  });

  group('Database, RecipeRepository, DiaryRepository & BackupService', () {
    late Directory tempDir;
    late RecipeRepository recipeRepo;
    late DiaryRepository diaryRepo;
    late BackupService backupService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cooking_app_test_');
      DatabaseHelper.instance.configureForTesting(
        dbPath: p.join(tempDir.path, DatabaseHelper.dbFileName),
        photosDirPath: p.join(tempDir.path, 'photos'),
      );
      await DatabaseHelper.instance.closeDatabase();
      recipeRepo = RecipeRepository();
      diaryRepo = DiaryRepository();
      backupService = BackupService();
    });

    tearDown(() async {
      await DatabaseHelper.instance.closeDatabase();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('seeds starter recipes and supports multi-keyword & comment search', () async {
      final initial = await recipeRepo.getRecipes();
      expect(initial.length, 2);

      // Search by multiple ingredients across recipe
      final chickenSpinach = await recipeRepo.getRecipes(query: 'chicken spinach');
      expect(chickenSpinach.length, 1);
      expect(chickenSpinach.first.title, contains('Chicken'));

      // Add a new recipe and a comment, then search by comment keyword
      final now = DateTime.now().toIso8601String();
      final newId = await recipeRepo.saveRecipe(
        Recipe(
          title: 'Overnight Oats',
          servings: 1,
          prepTimeMins: 5,
          tags: 'breakfast, oats',
          ingredients: '50g rolled oats\n150ml almond milk\n1 tbsp chia seeds',
          instructions: 'Mix in jar and refrigerate overnight.',
          caloriesPerServing: 290,
          proteinG: 10,
          carbsG: 42,
          fatG: 8,
          fiberG: 9,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await recipeRepo.addComment(newId, 'Great with cinnamon and blueberries!');

      final commentMatch = await recipeRepo.getRecipes(query: 'blueberries oats');
      expect(commentMatch.length, 1);
      expect(commentMatch.first.id, newId);
    });

    test('logs meals to food diary and aggregates daily macros', () async {
      const date = '2026-10-12';
      await diaryRepo.addEntry(
        const DiaryEntry(
          date: date,
          mealType: 'Breakfast',
          title: 'Protein Oatmeal',
          servingsEaten: 1,
          calories: 350,
          proteinG: 25,
          carbsG: 45,
          fatG: 7,
          fiberG: 6,
          createdAt: '2026-10-12T08:00:00Z',
        ),
      );
      await diaryRepo.addEntry(
        const DiaryEntry(
          date: date,
          mealType: 'Dinner',
          title: 'Garlic Lemon Herb Chicken & Rice',
          servingsEaten: 1.5,
          calories: 810,
          proteinG: 72,
          carbsG: 69,
          fatG: 24,
          fiberG: 3.75,
          createdAt: '2026-10-12T19:00:00Z',
        ),
      );

      final summary = await diaryRepo.getDailySummary(date);
      expect(summary.calories, 1160);
      expect(summary.proteinG, 97);
      expect(summary.carbsG, 114);
      expect(summary.fatG, 31);
      expect(summary.fiberG, closeTo(9.75, 0.01));
    });

    test('exports and restores ZIP backup with recipes and photos', () async {
      final recipes = await recipeRepo.getRecipes();
      final firstId = recipes.first.id!;

      // Create a dummy photo file and attach it to recipe
      final dummyPhoto = File(p.join(tempDir.path, 'sample.jpg'));
      await dummyPhoto.writeAsBytes([1, 2, 3, 4, 5]);
      await recipeRepo.addPhotoToRecipe(firstId, dummyPhoto.path);

      final zipFile = await backupService.createBackupZip(
        outputDirPath: tempDir.path,
      );
      expect(await zipFile.exists(), isTrue);

      // Delete a recipe, then restore from backup and verify it comes back
      await recipeRepo.deleteRecipe(firstId);
      expect((await recipeRepo.getRecipes()).length, 1);

      await backupService.restoreFromBackupZip(zipFile);
      final restoredRecipes = await recipeRepo.getRecipes();
      expect(restoredRecipes.length, 2);
      final restoredPhotos = await recipeRepo.getPhotosForRecipe(firstId);
      expect(restoredPhotos.length, 1);
      expect(await File(restoredPhotos.first.filePath).exists(), isTrue);
    });
  });
}
