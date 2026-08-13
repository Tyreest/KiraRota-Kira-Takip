import '../models/calculation.dart';

enum RentalRole {
  tenant,
  landlord;

  String get labelTr => switch (this) {
    RentalRole.tenant => 'Kiracı',
    RentalRole.landlord => 'Ev sahibi',
  };

  static RentalRole fromJson(String? raw) {
    return raw == 'landlord' ? RentalRole.landlord : RentalRole.tenant;
  }

  String toJson() => name;
}

/// Bir kira kaydına bağlı, sonradan değişmeyen hesaplama anlık görüntüsü.
class RentalCalculationSnapshot {
  const RentalCalculationSnapshot({
    required this.id,
    required this.calculatedAt,
    required this.oldRent,
    required this.calculatedRent,
    required this.tufeRatePercent,
    required this.applicableRatePercent,
    required this.tufeReferenceMonth,
    required this.increaseDate,
    this.contractRatePercent,
    this.isFiveYearsOrMore = false,
    this.requestedRent,
  });

  final String id;
  final DateTime calculatedAt;
  final double oldRent;
  final double calculatedRent;
  final double tufeRatePercent;
  final double applicableRatePercent;
  final String tufeReferenceMonth; // YYYY-MM
  final DateTime increaseDate;
  final double? contractRatePercent;
  final bool isFiveYearsOrMore;
  final double? requestedRent;

  factory RentalCalculationSnapshot.fromResult(
    CalculationResult r, {
    double? requestedRent,
  }) {
    return RentalCalculationSnapshot(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      calculatedAt: DateTime.now(),
      oldRent: r.input.currentRent,
      calculatedRent: r.calculatedRent,
      tufeRatePercent: r.tufeMaxRatePercent,
      applicableRatePercent: r.applicableRatePercent,
      tufeReferenceMonth: r.input.renewalMonthKey,
      increaseDate: r.input.renewalDate,
      contractRatePercent: r.input.contractIncreasePercent,
      isFiveYearsOrMore: r.isFiveYearsOrMore,
      requestedRent: requestedRent,
    );
  }

  factory RentalCalculationSnapshot.fromJson(Map<String, dynamic> json) {
    return RentalCalculationSnapshot(
      id: json['id'] as String,
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
      oldRent: (json['oldRent'] as num).toDouble(),
      calculatedRent: (json['calculatedRent'] as num).toDouble(),
      tufeRatePercent: (json['tufeRatePercent'] as num).toDouble(),
      applicableRatePercent:
          (json['applicableRatePercent'] as num?)?.toDouble() ??
          (json['tufeRatePercent'] as num).toDouble(),
      tufeReferenceMonth: json['tufeReferenceMonth'] as String,
      increaseDate: DateTime.parse(json['increaseDate'] as String),
      contractRatePercent: (json['contractRatePercent'] as num?)?.toDouble(),
      isFiveYearsOrMore: json['isFiveYearsOrMore'] as bool? ?? false,
      requestedRent: (json['requestedRent'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'calculatedAt': calculatedAt.toIso8601String(),
    'oldRent': oldRent,
    'calculatedRent': calculatedRent,
    'tufeRatePercent': tufeRatePercent,
    'applicableRatePercent': applicableRatePercent,
    'tufeReferenceMonth': tufeReferenceMonth,
    'increaseDate': increaseDate.toIso8601String(),
    'contractRatePercent': contractRatePercent,
    'isFiveYearsOrMore': isFiveYearsOrMore,
    if (requestedRent != null) 'requestedRent': requestedRent,
  };

  /// Kaydedilmiş snapshot’tan PDF için [CalculationResult] — yeniden hesaplama yok.
  CalculationResult toPdfCalculationResult({
    required DateTime contractStartDate,
  }) {
    final parts = tufeReferenceMonth.split('-');
    final year = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final month = parts.length == 2 ? int.tryParse(parts[1]) : null;
    final renewalYear = year ?? increaseDate.year;
    final renewalMonth = month ?? increaseDate.month;

    ContractCompareKind compare = ContractCompareKind.none;
    final contract = contractRatePercent;
    if (contract != null) {
      if (contract < tufeRatePercent) {
        compare = ContractCompareKind.contractLower;
      } else if (contract > tufeRatePercent) {
        compare = ContractCompareKind.contractHigher;
      } else {
        compare = ContractCompareKind.contractEqual;
      }
    }

    return CalculationResult(
      input: CalculationInput(
        currentRent: oldRent,
        renewalYear: renewalYear,
        renewalMonth: renewalMonth,
        renewalDay: increaseDate.day.clamp(1, 31),
        contractStart: contractStartDate,
        contractIncreasePercent: contractRatePercent,
      ),
      tufeMaxRatePercent: tufeRatePercent,
      applicableRatePercent: applicableRatePercent,
      calculatedRent: calculatedRent,
      increaseAmount: calculatedRent - oldRent,
      contractCompare: compare,
      isFiveYearsOrMore: isFiveYearsOrMore,
      tuikReleaseDate: calculatedAt,
      datasetUpdatedAt: calculatedAt,
      rateSourceLabel: 'Kayıtlı hesaplama',
    );
  }
}

class RentalReminderPrefs {
  const RentalReminderPrefs({
    this.enabled = false,
    this.notify30 = true,
    this.notify7 = true,
    this.notify0 = true,
  });

  final bool enabled;
  final bool notify30;
  final bool notify7;
  final bool notify0;

  factory RentalReminderPrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RentalReminderPrefs();
    return RentalReminderPrefs(
      enabled: json['enabled'] as bool? ?? false,
      notify30: json['notify30'] as bool? ?? true,
      notify7: json['notify7'] as bool? ?? true,
      notify0: json['notify0'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'notify30': notify30,
    'notify7': notify7,
    'notify0': notify0,
  };

  RentalReminderPrefs copyWith({
    bool? enabled,
    bool? notify30,
    bool? notify7,
    bool? notify0,
  }) {
    return RentalReminderPrefs(
      enabled: enabled ?? this.enabled,
      notify30: notify30 ?? this.notify30,
      notify7: notify7 ?? this.notify7,
      notify0: notify0 ?? this.notify0,
    );
  }
}

class Rental {
  Rental({
    required this.id,
    required this.role,
    required this.displayName,
    required this.currentRent,
    required this.contractStartDate,
    required this.increaseDate,
    required this.createdAt,
    required this.updatedAt,
    this.contractIncreaseRate,
    this.tenantName,
    this.ownerName,
    this.address,
    this.notes,
    this.reminder = const RentalReminderPrefs(),
    List<RentalCalculationSnapshot>? history,
  }) : history = List.unmodifiable(history ?? const []);

  final String id;
  final RentalRole role;

  /// Taşınmaz adı (UI: propertyName). Eski şemada `displayName`.
  final String displayName;
  final double currentRent;
  final DateTime contractStartDate;

  /// Yenileme / artış tarihi.
  final DateTime increaseDate;
  final double? contractIncreaseRate;
  final String? tenantName;
  final String? ownerName;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RentalReminderPrefs reminder;
  final List<RentalCalculationSnapshot> history;

  /// Stitch / ürün dili: taşınmaz adı.
  String get propertyName => displayName;

  DateTime get renewalDate => increaseDate;

  RentalCalculationSnapshot? get latestCalculation =>
      history.isEmpty ? null : history.first;

  factory Rental.fromJson(Map<String, dynamic> json) {
    final hist =
        (json['history'] as List<dynamic>? ?? [])
            .map(
              (e) =>
                  RentalCalculationSnapshot.fromJson(e as Map<String, dynamic>),
            )
            .toList()
          ..sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));

    // v1 uyumluluk: displayName veya propertyName
    final name = (json['propertyName'] as String?)?.trim().isNotEmpty == true
        ? (json['propertyName'] as String).trim()
        : (json['displayName'] as String? ?? '').trim();

    return Rental(
      id: json['id'] as String,
      role: RentalRole.fromJson(json['role'] as String?),
      displayName: name.isEmpty ? 'Adsız taşınmaz' : name,
      currentRent: (json['currentRent'] as num).toDouble(),
      contractStartDate: DateTime.parse(json['contractStartDate'] as String),
      increaseDate: DateTime.parse(
        (json['renewalDate'] as String?) ?? (json['increaseDate'] as String),
      ),
      contractIncreaseRate: (json['contractIncreaseRate'] as num?)?.toDouble(),
      tenantName: (json['tenantName'] as String?)?.trim(),
      ownerName: (json['ownerName'] as String?)?.trim(),
      address: (json['address'] as String?)?.trim(),
      notes: (json['notes'] as String?)?.trim(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      reminder: RentalReminderPrefs.fromJson(
        json['reminder'] as Map<String, dynamic>?,
      ),
      history: hist,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.toJson(),
    'displayName': displayName,
    'propertyName': displayName,
    'currentRent': currentRent,
    'contractStartDate': contractStartDate.toIso8601String(),
    'increaseDate': increaseDate.toIso8601String(),
    'renewalDate': increaseDate.toIso8601String(),
    'contractIncreaseRate': contractIncreaseRate,
    if (tenantName != null && tenantName!.isNotEmpty) 'tenantName': tenantName,
    if (ownerName != null && ownerName!.isNotEmpty) 'ownerName': ownerName,
    if (address != null && address!.isNotEmpty) 'address': address,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reminder': reminder.toJson(),
    'history': history.map((e) => e.toJson()).toList(),
  };

  Rental copyWith({
    RentalRole? role,
    String? displayName,
    double? currentRent,
    DateTime? contractStartDate,
    DateTime? increaseDate,
    double? contractIncreaseRate,
    bool clearContractIncreaseRate = false,
    String? tenantName,
    bool clearTenantName = false,
    String? ownerName,
    bool clearOwnerName = false,
    String? address,
    bool clearAddress = false,
    String? notes,
    bool clearNotes = false,
    DateTime? updatedAt,
    RentalReminderPrefs? reminder,
    List<RentalCalculationSnapshot>? history,
  }) {
    return Rental(
      id: id,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      currentRent: currentRent ?? this.currentRent,
      contractStartDate: contractStartDate ?? this.contractStartDate,
      increaseDate: increaseDate ?? this.increaseDate,
      contractIncreaseRate: clearContractIncreaseRate
          ? null
          : (contractIncreaseRate ?? this.contractIncreaseRate),
      tenantName: clearTenantName ? null : (tenantName ?? this.tenantName),
      ownerName: clearOwnerName ? null : (ownerName ?? this.ownerName),
      address: clearAddress ? null : (address ?? this.address),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminder: reminder ?? this.reminder,
      history: history ?? this.history,
    );
  }
}

/// Artış dönemi sonrası bir sonraki yıl dönümü (güvenli gün taşması).
DateTime nextIncreaseAnniversary(DateTime current) {
  final next = DateTime(current.year + 1, current.month, current.day);
  if (next.month != current.month) {
    return DateTime(current.year + 1, current.month + 1, 0);
  }
  return next;
}

/// Yenilemeye kalan gün (geçmişse negatif).
int daysUntilRenewal(DateTime renewal, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(renewal.year, renewal.month, renewal.day);
  return day.difference(today).inDays;
}
