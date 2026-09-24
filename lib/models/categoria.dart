class Categoria {
  final int? id;
  final String nombre;
  final String? creadoEn;

  Categoria({
    this.id,
    required this.nombre,
    this.creadoEn,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      if (creadoEn != null) 'creado_en': creadoEn,
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      creadoEn: map['creado_en'] as String?,
    );
  }
}
