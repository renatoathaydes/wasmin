import 'package:test/test.dart';
import 'package:wasmin/wasmin.dart';

void main() {
  final parser = DeclarationParser(WordParser(), ParsingContext());

  group('let declarations', () {
    test('can parse let declaration with simple type', () {
      final result = parser.parse(ParserState.fromString('abc i32'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected = VarDeclaration('abc', ValueType.i32);

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('abc'), equals(expected));
    });

    test('can parse exported let declaration with simple type', () {
      parser.isExported = true;
      final result = parser.parse(ParserState.fromString('def abc f32'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected = VarDeclaration('abc', ValueType.f32, isExported: true);

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('abc'), equals(expected));
    });
  });

  group('function declarations', () {
    test('can parse function signature returning constant', () {
      final result = parser.parse(ParserState.fromString('main []i64'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected = FunDeclaration('main', FunType(ValueType.i64, const []));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('main'), equals(expected));
    });

    test('can parse exported function signature', () {
      parser.isExported = true;
      final result =
          parser.parse(ParserState.fromString('def _start []i64'));
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected =
          FunDeclaration('_start', FunType(ValueType.i64, const []), true);

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('_start'), equals(expected));
    });

    test('can parse function signature with no arg, no return type', () {
      final iter = ParserState.fromString('print-time [];X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.CONTINUE));

      final expected =
          FunDeclaration('print-time', FunType(ValueType.empty, const []));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('print-time'), equals(expected));

      expect(iter.currentAsString, equals(';'));
    });

    test('can parse function signature with one arg, no return type', () {
      final iter = ParserState.fromString('log-time [f64];X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.CONTINUE));

      final expected = FunDeclaration(
          'log-time', FunType(ValueType.empty, const [ValueType.f64]));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('log-time'), equals(expected));

      expect(iter.currentAsString, equals(';'));
    });

    test('can parse function signature with one arg, one return type', () {
      final iter = ParserState.fromString('convert[f64]i32;X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.CONTINUE));

      final expected = FunDeclaration(
          'convert', FunType(ValueType.i32, const [ValueType.f64]));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('convert'), equals(expected));

      expect(iter.currentAsString, equals(';'));
    });

    test('can parse function signature with many args, one return type', () {
      final iter =
          ParserState.fromString('f  [i32,i64\n,   f32, f64 ] i32 ; X');
      final result = parser.parse(iter);
      expect(parser.failure?.message, isNull);
      expect(result, equals(ParseResult.CONTINUE));

      final expected = FunDeclaration(
          'f',
          FunType(ValueType.i32, const [
            ValueType.i32,
            ValueType.i64,
            ValueType.f32,
            ValueType.f64,
          ]));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('f'), equals(expected));

      expect(iter.currentAsString, equals(' '));
    });
  });

  group('failures', () {
    test('cannot parse empty string', () {
      final result = parser.parse(ParserState.fromString(''));
      expect(result, equals(ParseResult.FAIL));
      expect(parser.failure?.message, equals('Expected identifier, got EOF'));
    });

    test('cannot parse identifier without a type', () {
      final result = parser.parse(ParserState.fromString('hello; foo'));
      expect(result, equals(ParseResult.FAIL));
      expect(parser.failure?.message,
          equals("Expected type declaration, got ';'"));
    });

    test('cannot parse type with unexpected character', () {
      final result = parser.parse(ParserState.fromString('exp foo[]i64;'));
      expect(result, equals(ParseResult.FAIL));
      expect(parser.failure?.message,
          equals("Unexpected character. Expected type declaration, got '['"));
    });

    test('must close function arguments list', () {
      final result = parser.parse(ParserState.fromString('foo[i32'));
      expect(result, equals(ParseResult.FAIL));
      expect(
          parser.failure?.message,
          equals(
              "Unterminated function parameter list. Expected ']', got EOF"));

      final result2 = parser.parse(ParserState.fromString('func[i32; ]i64'));
      expect(result2, equals(ParseResult.FAIL));
      expect(
          parser.failure?.message,
          equals(
              "Unterminated function parameter list. Expected ']', got ';'"));
    });
  });
}
