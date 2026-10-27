class PriceRequestReasons {
  static const List<String> all = [
    'New parts / materials needed',
    'Replacement needed (old part damaged)',
    'Job bigger / more work than expected',
    'Extra labor required',
    'Transport / distance extra',
    'Other',
  ];

  static bool needsParts(Set<String> selected) =>
      selected.contains('New parts / materials needed') ||
      selected.contains('Replacement needed (old part damaged)');

  static bool needsLabor(Set<String> selected) =>
      selected.contains('Job bigger / more work than expected') ||
      selected.contains('Extra labor required') ||
      selected.contains('Transport / distance extra');

  static bool needsReplacement(Set<String> selected) =>
      selected.contains('Replacement needed (old part damaged)');
}