import 'package:collection/collection.dart';
import 'package:macros/macros.dart';

typedef FieldMetadata = ({String name, bool isRequired, TypeAnnotation? type});
typedef ConstructorParams = ({
List<FieldMetadata> positional,
List<FieldMetadata> named,
});

extension DefinitionBuilderX on DefinitionBuilder {
  Future<NamedTypeAnnotationCode> codeFrom(Uri library, String name) async {
    // ignore: deprecated_member_use
    return _codeFrom(library, name, resolveIdentifier);
  }

  Future<TypeAnnotation?> resolveType(
      FormalParameterDeclaration declaration,
      ClassDeclaration clazz,
      ) {
    return _resolveType(declaration, clazz, fieldsOf, superclassOf, report);
  }

  Future<ConstructorDeclaration?> defaultConstructorOf(TypeDeclaration clazz) {
    return _defaultConstructorOf(clazz, constructorsOf);
  }

  Future<ClassDeclaration?> superclassOf(ClassDeclaration clazz) {
    return _superclassOf(clazz, typeDeclarationOf);
  }

  Future<List<FieldDeclaration>> allFieldsOf(ClassDeclaration clazz) {
    return _allFieldsOf(clazz, fieldsOf, superclassOf);
  }

  Future<ConstructorParams> constructorParamsOf(
      ConstructorDeclaration constructor,
      ClassDeclaration clazz,
      ) {
    return _constructorParamsOf(constructor, clazz, resolveType);
  }
}

extension DeclarationBuilderX on DeclarationBuilder {
  Future<NamedTypeAnnotationCode> codeFrom(Uri library, String name) async {
    // ignore: deprecated_member_use
    return _codeFrom(library, name, resolveIdentifier);
  }

  Future<TypeAnnotation?> resolveType(
      FormalParameterDeclaration declaration,
      ClassDeclaration clazz,
      ) {
    return _resolveType(declaration, clazz, fieldsOf, superclassOf, report);
  }

  Future<ConstructorDeclaration?> defaultConstructorOf(TypeDeclaration clazz) {
    return _defaultConstructorOf(clazz, constructorsOf);
  }

  Future<ClassDeclaration?> superclassOf(ClassDeclaration clazz) {
    return _superclassOf(clazz, typeDeclarationOf);
  }

  Future<List<FieldDeclaration>> allFieldsOf(ClassDeclaration clazz) {
    return _allFieldsOf(clazz, fieldsOf, superclassOf);
  }

  Future<ConstructorParams> constructorParamsOf(
      ConstructorDeclaration constructor,
      ClassDeclaration clazz,
      ) {
    return _constructorParamsOf(constructor, clazz, resolveType);
  }
}

Future<NamedTypeAnnotationCode> _codeFrom(
    Uri library,
    String name,
    Future<Identifier> resolveIdentifier(Uri library, String name),
    ) async {
  final identifier = await resolveIdentifier(library, name);
  return NamedTypeAnnotationCode(name: identifier);
}

Future<List<FieldDeclaration>> _allFieldsOf(
    ClassDeclaration clazz,
    Future<List<FieldDeclaration>> fieldsOf(TypeDeclaration type),
    Future<ClassDeclaration?> superclassOf(ClassDeclaration clazz),
    ) async {
  final allFields = <FieldDeclaration>[];
  allFields.addAll(await fieldsOf(clazz));

  var superclass = await superclassOf(clazz);
  while (superclass != null && superclass.identifier.name != 'Object') {
    allFields.addAll(await fieldsOf(superclass));
    superclass = await superclassOf(superclass);
  }
  return allFields..removeWhere((f) => f.hasStatic);
}

Future<TypeAnnotation?> _resolveType(
    FormalParameterDeclaration declaration,
    ClassDeclaration clazz,
    Future<List<FieldDeclaration>> fieldsOf(TypeDeclaration type),
    Future<ClassDeclaration?> superclassOf(ClassDeclaration clazz),
    void report(Diagnostic diagnostic),
    ) async {
  final type = declaration.type;
  final name = declaration.name;
  if (type is NamedTypeAnnotation) return type;
  final fieldDeclarations = await fieldsOf(clazz);
  final field = fieldDeclarations.firstWhereOrNull(
        (f) => f.identifier.name == name,
  );

  if (field != null) return field.type;
  final superclass = await superclassOf(clazz);
  if (superclass != null) {
    return _resolveType(
      declaration,
      superclass,
      fieldsOf,
      superclassOf,
      report,
    );
  }

  report(
    Diagnostic(
      DiagnosticMessage(
        '''
Only fields with explicit types are allowed on data classes.
Please add a type to field "${name}" on class "${clazz.identifier.name}".''',
        target: declaration.asDiagnosticTarget,
      ),
      Severity.error,
    ),
  );
  return null;
}

Future<ClassDeclaration?> _superclassOf(
    ClassDeclaration clazz,
    Future<TypeDeclaration> typeDeclarationOf(Identifier identifier),
    ) async {
  final superclassType = clazz.superclass != null
      ? await typeDeclarationOf(clazz.superclass!.identifier)
      : null;
  return superclassType is ClassDeclaration ? superclassType : null;
}

Future<ConstructorDeclaration?> _defaultConstructorOf(
    TypeDeclaration clazz,
    Future<List<ConstructorDeclaration>> constructorsOf(TypeDeclaration type),
    ) async {
  final constructors = await constructorsOf(clazz);
  final defaultConstructor = constructors.firstWhereOrNull(
        (c) => c.identifier.name == '',
  );
  return defaultConstructor;
}

Future<ConstructorParams> _constructorParamsOf(
    ConstructorDeclaration constructor,
    ClassDeclaration clazz,
    Future<TypeAnnotation?> resolveType(
        FormalParameterDeclaration declaration,
        ClassDeclaration clazz,
        ),
    ) async {
  final (positional, named) = await (
  Future.wait([
    ...constructor.positionalParameters.map((p) {
      return resolveType(p, clazz).then((type) {
        return (
        // TODO(felangel): this workaround until we are able to detect default values.
        isRequired: type?.isNullable == false ? true : p.isRequired,
        name: p.identifier.name,
        type: type,
        );
      });
    })
  ]),
  Future.wait([
    ...constructor.namedParameters.map((p) {
      return resolveType(p, clazz).then((type) {
        return (
        isRequired: p.isRequired,
        name: p.identifier.name,
        type: type,
        );
      });
    })
  ])
  ).wait;
  return (positional: positional, named: named);
}

extension CodeX on Code {
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

extension TypeAnnotationX on TypeAnnotation {
  T cast<T extends TypeAnnotation>() => this as T;

  NamedTypeAnnotation? checkNamed(Builder builder) {
    if (this is NamedTypeAnnotation) return this as NamedTypeAnnotation;
    if (this is OmittedTypeAnnotation) {
      builder.report(
        Diagnostic(
          DiagnosticMessage(
            'Only fields with explicit types are allowed on data classes, please add a type.',
            target: asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
    } else {
      builder.report(
        Diagnostic(
          DiagnosticMessage(
            'Only fields with named types are allowed on data classes.',
            target: asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
    }
    return null;
  }
}
