import '../domain/branch_detail.dart';
import '../infrastructure/branches_api.dart';

class BranchDetailController {
  BranchDetailController(this._branchesApi);

  final BranchesApi _branchesApi;

  Future<BranchDetailPayload> load({required String branchId}) {
    return _branchesApi.fetchBranchDetail(branchId: branchId);
  }
}
