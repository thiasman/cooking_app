import 'package:flutter/material.dart';
import '../../data/recipe_repository.dart';
import '../../models/recipe.dart';

class RecipeEditScreen extends StatefulWidget {
  final Recipe? existingRecipe;

  const RecipeEditScreen({super.key, this.existingRecipe});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = RecipeRepository();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _servingsCtrl;
  late final TextEditingController _prepTimeCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _ingredientsCtrl;
  late final TextEditingController _instructionsCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRecipe;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _servingsCtrl = TextEditingController(
      text: r != null ? _formatNumber(r.servings) : '2',
    );
    _prepTimeCtrl = TextEditingController(
      text: r?.prepTimeMins != null ? r!.prepTimeMins.toString() : '',
    );
    _tagsCtrl = TextEditingController(text: r?.tags ?? '');
    _ingredientsCtrl = TextEditingController(text: r?.ingredients ?? '');
    _instructionsCtrl = TextEditingController(text: r?.instructions ?? '');
  }

  String _formatNumber(double val) {
    return val == val.roundToDouble()
        ? val.toInt().toString()
        : val.toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _servingsCtrl.dispose();
    _prepTimeCtrl.dispose();
    _tagsCtrl.dispose();
    _ingredientsCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final servings = double.tryParse(_servingsCtrl.text.trim()) ?? 1.0;
      final prepTime = int.tryParse(_prepTimeCtrl.text.trim());

      final base = widget.existingRecipe;
      final recipe = Recipe(
        id: base?.id,
        title: _titleCtrl.text.trim(),
        servings: servings <= 0 ? 1.0 : servings,
        prepTimeMins: prepTime,
        tags: _tagsCtrl.text.trim(),
        ingredients: _ingredientsCtrl.text.trim(),
        instructions: _instructionsCtrl.text.trim(),
        caloriesPerServing: base?.caloriesPerServing,
        proteinG: base?.proteinG,
        carbsG: base?.carbsG,
        fatG: base?.fatG,
        fiberG: base?.fiberG,
        nutritionNote: base?.nutritionNote,
        createdAt: base?.createdAt ?? now,
        updatedAt: now,
      );

      final savedId = await _repo.saveRecipe(recipe);
      if (mounted) {
        Navigator.of(context).pop(savedId);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRecipe?.id != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Recipe Title *',
                hintText: 'e.g., Spicy Garlic Noodles',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Servings *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prep Time (mins)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                hintText: 'dinner, quick, high-protein, pasta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ingredientsCtrl,
              decoration: const InputDecoration(
                labelText: 'Ingredients (one per line) *',
                hintText: '200g spaghetti\n3 cloves garlic, minced\n2 tbsp olive oil',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
              minLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter at least one ingredient'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Instructions *',
                hintText: '1. Boil salted water...\n2. Sauté garlic in olive oil...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 12,
              minLines: 6,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter instructions'
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
