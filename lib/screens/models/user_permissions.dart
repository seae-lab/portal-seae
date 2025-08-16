// Baseado no seu log de erro, o arquivo está em 'screens/models/'.
// Mantenha-o neste caminho.

class UserPermissions {
  final Map<String, bool> roles;

  UserPermissions(this.roles);

  // MÉTODO ATUALIZADO
  factory UserPermissions.fromMap(Map<String, dynamic> data) {
    final rolesMap = <String, bool>{};
    data.forEach((key, value) {
      // Agora, qualquer campo que seja um booleano 'true' é considerado um papel.
      // Isso torna o sistema flexível para novos papéis.
      if (value is bool && value == true) {
        rolesMap[key] = value;
      }
    });
    return UserPermissions(rolesMap);
  }

  // GETTER ATUALIZADO
  bool get isAdmin => roles['admin'] ?? false;

  // Este método continua igual, mas agora receberá nomes de papéis sem o prefixo.
  bool hasRole(String roleName) {
    if (isAdmin) return true;
    return roles[roleName] ?? false;
  }

  bool get hasAnyRole => roles.isNotEmpty;
}