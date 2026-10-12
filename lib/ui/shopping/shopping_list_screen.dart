import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/recipe_repository.dart';
import '../../models/shopping_item.dart';

class ShoppingListScreen extends StatefulWidget {
  final VoidCallback? onChanged;

  const ShoppingListScreen({super.key, this.onChanged});

  @override
  State<ShoppingListScreen> createState() => ShoppingListScreenState();
}

class ShoppingListScreenState extends State<ShoppingListScreen> {
  final _repo = RecipeRepository();
  final _itemCtrl = TextEditingController();
  List<ShoppingItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final items = await _repo.getShoppingItems();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _addItem() async {
    final text = _itemCtrl.text.trim();
    if (text.isEmpty) return;
    _itemCtrl.clear();
    await _repo.addShoppingItems([text]);
    widget.onChanged?.call();
    await reload();
  }

  Future<void> _shareList() async {
    final unchecked = _items.where((i) => !i.isChecked).toList();
    if (unchecked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unchecked items to share.')),
      );
      return;
    }

    final buffer = StringBuffer('Shopping List:\n');
    for (final item in unchecked) {
      final suffix =
          item.recipeTitle != null ? ' (${item.recipeTitle})' : '';
      buffer.writeln('- [ ] ${item.itemText}$suffix');
    }

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString().trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasChecked = _items.any((i) => i.isChecked);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add item to buy (e.g., 2 lemons)...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _items.isEmpty ? null : _shareList,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share / Send to Keep'),
                ),
                if (hasChecked)
                  TextButton.icon(
                    onPressed: () async {
                      await _repo.clearCheckedShoppingItems();
                      widget.onChanged?.call();
                      await reload();
                    },
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: const Text('Clear Checked'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_basket_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Shopping list is empty.\nTap ingredients on any recipe to add them here!',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return CheckboxListTile(
                            value: item.isChecked,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) async {
                              if (item.id != null && val != null) {
                                await _repo.toggleShoppingItem(item.id!, val);
                                widget.onChanged?.call();
                                await reload();
                              }
                            },
                            title: Text(
                              item.itemText,
                              style: TextStyle(
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: item.recipeTitle != null
                                ? Text(
                                    'From: ${item.recipeTitle}',
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            secondary: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () async {
                                if (item.id != null) {
                                  await _repo.deleteShoppingItem(item.id!);
                                  widget.onChanged?.call();
                                  await reload();
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
