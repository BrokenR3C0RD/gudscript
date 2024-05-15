import 'package:source_span/source_span.dart';

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

abstract class Stmt extends Node {
  Stmt(super.span);
}

abstract class Expr extends Stmt {
  Expr(super.span);
}

abstract class UnaryExpression extends Expr {
  final Expr expression;
  UnaryExpression(super.span, {required this.expression});

  @override
  String toString() => '${super.toString()}:\n'
      '    ${expression.toString().indent()}';
}

abstract class BinaryExpression extends Expr {
  final Expr left;
  final Expr right;

  BinaryExpression(super.span, {required this.left, required this.right});
  @override
  String toString() => '${super.toString()}:\n'
      '    Left: ${left.toString().indent()}\n'
      '    Right: ${right.toString().indent()}';
}

mixin AssignTarget on Expr {}

final class Variable extends Expr with AssignTarget {
  final String name;

  Variable(super.span, this.name);

  @override
  String toString() => '${super.toString()} = $name';
}

final class Number extends Expr {
  final num value;

  Number(super.span, this.value);

  @override
  String toString() => '${super.toString()} = $value';
}

final class Boolean extends Expr {
  final bool value;

  Boolean(super.span, this.value);

  @override
  String toString() => '${super.toString()} = $value';
}

final class MemberAccess extends Expr with AssignTarget {
  final Expr parent;
  final Expr property;

  MemberAccess(super.span, {required this.parent, required this.property});

  @override
  String toString() => '${super.toString()}:\n'
      '    Parent: ${parent.toString().indent()}\n'
      '    Property: ${property.toString().indent()}';
}

final class FunctionCall extends Expr {
  final Expr callee;
  final List<Expr> parameters;

  FunctionCall(super.span, {required this.callee, required this.parameters});

  @override
  String toString() => '${super.toString()}: $callee (\n'
      '  ${parameters.join(',\n').indent()}\n'
      ')';
}

final class PostfixIncrement extends Expr {
  final AssignTarget target;

  PostfixIncrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PostfixDecrement extends Expr {
  final AssignTarget target;

  PostfixDecrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PrefixIncrement extends Expr {
  final AssignTarget target;

  PrefixIncrement(super.span, this.target);

  @override
  String toString() => '${super.toString()}: ${target.toString().indent()})';
}

final class PrefixDecrement extends Expr {
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

final class Ternary extends Expr {
  final Expr condition;
  final Expr ifTrue;
  final Expr ifFalse;

  Ternary(super.span,
      {required this.condition, required this.ifTrue, required this.ifFalse});

  @override
  String toString() => '${super.toString()}:\n'
      '  Condition: ${condition.toString().indent()}\n'
      '  If `true`: ${ifTrue.toString().indent()}\n'
      '  If `false`: ${ifFalse.toString().indent()})';
}

final class VariableDefine extends Stmt {
  final Variable target;
  final Expr? value;

  VariableDefine(super.span, {required this.target, this.value});

  @override
  String toString() => '${super.toString()}:\n'
      '  Variable: ${target.toString().indent()}\n'
      '  Value: ${value.toString().indent()}';
}

final class Assign extends Stmt {
  final AssignTarget target;
  final Expr value;

  Assign(super.span, {required this.target, required this.value});
}
