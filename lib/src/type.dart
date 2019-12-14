import 'package:collection/collection.dart';

abstract class WasminType {
  const WasminType._();

  T match<T>({
    T Function(ValueType) onValueType,
    T Function(FunType) onFunType,
  });
}

/// A type that refers to a concrete value.
class ValueType extends WasminType {
  static const ValueType i32 = ValueType('i32');
  static const ValueType i64 = ValueType('i64');
  static const ValueType f32 = ValueType('f32');
  static const ValueType f64 = ValueType('f64');
  static const ValueType empty = ValueType('empty');
  static const ValueType anyFun = ValueType('anyfunc');

  final String name;

  const ValueType(this.name) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValueType &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ValueType{name: $name}';

  @override
  T match<T>({
    T Function(ValueType) onValueType,
    T Function(FunType) onFunType,
  }) {
    return onValueType(this);
  }
}

/// The type of a function.
class FunType extends WasminType {
  final ValueType returns;
  final List<ValueType> takes;

  const FunType(this.returns, this.takes) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FunType &&
          runtimeType == other.runtimeType &&
          returns == other.returns &&
          const IterableEquality<ValueType>().equals(takes, other.takes);

  @override
  int get hashCode => returns.hashCode ^ takes.hashCode;

  @override
  String toString() {
    return 'FunType{returns: $returns, takes: $takes}';
  }

  @override
  T match<T>({
    T Function(ValueType) onValueType,
    T Function(FunType) onFunType,
  }) {
    return onFunType(this);
  }
}
