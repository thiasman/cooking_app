import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/recipe_repository.dart';
import '../../models/recipe.dart';
import '../../services/gemini_service.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';

class RecipesScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const RecipesScreen({super.key, this.onDataChanged});

  @override
  State<RecipesScreen> createState() => RecipesScreenState();
}

class RecipesScreenState extends State<RecipesScreen> {
  final _repo = RecipeRepository();
  final _gemini = GeminiService();
  final _searchCtrl = TextEditingController();

  List<Recipe> _recipes = [];
  List<String> _allTags = [];
  String? _selectedTag;
  bool _loading = true;

  bool _aiInspirationMode = false;
  bool _loadingInspiration = false;
  InspirationResult? _inspirationResult;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final recipes = await _repo.getRecipes(
      query: _aiInspirationMode ? '' : _searchCtrl.text,
      tagFilter: _aiInspirationMode ? null : _selectedTag,
    );
    final tags = await _repo.getAllTags();
    if (mounted) {
      setState(() {
        _recipes = recipes;
        _allTags = tags;
        _loading = false;
      });
    }
  }

  Future<void> _runAiInspiration() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loadingInspiration = true;
      _inspirationResult = null;
    });

    try {
      final allSaved = await _repo.getRecipes();
      final result = await _gemini.getInspiration(
        query: query,
        savedRecipes: allSaved,
      );
      if (mounted) {
        setState(() => _inspirationResult = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingInspiration = false);
      }
    }
  }

  Future<void> _saveSuggestedIdea(SuggestedRecipeIdea idea) async {
    final now = DateTime.now().toIso8601String();
    final newRecipe = Recipe(
      title: idea.title,
      servings: idea.servings,
      prepTimeMins: idea.prepTimeMins,
      tags: idea.tags,
      ingredients: idea.ingredients,
      instructions: idea.instructions,
      caloriesPerServing: idea.caloriesPerServing,
      proteinG: idea.proteinG,
      carbsG: idea.carbsG,
      fatG: idea.fatG,
      fiberG: idea.fiberG,
      nutritionNote: 'Estimated by Gemini 3.5 Flash Lite during AI Inspiration',
      createdAt: now,
      updatedAt: now,
    );

    final id = await _repo.saveRecipe(newRecipe);
    widget.onDataChanged?.call();
    await reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${idea.title}" to your cookbook!')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(
            recipeId: id,
            onDataChanged: () {
              reload();
              widget.onDataChanged?.call();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: _aiInspirationMode
                              ? 'Ask AI: e.g. "Quick dinner with chicken & spinach"'
                              : 'Search recipes, ingredients, notes...',
                          prefixIcon: Icon(
                            _aiInspirationMode
                                ? Icons.auto_awesome
                                : Icons.search,
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _inspirationResult = null);
                                    reload();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (v) {
                          setState(() {});
                          if (!_aiInspirationMode) {
                            reload();
                          }
                        },
                        onSubmitted: (_) {
                          if (_aiInspirationMode) {
                            _runAiInspiration();
                          }
                        },
                      ),
                    ),
                    if (_aiInspirationMode) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed:
                            _loadingInspiration ? null : _runAiInspiration,
                        child: const Text('Ask'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      FilterChip(
                        avatar: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('AI Inspiration'),
                        selected: _aiInspirationMode,
                        onSelected: (val) {
                          setState(() {
                            _aiInspirationMode = val;
                            _inspirationResult = null;
                          });
                          reload();
                        },
                      ),
                      if (!_aiInspirationMode && _allTags.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ..._allTags.map((tag) {
                          final isSelected = _selectedTag == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('#$tag'),
                              selected: isSelected,
                              onSelected: (sel) {
                                setState(() {
                                  _selectedTag = sel ? tag : null;
                                });
                                reload();
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _aiInspirationMode
                ? _buildInspirationBody()
                : _buildRecipeListBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final createdId = await Navigator.of(context).push<int>(
            MaterialPageRoute(builder: (_) => const RecipeEditScreen()),
          );
          await reload();
          widget.onDataChanged?.call();
          if (createdId != null && context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(
                  recipeId: createdId,
                  onDataChanged: () {
                    reload();
                    widget.onDataChanged?.call();
                  },
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Recipe'),
      ),
    );
  }

  Widget _buildRecipeListBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                _searchCtrl.text.isEmpty && _selectedTag == null
                    ? 'Your cookbook is empty. Tap "New Recipe" to add your first dish!'
                    : 'No saved recipes match your filter. Try toggling "AI Inspiration" above!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final r = _recipes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              if (r.id == null) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(
                    recipeId: r.id!,
                    onDataChanged: () {
                      reload();
                      widget.onDataChanged?.call();
                    },
                  ),
                ),
              );
              await reload();
            },
            child: Row(
              children: [
                if (r.coverPhotoPath != null &&
                    File(r.coverPhotoPath!).existsSync())
                  Image.file(
                    File(r.coverPhotoPath!),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    width: 100,
                    height: 100,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.restaurant,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (r.prepTimeMins != null) ...[
                              const Icon(Icons.timer_outlined, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                '${r.prepTimeMins}m',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (r.hasNutrition) ...[
                              const Icon(
                                Icons.local_fire_department_outlined,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${r.caloriesPerServing!.round()} kcal • ${r.proteinG?.round() ?? 0}g P',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        if (r.tagList.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: r.tagList.take(3).map((t) {
                              return Text(
                                '#$t',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInspirationBody() {
    if (_loadingInspiration) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Asking Gemini 3.5 Flash Lite for cooking ideas...'),
          ],
        ),
      );
    }

    final result = _inspirationResult;
    if (result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Type what ingredients you have or what you\'re craving above and tap "Ask".\n\nGemini 3.5 Flash Lite will search your cookbook AND suggest new recipes you can save in 1 tap!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        Text(
          'From Your Saved Cookbook (${result.savedMatches.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (result.savedMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('No exact matches in your saved recipes for this prompt.'),
          )
        else
          ...result.savedMatches.map((m) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(
                  m.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(m.reasonOrTip),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipeId: m.recipeId,
                        onDataChanged: reload,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        const SizedBox(height: 16),
        Text(
          'New AI Recipe Ideas (${result.newIdeas.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...result.newIdeas.map((idea) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          idea.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _saveSuggestedIdea(idea),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Save Recipe'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${idea.prepTimeMins} min • ${idea.servings.round()} serv • ${idea.caloriesPerServing.round()} kcal / ${idea.proteinG.round()}g P per serving',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 16),
                  const Text(
                    'Ingredients:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(idea.ingredients),
                  const SizedBox(height: 8),
                  const Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(idea.instructions),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
