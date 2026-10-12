import 'package:sqflite/sqflite.dart';
import '../models/diary_entry.dart';
import 'database_helper.dart';

class DiaryRepository {
  final DatabaseHelper _dbHelper;

  DiaryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<DiaryEntry>> getEntriesForDate(String date) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'diary_entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id ASC',
    );
    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<DailyMacroSummary> getDailySummary(String date) async {
    final entries = await getEntriesForDate(date);
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double fiber = 0;

    for (final e in entries) {
      calories += e.calories ?? 0;
      protein += e.proteinG ?? 0;
      carbs += e.carbsG ?? 0;
      fat += e.fatG ?? 0;
      fiber += e.fiberG ?? 0;
    }

    return DailyMacroSummary(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: fiber,
    );
  }

  Future<int> addEntry(DiaryEntry entry) async {
    final db = await _dbHelper.database;
    return db.insert('diary_entries', entry.toMap());
  }

  Future<void> deleteEntry(int id) async {
    final db = await _dbHelper.database;
    await db.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<double?> getDailyTarget(String key) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return double.tryParse(rows.first['value'] as String);
  }

  Future<void> setDailyTarget(String key, double? value) async {
    final db = await _dbHelper.database;
    if (value == null || value <= 0) {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert(
        'app_settings',
        {'key': key, 'value': value.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
