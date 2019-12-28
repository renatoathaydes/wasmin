import '../ast.dart';
import '../type_context.dart';
import 'base.dart';
import 'iterator.dart';
import 'type.dart';

class DeclarationParser with WordBasedParser<Declaration> {
  @override
  final WordParser words;

  @override
  String failure;

  final TypeParser type;
  final ParsingContext context;

  Declaration _declaration;
  String firstWord;

  DeclarationParser(this.words, this.context) : type = TypeParser(words);

  @override
  ParseResult parse(ParserState runes) {
    final word = firstWord ?? nextWord(runes);
    reset();

    String id;
    bool isExported;

    if (word == 'export') {
      id = nextWord(runes);
      isExported = true;
    } else {
      id = word;
      isExported = false;
    }

    if (id.isEmpty) {
      failure = 'identifier'.wasExpected(runes, false);
      return ParseResult.FAIL;
    }

    final result = type.parse(runes);
    if (result == ParseResult.FAIL) {
      failure = type.failure;
      return result;
    }

    _declaration = type.consume().match(
        onFunType: (type) => FunDeclaration(id, type, isExported),
        onValueType: (type) =>
            VarDeclaration(id, type, isExported: isExported));

    context.add(_declaration);

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
    firstWord = null;
    _declaration = null;
  }
}
