// Baseado no seu log de erro, o arquivo está em 'screens/models/'.
// Mantenha-o neste caminho.

class UserPermissions {
  final Map<String, bool> roles;

  UserPermissions(this.roles);

  /// MÉTODO ATUALIZADO para lidar com mapas aninhados de permissões.
  factory UserPermissions.fromMap(Map<String, dynamic> data) {
    final rolesMap = <String, bool>{};

    // Função interna que processa o mapa de permissões recursivamente
    void flattenPermissions(Map<String, dynamic> map) {
      map.forEach((key, value) {
        if (value is bool && value == true) {
          rolesMap[key] = true;
        } else if (value is Map<String, dynamic>) {
          // Se o valor for outro mapa, chama a função para ele também
          flattenPermissions(value);
        }
      });
    }

    flattenPermissions(data);
    return UserPermissions(rolesMap);
  }

  bool get isAdmin => roles['admin'] ?? false;

  bool hasRole(String roleName) {
    // Se o usuário for admin, ele sempre terá acesso
    if (isAdmin) return true;
    return roles[roleName] ?? false;
  }

  bool get hasAnyRole => roles.isNotEmpty;
}