import 'package:wasmin/src/ast.dart';
import 'package:wasmin/src/parse/type.dart';

import 'base.dart';

class DeclarationParser with WordBasedParser<Declaration> {
  final WordParser words;
  final TypeParser type;

  Declaration _declaration;
  String failure;
  String firstWord;

  DeclarationParser(this.words) : type = TypeParser(words);

  @override
  ParseResult parse(RuneIterator runes) {
    var word = firstWord;
    reset();

    String id;
    bool isExported;

    if (word == null) {
      word = nextWord(runes);
    }

    if (word == 'export') {
      id = nextWord(runes);
      isExported = true;
    } else {
      id = word;
      isExported = false;
    }

    if (id.isEmpty) {
      failure = "variable of function declaration".wasExpected(runes, false);
      return ParseResult.FAIL;
    }

    final result = type.parse(runes);
    if (result == ParseResult.FAIL) {
      failure = type.failure;
      return result;
    }

    _declaration = type.consume().match(
        onFunType: (type) => FunDeclaration(type, id, isExported),
        onValueType: (type) => LetDeclaration(id, type, isExported));

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
