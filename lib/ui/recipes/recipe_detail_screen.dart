import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/diary_repository.dart';
import '../../data/recipe_repository.dart';
import '../../models/diary_entry.dart';
import '../../models/recipe.dart';
import '../../models/recipe_comment.dart';
import '../../models/recipe_photo.dart';
import '../../services/gemini_service.dart';
import '../../services/ingredient_scaler.dart';
import 'recipe_edit_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  final VoidCallback? onDataChanged;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.onDataChanged,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _repo = RecipeRepository();
  final _diaryRepo = DiaryRepository();
  final _gemini = GeminiService();
  final _picker = ImagePicker();
  final _commentCtrl = TextEditingController();

  Recipe? _recipe;
  List<RecipePhoto> _photos = [];
  List<RecipeComment> _comments = [];
  double _currentServings = 1.0;
  bool _loading = true;
  bool _estimatingNutrition = false;
  final Set<int> _crossedIngredients = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool resetServings = true}) async {
    final recipe = await _repo.getRecipeById(widget.recipeId);
    if (recipe == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final photos = await _repo.getPhotosForRecipe(widget.recipeId);
    final comments = await _repo.getCommentsForRecipe(widget.recipeId);

    if (mounted) {
      setState(() {
        _recipe = recipe;
        _photos = photos;
        _comments = comments;
        if (resetServings) {
          _currentServings = recipe.servings;
        }
        _loading = false;
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _repo.addPhotoToRecipe(widget.recipeId, picked.path);
      widget.onDataChanged?.call();
      await _loadAll(resetServings: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add photo: $e')),
        );
      }
    }
  }

  Future<void> _estimateNutrition() async {
    final recipe = _recipe;
    if (recipe == null) return;

    setState(() => _estimatingNutrition = true);
    try {
      final estimate = await _gemini.estimateNutrition(
        title: recipe.title,
        ingredients: recipe.ingredients,
        servings: recipe.servings,
      );
      final updated = recipe.copyWith(
        caloriesPerServing: estimate.caloriesPerServing,
        proteinG: estimate.proteinG,
        carbsG: estimate.carbsG,
        fatG: estimate.fatG,
        fiberG: estimate.fiberG,
        nutritionNote: estimate.note,
      );
      await _repo.saveRecipe(updated);
      widget.onDataChanged?.call();
      await _loadAll(resetServings: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nutrition estimated with Gemini 3.5 Flash Lite!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _estimatingNutrition = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    await _repo.addComment(widget.recipeId, text);
    await _loadAll(resetServings: false);
  }

  Future<void> _logToDiaryDialog() async {
    final recipe = _recipe;
    if (recipe == null) return;

    String selectedMeal = 'Dinner';
    final servingsCtrl = TextEditingController(text: '1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Log Recipe to Food Diary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedMeal,
                decoration: const InputDecoration(
                  labelText: 'Meal',
                  border: OutlineInputBorder(),
                ),
                items: const ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => selectedMeal = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: servingsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Servings Eaten',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              if (!recipe.hasNutrition) ...[
                const SizedBox(height: 8),
                const Text(
                  'Tip: Estimate nutrition on this recipe first so calories & macros are logged automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log Meal'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final eaten = double.tryParse(servingsCtrl.text.trim()) ?? 1.0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await _diaryRepo.addEntry(
      DiaryEntry(
        date: today,
        mealType: selectedMeal,
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
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    widget.onDataChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged "${recipe.title}" to today\'s Food Diary!')),
      );
    }
  }

  Future<void> _confirmDeleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe?'),
        content: const Text('This will permanently remove this recipe, its photos, and comments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.deleteRecipe(widget.recipeId);
      widget.onDataChanged?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _recipe == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final recipe = _recipe!;
    final scaledIngredients = IngredientScaler.scaleIngredients(
      recipe.ingredientLines,
      baseServings: recipe.servings,
      targetServings: _currentServings,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: 'Log to Food Diary',
            icon: const Icon(Icons.restaurant_menu),
            onPressed: _logToDiaryDialog,
          ),
          IconButton(
            tooltip: 'Edit Recipe',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeEditScreen(existingRecipe: recipe),
                ),
              );
              widget.onDataChanged?.call();
              await _loadAll(resetServings: false);
            },
          ),
          IconButton(
            tooltip: 'Delete Recipe',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDeleteRecipe,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildPhotoSection(recipe),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags & Prep time row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (recipe.prepTimeMins != null)
                      Chip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: Text('${recipe.prepTimeMins} min'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ...recipe.tagList.map(
                      (tag) => Chip(
                        label: Text('#$tag'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Nutrition Card (Per Serving)
                _buildNutritionCard(recipe),
                const SizedBox(height: 20),

                // Servings Scaler & Ingredients Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ingredients',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: _currentServings > 0.5
                              ? () => setState(() {
                                    _currentServings = (_currentServings - 0.5)
                                        .clamp(0.5, 50.0);
                                  })
                              : null,
                          icon: const Icon(Icons.remove, size: 18),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${IngredientScaler.formatQuantity(_currentServings)} serv.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            _currentServings =
                                (_currentServings + 0.5).clamp(0.5, 50.0);
                          }),
                          icon: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await _repo.addShoppingItems(
                        scaledIngredients,
                        recipeTitle: recipe.title,
                      );
                      widget.onDataChanged?.call();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Added all ingredients to Shopping List'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Add all to Shopping List'),
                  ),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scaledIngredients.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final line = scaledIngredients[idx];
                      final isCrossed = _crossedIngredients.contains(idx);
                      return ListTile(
                        dense: true,
                        onTap: () {
                          setState(() {
                            if (isCrossed) {
                              _crossedIngredients.remove(idx);
                            } else {
                              _crossedIngredients.add(idx);
                            }
                          });
                        },
                        leading: Icon(
                          isCrossed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: isCrossed
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          line,
                          style: TextStyle(
                            decoration:
                                isCrossed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Add to Shopping List',
                          icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                          onPressed: () async {
                            await _repo.addShoppingItems(
                              [line],
                              recipeTitle: recipe.title,
                            );
                            widget.onDataChanged?.call();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "$line" to Shopping List'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Instructions
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      recipe.instructions,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Comments / Cooking Log
                Text(
                  'Cooking Notes & Comments (${_comments.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add a note about how it turned out...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addComment,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_comments.isEmpty)
                  const Text(
                    'No notes yet. Jot down tweaks or cooking times after you make it!',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ..._comments.map((c) {
                    final dt = DateTime.tryParse(c.createdAt);
                    final dateStr = dt != null
                        ? DateFormat('MMM d, yyyy • HH:mm').format(dt)
                        : c.createdAt;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(c.comment),
                        subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () async {
                            if (c.id != null) {
                              await _repo.deleteComment(c.id!);
                              await _loadAll(resetServings: false);
                            }
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(Recipe recipe) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          if (_photos.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      size: 44,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text('No photos yet — snap a picture when you cook it!'),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 230,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(photo.filePath),
                            height: 206,
                            width: 260,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 206,
                              width: 260,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Row(
                            children: [
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                tooltip: photo.isCover
                                    ? 'Cover photo'
                                    : 'Set as cover photo',
                                icon: Icon(
                                  photo.isCover ? Icons.star : Icons.star_border,
                                  size: 18,
                                  color: photo.isCover ? Colors.amber.shade700 : null,
                                ),
                                onPressed: () async {
                                  if (photo.id != null) {
                                    await _repo.setCoverPhoto(
                                      widget.recipeId,
                                      photo.id!,
                                    );
                                    widget.onDataChanged?.call();
                                    await _loadAll(resetServings: false);
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Delete photo',
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () async {
                                  await _repo.deletePhoto(photo);
                                  widget.onDataChanged?.call();
                                  await _loadAll(resetServings: false);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Take Photo'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard(Recipe recipe) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Nutrition per Serving',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: _estimatingNutrition ? null : _estimateNutrition,
                  icon: _estimatingNutrition
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    recipe.hasNutrition ? 'Recalculate AI' : 'Estimate with AI',
                  ),
                ),
              ],
            ),
            if (recipe.hasNutrition) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroPill('Calories', '${recipe.caloriesPerServing!.round()} kcal'),
                  _macroPill('Protein', '${recipe.proteinG?.toStringAsFixed(1) ?? "0"}g'),
                  _macroPill('Carbs', '${recipe.carbsG?.toStringAsFixed(1) ?? "0"}g'),
                  _macroPill('Fat', '${recipe.fatG?.toStringAsFixed(1) ?? "0"}g'),
                  _macroPill('Fiber', '${recipe.fiberG?.toStringAsFixed(1) ?? "0"}g'),
                ],
              ),
              if (recipe.nutritionNote != null &&
                  recipe.nutritionNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  recipe.nutritionNote!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 6),
              const Text(
                'Tap "Estimate with AI" to calculate calories & nutrients per serving using Gemini 3.5 Flash Lite.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macroPill(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
