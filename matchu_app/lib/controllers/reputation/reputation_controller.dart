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
  final RxList<ReputationHistoryItem> historyItems =
      <ReputationHistoryItem>[].obs;
  final isLoadingHistory = false.obs;
  final RxnString historyErrorMessage = RxnString();

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
      final gemAwarded = response.claim.gemAwarded;
      final title =
          awarded > 0 || gemAwarded > 0
              ? "Nhận thưởng thành công"
              : "Đã xử lý claim";
      final message = _reasonMessage(reason, awarded, gemAwarded);
      Get.snackbar(title, message, snackPosition: SnackPosition.TOP);
    } catch (error) {
      final message = _toDisplayError(error);
      errorMessage.value = message;
      Get.snackbar(
        "Không thể nhận điểm",
        message,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isClaimingTaskId.value = null;
    }
  }

  Future<void> loadHistory({bool force = false}) async {
    if (isLoadingHistory.value) return;
    if (!force && historyItems.isNotEmpty) return;

    isLoadingHistory.value = true;
    historyErrorMessage.value = null;

    try {
      final response = await _service.getHistory();
      historyItems.assignAll(response.items);
    } catch (error) {
      historyErrorMessage.value = _toDisplayError(error);
    } finally {
      isLoadingHistory.value = false;
    }
  }

  String _reasonMessage(String reason, int awarded, int gemAwarded) {
    switch (reason) {
      case "claimed":
        return "Bạn vừa nhận +$awarded điểm uy tín.";
      case "claimed_as_gem":
        return "Uy tín đã đạt 100. Bạn vừa nhận +$gemAwarded gem.";
      case "claimed_with_gem_conversion":
        return "Bạn vừa nhận +$awarded uy tín và +$gemAwarded gem.";
      case "daily_cap_reached":
        return "Hôm nay đã hết giới hạn nhận điểm.";
      case "reputation_max_reached":
        return "Tài khoản này đã đạt 100 uy tín.";
      case "already_claimed":
        return "Nhiệm vụ này đã được nhận điểm";
      case "not_completed":
        return "Nhiệm vụ này chưa hoàn thành";
      case "claim_request_replayed":
        return "Yêu cầu claim bị lặp, đã bỏ qua.";
      default:
        return "Đã cập nhật trạng thái nhiệm vụ.";
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
