import 'ast.dart';
import 'type.dart';

const _i32UniBoolOperator = FunType(ValueType.i32, [ValueType.i32]);
const _i64UniBoolOperator = FunType(ValueType.i32, [ValueType.i64]);

const _i32BiBoolOperator =
    FunType(ValueType.i32, [ValueType.i32, ValueType.i32]);
const _i64BiBoolOperator =
    FunType(ValueType.i32, [ValueType.i64, ValueType.i64]);
const _f32BiBoolOperator =
    FunType(ValueType.i32, [ValueType.f32, ValueType.f32]);
const _f64BiBoolOperator =
    FunType(ValueType.i32, [ValueType.f64, ValueType.f64]);

const _i32UniOperator = FunType(ValueType.i32, [ValueType.i32]);
const _i64UniOperator = FunType(ValueType.i64, [ValueType.i64]);
const _f32UniOperator = FunType(ValueType.f32, [ValueType.f32]);
const _f64UniOperator = FunType(ValueType.f64, [ValueType.f64]);

const _i32BiOperator = FunType(ValueType.i32, [ValueType.i32, ValueType.i32]);
const _i64BiOperator = FunType(ValueType.i64, [ValueType.i64, ValueType.i64]);
const _f32BiOperator = FunType(ValueType.f32, [ValueType.f32, ValueType.f32]);
const _f64BiOperator = FunType(ValueType.f64, [ValueType.f64, ValueType.f64]);

mixin TypeContext {
  Set<FunType> typeOfFun(String funName, int argsCount);

  Declaration declarationOf(String id);
}

mixin MutableTypeContext implements TypeContext {
  void add(Declaration declaration);
}

class WasmDefaultTypeContext with TypeContext {
  static const _operators = {
    // iunop
    'clz': [_i32UniOperator, _i64UniOperator],
    'ctz': [_i32UniOperator, _i64UniOperator],
    'popcnt': [_i32UniOperator, _i64UniOperator],

    // ibinop && fbinop
    'add': [_i32BiOperator, _i64BiOperator, _f32BiOperator, _f64BiOperator],
    'sub': [_i32BiOperator, _i64BiOperator, _f32BiOperator, _f64BiOperator],
    'mul': [_i32BiOperator, _i64BiOperator, _f32BiOperator, _f64BiOperator],

    // ibiniop
    'div_u': [_i32BiOperator, _i64BiOperator],
    'div_s': [_i32BiOperator, _i64BiOperator],
    'rem_u': [_i32BiOperator, _i64BiOperator],
    'rem_s': [_i32BiOperator, _i64BiOperator],
    'and': [_i32BiOperator, _i64BiOperator],
    'or': [_i32BiOperator, _i64BiOperator],
    'xor': [_i32BiOperator, _i64BiOperator],
    'shl': [_i32BiOperator, _i64BiOperator],
    'shr_u': [_i32BiOperator, _i64BiOperator],
    'shr_s': [_i32BiOperator, _i64BiOperator],
    'rotl': [_i32BiOperator, _i64BiOperator],
    'rotr': [_i32BiOperator, _i64BiOperator],

    // fbinop
    'div': [_f32BiOperator, _f64BiOperator],
    'min': [_f32BiOperator, _f64BiOperator],
    'max': [_f32BiOperator, _f64BiOperator],
    'copysign': [_f32BiOperator, _f64BiOperator],

    // funop
    'abs': [_f32UniOperator, _f64UniOperator],
    'neg': [_f32UniOperator, _f64UniOperator],
    'sqrt': [_f32UniOperator, _f64UniOperator],
    'ceil': [_f32UniOperator, _f64UniOperator],
    'floor': [_f32UniOperator, _f64UniOperator],
    'trunc': [_f32UniOperator, _f64UniOperator],
    'nearest': [_f32UniOperator, _f64UniOperator],

    // itestop
    'eqz': [_i32UniBoolOperator, _i64UniBoolOperator],

    // irelop && frelop
    'eq': [
      _i32BiBoolOperator,
      _i64BiBoolOperator,
      _f32BiBoolOperator,
      _f64BiBoolOperator,
    ],
    'ne': [
      _i32BiBoolOperator,
      _i64BiBoolOperator,
      _f32BiBoolOperator,
      _f64BiBoolOperator,
    ],

    // irelop
    'lt_u': [_i32BiBoolOperator, _i64BiBoolOperator],
    'lt_s': [_i32BiBoolOperator, _i64BiBoolOperator],
    'gt_u': [_i32BiBoolOperator, _i64BiBoolOperator],
    'gt_s': [_i32BiBoolOperator, _i64BiBoolOperator],
    'le_u': [_i32BiBoolOperator, _i64BiBoolOperator],
    'le_s': [_i32BiBoolOperator, _i64BiBoolOperator],
    'ge_u': [_i32BiBoolOperator, _i64BiBoolOperator],
    'ge_s': [_i32BiBoolOperator, _i64BiBoolOperator],

    // frelop
    'lt': [_f32BiBoolOperator, _f64BiBoolOperator],
    'gt': [_f32BiBoolOperator, _f64BiBoolOperator],
    'le': [_f32BiBoolOperator, _f64BiBoolOperator],
    'ge': [_f32BiBoolOperator, _f64BiBoolOperator],
  };

  const WasmDefaultTypeContext();

  @override
  Set<FunType> typeOfFun(String funName, int argsCount) {
    final types = _operators[funName];
    if (types != null) {
      return types.where((op) => op.takes.length == argsCount).toSet();
    }
    return const {};
  }

  @override
  Declaration declarationOf(String id) => null;
}

class ParsingContext with MutableTypeContext {
  final _declarations = <String, Set<Declaration>>{};
  final TypeContext _parent;

  ParsingContext([this._parent = const WasmDefaultTypeContext()]);

  @override
  Set<FunType> typeOfFun(String funName, int argsCount) {
    final declarations = _declarations[funName]
            ?.expand((decl) => decl.match(
                  onVar: (_) => const <FunType>{},
                  onFun: (f) => [f.type],
                ))
            ?.toSet() ??
        const <FunType>{};
    return {..._parent.typeOfFun(funName, argsCount), ...declarations};
  }

  @override
  Declaration declarationOf(String id) {
    // FIXME should return a List<Declaration>
    return _declarations[id]?.first ?? _parent.declarationOf(id);
  }

  @override
  void add(Declaration declaration) {
    _declarations
        .putIfAbsent(declaration.id, () => <Declaration>{})
        .add(declaration);
  }

  ParsingContext createChild() => ParsingContext(this);
}
