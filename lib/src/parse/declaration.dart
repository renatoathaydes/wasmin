import '../ast.dart';
import '../expression.dart';
import 'base.dart';
import 'iterator.dart';
import 'type.dart';

class DeclarationParser with WordBasedParser<Declaration> {
  @override
  final WordParser words;

  @override
  CompilerError? failure;

  bool isExported = false;

  final TypeParser type;

  Declaration? _declaration;

  DeclarationParser(this.words) : type = TypeParser(words);

  @override
  ParseResult parse(ParserState runes) {
    final export = isExported;
    reset();

    if (export) {
      final word = nextWord(runes);
      if (word != 'def') {
        failure = 'def'.wasExpected(runes, prefix: 'Invalid pub statement');
        return ParseResult.FAIL;
      }
    }

    final id = nextWord(runes);

    if (id.isEmpty) {
      failure = 'identifier'.wasExpected(runes);
      return ParseResult.FAIL;
    }

    final result = type.parse(runes);
    if (result == ParseResult.FAIL) {
      failure = type.failure;
      return result;
    }

    _declaration = type.consume().match(
        onFunType: (type) => FunDeclaration(id, type, export),
        onValueType: (type) =>
            VarDeclaration(id, type, isExported: export, isGlobal: true));

    return result;
  }

  @override
  Declaration consume() {
    final result = _declaration;
    if (result == null) throw Exception('declaration not parsed yet');
    reset();
    return result;
  }

  void reset() {
    failure = null;
    isExported = false;
    _declaration = null;
  }
}
