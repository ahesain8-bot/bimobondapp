/// Returns true when [roles] includes an admin role (case-insensitive).
bool userHasAdminRole(List<String>? roles) {
  if (roles == null || roles.isEmpty) return false;
  return roles.any((role) {
    final normalized = role.trim().toUpperCase();
    return normalized == 'ADMIN' || normalized == 'ROLE_ADMIN';
  });
}
