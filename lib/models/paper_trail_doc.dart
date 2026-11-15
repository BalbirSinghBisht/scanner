class PaperTrailDoc {
  final String id;
  final String localId;
  final String title;
  final String category;
  final DateTime purchaseDate;
  final DateTime? warrantyExpiryDate;
  final double? amount;
  final String currency;
  final String? storeName;
  final String? notes;
  final DateTime createdAt;

  const PaperTrailDoc({
    required this.id,
    required this.localId,
    required this.title,
    required this.category,
    required this.purchaseDate,
    this.warrantyExpiryDate,
    this.amount,
    this.currency = '\$',
    this.storeName,
    this.notes,
    required this.createdAt,
  });

  bool get hasWarranty => warrantyExpiryDate != null;

  bool get isWarrantyExpired {
    if (warrantyExpiryDate == null) return false;
    return DateTime.now().isAfter(warrantyExpiryDate!);
  }

  int get daysRemaining {
    if (warrantyExpiryDate == null) return 0;
    return warrantyExpiryDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpiringSoon {
    if (warrantyExpiryDate == null) return false;
    final days = daysRemaining;
    return days >= 0 && days <= 30;
  }

  String get formattedWarrantyStatus {
    if (warrantyExpiryDate == null) return 'No Warranty Set';
    if (isWarrantyExpired) {
      final days = -daysRemaining;
      return days <= 1 ? 'Expired yesterday' : 'Expired $days days ago';
    }
    final days = daysRemaining;
    if (days == 0) return 'Expires today!';
    if (days == 1) return 'Expires tomorrow!';
    if (days <= 30) return '$days days remaining (Expiring soon)';
    if (days < 365) return '$days days remaining';
    final years = (days / 365).toStringAsFixed(1);
    return '$years years remaining ($days days)';
  }

  String get formattedAmount {
    if (amount == null) return '';
    return '$currency${amount!.toStringAsFixed(2)}';
  }

  PaperTrailDoc copyWith({
    String? id,
    String? localId,
    String? title,
    String? category,
    DateTime? purchaseDate,
    DateTime? warrantyExpiryDate,
    double? amount,
    String? currency,
    String? storeName,
    String? notes,
    DateTime? createdAt,
  }) {
    return PaperTrailDoc(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      title: title ?? this.title,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyExpiryDate: warrantyExpiryDate ?? this.warrantyExpiryDate,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      storeName: storeName ?? this.storeName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_id': localId,
      'title': title,
      'category': category,
      'purchase_date': purchaseDate.millisecondsSinceEpoch,
      'warranty_expiry_date': warrantyExpiryDate?.millisecondsSinceEpoch,
      'amount': amount,
      'currency': currency,
      'store_name': storeName,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PaperTrailDoc.fromMap(Map<String, dynamic> map) {
    return PaperTrailDoc(
      id: map['id'] as String,
      localId: map['local_id'] as String,
      title: map['title'] as String,
      category: map['category'] as String? ?? 'Receipts',
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(map['purchase_date'] as int),
      warrantyExpiryDate: map['warranty_expiry_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['warranty_expiry_date'] as int)
          : null,
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : null,
      currency: map['currency'] as String? ?? '\$',
      storeName: map['store_name'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

