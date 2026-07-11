import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/trust_seal.dart';

// ─────────────────────────────────── WORKER DASHBOARD ──
class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});
  @override
  State<WorkerDashboardScreen> createState() =>
      _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  final _worker = WorkerService();
  final _jobs = JobService();
  WorkerProfile? _me;
  List<Map<String, dynamic>> _invites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _worker.me();
    final invites = await _jobs.myInvitations();
    if (mounted) setState(() { _me = me; _invites = invites; });
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkLink'),
        actions: [
          IconButton(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    TrustSeal(
                        level: VerificationLevels.levelOf(me.verification),
                        size: 52),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.fullName,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text(
                            '${me.town ?? 'Zambia'} · ★ ${me.ratingAvg} '
                            '(${me.ratingCount})',
                            style: const TextStyle(
                                fontSize: 13, color: WL.inkSoft)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _TrustCard(me: me),
                  const SizedBox(height: 18),
                  const _Label('My availability'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: Availability.values.entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value),
                              selected: me.availability == e.key,
                              onSelected: (_) async {
                                await _worker.setAvailability(e.key);
                                _load();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  const _Label('Job invitations'),
                  if (_invites.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'No invitations yet. Staying "Available now" ranks '
                          'you higher in matching.',
                          style: TextStyle(
                              fontSize: 13, color: WL.inkSoft),
                        ),
                      ),
                    ),
                  for (final inv in _invites) _InviteCard(inv, _jobs, _load),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PassportScreen())),
                    child: const Text('Open my Digital Work Passport →'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  final WorkerProfile me;
  const _TrustCard({required this.me});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WL.greenDeep,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TRUST SCORE',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.5)),
          Text('${me.trustScore}/100',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: me.trustScore / 100,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(WL.copper),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${me.jobsCompleted} jobs completed · '
            '${me.trustScore >= 70 ? "Micro-loans unlocked" : "Reach 70 to unlock micro-loans"}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final Map<String, dynamic> inv;
  final JobService jobs;
  final VoidCallback onChanged;
  const _InviteCard(this.inv, this.jobs, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final job = inv['jobs'] as Map<String, dynamic>?;
    final done = inv['worker_marked_complete'] == true;
    final confirmed = inv['employer_confirmed_complete'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job?['title'] ?? 'Job',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
                '${job?['town']} · ${job?['duration_days']} day(s) · '
                'budget ${zmw((job?['budget_zmw'] as num?) ?? 0)}',
                style:
                    const TextStyle(fontSize: 12.5, color: WL.inkSoft)),
            const SizedBox(height: 8),
            if (!done)
              ElevatedButton(
                onPressed: () async {
                  await jobs.markComplete(inv['id'], asWorker: true);
                  onChanged();
                },
                child: const Text('Mark job complete'),
              )
            else
              Text(
                confirmed
                    ? '✓ Complete — payment releases from escrow'
                    : 'Waiting for employer confirmation…',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: confirmed ? WL.green : WL.copper),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── DIGITAL WORK PASSPORT ──
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});
  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  final _worker = WorkerService();
  WorkerProfile? _me;
  List<PassportEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    Future.wait([_worker.me(), _worker.passport()]).then((r) {
      if (mounted) {
        setState(() {
          _me = r[0] as WorkerProfile;
          _entries = r[1] as List<PassportEntry>;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final fmt = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Work Passport')),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Passport cover
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: WL.greenDeep,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: WL.copper, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DIGITAL WORK PASSPORT',
                          style: TextStyle(
                              color: WL.copperLight,
                              fontSize: 10,
                              letterSpacing: 2.5)),
                      const SizedBox(height: 6),
                      Text(me.fullName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                      Text('${me.town ?? ''}, Zambia',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 14),
                      Row(children: [
                        _Stat('JOBS', '${me.jobsCompleted}'),
                        _Stat('RATING', '${me.ratingAvg} ★'),
                        _Stat('TRUST', '${me.trustScore}'),
                      ]),
                      const SizedBox(height: 10),
                      const Text(
                        'Owned by the worker, permanently. Verifiable by any '
                        'employer, bank or insurer.',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _Label('Stamped work history'),
                if (_entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Your first completed, paid job will be stamped here '
                        'forever.',
                        style:
                            TextStyle(fontSize: 13, color: WL.inkSoft),
                      ),
                    ),
                  ),
                for (final e in _entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(e.jobTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(
                          '${e.employerName} · ${e.town ?? ''} · '
                          '${e.durationDays ?? '-'} days · '
                          '${fmt.format(e.completedAt)}'
                          '${e.stars != null ? '\n${'★' * e.stars!}' : ''}'),
                      isThreeLine: e.stars != null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: WL.copper,
                              style: BorderStyle.solid,
                              width: 1.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PAID\n${e.amountPaid != null ? zmw(e.amountPaid!) : '—'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: WL.copper,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 9.5)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: WL.inkSoft,
                fontWeight: FontWeight.w600)),
      );
}
