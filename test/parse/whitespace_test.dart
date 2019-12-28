import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  final parser = SkipWhitespaces();

  test('can skip whitespace', () {
    final runes = ParserState.fromString(' X');
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });

  test('can skip many whitespaces', () {
    final runes = ParserState.fromString('       X');
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });

  test('does not skip non-whitespace', () {
    final runes = ParserState.fromString('XYZ');
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });

  test('returns DONE if it consumed the whole input', () {
    final runes = ParserState.fromString('   ');
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.DONE));
    expect(runes.currentAsString, isNull);
  });

  test('can skip comments as if they were whitespaces', () {
    final runes = ParserState.fromString('# foo bar\nX');
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });

  test('can skip many comments as if they were whitespaces', () {
    final runes =
        ParserState.fromString('   # foo bar\n# more foo\n\n# hello #\nX');
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });
}
