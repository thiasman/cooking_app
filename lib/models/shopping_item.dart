class ShoppingItem {
  final int? id;
  final String itemText;
  final String? recipeTitle;
  final bool isChecked;

  const ShoppingItem({
    this.id,
    required this.itemText,
    this.recipeTitle,
    this.isChecked = false,
  });

  ShoppingItem copyWith({
    int? id,
    String? itemText,
    String? recipeTitle,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      itemText: itemText ?? this.itemText,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'item_text': itemText,
      'recipe_title': recipeTitle,
      'is_checked': isChecked ? 1 : 0,
    };
  }

  factory ShoppingItem.fromMap(Map<String, Object?> map) {
    return ShoppingItem(
      id: map['id'] as int?,
      itemText: map['item_text'] as String,
      recipeTitle: map['recipe_title'] as String?,
      isChecked: (map['is_checked'] as int? ?? 0) == 1,
    );
  }
}
