import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'trust_seal.dart';

class MatchCard extends StatelessWidget {
  final MatchResult match;
  final int rank;
  final bool hired;
  final VoidCallback onHire;
  const MatchCard({
    super.key,
    required this.match,
    required this.rank,
    required this.hired,
    required this.onHire,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            TrustSeal(level: VerificationLevels.levelOf(match.verification)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$rank. ${match.fullName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    '${match.distanceKm} km · ★ ${match.ratingAvg} · '
                    '${match.jobsCompleted} jobs'
                    '${match.dailyRate != null ? ' · ${zmw(match.dailyRate!)}/day' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: WL.inkSoft),
                  ),
                  Text('${match.score.round()} match points',
                      style: const TextStyle(
                          fontSize: 12,
                          color: WL.copper,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            hired
                ? const Text('✓ Hired',
                    style: TextStyle(
                        color: WL.green, fontWeight: FontWeight.w700))
                : OutlinedButton(onPressed: onHire, child: const Text('Hire')),
          ],
        ),
      ),
    );
  }
}
