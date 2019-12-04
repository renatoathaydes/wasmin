import 'package:test/test.dart';
import 'package:wasmin/src/parse/base.dart';

void main() {
  WordParser parser;
  setUp(() => parser = WordParser());

  test('can parse a word', () {
    final result = parser.parse("hello".runes.iterator);
    expect(result, equals(ParseResult.DONE));
    expect(parser.consumeWord(), equals('hello'));
    expect(parser.consumeWord(), equals(''));
  });

  test('does not consume more than a word', () {
    final iter = 'hello world'.runes.iterator;
    final result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('hello'));
    expect(iter.currentAsString, equals(' '));
    expect(iter.moveNext(), isTrue);
    expect(iter.currentAsString, equals('w'));
  });

  test('can parse words separated by common separators', () {
    final iter = 'let x=10'.runes.iterator;
    var result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('let'));
    expect(iter.currentAsString, equals(' '));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('x'));
    expect(iter.currentAsString, equals('='));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.DONE));
    expect(parser.consumeWord(), equals('10'));
    expect(iter.currentAsString, isNull);
    expect(iter.moveNext(), isFalse);
  });

  test('can parse many words with separators and multi-lines', () {
    final iter = "abc\ndef;;ghi,jkl\nmno pqr\n".runes.iterator;

    var result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('abc'));
    expect(iter.currentAsString, equals('\n'));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('def'));
    expect(iter.currentAsString, equals(';'));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals(''));
    expect(iter.currentAsString, equals(';'));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('ghi'));
    expect(iter.currentAsString, equals(','));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('jkl'));
    expect(iter.currentAsString, equals('\n'));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('mno'));
    expect(iter.currentAsString, equals(' '));
    expect(iter.moveNext(), isTrue);

    result = parser.parse(iter);
    expect(result, equals(ParseResult.CONTINUE));
    expect(parser.consumeWord(), equals('pqr'));
    expect(iter.currentAsString, equals('\n'));
    expect(iter.moveNext(), isFalse);
  });
}
