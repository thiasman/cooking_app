import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String dbFileName = 'cooking_app.db';
  static const int _dbVersion = 1;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _db;
  String? _overrideDbPath;
  String? _overridePhotosDirPath;

  void configureForTesting({
    required String dbPath,
    required String photosDirPath,
  }) {
    _overrideDbPath = dbPath;
    _overridePhotosDirPath = photosDirPath;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<String> getDatabaseFilePath() async {
    if (_overrideDbPath != null) return _overrideDbPath!;
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, dbFileName);
  }

  Future<Directory> getPhotosDirectory() async {
    if (_overridePhotosDirPath != null) {
      final dir = Directory(_overridePhotosDirPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDocDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabaseFilePath();
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        servings REAL NOT NULL DEFAULT 1,
        prep_time_mins INTEGER,
        tags TEXT NOT NULL DEFAULT '',
        ingredients TEXT NOT NULL,
        instructions TEXT NOT NULL,
        calories_per_serving REAL,
        protein_g REAL,
        carbs_g REAL,
        fat_g REAL,
        fiber_g REAL,
        nutrition_note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        is_cover INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        comment TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE diary_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        recipe_id INTEGER,
        title TEXT NOT NULL,
        servings_eaten REAL NOT NULL DEFAULT 1,
        calories REAL,
        protein_g REAL,
        carbs_g REAL,
        fat_g REAL,
        fiber_g REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_text TEXT NOT NULL,
        recipe_title TEXT,
        is_checked INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _seedStarterRecipes(db);
  }

  Future<void> _seedStarterRecipes(Database db) async {
    final now = DateTime.now().toIso8601String();
    final id1 = await db.insert('recipes', {
      'title': 'Garlic Lemon Herb Chicken & Rice',
      'servings': 2.0,
      'prep_time_mins': 25,
      'tags': 'dinner, high-protein, quick',
      'ingredients': '300g chicken breast\n1 cup jasmine rice\n2 tbsp olive oil\n3 cloves garlic, minced\n1 lemon, juiced\n1 tsp dried oregano\n2 cups spinach',
      'instructions': '1. Rinse and cook the jasmine rice according to package instructions.\n2. Season chicken breast with salt, pepper, and dried oregano.\n3. Heat olive oil in a skillet over medium-high heat and sear chicken for 5-6 minutes per side.\n4. Add minced garlic and lemon juice in the last 2 minutes, then wilt the spinach in the pan juices.\n5. Slice and serve over warm rice.',
      'calories_per_serving': 540.0,
      'protein_g': 48.0,
      'carbs_g': 46.0,
      'fat_g': 16.0,
      'fiber_g': 2.5,
      'nutrition_note': 'Estimated for 150g chicken breast, 0.5 cup dry rice, and 1 tbsp olive oil per serving.',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('recipe_comments', {
      'recipe_id': id1,
      'comment': 'Great weeknight staple! Using chicken thighs also works well if you reduce olive oil to 1 tbsp.',
      'created_at': now,
    });

    await db.insert('recipes', {
      'title': 'Mediterranean Chickpea & Feta Bowl',
      'servings': 2.0,
      'prep_time_mins': 15,
      'tags': 'lunch, vegetarian, meal-prep',
      'ingredients': '1 can (400g) chickpeas, drained\n1 cucumber, diced\n1 cup cherry tomatoes, halved\n60g feta cheese, crumbled\n1/4 red onion, thinly sliced\n1.5 tbsp extra virgin olive oil\n1 tbsp red wine vinegar',
      'instructions': '1. Rinse and drain the chickpeas thoroughly.\n2. Dice the cucumber, halve the cherry tomatoes, and slice the red onion.\n3. Toss vegetables and chickpeas in a bowl with olive oil, red wine vinegar, salt, and black pepper.\n4. Top with crumbled feta cheese and serve chilled or at room temperature.',
      'calories_per_serving': 410.0,
      'protein_g': 15.0,
      'carbs_g': 38.0,
      'fat_g': 21.0,
      'fiber_g': 9.0,
      'nutrition_note': 'Based on half a can of drained chickpeas and 30g feta per serving.',
      'created_at': now,
      'updated_at': now,
    });
  }
}
