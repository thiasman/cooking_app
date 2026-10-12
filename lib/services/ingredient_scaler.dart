class IngredientScaler {
  // Matches leading integers, decimals, mixed fractions (e.g. "1 1/2"), or simple fractions (e.g. "3/4"),
  // even when attached directly to a unit like "200g".
  static final RegExp _leadingAmountRegex = RegExp(
    r'^(\s*)(\d+\s+\d+\/\d+|\d+\/\d+|\d+(?:\.\d+)?)((?!\s*\d|\/).*)$',
  );

  /// Scales all lines in a multiline ingredients string from [baseServings] to [targetServings].
  static List<String> scaleIngredients(
    List<String> lines, {
    required double baseServings,
    required double targetServings,
  }) {
    if (baseServings <= 0 || targetServings <= 0 || baseServings == targetServings) {
      return lines;
    }
    final factor = targetServings / baseServings;
    return lines.map((line) => scaleLine(line, factor)).toList();
  }

  /// Scales a single ingredient line by [factor].
  static String scaleLine(String line, double factor) {
    if ((factor - 1.0).abs() < 1e-6) return line;

    final match = _leadingAmountRegex.firstMatch(line);
    if (match == null) return line;

    final prefix = match.group(1) ?? '';
    final amountStr = match.group(2)!;
    final suffix = match.group(3) ?? '';

    final parsed = parseQuantity(amountStr);
    if (parsed == null) return line;

    final scaled = parsed * factor;
    return '$prefix${formatQuantity(scaled)}$suffix';
  }

  static double? parseQuantity(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains(' ')) {
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final whole = double.tryParse(parts[0]);
        final frac = _parseFraction(parts[1]);
        if (whole != null && frac != null) return whole + frac;
      }
    }
    if (trimmed.contains('/')) {
      return _parseFraction(trimmed);
    }
    return double.tryParse(trimmed);
  }

  static double? _parseFraction(String frac) {
    final parts = frac.split('/');
    if (parts.length != 2) return null;
    final num = double.tryParse(parts[0]);
    final den = double.tryParse(parts[1]);
    if (num == null || den == null || den == 0) return null;
    return num / den;
  }

  static String formatQuantity(double value) {
    final roundedInt = value.roundToDouble();
    if ((value - roundedInt).abs() < 0.04) {
      return roundedInt.toInt().toString();
    }

    // Check common kitchen fractions
    final whole = value.floor();
    final rem = value - whole;
    final fractions = <double, String>{
      0.25: '1/4',
      0.333: '1/3',
      0.5: '1/2',
      0.667: '2/3',
      0.75: '3/4',
    };

    for (final entry in fractions.entries) {
      if ((rem - entry.key).abs() < 0.05) {
        return whole > 0 ? '$whole ${entry.value}' : entry.value;
      }
    }

    // Otherwise format to at most 1 decimal place
    final formatted = value.toStringAsFixed(1);
    return formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
  }
}
