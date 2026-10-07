import 'package:mostro_mobile/features/reputation/reputation_service.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// User-facing text for a [ReputationException.reason].
String reputationErrorText(S s, String reason) {
  switch (reason) {
    case ReputationService.nodeDoesNotExport:
      return s.reputationNodeDoesNotExport;
    case ReputationService.nodeDoesNotImport:
      return s.reputationNodeDoesNotImport;
    case ReputationService.noResponse:
      return s.reputationNoResponse;
    case 'reputation_identity_required':
      return s.reputationIdentityRequired;
    case 'not_eligible_for_reputation_export':
      return s.reputationNotEligible;
    case 'reputation_bound_to_other_identity':
      return s.reputationBoundToOtherIdentity;
    case 'invalid_reputation_rebind':
      return s.reputationInvalidRebind;
    case 'expired_reputation_attestation':
      return s.reputationExpiredAttestation;
    case 'untrusted_reputation_issuer':
      return s.reputationUntrustedIssuer;
    case 'reputation_identity_mismatch':
      return s.reputationIdentityMismatch;
    case 'reputation_already_imported':
      return s.reputationAlreadyImported;
    default:
      return s.reputationInvalidAttestation;
  }
}
