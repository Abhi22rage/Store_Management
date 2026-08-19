import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_store/src/core/services/api_service.dart';
import 'package:smart_store/src/core/services/data_repository.dart';
import 'package:smart_store/src/core/services/branch_service.dart';
import 'purchase_event.dart';
import 'purchase_state.dart';

class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  final ApiService _apiService = ApiService();
  final DataRepository _repository = DataRepository();

  PurchaseBloc() : super(const PurchaseState()) {
    on<FetchPurchases>(_onFetchPurchases);
    on<FetchSuppliers>(_onFetchSuppliers);
    on<AddPurchaseOrder>(_onAddPurchase);
    on<AddSupplier>(_onAddSupplier);

    BranchService().addListener(_onBranchChanged);
  }

  void _onBranchChanged() {
    final branch = BranchService().currentBranch;
    add(FetchPurchases(branch: branch));
  }

  @override
  Future<void> close() {
    BranchService().removeListener(_onBranchChanged);
    return super.close();
  }

  Future<void> _onFetchPurchases(
    FetchPurchases event,
    Emitter<PurchaseState> emit,
  ) async {
    if (state.purchases.isEmpty) {
      emit(state.copyWith(status: PurchaseStatus.loading));
    }
    try {
      final purchases = await _repository.getPurchases(branch: event.branch);
      emit(state.copyWith(
        status: PurchaseStatus.success,
        purchases: purchases,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PurchaseStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onFetchSuppliers(
    FetchSuppliers event,
    Emitter<PurchaseState> emit,
  ) async {
    try {
      final suppliers = await _repository.getSuppliers();
      emit(state.copyWith(suppliers: suppliers));
    } catch (e) {
      // Non-fatal for the main purchase flow, but good to know
    }
  }

  Future<void> _onAddPurchase(
    AddPurchaseOrder event,
    Emitter<PurchaseState> emit,
  ) async {
    emit(state.copyWith(status: PurchaseStatus.loading));
    try {
      await _apiService.createPurchase(
        event.purchase,
        branch: event.branch,
        billFile: event.billFile,
      );
      add(FetchPurchases(branch: event.branch)); // Refresh list
    } catch (e) {
      emit(state.copyWith(
        status: PurchaseStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAddSupplier(
    AddSupplier event,
    Emitter<PurchaseState> emit,
  ) async {
    try {
      await _apiService.createSupplier(event.supplier, branch: event.branch);
      add(FetchSuppliers(branch: event.branch)); // Refresh list
    } catch (e) {
      emit(state.copyWith(
        status: PurchaseStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
