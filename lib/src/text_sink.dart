import 'ast.dart';

class TextSink with Sink<AstNode> {
  final StringSink _textSink;
  final _nodes = <AstNode>[];

  TextSink(this._textSink);

  @override
  void add(AstNode data) {
    _nodes.add(data);
  }

  @override
  void close() {
    for (final node in _nodes) {
      node.match(_letDeclaration);
    }
    for (final node in _nodes) {
      node.match(_letAssignment);
    }
  }

  void _letDeclaration(Let let) {
    _textSink.writeln('(local \$${let.id} ${let.type})');
  }

  void _letAssignment(Let let) {
    if (let.expr.args.isNotEmpty) {
      throw 'complex expressions are not implemented yet';
    }
    _textSink.write('(local.set \$${let.id} ');
    final constant = let.expr.op;
    _writeConst(constant);
    _textSink.writeln(')');
  }

  void _writeConst(String cons) {
    int i64 = int.tryParse(cons);
    if (i64 != null) {
      return _textSink.write('(i64.const $cons)');
    }
    double f64 = double.tryParse(cons);
    if (f64 != null) {
      return _textSink.write('(f64.const $cons)');
    }
    throw 'Do not know how to convert to constant: \'$cons\'';
  }
}
