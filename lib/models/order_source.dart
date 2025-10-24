class OrderSource {
  final String id;
  final String name;
  final String iconPath; // Path to icon asset or url
  final OrderSourceType type;
  final double commissionRate; // Percentage (0-100)
  final bool requiresCommissionInput;
  final CommissionInputType commissionInputType; // before_fee or after_fee
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderSource({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.type,
    this.commissionRate = 0,
    this.requiresCommissionInput = false,
    this.commissionInputType = CommissionInputType.afterFee,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Calculate amount after fee from amount before fee
  double calculateAmountAfterFee(double amountBeforeFee) {
    if (commissionRate == 0) return amountBeforeFee;
    return amountBeforeFee * (1 - commissionRate / 100);
  }

  // Calculate amount before fee from amount after fee
  double calculateAmountBeforeFee(double amountAfterFee) {
    if (commissionRate == 0) return amountAfterFee;
    return amountAfterFee / (1 - commissionRate / 100);
  }

  // Calculate commission fee
  double calculateCommissionFee(double amount, {bool isBeforeFee = true}) {
    if (commissionRate == 0) return 0;

    if (isBeforeFee) {
      return amount * (commissionRate / 100);
    } else {
      // If amount is after fee, calculate what the before fee amount was
      final beforeFee = calculateAmountBeforeFee(amount);
      return beforeFee - amount;
    }
  }

  OrderSource copyWith({
    String? id,
    String? name,
    String? iconPath,
    OrderSourceType? type,
    double? commissionRate,
    bool? requiresCommissionInput,
    CommissionInputType? commissionInputType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderSource(
      id: id ?? this.id,
      name: name ?? this.name,
      iconPath: iconPath ?? this.iconPath,
      type: type ?? this.type,
      commissionRate: commissionRate ?? this.commissionRate,
      requiresCommissionInput: requiresCommissionInput ?? this.requiresCommissionInput,
      commissionInputType: commissionInputType ?? this.commissionInputType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_path': iconPath,
      'type': type.value,
      'commission_rate': commissionRate,
      'requires_commission_input': requiresCommissionInput ? 1 : 0,
      'commission_input_type': commissionInputType.value,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory OrderSource.fromMap(Map<String, dynamic> map) {
    return OrderSource(
      id: map['id'].toString(),
      name: map['name'] as String,
      iconPath: map['icon_path'] as String,
      type: OrderSourceType.fromString(map['type'] as String),
      commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0,
      requiresCommissionInput: (map['requires_commission_input'] as int?) == 1,
      commissionInputType: CommissionInputType.fromString(
        map['commission_input_type'] as String? ?? 'after_fee',
      ),
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  // Default order sources
  static List<OrderSource> getDefaultSources() {
    final now = DateTime.now();
    return [
      OrderSource(
        id: '1',
        name: 'On site',
        iconPath: 'onsite',
        type: OrderSourceType.onsite,
        commissionRate: 0,
        requiresCommissionInput: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      OrderSource(
        id: '2',
        name: 'Takeaway',
        iconPath: 'takeaway',
        type: OrderSourceType.takeaway,
        commissionRate: 0,
        requiresCommissionInput: false,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      OrderSource(
        id: '3',
        name: 'Shopee',
        iconPath: 'shopee',
        type: OrderSourceType.delivery,
        commissionRate: 29,
        requiresCommissionInput: true,
        commissionInputType: CommissionInputType.afterFee,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      OrderSource(
        id: '4',
        name: 'Grab food',
        iconPath: 'grabfood',
        type: OrderSourceType.delivery,
        commissionRate: 25,
        requiresCommissionInput: true,
        commissionInputType: CommissionInputType.beforeFee,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

enum OrderSourceType {
  onsite('ONSITE'),
  takeaway('TAKEAWAY'),
  delivery('DELIVERY');

  const OrderSourceType(this.value);
  final String value;

  static OrderSourceType fromString(String value) {
    return OrderSourceType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => OrderSourceType.onsite,
    );
  }
}

enum CommissionInputType {
  beforeFee('before_fee'),
  afterFee('after_fee');

  const CommissionInputType(this.value);
  final String value;

  static CommissionInputType fromString(String value) {
    return CommissionInputType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => CommissionInputType.afterFee,
    );
  }
}
