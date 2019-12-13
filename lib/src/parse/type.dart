import '../type.dart';
import 'base.dart';

class TypeParser with WordBasedParser<WasminType> {
  @override
  String failure;

  WasminType _type;

  @override
  final WordParser words;

  TypeParser(this.words);

  @override
  ParseResult parse(RuneIterator runes) {
    reset();
    final word = nextWord(runes);
    if (word.isEmpty) {
      whitespaces.parse(runes);
      if (runes.currentAsString == '[') {
        final args = <String>[];
        do {
          runes.moveNext();
          final arg = nextWord(runes);
          if (arg.isEmpty) break; // allow trailing comma
          args.add(arg);
          whitespaces.parse(runes);
        } while (runes.currentAsString == ',');
        if (runes.currentAsString == ']') {
          runes.moveNext();
          final returns = nextWord(runes);
          if (returns.isEmpty) {
            failure =
                'function return type declaration'.wasExpected(runes, false);
            return ParseResult.FAIL;
          } else {
            _type = FunType(ValueType(returns),
                args.map((a) => ValueType(a)).toList(growable: false));
          }
        } else {
          failure = 'Unterminated function parameter list. ' +
              ']'.wasExpected(runes, true);
          return ParseResult.FAIL;
        }
      } else {
        failure = 'type declaration'.wasExpected(runes, false);
        return ParseResult.FAIL;
      }
    } else {
      _type = ValueType(word);
    }

    return runes.currentAsString == null
        ? ParseResult.DONE
        : ParseResult.CONTINUE;
  }

  @override
  WasminType consume() {
    final result = _type;
    if (result == null) throw Exception('type not parsed yet');
    reset();
    return result;
  }

  void reset() {
    _type = null;
    failure = null;
  }
}