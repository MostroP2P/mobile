import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/repositories/dispute_repository.dart';

/// Stub service for disputes - UI only implementation
class DisputeService {
  static final DisputeService _instance = DisputeService._internal();
  factory DisputeService() => _instance;
  DisputeService._internal();

  final DisputeRepository _disputeRepository = DisputeRepository();

  Future<List<Dispute>> getUserDisputes() async {
    return await _disputeRepository.getUserDisputes();
  }

  Future<Dispute?> getDispute(String disputeId) async {
    return await _disputeRepository.getDispute(disputeId);
  }

  Future<void> sendDisputeMessage(String disputeId, String message) async {
    await _disputeRepository.sendDisputeMessage(disputeId, message);
  }

  Future<void> initiateDispute(String orderId, String reason) async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 500));
  }
}