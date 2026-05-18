DateTime bondClaimDeadline(int slashedAt, int claimWindowDays) {
  return DateTime.fromMillisecondsSinceEpoch(
    (slashedAt + claimWindowDays * 86400) * 1000,
    isUtc: true,
  ).toLocal();
}

bool isBondClaimExpired(int slashedAt, int claimWindowDays) {
  return DateTime.now().isAfter(bondClaimDeadline(slashedAt, claimWindowDays));
}
