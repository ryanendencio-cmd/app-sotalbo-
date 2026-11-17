double? projectExpenseLimit(Map<String, dynamic> project) {
  final limits = <double>[];
  for (final key in const [
    'budget',
    'contract_amount',
    'contractAmount',
    'contract',
  ]) {
    final value = project[key];
    if (value == null || value.toString().trim().isEmpty) continue;
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());
    if (amount != null && amount.isFinite && amount >= 0) {
      limits.add(amount);
    }
  }
  if (limits.isEmpty) return null;
  return limits.reduce((left, right) => left < right ? left : right);
}

double? remainingProjectBudget(Map<String, dynamic> project, double spent) {
  final limit = projectExpenseLimit(project);
  return limit == null ? null : limit - spent;
}

String normalizedProjectStatus(dynamic status) {
  final value = status?.toString().trim().toUpperCase() ?? '';
  if (value.isEmpty || value == 'ACTIVE') return 'ONGOING';
  if (value == 'STANDBY') return 'UPCOMING';
  return value;
}

bool countsAsActiveProject(dynamic status) {
  final value = normalizedProjectStatus(status);
  return value == 'ONGOING' || value == 'UPCOMING';
}

String projectStatusLabel(dynamic status) {
  switch (normalizedProjectStatus(status)) {
    case 'ONGOING':
      return 'Ongoing';
    case 'UPCOMING':
      return 'Upcoming';
    case 'COMPLETED':
      return 'Completed';
    case 'ON HOLD':
      return 'On Hold';
    default:
      final value = status?.toString().trim() ?? '';
      return value.isEmpty ? 'Ongoing' : value;
  }
}
