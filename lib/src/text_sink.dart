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
    expr.matchExpr(
      onConst: _writeConst,
      onVariable: _writeVariable,
      onFunCall: _writeFunctionCall,
    );
  }

  void _writeConst(String cons, ValueType type) {
    return _textSink.write('(${type.name()}.const $cons)');
  }

  void _writeVariable(String name, ValueType type) {
    return _textSink.write('(local.get \$$name)');
  }

  void _writeFunctionCall(String name, List<Expression> args, ValueType type) {
    final prefix = operators.contains(name) ? '${type.name()}.' : r'call $';
    _textSink.write('($prefix${name} ');
    var index = 0;
    for (final arg in args) {
      _writeExpression(arg);
      index++;
      if (index < args.length) _textSink.write(' ');
    }
    _textSink.writeln(')');
  }
}
