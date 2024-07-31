import 'package:macros/macros.dart';

extension NamedTypeAnnotationExtension on NamedTypeAnnotation {
  /// Follows the declaration of this type through any type aliases, until it
  /// reaches a [ClassDeclaration], or returns null if it does not bottom out on
  /// a class.
  Future<ClassDeclaration?> classDeclaration(DeclarationBuilder builder) async {
    try {
      var typeDecl = await builder.typeDeclarationOf(identifier);

      while (typeDecl is TypeAliasDeclaration) {
        final aliasedType = typeDecl.aliasedType;
        if (aliasedType is! NamedTypeAnnotation) {
          builder.report(Diagnostic(
              DiagnosticMessage(
                  'Only fields with named types are allowed on serializable '
                  'classes',
                  target: asDiagnosticTarget),
              Severity.error));
          return null;
        }
        typeDecl = await builder.typeDeclarationOf(aliasedType.identifier);
      }
      if (typeDecl is! ClassDeclaration) {
        builder.report(Diagnostic(
            DiagnosticMessage(
                'Only classes are supported as field types for serializable '
                'classes',
                target: asDiagnosticTarget),
            Severity.error));
        return null;
      }
      return typeDecl;
    } on MacroException catch (e) {
      builder.report(
        Diagnostic(
          DiagnosticMessage('Type ${identifier.name}: ${e.message}'),
          Severity.error,
        ),
      );
      return null;
    }
  }
}
