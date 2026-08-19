class CategoryUtils {
  static bool isDescendant(String parentName, String potentialDescendant, List<dynamic> categories) {
    if (parentName == 'All Collections') return true;

    // Find the parent category object
    dynamic findIn(List<dynamic> list, String target) {
      for (var item in list) {
        final String name = item is Map ? item['name'] : item.toString();
        if (name == target) return item;
        if (item is Map && item['subcategories'] != null) {
          final found = findIn(item['subcategories'], target);
          if (found != null) return found;
        }
      }
      return null;
    }

    final parentObj = findIn(categories, parentName);
    if (parentObj == null || parentObj is String) return false;

    // Check if potentialDescendant is in subcategories of parentObj (recursive)
    bool checkIn(List<dynamic> list, String target) {
      for (var item in list) {
        final String name = item is Map ? item['name'] : item.toString();
        if (name == target) return true;
        if (item is Map && item['subcategories'] != null) {
          if (checkIn(item['subcategories'], target)) return true;
        }
      }
      return false;
    }

    return checkIn(parentObj['subcategories'] ?? [], potentialDescendant);
  }
}
