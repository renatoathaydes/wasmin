class ParserPosition {
  final int line;
  final int column;

  const ParserPosition(this.line, this.column);

  @override
  String toString() => '$line:$column';
}

mixin ParserState {
  ParserPosition get position;

  String get currentAsString;

  bool moveNext();

  static ParserState fromChunks(Iterable<String> chunks) =>
      _ParserIterator.fromChunks(chunks);

  static ParserState fromString(String text) =>
      _ParserIterator.fromChunks([text]);
}

class _ParserIterator implements ParserState, RuneIterator {
  int _line = 1;
  int _col = 1;

  final RuneIterator _delegate;

  _ParserIterator(this._delegate);

  _ParserIterator.fromChunks(Iterable<String> chunks)
      : _delegate = _ChunkedRunes(chunks.iterator);

  @override
  ParserPosition get position => ParserPosition(_line, _col);

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
    throw UnsupportedError('movePrevious');
  }

  @override
  void reset([int rawIndex = 0]) {
    throw UnsupportedError('reset');
  }

  @override
  String get string => 'ParserIterator{line=$_line,col=$_col}';
}

class _ChunkedRunes implements RuneIterator {
  final Iterator<String> _chunks;
  RuneIterator _currentRunes;

  _ChunkedRunes(this._chunks) {
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
  String get string => '_ChunkedRunes';

  RuneIterator _next() {
    if (_chunks.moveNext()) {
      return _chunks.current.runes.iterator;
    }
    return null;
  }
}
