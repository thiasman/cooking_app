import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/diary_repository.dart';
import '../../models/diary_entry.dart';
import '../recipes/recipe_detail_screen.dart';
import 'add_diary_entry_sheet.dart';

class FoodDiaryScreen extends StatefulWidget {
  const FoodDiaryScreen({super.key});

  @override
  State<FoodDiaryScreen> createState() => FoodDiaryScreenState();
}

class FoodDiaryScreenState extends State<FoodDiaryScreen> {
  final _repo = DiaryRepository();
  DateTime _selectedDate = DateTime.now();

  List<DiaryEntry> _entries = [];
  DailyMacroSummary _summary = const DailyMacroSummary();
  double? _targetCalories;
  double? _targetProtein;
  bool _loading = true;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final entries = await _repo.getEntriesForDate(_dateKey);
    final summary = await _repo.getDailySummary(_dateKey);
    final calGoal = await _repo.getDailyTarget('target_calories');
    final protGoal = await _repo.getDailyTarget('target_protein');
    if (mounted) {
      setState(() {
        _entries = entries;
        _summary = summary;
        _targetCalories = calGoal;
        _targetProtein = protGoal;
        _loading = false;
      });
    }
  }

  void _shiftDay(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
    });
    reload();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday =
        DateFormat('yyyy-MM-dd').format(DateTime.now()) == _dateKey;
    final dateDisplay = isToday
        ? 'Today, ${DateFormat('MMM d').format(_selectedDate)}'
        : DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

    return Scaffold(
      body: Column(
        children: [
          // Date selector bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _shiftDay(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    dateDisplay,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftDay(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // Daily Macro Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryMetric(
                          'Calories',
                          _targetCalories != null
                              ? '${_summary.calories.round()} / ${_targetCalories!.round()}'
                              : '${_summary.calories.round()} kcal',
                        ),
                        _summaryMetric(
                          'Protein',
                          _targetProtein != null
                              ? '${_summary.proteinG.round()} / ${_targetProtein!.round()}g'
                              : '${_summary.proteinG.toStringAsFixed(1)}g',
                        ),
                        _summaryMetric(
                          'Carbs',
                          '${_summary.carbsG.toStringAsFixed(1)}g',
                        ),
                        _summaryMetric(
                          'Fat',
                          '${_summary.fatG.toStringAsFixed(1)}g',
                        ),
                        _summaryMetric(
                          'Fiber',
                          '${_summary.fiberG.toStringAsFixed(1)}g',
                        ),
                      ],
                    ),
                    if (_targetCalories != null && _targetCalories! > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (_summary.calories / _targetCalories!)
                              .clamp(0.0, 1.0),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 12),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_calendar_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            const Text('No meals logged for this day yet.'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: _entries.length,
                        itemBuilder: (context, idx) {
                          final entry = _entries[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: entry.recipeId != null
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => RecipeDetailScreen(
                                            recipeId: entry.recipeId!,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              leading: CircleAvatar(
                                child: Text(entry.mealType.substring(0, 1)),
                              ),
                              title: Text(
                                entry.title,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  entry.mealType,
                                  if (entry.recipeId != null)
                                    '${entry.servingsEaten} serv.',
                                  if (entry.calories != null)
                                    '${entry.calories!.round()} kcal',
                                  if (entry.proteinG != null)
                                    '${entry.proteinG!.toStringAsFixed(1)}g P',
                                  if (entry.carbsG != null)
                                    '${entry.carbsG!.toStringAsFixed(1)}g C',
                                  if (entry.fatG != null)
                                    '${entry.fatG!.toStringAsFixed(1)}g F',
                                ].join(' • '),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () async {
                                  if (entry.id != null) {
                                    await _repo.deleteEntry(entry.id!);
                                    await reload();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddDiaryEntrySheet(date: _dateKey),
          );
          if (added == true) {
            await reload();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Log Meal'),
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
