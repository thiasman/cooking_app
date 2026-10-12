import 'package:flutter/material.dart';
import '../../data/diary_repository.dart';
import '../../data/recipe_repository.dart';
import '../../models/diary_entry.dart';
import '../../models/recipe.dart';
import '../../services/gemini_service.dart';

class AddDiaryEntrySheet extends StatefulWidget {
  final String date;

  const AddDiaryEntrySheet({super.key, required this.date});

  @override
  State<AddDiaryEntrySheet> createState() => _AddDiaryEntrySheetState();
}

class _AddDiaryEntrySheetState extends State<AddDiaryEntrySheet> {
  final _recipeRepo = RecipeRepository();
  final _diaryRepo = DiaryRepository();
  final _gemini = GeminiService();

  bool _fromSavedRecipe = true;
  String _mealType = 'Dinner';
  List<Recipe> _recipes = [];
  Recipe? _selectedRecipe;

  final _servingsCtrl = TextEditingController(text: '1');
  final _customTitleCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();

  bool _estimatingAi = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _servingsCtrl.dispose();
    _customTitleCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final list = await _recipeRepo.getRecipes();
    if (mounted) {
      setState(() {
        _recipes = list;
        if (list.isNotEmpty) {
          _selectedRecipe = list.first;
        } else {
          _fromSavedRecipe = false;
        }
      });
    }
  }

  Future<void> _estimateCustomMealWithAi() async {
    final desc = _customTitleCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter what you ate first')),
      );
      return;
    }

    setState(() => _estimatingAi = true);
    try {
      final est = await _gemini.estimateNutrition(
        title: desc,
        ingredients: desc,
        servings: 1.0,
      );
      if (mounted) {
        setState(() {
          _caloriesCtrl.text = est.caloriesPerServing.round().toString();
          _proteinCtrl.text = est.proteinG.toStringAsFixed(1);
          _carbsCtrl.text = est.carbsG.toStringAsFixed(1);
          _fatCtrl.text = est.fatG.toStringAsFixed(1);
          _fiberCtrl.text = est.fiberG.toStringAsFixed(1);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _estimatingAi = false);
    }
  }

  Future<void> _save() async {
    final now = DateTime.now().toIso8601String();
    if (_fromSavedRecipe) {
      final recipe = _selectedRecipe;
      if (recipe == null) return;
      final eaten = double.tryParse(_servingsCtrl.text.trim()) ?? 1.0;

      await _diaryRepo.addEntry(
        DiaryEntry(
          date: widget.date,
          mealType: _mealType,
          recipeId: recipe.id,
          title: recipe.title,
          servingsEaten: eaten,
          calories: recipe.caloriesPerServing != null
              ? recipe.caloriesPerServing! * eaten
              : null,
          proteinG: recipe.proteinG != null ? recipe.proteinG! * eaten : null,
          carbsG: recipe.carbsG != null ? recipe.carbsG! * eaten : null,
          fatG: recipe.fatG != null ? recipe.fatG! * eaten : null,
          fiberG: recipe.fiberG != null ? recipe.fiberG! * eaten : null,
          createdAt: now,
        ),
      );
    } else {
      final title = _customTitleCtrl.text.trim();
      if (title.isEmpty) return;

      await _diaryRepo.addEntry(
        DiaryEntry(
          date: widget.date,
          mealType: _mealType,
          title: title,
          servingsEaten: 1.0,
          calories: double.tryParse(_caloriesCtrl.text.trim()),
          proteinG: double.tryParse(_proteinCtrl.text.trim()),
          carbsG: double.tryParse(_carbsCtrl.text.trim()),
          fatG: double.tryParse(_fatCtrl.text.trim()),
          fiberG: double.tryParse(_fiberCtrl.text.trim()),
          createdAt: now,
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log to Food Diary (${widget.date})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('From Saved Recipe'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit_note),
                  label: Text('Quick-Add Meal'),
                ),
              ],
              selected: {_fromSavedRecipe},
              onSelectionChanged: (s) {
                setState(() => _fromSavedRecipe = s.first);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _mealType,
              decoration: const InputDecoration(
                labelText: 'Meal Type',
                border: OutlineInputBorder(),
              ),
              items: const ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _mealType = v);
              },
            ),
            const SizedBox(height: 12),
            if (_fromSavedRecipe) ...[
              if (_recipes.isEmpty)
                const Text('No saved recipes yet. Use Quick-Add instead.')
              else ...[
                DropdownButtonFormField<Recipe>(
                  initialValue: _selectedRecipe,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Recipe',
                    border: OutlineInputBorder(),
                  ),
                  items: _recipes
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r.hasNutrition
                                ? '${r.title} (${r.caloriesPerServing!.round()} kcal/serv)'
                                : r.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (r) => setState(() => _selectedRecipe = r),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _servingsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Servings Eaten',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ] else ...[
              TextField(
                controller: _customTitleCtrl,
                decoration: InputDecoration(
                  labelText: 'What did you eat? *',
                  hintText: 'e.g., 2 eggs, avocado & 1 slice sourdough toast',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Estimate calories & macros with AI',
                    onPressed: _estimatingAi ? null : _estimateCustomMealWithAi,
                    icon: _estimatingAi
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _estimatingAi ? null : _estimateCustomMealWithAi,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Estimate Nutrition with AI'),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caloriesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Calories (kcal)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _proteinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _carbsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fatCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fat (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fiberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fiber (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Add to Diary'),
            ),
          ],
        ),
      ),
    );
  }
}
