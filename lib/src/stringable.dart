import 'dart:async';
import 'package:macros/macros.dart';

macro class ToStringable
    with _ToString
    implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const ToStringable();

  @override
  Future<void> buildDeclarationsForClass(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    final stringObject = await
    builder.resolveIdentifier(_dartCore, 'String');
    await _declareToString(clazz, builder, stringObject);
  }

  @override
  Future<void> buildDefinitionForClass(ClassDeclaration clazz,
      TypeDefinitionBuilder builder) async {
    final introspectionData = await _SharedIntrospectionData.build(
        builder, clazz);
    await _buildToString(clazz, builder, introspectionData);
  }
}

mixin _ToString {
  Future<void> _buildToString(ClassDeclaration clazz,
      TypeDefinitionBuilder typeBuilder,
      _SharedIntrospectionData introspectionData,) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final toStringMethod = methods.firstWhereOrNull((m) =>
    m.identifier.name == 'toString');
    if (toStringMethod == null) return;

    final builder = await typeBuilder.buildMethod(toStringMethod.identifier);
    final fields = introspectionData.fields;

    final parts = <Object>[
      '{\n'
      // stringObject,
      // ' toString() {\n',
          '    return "${clazz.identifier.name}(',
    ];

    bool first = true;
    for (final field in fields) {
      if (!first) parts.add(', ');
      first = false;
      parts.add('${field.identifier.name}: \${${field.identifier.name}}');
    }

    parts.add(')";\n');
    parts.add('  }\n');

    builder.augment(FunctionBodyCode.fromParts(parts));
  }

  Future<void> _declareToString(ClassDeclaration clazz,
      MemberDeclarationBuilder builder, Identifier stringObject) async {
    final methods = await builder.methodsOf(clazz);
    final toStringMethod = methods.firstWhereOrNull((m) =>
    m.identifier.name == 'toString');
    if (toStringMethod != null) return;

    builder.declareInType(DeclarationCode.fromParts([
      '  external ',
      stringObject,
      ' toString();',
    ]));
  }
}

final class _SharedIntrospectionData {
  final ClassDeclaration clazz;
  final List<FieldDeclaration> fields;

  _SharedIntrospectionData({
    required this.clazz,
    required this.fields,
  });

  static Future<_SharedIntrospectionData> build(
      DeclarationPhaseIntrospector builder, ClassDeclaration clazz) async {
    final fields = await builder.fieldsOf(clazz);

    return _SharedIntrospectionData(
      clazz: clazz,
      fields: fields,
    );
  }
}

final _dartCore = Uri.parse('dart:core');

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) compare) {
    for (final item in this) {
      if (compare(item)) return item;
    }
    return null;
  }
}
