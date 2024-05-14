import 'package:gudscript/src/tokens.dart';
import 'package:source_span/source_span.dart';

extension SpannedTokenMapExtension<T extends Token, N> on SpannedToken<T> {
  N? map(N? Function(T, FileSpan) convert) => convert(token, span);

  SpannedToken<T>? where(bool Function(T) test) => test(token) ? this : null;
}

extension on String {
  String indent() => split('\n')
      .indexed
      .map((t) => t.$1 == 0 ? t.$2 : '    ${t.$2}')
      .join('\n');
}

abstract class Node {
  FileSpan span;

  Node(this.span);

  @override
  String toString() => '$runtimeType[${span.start.toolString}]';
}

abstract class Statement extends Node {
  Statement(super.span);
}

abstract class Expression extends Statement {
  Expression(super.span);
}

abstract class UnaryExpression extends Expression {
  final Expression expression;
  UnaryExpression(super.span, {required this.expression});

  @override
  String toString() =>
      '${super.toString()}:\n${expression.toString().indent()}';
}

abstract class BinaryExpression extends Expression {
  final Expression left;
  final Expression right;

  BinaryExpression(super.span, {required this.left, required this.right});
  @override
  String toString() =>
      '${super.toString()}:\n  Left: ${left.toString().indent()}\n  Right: ${right.toString().indent()}';
}

mixin AssignTarget on Expression {}

final class Variable extends Expression with AssignTarget {
  final String name;

  Variable(super.span, this.name);

  @override
  String toString() => '${super.toString()} = $name';
}

final class Number extends Expression {
  final num value;

  Number(super.span, this.value);

  @override
  String toString() => '${super.toString()} = $value';
}

final class Boolean extends Expression {
  final bool value;

  Boolean(super.span, this.value);

  @override
  String toString() => '${super.toString()} = $value';
}

final class MemberAccess extends Expression with AssignTarget {
  final Expression parent;
  final Expression property;

  MemberAccess(super.span, {required this.parent, required this.property});

  @override
  String toString() => '${super.toString()}:\n'
      '  Parent: ${parent.toString().indent()}\n'
      '  Property: ${property.toString().indent()}';
}

final class FunctionCall extends Expression {
  final Expression callee;
  final List<Expression> parameters;

  FunctionCall(super.span, {required this.callee, required this.parameters});

  @override
  String toString() => '${super.toString()}: $callee (\n'
      '  ${parameters.join(',\n').indent()}\n'
      ')';
}

final class PostfixIncrement extends Expression {
  final AssignTarget target;

  PostfixIncrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PostfixDecrement extends Expression {
  final AssignTarget target;

  PostfixDecrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PrefixIncrement extends Expression {
  final AssignTarget target;

  PrefixIncrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PrefixDecrement extends Expression {
  final AssignTarget target;

  PrefixDecrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class Not extends UnaryExpression {
  Not(super.span, {required super.expression});
}

final class Negate extends UnaryExpression {
  Negate(super.span, {required super.expression});
}

final class Exponentiate extends BinaryExpression {
  Exponentiate(super.span, {required super.left, required super.right});
}

final class Multiply extends BinaryExpression {
  Multiply(super.span, {required super.left, required super.right});
}

final class Divide extends BinaryExpression {
  Divide(super.span, {required super.left, required super.right});
}

final class Modulo extends BinaryExpression {
  Modulo(super.span, {required super.left, required super.right});
}

final class Add extends BinaryExpression {
  Add(super.span, {required super.left, required super.right});
}

final class Subtract extends BinaryExpression {
  Subtract(super.span, {required super.left, required super.right});
}

final class LeftShift extends BinaryExpression {
  LeftShift(super.span, {required super.left, required super.right});
}

final class RightShift extends BinaryExpression {
  RightShift(super.span, {required super.left, required super.right});
}

final class LesserEqual extends BinaryExpression {
  LesserEqual(super.span, {required super.left, required super.right});
}

final class GreaterEqual extends BinaryExpression {
  GreaterEqual(super.span, {required super.left, required super.right});
}

final class Lesser extends BinaryExpression {
  Lesser(super.span, {required super.left, required super.right});
}

final class Greater extends BinaryExpression {
  Greater(super.span, {required super.left, required super.right});
}

final class Equal extends BinaryExpression {
  Equal(super.span, {required super.left, required super.right});
}

final class NotEqual extends BinaryExpression {
  NotEqual(super.span, {required super.left, required super.right});
}

final class BitAnd extends BinaryExpression {
  BitAnd(super.span, {required super.left, required super.right});
}

final class BitOr extends BinaryExpression {
  BitOr(super.span, {required super.left, required super.right});
}

final class BitXor extends BinaryExpression {
  BitXor(super.span, {required super.left, required super.right});
}

final class LogicalAnd extends BinaryExpression {
  LogicalAnd(super.span, {required super.left, required super.right});
}

final class LogicalOr extends BinaryExpression {
  LogicalOr(super.span, {required super.left, required super.right});
}

final class Ternary extends Expression {
  final Expression condition;
  final Expression ifTrue;
  final Expression ifFalse;

  Ternary(super.span,
      {required this.condition, required this.ifTrue, required this.ifFalse});

  @override
  String toString() => '${super.toString()}:\n'
      '  Condition: ${condition.toString().indent()}\n'
      '  If `true`: ${ifTrue.toString().indent()}\n'
      '  If `false`: ${ifFalse.toString().indent()})';
}

final class VariableDefine extends Statement {
  final Variable target;
  final Expression? value;

  VariableDefine(super.span, {required this.target, this.value});

  @override
  String toString() => '${super.toString()}:\n'
      '  Variable: ${target.toString().indent()}\n'
      '  Value: ${value.toString().indent()}';
}

final class Assign extends Statement {
  final AssignTarget target;
  final Expression value;

  Assign(super.span, {required this.target, required this.value});
}
