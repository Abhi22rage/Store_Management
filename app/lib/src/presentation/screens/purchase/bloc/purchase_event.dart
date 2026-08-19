import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class PurchaseEvent extends Equatable {
  const PurchaseEvent();

  @override
  List<Object?> get props => [];
}

class FetchPurchases extends PurchaseEvent {
  final String? branch;
  const FetchPurchases({this.branch});

  @override
  List<Object?> get props => [branch];
}

class FetchSuppliers extends PurchaseEvent {
  final String? branch;
  const FetchSuppliers({this.branch});

  @override
  List<Object?> get props => [branch];
}

class AddPurchaseOrder extends PurchaseEvent {
  final Map<String, dynamic> purchase;
  final String? branch;
  final XFile? billFile;

  const AddPurchaseOrder({required this.purchase, this.branch, this.billFile});

  @override
  List<Object?> get props => [purchase, branch, billFile];
}

class AddSupplier extends PurchaseEvent {
  final Map<String, dynamic> supplier;
  final String? branch;

  const AddSupplier({required this.supplier, this.branch});

  @override
  List<Object?> get props => [supplier, branch];
}
