import 'ast.dart';
import 'compile.dart';
import 'expression.dart';
import 'parse/parse.dart';
import 'type.dart';
import 'type_check.dart';

class WasmTextSink {
  var _indent = '';
  final StringSink _textSink;
  final _blockStack = <String>[];
  var _compilationResult = CompilationResult.success;

  WasmTextSink(this._textSink);

  Future<CompilationResult> call(Future<WasminUnit> programUnit) async {
    final unit = await programUnit;
    _textSink.writeln('(module');
    _increaseIndent();

    // write declarations first to the top of the file
    for (final declaration in unit.declarations) {
      declaration.match(
          onFun: (f) => _funDeclaration(f, writeInNewLine: true),
          onVar: (v) => _declaration(v, writeInNewLine: true));
      _textSink.writeln();
    }

    // write all the implementation
    for (final impl in unit.implementations) {
      impl.match(onFun: _fun, onLet: _topLevelLet);
      _textSink.writeln();
    }

    _decreaseIndent();
    _textSink.writeln(')');

    return _compilationResult;
  }

  /// Debug method to write any node without validating anything.
  void add(Object node) {
    if (node is Expression) {
      return _writeExpression(node);
    }
    if (node is VarDeclaration) {
      return _declaration(node);
    }
    if (node is Fun) {
      return _fun(node);
    }
    throw 'Cannot write $node';
  }

  void _funDeclaration(FunDeclaration fun, {bool writeInNewLine = false}) {
    // only write a declaration if it needs to be exported
    if (fun.isExported) {
      if (writeInNewLine) _textSink.writeln('\n$_indent');
      _textSink.write('(export "${fun.id}" (func \$${fun.id}))');
    }
  }

  void _declaration(VarDeclaration declaration, {bool writeInNewLine = false}) {
    if (writeInNewLine) _textSink.writeln('\n$_indent');
    _textSink.write('(local \$${declaration.id} ${declaration.varType.name})');
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
    final wroteNewLine = _writeDeclarations(fun.body.declarations);
    if (wroteNewLine) _textSink.write(_indent);
    _writeExpression(fun.body);
    _decreaseIndent();
    _textSink.write('\n$_indent)');
  }

  bool _writeDeclarations(List<VarDeclaration> assignments) {
    var hasWrittenNewLine = false;
    for (final assignment in assignments) {
      if (hasWrittenNewLine) {
        _textSink.write(_indent);
      }
      _declaration(assignment);
      _textSink.writeln();
      hasWrittenNewLine = true;
    }
    return hasWrittenNewLine;
  }

  void _topLevelLet(Let let) {
    throw 'TODO: top-level Let';
  }

  void _writeExpression(Expression expr) {
    expr.matchExpr(
      onConst: _const,
      onVariable: _variable,
      onFunCall: _funCall,
      onAssign: _assign,
      onIf: _if,
      onLoop: _loop,
      onBreak: _break,
      onGroup: _group,
      onError: _error,
    );
  }

  void _const(Const constant) {
    _textSink.write('(${constant.type.name}.const ${constant.value})');
  }

  void _variable(Var variable) {
    _textSink.write('(local.get \$${variable.name})');
  }

  void _funCall(FunCall funCall) {
    final prefix = operators.contains(funCall.name)
        ? '${funCall.args.first.type.name}.'
        : r'call $';
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

  void _assign(AssignExpression let) {
    _textSink.write('(local.set \$${let.id}\n');
    _increaseIndent();
    _textSink.write(_indent);
    _writeExpression(let.body);
    _decreaseIndent();
    _textSink.write('\n$_indent)');
  }

  void _if(IfExpression ifExpr) {
    _textSink.write('(if');
    if (ifExpr.type == ValueType.empty) {
      _textSink.writeln();
    } else {
      _textSink.write(' (result ${ifExpr.type.name})\n');
    }
    _increaseIndent();
    _textSink.write(_indent);
    _writeExpression(ifExpr.cond);
    _textSink.writeln();
    _textSink.write(_indent);
    _writeExpression(ifExpr.then);
    if (ifExpr.els != null) {
      _textSink.writeln();
      _textSink.write(_indent);
      _writeExpression(ifExpr.els);
    }
    _decreaseIndent();
    _textSink.write('\n$_indent)');
  }

  void _loop(LoopExpression loop) {
    _pushBlock();
    _textSink.writeln('(loop ${_currentBlock()}');
    _increaseIndent();
    _textSink.write(_indent);
    _writeExpression(loop.body);
    _decreaseIndent();
    _textSink.write('\n$_indent)');
    _dropBlock();
  }

  void _break() {
    _textSink.write('(br ${_currentBlock()})');
  }

  void _group(Group group) {
    var i = 0;
    for (final expr in group.body) {
      if (i != 0) _textSink.write(_indent);
      _writeExpression(expr);
      i++;
      if (i < group.body.length) _textSink.writeln();
    }
  }

  void _error(CompilerError compilerError) {
    _compilationResult = CompilationResult.error;
    print('ERROR: ${compilerError.position} - ${compilerError.message}');
  }

  void _increaseIndent() {
    _indent = _indent + '  ';
  }

  void _decreaseIndent() {
    _indent = _indent.substring(0, _indent.length - 2);
  }

  void _pushBlock() {
    _blockStack.add('\$block${_blockStack.length}');
  }

  void _dropBlock() {
    _blockStack.removeLast();
  }

  String _currentBlock() => _blockStack.last;
}
