import 'package:intl/intl.dart';

/// Money handling for the whole app.
///
/// Amounts move around as `int` cents. Nothing in this project stores or
/// arithmetics a `double` amount, because floating point cannot hold
/// 0.10 exactly and a month of small food entries would drift the budget
/// total by a few sen. Conversion to and from a display string happens
/// only at the edges: this file.
class Money {
  Money._();

  static final NumberFormat _display = NumberFormat('#,##0.00', 'en_MY');

  /// 121200 -> 'RM 1,212.00'
  static String format(int cents) => 'RM ${_display.format(cents / 100)}';

  /// 121200 -> '1,212.00' (for places where the RM prefix is already shown)
  static String formatBare(int cents) => _display.format(cents / 100);

  /// Turns typed input into cents. Accepts '12', '12.5', '12.50',
  /// 'RM 12.50' and '1,212.00'. Returns null when the text is not a
  /// usable amount, so callers can show a field error instead of
  /// silently saving zero.
  static int? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    if (cleaned.indexOf('.') != cleaned.lastIndexOf('.')) return null;

    final value = double.tryParse(cleaned);
    if (value == null || value <= 0) return null;

    // Round rather than truncate: '12.999' should become 13.00, not 12.99.
    return (value * 100).round();
  }

  /// Percentage of [limitCents] used by [spentCents], as a whole number.
  /// Returns 0 when there is no limit set, so a missing budget never
  /// renders as a warning.
  static int percentUsed({required int spentCents, required int limitCents}) {
    if (limitCents <= 0) return 0;
    return ((spentCents / limitCents) * 100).round();
  }
}
