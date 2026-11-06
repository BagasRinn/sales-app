library;

class BranchCode {
  static const String banjarmasin = 'BANJARMASIN';
  static const String batulicin = 'BATULICIN';
  static const String barabai = 'BARABAI';
  static const String palangkaraya = 'PALANGKARAYA';
  static const String sampit = 'SAMPIT';

  static const List<String> all = [
    banjarmasin,
    batulicin,
    barabai,
    palangkaraya,
    sampit,
  ];

  static bool isValid(String? code) {
    if (code == null) return false;
    return all.contains(code.toUpperCase());
  }

  static String? normalize(String? code) {
    if (code == null) return null;
    final upper = code.toUpperCase();
    return isValid(upper) ? upper : null;
  }
}

class BranchLabel {
  static const Map<String, String> labels = {
    'BANJARMASIN': 'Cabang Banjarmasin',
    'BATULICIN': 'Cabang Batulicin',
    'BARABAI': 'Cabang Barabai',
    'PALANGKARAYA': 'Cabang Palangkaraya',
    'SAMPIT': 'Cabang Sampit',
  };

  static String? display(String? code) {
    if (code == null) return null;
    return labels[code] ?? code;
  }
}

class RoleLabel {
  static const Map<String, String> labels = {
    'ADMIN': 'Admin',
    'SUPERVISOR': 'Supervisor',
    'MANAGER': 'Manager',
    'SALES': 'Sales',
  };

  static String? display(String? role) {
    if (role == null) return null;
    return labels[role.toUpperCase()] ?? role;
  }
}
