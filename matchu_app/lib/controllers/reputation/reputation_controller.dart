import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'package:matchu_app/models/reputation_daily_state.dart';
import 'package:matchu_app/services/reputation/reputation_service.dart';

class ReputationController extends GetxController {
  final ReputationService _service;

  ReputationController({ReputationService? service})
    : _service = service ?? ReputationService();

  final Rxn<ReputationDailyState> state = Rxn<ReputationDailyState>();
  final isLoading = false.obs;
  final RxnString isClaimingTaskId = RxnString();
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    refreshState(useTouch: true);
  }

  Future<void> refreshState({bool useTouch = false}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = null;

    try {
      state.value =
          useTouch
              ? await _service.touchDailyLoginTask()
              : await _service.getDailyState();
    } catch (error) {
      errorMessage.value = _toDisplayError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> claimTask(String taskId) async {
    if (isClaimingTaskId.value != null) return;
    isClaimingTaskId.value = taskId;
    errorMessage.value = null;

    try {
      final response = await _service.claimTask(taskId: taskId);
      state.value = response.state;

      final reason = response.claim.reason;
      final awarded = response.claim.awarded;
      final title = awarded > 0 ? "Nhan diem thanh cong" : "Da xu ly claim";
      final message = _reasonMessage(reason, awarded);
      Get.snackbar(title, message, snackPosition: SnackPosition.TOP);
    } catch (error) {
      final message = _toDisplayError(error);
      errorMessage.value = message;
      Get.snackbar(
        "Khong the nhan diem",
        message,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isClaimingTaskId.value = null;
    }
  }

  String _reasonMessage(String reason, int awarded) {
    switch (reason) {
      case "claimed":
        return "Ban vua nhan +$awarded diem uy tin.";
      case "daily_cap_reached":
        return "Hom nay da dat gioi han diem uy tin.";
      case "reputation_max_reached":
        return "Tai khoan da dat 100 diem uy tin.";
      case "already_claimed":
        return "Nhiem vu nay da duoc nhan diem.";
      case "not_completed":
        return "Nhiem vu chua hoan thanh.";
      case "claim_request_replayed":
        return "Yeu cau claim bi lap, da bo qua.";
      default:
        return "Da cap nhat trang thai nhiem vu.";
    }
  }

  String _toDisplayError(Object error) {
    if (error is FirebaseFunctionsException) {
      final code = error.code;
      final message = error.message;
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
      return "Functions error: $code";
    }

    return error.toString();
  }
}
