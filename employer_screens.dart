import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/worker_card.dart';
import 'chat_screen.dart';

// ─────────────────────────────────────── EMPLOYER HOME ──
class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});
  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  final _jobs = JobService();
  List<Job> _myJobs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jobs = await _jobs.myOpenJobs();
    if (mounted) setState(() => _myJobs = jobs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkLink — Employer'),
        actions: [
          IconButton(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: WL.copper,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PostJobScreen()));
          _load();
        },
        label: const Text('Post a job'),
        icon: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Your jobs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_myJobs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No jobs yet. Post one and the matching engine will rank '
                  'verified workers near your site.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: WL.inkSoft),
                ),
              ),
            for (final job in _myJobs)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(job.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${job.town} · ${job.durationDays} day(s) · '
                      '${zmw(job.budget)} · ${job.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => JobManageScreen(job: job))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── POST JOB ──
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});
  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _jobs = JobService();
  final _worker = WorkerService();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  List<Skill> _catalogue = [];
  int? _skillId;
  int _workers = 1;
  int _days = 1;
  double _budget = 3000;
  String _town = 'Lusaka';
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _worker.skillsCatalogue().then((s) => setState(() {
          _catalogue = s;
          _skillId = s.isNotEmpty ? s.first.id : null;
        }));
  }

  Future<void> _submit() async {
    if (_skillId == null || _title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {}
      final job = await _jobs.postJob(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        skillId: _skillId!,
        workersNeeded: _workers,
        town: _town,
        lat: pos?.latitude ?? -15.4167, // Lusaka fallback
        lng: pos?.longitude ?? 28.2833,
        startDate: _start,
        durationDays: _days,
        budgetZmw: _budget,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => MatchesScreen(job: job)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Job title',
                  hintText: 'e.g. Need 4 bricklayers')),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _skillId,
            items: _catalogue
                .map((s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _skillId = v),
            decoration: const InputDecoration(labelText: 'Skill required'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _Stepper(
                  label: 'Workers',
                  value: _workers,
                  onChanged: (v) => setState(() => _workers = v)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stepper(
                  label: 'Days',
                  value: _days,
                  onChanged: (v) => setState(() => _days = v)),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _town,
            items: const ['Lusaka', 'Kitwe', 'Ndola', 'Livingstone', 'Chipata']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _town = v!),
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 16),
          Text('Budget — ${zmw(_budget)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _budget,
            min: 500,
            max: 20000,
            divisions: 195,
            activeColor: WL.copper,
            onChanged: (v) => setState(() => _budget = v),
          ),
          TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Notes (site details, tools provided…)')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Posting…' : 'Find matching workers'),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove)),
          Text('$value', style: const TextStyle(fontSize: 16)),
          IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────── MATCHES ──
class MatchesScreen extends StatefulWidget {
  final Job job;
  const MatchesScreen({super.key, required this.job});
  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _jobs = JobService();
  List<MatchResult> _matches = [];
  final Set<String> _hired = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _jobs.matchWorkers(widget.job.id).then((m) {
      if (mounted) setState(() { _matches = m; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.job.title)),
      bottomNavigationBar: _hired.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: WL.copper),
                  onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => JobManageScreen(job: widget.job))),
                  child: Text('Continue with ${_hired.length} hired →'),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Ranked by the matching engine: skills, distance, rating, '
                  'availability, verification, repeat hires, price fit and '
                  'response speed.',
                  style: TextStyle(fontSize: 12.5, color: WL.inkSoft),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _matches.length; i++)
                  MatchCard(
                    match: _matches[i],
                    rank: i + 1,
                    hired: _hired.contains(_matches[i].workerId),
                    onHire: () async {
                      await _jobs.inviteWorker(widget.job.id,
                          _matches[i].workerId, _matches[i].score);
                      setState(() => _hired.add(_matches[i].workerId));
                    },
                  ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────── JOB MANAGE ──
class JobManageScreen extends StatefulWidget {
  final Job job;
  const JobManageScreen({super.key, required this.job});
  @override
  State<JobManageScreen> createState() => _JobManageScreenState();
}

class _JobManageScreenState extends State<JobManageScreen> {
  final _jobs = JobService();
  final _pay = PaymentService();
  final _chat = ChatService();
  List<JobApplication> _apps = [];
  EscrowTransaction? _escrow;
  String _provider = 'mtn_momo';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await _jobs.applicationsFor(widget.job.id);
    final escrow = await _pay.forJob(widget.job.id);
    if (mounted) setState(() { _apps = apps; _escrow = escrow; });
  }

  Future<void> _openChat() async {
    final members = [
      db.auth.currentUser!.id,
      ..._apps.map((a) => a.workerId)
    ];
    final convId =
        await _chat.conversationForJob(widget.job.id, members);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: convId)));
  }

  Future<void> _rate(JobApplication app) async {
    final stars = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Rate this worker'),
        children: [
          for (var s = 5; s >= 1; s--)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text('${'★' * s}${'☆' * (5 - s)}'),
            ),
        ],
      ),
    );
    if (stars != null) {
      await _jobs.rate(
          jobId: widget.job.id, rateeId: app.workerId, stars: stars);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Saved to the worker's Digital Work Passport")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final funded = _escrow?.status == 'funded';
    final released = _escrow?.status == 'released';
    final allComplete = _apps.isNotEmpty &&
        _apps.every(
            (a) => a.workerMarkedComplete && a.employerConfirmedComplete);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.title),
        actions: [
          IconButton(
              onPressed: _apps.isEmpty ? null : _openChat,
              icon: const Icon(Icons.chat_bubble_outline)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('Hired team (${_apps.length})'),
            for (final a in _apps)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text('Worker ${a.workerId.substring(0, 8)}…'),
                  subtitle: Text(a.workerMarkedComplete
                      ? (a.employerConfirmedComplete
                          ? 'Complete ✓'
                          : 'Worker marked complete — confirm?')
                      : 'In progress'),
                  trailing: released
                      ? TextButton(
                          onPressed: () => _rate(a),
                          child: const Text('Rate'))
                      : (a.workerMarkedComplete &&
                              !a.employerConfirmedComplete
                          ? TextButton(
                              onPressed: () async {
                                await _jobs.markComplete(a.id,
                                    asWorker: false);
                                _load();
                              },
                              child: const Text('Confirm'))
                          : null),
                ),
              ),
            const SizedBox(height: 16),
            _SectionLabel('Escrow payment'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_escrow == null) ...[
                      Text(
                        'Fund ${zmw(widget.job.budget)} into escrow. It is '
                        'released only when both sides confirm completion.',
                        style: const TextStyle(
                            fontSize: 13.5, color: WL.inkSoft),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        children: PayProviders.values.entries
                            .map((e) => ChoiceChip(
                                  label: Text(e.value),
                                  selected: _provider == e.key,
                                  onSelected: (_) =>
                                      setState(() => _provider = e.key),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: WL.copper),
                        onPressed: _apps.isEmpty
                            ? null
                            : () async {
                                await _pay.fundEscrow(
                                    jobId: widget.job.id,
                                    amount: widget.job.budget,
                                    provider: _provider);
                                _load();
                              },
                        child: Text(
                            'Fund escrow — ${zmw(widget.job.budget)}'),
                      ),
                    ] else if (funded) ...[
                      Text('● Held in escrow — ${zmw(_escrow!.amount)}',
                          style: const TextStyle(
                              color: WL.copper,
                              fontWeight: FontWeight.w700)),
                      if (allComplete) ...[
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            await _pay.releaseEscrow(_escrow!.id);
                            _load();
                          },
                          child: Text(
                              'Release ${zmw(_escrow!.amount)} to workers'),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                              'Waiting for both sides to confirm completion.',
                              style: TextStyle(
                                  fontSize: 12.5, color: WL.inkSoft)),
                        ),
                    ] else if (released)
                      const Text('✓ Released to workers',
                          style: TextStyle(
                              color: WL.green,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
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
