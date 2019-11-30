class ParserIterator implements RuneIterator {
  int _line = 1;
  int _col = 1;

  final RuneIterator _delegate;

  ParserIterator(this._delegate);

  ParserIterator.fromLines(Iterable<String> lines)
      : _delegate = _LinesRunes(lines.iterator);

  String get position => "$_line:$_col";

  @override
  int get rawIndex => _delegate.rawIndex;

  @override
  set rawIndex(int rawIndex) {
    throw UnsupportedError('rawIndex');
  }

  @override
  int get current => _delegate.current;

  @override
  String get currentAsString => _delegate.currentAsString;

  @override
  int get currentSize => _delegate.currentSize;

  @override
  bool moveNext() {
    final moved = _delegate.moveNext();
    if (moved) {
      if (_delegate.currentAsString == '\n') {
        _line++;
        _col = 1;
      } else {
        _col++;
      }
    }
    return moved;
  }

  @override
  bool movePrevious() {
    throw UnsupportedError("movePrevious");
  }

  @override
  void reset([int rawIndex = 0]) {
    throw UnsupportedError('reset');
  }

  @override
  String get string => "ParserIterator{line=$_line,col=$_col}";
}

class _LinesRunes implements RuneIterator {
  final Iterator<String> _lines;
  RuneIterator _currentRunes;

  _LinesRunes(this._lines) {
    _currentRunes = _next();
  }

  @override
  int rawIndex = 0;

  @override
  int get current => _currentRunes?.current;

  @override
  String get currentAsString => _currentRunes?.currentAsString;

  @override
  int get currentSize => _currentRunes?.currentSize;

  @override
  bool moveNext() {
    if (_currentRunes?.moveNext() ?? false) {
      return true;
    } else {
      _currentRunes = _next();
      if (_currentRunes == null) return false;
      return _currentRunes.moveNext();
    }
  }

  @override
  bool movePrevious() {
    throw UnsupportedError('movePrevious');
  }

  @override
  void reset([int rawIndex = 0]) {
    throw UnsupportedError('reset');
  }

  @override
  String get string => "_LinesRunes";

  RuneIterator _next() {
    if (_lines.moveNext()) {
      return "${_lines.current}\n".runes.iterator;
    }
    return null;
  }
}
