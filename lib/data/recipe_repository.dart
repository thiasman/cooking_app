import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/recipe.dart';
import '../models/recipe_comment.dart';
import '../models/recipe_photo.dart';
import '../models/shopping_item.dart';
import 'database_helper.dart';

class RecipeRepository {
  final DatabaseHelper _dbHelper;

  RecipeRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Fetches all recipes, optionally filtered by a multi-keyword search query and/or tag.
  Future<List<Recipe>> getRecipes({
    String query = '',
    String? tagFilter,
  }) async {
    final db = await _dbHelper.database;

    final rows = await db.rawQuery('''
      SELECT r.*,
        (
          SELECT rp.file_path
          FROM recipe_photos rp
          WHERE rp.recipe_id = r.id
          ORDER BY rp.is_cover DESC, rp.id ASC
          LIMIT 1
        ) AS cover_photo_path,
        (
          SELECT GROUP_CONCAT(rc.comment, ' ')
          FROM recipe_comments rc
          WHERE rc.recipe_id = r.id
        ) AS comments_concat
      FROM recipes r
      ORDER BY r.updated_at DESC
    ''');

    final photosDir = await _dbHelper.getPhotosDirectory();
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final normalizedTag = tagFilter?.trim().toLowerCase();

    final results = <Recipe>[];
    for (final row in rows) {
      final map = Map<String, Object?>.from(row);
      final relCover = map['cover_photo_path'] as String?;
      if (relCover != null && relCover.isNotEmpty) {
        map['cover_photo_path'] = p.join(photosDir.path, relCover);
      }

      final recipe = Recipe.fromMap(map);

      if (normalizedTag != null && normalizedTag.isNotEmpty) {
        final hasTag = recipe.tagList
            .any((t) => t.toLowerCase() == normalizedTag);
        if (!hasTag) continue;
      }

      if (tokens.isNotEmpty) {
        final commentsConcat = (row['comments_concat'] as String?) ?? '';
        final searchableBlob = [
          recipe.title,
          recipe.ingredients,
          recipe.tags,
          recipe.instructions,
          commentsConcat,
        ].join(' ').toLowerCase();

        final matchesAllTokens =
            tokens.every((token) => searchableBlob.contains(token));
        if (!matchesAllTokens) continue;
      }

      results.add(recipe);
    }

    return results;
  }

  Future<List<String>> getAllTags() async {
    final recipes = await getRecipes();
    final tagSet = <String>{};
    for (final r in recipes) {
      for (final tag in r.tagList) {
        tagSet.add(tag.toLowerCase());
      }
    }
    final sorted = tagSet.toList()..sort();
    return sorted;
  }

  Future<Recipe?> getRecipeById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT r.*,
        (
          SELECT rp.file_path
          FROM recipe_photos rp
          WHERE rp.recipe_id = r.id
          ORDER BY rp.is_cover DESC, rp.id ASC
          LIMIT 1
        ) AS cover_photo_path
      FROM recipes r
      WHERE r.id = ?
    ''', [id]);

    if (rows.isEmpty) return null;
    final map = Map<String, Object?>.from(rows.first);
    final relCover = map['cover_photo_path'] as String?;
    if (relCover != null && relCover.isNotEmpty) {
      final photosDir = await _dbHelper.getPhotosDirectory();
      map['cover_photo_path'] = p.join(photosDir.path, relCover);
    }
    return Recipe.fromMap(map);
  }

  Future<int> saveRecipe(Recipe recipe) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final updated = recipe.copyWith(updatedAt: now);

    if (recipe.id == null) {
      return db.insert('recipes', updated.toMap());
    } else {
      await db.update(
        'recipes',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [recipe.id],
      );
      return recipe.id!;
    }
  }

  Future<void> deleteRecipe(int id) async {
    final photos = await getPhotosForRecipe(id);
    for (final photo in photos) {
      final file = File(photo.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final db = await _dbHelper.database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  // --- Photos ---

  Future<List<RecipePhoto>> getPhotosForRecipe(int recipeId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'recipe_photos',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'is_cover DESC, id DESC',
    );
    final photosDir = await _dbHelper.getPhotosDirectory();
    return rows.map((r) {
      final map = Map<String, Object?>.from(r);
      final relPath = map['file_path'] as String;
      map['file_path'] = p.join(photosDir.path, relPath);
      return RecipePhoto.fromMap(map);
    }).toList();
  }

  Future<RecipePhoto> addPhotoToRecipe(int recipeId, String sourceFilePath) async {
    final photosDir = await _dbHelper.getPhotosDirectory();
    final ext = p.extension(sourceFilePath).isNotEmpty
        ? p.extension(sourceFilePath)
        : '.jpg';
    final fileName =
        'recipe_${recipeId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(photosDir.path, fileName);

    await File(sourceFilePath).copy(destPath);

    final db = await _dbHelper.database;
    final existing = await db.query(
      'recipe_photos',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
    final isFirst = existing.isEmpty;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('recipe_photos', {
      'recipe_id': recipeId,
      'file_path': fileName,
      'is_cover': isFirst ? 1 : 0,
      'created_at': now,
    });

    return RecipePhoto(
      id: id,
      recipeId: recipeId,
      filePath: destPath,
      isCover: isFirst,
      createdAt: now,
    );
  }

  Future<void> setCoverPhoto(int recipeId, int photoId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'recipe_photos',
        {'is_cover': 0},
        where: 'recipe_id = ?',
        whereArgs: [recipeId],
      );
      await txn.update(
        'recipe_photos',
        {'is_cover': 1},
        where: 'id = ?',
        whereArgs: [photoId],
      );
    });
  }

  Future<void> deletePhoto(RecipePhoto photo) async {
    final file = File(photo.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    final db = await _dbHelper.database;
    await db.delete('recipe_photos', where: 'id = ?', whereArgs: [photo.id]);
  }

  // --- Comments ---

  Future<List<RecipeComment>> getCommentsForRecipe(int recipeId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'recipe_comments',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(RecipeComment.fromMap).toList();
  }

  Future<RecipeComment> addComment(int recipeId, String text) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('recipe_comments', {
      'recipe_id': recipeId,
      'comment': text.trim(),
      'created_at': now,
    });
    return RecipeComment(
      id: id,
      recipeId: recipeId,
      comment: text.trim(),
      createdAt: now,
    );
  }

  Future<void> deleteComment(int commentId) async {
    final db = await _dbHelper.database;
    await db.delete('recipe_comments', where: 'id = ?', whereArgs: [commentId]);
  }

  // --- Shopping List ---

  Future<List<ShoppingItem>> getShoppingItems() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'shopping_items',
      orderBy: 'is_checked ASC, id DESC',
    );
    return rows.map(ShoppingItem.fromMap).toList();
  }

  Future<void> addShoppingItems(
    List<String> items, {
    String? recipeTitle,
  }) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      batch.insert('shopping_items', {
        'item_text': trimmed,
        'recipe_title': recipeTitle,
        'is_checked': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> toggleShoppingItem(int id, bool isChecked) async {
    final db = await _dbHelper.database;
    await db.update(
      'shopping_items',
      {'is_checked': isChecked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteShoppingItem(int id) async {
    final db = await _dbHelper.database;
    await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCheckedShoppingItems() async {
    final db = await _dbHelper.database;
    await db.delete('shopping_items', where: 'is_checked = 1');
  }
}
