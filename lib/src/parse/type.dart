import '../expression.dart';
import '../type.dart';
import 'base.dart';
import 'iterator.dart';

class TypeParser with WordBasedParser<WasminType> {
  @override
  CompilerError failure;

  WasminType _type;

  @override
  final WordParser words;

  TypeParser(this.words);

  @override
  ParseResult parse(ParserState runes) {
    reset();
    final word = nextWord(runes);
    whitespaces.parse(runes);

    if (word.isEmpty) {
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
          whitespaces.parse(runes);
          final returnType =
              returns.isEmpty ? ValueType.empty : ValueType(returns);
          if (runes.currentAsString == null || runes.currentAsString == ';') {
            runes.moveNext();
          } else {
            failure = ';'.wasExpected(runes,
                quoteExpected: true,
                prefix: 'Unexpected character after type declaration');
            return ParseResult.FAIL;
          }
          _type = FunType(returnType,
              args.map((a) => ValueType(a)).toList(growable: false));
        } else {
          failure = ']'.wasExpected(runes,
              quoteExpected: true,
              prefix: 'Unterminated function parameter list');
          return ParseResult.FAIL;
        }
      } else {
        failure = 'type declaration'.wasExpected(runes);
        return ParseResult.FAIL;
      }
    } else {
      if (runes.currentAsString == null || runes.currentAsString == ';') {
        runes.moveNext();
        _type = ValueType(word);
      } else {
        failure = 'type declaration'
            .wasExpected(runes, prefix: 'Unexpected character');
        return ParseResult.FAIL;
      }
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
