import 'package:equatable/equatable.dart';

enum PurchaseStatus { initial, loading, success, failure }

class PurchaseState extends Equatable {
  final PurchaseStatus status;
  final List<dynamic> purchases;
  final List<dynamic> suppliers;
  final String? errorMessage;

  const PurchaseState({
    this.status = PurchaseStatus.initial,
    this.purchases = const [],
    this.suppliers = const [],
    this.errorMessage,
  });

  PurchaseState copyWith({
    PurchaseStatus? status,
    List<dynamic>? purchases,
    List<dynamic>? suppliers,
    String? errorMessage,
  }) {
    return PurchaseState(
      status: status ?? this.status,
      purchases: purchases ?? this.purchases,
      suppliers: suppliers ?? this.suppliers,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, purchases, suppliers, errorMessage];
}
