import 'package:flutter/material.dart';
import '../data/recipe_repository.dart';
import 'diary/food_diary_screen.dart';
import 'recipes/recipes_screen.dart';
import 'settings/settings_screen.dart';
import 'shopping/shopping_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _repo = RecipeRepository();
  final _recipesKey = GlobalKey<RecipesScreenState>();
  final _diaryKey = GlobalKey<FoodDiaryScreenState>();
  final _shoppingKey = GlobalKey<ShoppingListScreenState>();

  int _selectedIndex = 0;
  int _uncheckedShoppingCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshBadgeCount();
  }

  Future<void> _refreshBadgeCount() async {
    final items = await _repo.getShoppingItems();
    if (mounted) {
      setState(() {
        _uncheckedShoppingCount = items.where((i) => !i.isChecked).length;
      });
    }
  }

  void _refreshAllTabs() {
    _recipesKey.currentState?.reload();
    _diaryKey.currentState?.reload();
    _shoppingKey.currentState?.reload();
    _refreshBadgeCount();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['My Cookbook', 'Food Diary', 'Shopping List'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings & Backup',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(onRestored: _refreshAllTabs),
                ),
              );
              _refreshAllTabs();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          RecipesScreen(
            key: _recipesKey,
            onDataChanged: _refreshAllTabs,
          ),
          FoodDiaryScreen(key: _diaryKey),
          ShoppingListScreen(
            key: _shoppingKey,
            onChanged: _refreshBadgeCount,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          setState(() => _selectedIndex = idx);
          _refreshAllTabs();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recipes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Food Diary',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _uncheckedShoppingCount > 0,
              label: Text('$_uncheckedShoppingCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _uncheckedShoppingCount > 0,
              label: Text('$_uncheckedShoppingCount'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Shopping',
          ),
        ],
      ),
    );
  }
}
