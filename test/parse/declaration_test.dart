import 'package:test/test.dart';
import 'package:wasmin/src/ast.dart';
import 'package:wasmin/src/parse/base.dart';
import 'package:wasmin/src/parse/declaration.dart';
import 'package:wasmin/src/type.dart';
import 'package:wasmin/src/type_context.dart';

void main() {
  final parser = DeclarationParser(WordParser(), ParsingContext());

  group('let declarations', () {
    test('can parse let declaration with simple type', () {
      final result = parser.parse('abc i32'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected = VarDeclaration('abc', ValueType.i32);

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('abc'), equals(expected));
    });

    test('can parse exported let declaration with simple type', () {
      parser.firstWord = 'export';
      final result = parser.parse('def f32'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected = VarDeclaration('def', ValueType.f32, isExported: true);

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('def'), equals(expected));
    });
  });

  group('function declarations', () {
    test('can parse function signature returning constant', () {
      final result = parser.parse('main []i64'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected = FunDeclaration('main', FunType(ValueType.i64, const []));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('main'), equals(expected));
    });

    test('can parse exported function signature', () {
      final result = parser.parse('export _start []i64'.runes.iterator);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.DONE));

      final expected =
          FunDeclaration('_start', FunType(ValueType.i64, const []), true);

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('_start'), equals(expected));
    });

    test('can parse function signature with no arg, no return type', () {
      final iter = 'print-time [];X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));

      final expected =
          FunDeclaration('print-time', FunType(ValueType.empty, const []));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('print-time'), equals(expected));

      expect(iter.currentAsString, equals(';'));
    });

    test('can parse function signature with one arg, no return type', () {
      final iter = 'log-time [f64];X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));

      final expected = FunDeclaration(
          'log-time', FunType(ValueType.empty, const [ValueType.f64]));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('log-time'), equals(expected));

      expect(iter.currentAsString, equals(';'));
    });

    test('can parse function signature with one arg, one return type', () {
      final iter = 'convert[f64]i32;X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
      expect(result, equals(ParseResult.CONTINUE));

      final expected = FunDeclaration(
          'convert', FunType(ValueType.i32, const [ValueType.f64]));

      expect(parser.consume(), equals(expected));
      expect(parser.context.declarationOf('convert'), equals(expected));

      expect(iter.currentAsString, equals(';'));
    });

    test('can parse function signature with many args, one return type', () {
      final iter = 'f  [i32,i64\n,   f32, f64 ] i32 ; X'.runes.iterator;
      final result = parser.parse(iter);
      expect(parser.failure, isNull);
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
      final result = parser.parse(''.runes.iterator);
      expect(result, equals(ParseResult.FAIL));
      expect(parser.failure, equals('Expected identifier, got EOF'));
    });

    test('cannot parse identifier without a type', () {
      final result = parser.parse('hello; foo'.runes.iterator);
      expect(result, equals(ParseResult.FAIL));
      expect(parser.failure, equals("Expected type declaration, got ';'"));
    });

    test('', () {
      final result = parser.parse('exp foo[]i64;'.runes.iterator);
      expect(result, equals(ParseResult.FAIL));
      expect(
          parser.failure, equals("Unexpected character in type declaration: '['"));
    });

    test('must close function arguments list', () {
      final result = parser.parse('foo[i32'.runes.iterator);
      expect(result, equals(ParseResult.FAIL));
      expect(
          parser.failure,
          equals(
              "Unterminated function parameter list. Expected ']', got EOF"));

      final result2 = parser.parse('func[i32; ]i64'.runes.iterator);
      expect(result2, equals(ParseResult.FAIL));
      expect(
          parser.failure,
          equals(
              "Unterminated function parameter list. Expected ']', got ';'"));
    });
  });
}
