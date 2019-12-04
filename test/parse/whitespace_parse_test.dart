import 'package:test/test.dart';
import 'package:wasmin/src/parse/base_parse.dart';

void main() {
  final parser = const SkipWhitespaces();

  test('can skip whitespace', () {
    final runes = " X".runes.iterator;
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });

  test('can skip many whitespaces', () {
    final runes = "       X".runes.iterator;
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });

  test('does not skip non-whitespace', () {
    final runes = "XYZ".runes.iterator;
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.CONTINUE));
    expect(runes.currentAsString, equals('X'));
  });

  test('returns DONE if it consumed the whole input', () {
    final runes = "   ".runes.iterator;
    final result = parser.parse(runes);
    expect(result, equals(ParseResult.DONE));
    expect(runes.currentAsString, isNull);
  });
}
