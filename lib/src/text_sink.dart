import 'package:wasmin/src/parse/parse.dart';
import 'package:wasmin/src/type.dart';

import 'ast.dart';
import 'expression.dart';
import 'type_check.dart';

class WasmTextSink {
  var _indent = '';
  final StringSink _textSink;

  WasmTextSink(this._textSink);

  Future<void> call(Future<WasminUnit> programUnit) async {
    final unit = await programUnit;
    _textSink.writeln('(module');
    _increaseIndent();

    // write declarations first to the top of the file
    for (final declaration in unit.declarations) {
      _textSink.write(_indent);
      declaration.match(onFun: _funDeclaration, onLet: _assignment);
      _textSink.writeln();
    }

    // write all the implementation
    for (final impl in unit.implementations) {
      impl.match(onFun: _fun, onLet: _topLevelLet);
      _textSink.writeln();
    }

    _decreaseIndent();
    _textSink.writeln(')');
  }

  /// Debug method to write any node without validating anything.
  void add(Object node) {
    if (node is Expression) {
      return _writeExpression(node);
    }
    if (node is Assignment) {
      return _assignment(node);
    }
    if (node is Fun) {
      return _fun(node);
    }
    throw 'Cannot write $node';
  }

  void _funDeclaration(FunDeclaration fun) {
    // only write a declaration if it needs to be exported
    if (fun.isExported) {
      _textSink.write('(export "${fun.id}" (func \$${fun.id}))');
    }
  }

  void _assignment(Assignment assignment) {
    _textSink.write('(local \$${assignment.id} ${assignment.varType.name})');
  }

  void _fun(Fun fun) {
    final decl = fun.declaration;
    _textSink.write('$_indent(func \$${decl.id}');
    final argTypes = decl.type.takes;
    if (argTypes.length != fun.args.length) {
      throw Exception(
          'Invalid function instance: declaration has ${argTypes.length} types, '
          'but the implementation contains ${fun.args.length} parameters');
    }
    var i = 0;
    for (final param in fun.args) {
      final type = argTypes[i];
      _textSink.write(' (param \$${param} ${type.name})');
      i++;
    }
    if (decl.type.returns != ValueType.empty) {
      _textSink.write(' (result ${decl.type.returns.name})');
    }
    _textSink.writeln();
    _increaseIndent();
    _textSink.write(_indent);
    _writeExpression(fun.body);
    _decreaseIndent();
    _textSink.write('\n$_indent)');
  }

  void _topLevelLet(Let let) {
    throw 'TODO: top-level Let';
  }

  void _writeExpression(Expression expr) {
    expr.matchExpr(
      onConst: _const,
      onVariable: _variable,
      onFunCall: _funCall,
      onLet: _let,
      onGroup: _group,
    );
  }

  void _const(Const constant) {
    _textSink.write('(${constant.type.name}.const ${constant.value})');
  }

  void _variable(Var variable) {
    _textSink.write('(local.get \$${variable.name})');
  }

  void _funCall(FunCall funCall) {
    final prefix =
        operators.contains(funCall.name) ? '${funCall.type.name}.' : r'call $';
    _textSink.write('($prefix${funCall.name}');
    if (funCall.args.isNotEmpty) {
      _textSink.writeln();
      _increaseIndent();
      for (final arg in funCall.args) {
        _textSink.write(_indent);
        _writeExpression(arg);
        _textSink.writeln();
      }
      _decreaseIndent();
      _textSink.write('$_indent)');
    } else {
      _textSink.write(')');
    }
  }

  void _let(LetExpression let) {
    _textSink.write('(local.set \$${let.id}\n');
    _increaseIndent();
    _textSink.write(_indent);
    _writeExpression(let.body);
    _decreaseIndent();
    _textSink.write('\n$_indent)');
  }

  void _group(Group group) {
    final newVarAssignments = group.body.whereType<LetExpression>();

    // first, write all new assignments declarations
    var i = 0;
    for (final assignment in newVarAssignments) {
      if (i != 0) {
        _textSink.write(_indent);
      }
      _assignment(assignment);
      i++;
      _textSink.writeln();
    }

    // then, write the expressions themselves
    i = 0;
    for (final expr in group.body) {
      _textSink.write(_indent);
      _writeExpression(expr);
      i++;
      if (i < group.body.length) {
        _textSink.writeln();
      }
    }
  }

  void _increaseIndent() {
    _indent = _indent + '  ';
  }

  void _decreaseIndent() {
    _indent = _indent.substring(0, _indent.length - 2);
  }
}
