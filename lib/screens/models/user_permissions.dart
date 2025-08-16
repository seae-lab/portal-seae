// Baseado no seu log de erro, o arquivo está em 'screens/models/'.
// Mantenha-o neste caminho.

class UserPermissions {
  final Map<String, bool> roles;

  UserPermissions(this.roles);

  // MÉTODO CORRIGIDO
  factory UserPermissions.fromMap(Map<String, dynamic> data) {
    final rolesMap = <String, bool>{};
    // Iteramos sobre os dados do Firestore de forma segura
    data.forEach((key, value) {
      // Se a chave começa com "papel_" e o valor é exatamente 'true'
      if (key.startsWith('papel_') && value == true) {
        rolesMap[key] = value;
      }
    });
    return UserPermissions(rolesMap);
  }

  bool get isAdmin => roles['papel_admin'] ?? false;

  bool hasRole(String roleName) {
    if (isAdmin) return true;
    return roles[roleName] ?? false;
  }

  bool get hasAnyRole => roles.isNotEmpty;
}