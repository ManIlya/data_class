import 'dart:async';

import 'package:collection/collection.dart';
import 'package:data_class/src/extensions/named_type_anatation_extension.dart';
import 'package:macro_util/macro_util.dart';
import 'package:macros/macros.dart';

macro class CopyWith
    with _Shared, _CopyWithMixin
    implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const CopyWith();

  @override
  Future<void> buildDeclarationsForClass(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    await _declareCopyWith(clazz, builder);
  }

  @override
  Future<void> buildDefinitionForClass(ClassDeclaration clazz,
      TypeDefinitionBuilder builder) async {
    await _buildCopyWith(clazz, builder);
  }

}

mixin _CopyWithMixin on _Shared{
  Future<void> _declareCopyWith(ClassDeclaration clazz,
      MemberDeclarationBuilder builder) async {
    final methods = await builder.methodsOf(clazz);
    final copyWithMethod = methods
        .firstWhereOrNull(
          (method) => method.identifier.name == 'copyWith',
    );
    if (copyWithMethod != null) {
      builder.reportError('The copyWith method exists');
      return;
    }
    final fields = await builder.fieldsOf(clazz);
    final paramList = [];
    for (final field in fields) {
      final namedType = _checkNamedType(field.type, builder);
      if (namedType == null) {
        builder.reportError('InvalidType ${field.identifier.name}');
        return;
      }
      var classDecl = await namedType.classDeclaration(builder);
      if (classDecl == null) {
        builder.reportError(
            "Unable to parameter type ${(namedType.code).debugString}",
            target: namedType.asDiagnosticTarget);
        return;
      }
      paramList.add(RawCode.fromParts([
        field.type.code.asNullable,
        ' ',
        field.identifier.name,
        ',\n',
      ].indent(4)));
    }
    final className = clazz.identifier.name;
    builder.declareInType(
      DeclarationCode.fromParts([
        'external ',
        className,
        ' copyWith({\n',
        ...paramList,
        '});\n'
      ]),
    );
  }

  Future<void> _buildCopyWith(ClassDeclaration clazz,
      TypeDefinitionBuilder typeBuilder) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final copyWithMethod = methods
        .firstWhereOrNull(
          (method) => method.identifier.name == 'copyWith',
    );
    if (copyWithMethod == null) return;

    final methodBuilder = await typeBuilder.buildMethod(
        copyWithMethod.identifier);
    final fields = await typeBuilder.fieldsOf(clazz);
    final parts = <Object>[
      '{\n',
      ...['return ',
        clazz.identifier.name,
        '(\n',
        ..._generateCopyWithFields(fields, typeBuilder).indent(),
        ');\n',
      ].indent(4),
      '\t}\n'
    ];

    methodBuilder.augment(FunctionBodyCode.fromParts(parts));
  }

  Iterable<Object> _generateCopyWithFields(List<FieldDeclaration> fields,
      Builder builder) {
    return fields.map((field) {
      final name = field.identifier.name;
      return '$name: $name ?? this.$name,\n';
    });
  }
}
mixin _Shared{
  NamedTypeAnnotation? _checkNamedType(TypeAnnotation type, Builder builder) {
    if (type is NamedTypeAnnotation) return type;
    if (type is OmittedTypeAnnotation) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Only fields with explicit types are allowed on serializable '
                  'classes, please add a type.',
              target: type.asDiagnosticTarget),
          Severity.error));
    } else {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Only fields with named types are allowed on serializable '
                  'classes.',
              target: type.asDiagnosticTarget),
          Severity.error));
    }
    return null;
  }
}
extension on Code {
  /// Used for error messages.
  String get debugString {
    final buffer = StringBuffer();
    _writeDebugString(buffer);
    return buffer.toString();
  }

  void _writeDebugString(StringBuffer buffer) {
    for (final part in parts) {
      switch (part) {
        case Code():
          part._writeDebugString(buffer);
        case Identifier():
          buffer.write(part.name);
        case OmittedTypeAnnotation():
          buffer.write('<omitted>');
        default:
          buffer.write(part);
      }
    }
  }
}