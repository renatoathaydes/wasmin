import 'ast.dart';
import 'type_check.dart';

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
    // write declarations first to the top of the file
    for (final node in _nodes) {
      node.match(_letDeclaration, (expr) {});
    }
    // write all the rest
    for (final node in _nodes) {
      node.match(_letAssignment, _writeExpression);
    }
  }

  void _letDeclaration(Let let) {
    _textSink.writeln('(local \$${let.id} ${let.type.name()})');
  }

  void _letAssignment(Let let) {
    _textSink.write('(local.set \$${let.id} ');
    _writeExpression(let.expr);
    _textSink.writeln(')');
  }

  void _writeExpression(Expression expr) {
    if (expr.args.isEmpty) {
      final constant = expr.op;
      _writeConst(constant, expr.type);
    } else {
      _writeFunctionCall(expr);
    }
  }

  void _writeConst(String cons, ValueType type) {
    return _textSink.write('(${type.name()}.const $cons)');
  }

  void _writeFunctionCall(Expression expr) {
    final prefix =
        operators.contains(expr.op) ? '${expr.type.name()}.' : r'call $';
    _textSink.write('($prefix${expr.op} ');

    // TODO allow non-constant arguments
    int index = 0;
    for (final arg in expr.args) {
      if (arg.args.isNotEmpty) {
        throw 'writing non-constant function args not supported yet: ${arg.args}';
      }
      _writeConst(arg.op, arg.type);
      if ((++index) != expr.args.length) {
        _textSink.write(' ');
      }
    }

    _textSink.writeln(')');
  }
}
