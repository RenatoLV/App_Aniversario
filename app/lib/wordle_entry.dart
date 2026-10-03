/// Five physical cells: revealed letters cannot be overwritten or erased.
class WordleEntry {
  final cells = List<String>.filled(5, '');
  final locked = <int>{};
  final _typed = <int>[];
  String get word => cells.join();
  bool get complete => cells.every((c) => c.isNotEmpty);
  void reveal(int index, String letter) {
    cells[index] = letter;
    locked.add(index);
    _typed.remove(index);
  }

  void type(String letter) {
    final index = cells.indexOf('');
    if (index < 0) return;
    cells[index] = letter;
    _typed.add(index);
  }

  void delete() {
    if (_typed.isNotEmpty) cells[_typed.removeLast()] = '';
  }

  void clear() {
    for (var i = 0; i < 5; i++) {
      if (!locked.contains(i)) cells[i] = '';
    }
    _typed.clear();
  }
}
