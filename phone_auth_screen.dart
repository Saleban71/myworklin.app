import 'package:flutter/material.dart';

import '../core/supabase.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/services.dart';

/// PRD §6: registration in under one minute.
/// Step 1: phone → OTP. Step 2: name, role, NRC (workers), skills.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _auth = AuthService();
  final _phone = TextEditingController(text: '+260');
  final _otp = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() { _busy = true; _error = null; });
    try {
      await fn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: WL.ink,
                      fontFamily: 'Archivo'),
                  children: [
                    TextSpan(text: 'Work'),
                    TextSpan(text: 'Link', style: TextStyle(color: WL.copper)),
                  ],
                ),
              ),
              const Text('Trusted work. Secure pay. Your record, forever.',
                  style: TextStyle(color: WL.inkSoft)),
              const SizedBox(height: 36),
              if (!_otpSent) ...[
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await _auth.sendOtp(_phone.text.trim());
                            setState(() => _otpSent = true);
                          }),
                  child: const Text('Send verification code'),
                ),
              ] else ...[
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Code sent to ${_phone.text}'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await _auth.verifyOtp(
                                _phone.text.trim(), _otp.text.trim());
                            if (!mounted) return;
                            Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const OnboardingScreen()));
                          }),
                  child: const Text('Verify and continue'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: const TextStyle(color: WL.red, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _auth = AuthService();
  final _workerSvc = WorkerService();
  final _name = TextEditingController();
  final _nrc = TextEditingController();
  final _rate = TextEditingController();
  String _role = 'worker';
  String _town = 'Lusaka';
  final Set<int> _skills = {};
  List<Skill> _catalogue = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _workerSvc.skillsCatalogue().then((s) => setState(() => _catalogue = s));
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await _auth.createProfile(
        role: _role,
        fullName: _name.text.trim(),
        nrcNumber: _role == 'worker' ? _nrc.text.trim() : null,
        town: _town,
      );
      if (_role == 'worker') {
        await _workerSvc.setSkills(_skills.toList());
        final rate = double.tryParse(_rate.text);
        if (rate != null) await _workerSvc.setRates(daily: rate);
        // Fire-and-forget AI bio generation (PRD: AI Profile Generator)
        _workerSvc.generateAiProfile().catchError((_) => <String, dynamic>{});
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'worker', label: Text('I want work')),
              ButtonSegment(value: 'employer', label: Text('I want to hire')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _town,
            items: const ['Lusaka', 'Kitwe', 'Ndola', 'Livingstone', 'Chipata']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _town = v!),
            decoration: const InputDecoration(labelText: 'Town'),
          ),
          if (_role == 'worker') ...[
            const SizedBox(height: 12),
            TextField(
                controller: _nrc,
                decoration: const InputDecoration(
                    labelText: 'NRC number',
                    helperText:
                        'Verified for your Level 2 trust seal')),
            const SizedBox(height: 12),
            TextField(
                controller: _rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Daily rate (ZMW)')),
            const SizedBox(height: 16),
            const Text('Your skills',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _catalogue
                  .map((s) => FilterChip(
                        label: Text(s.name),
                        selected: _skills.contains(s.id),
                        onSelected: (v) => setState(() =>
                            v ? _skills.add(s.id) : _skills.remove(s.id)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy || _name.text.trim().isEmpty ? null : _finish,
            child: Text(_busy ? 'Saving…' : 'Start using WorkLink'),
          ),
          const SizedBox(height: 12),
          Text(
            'Face verification and references can be added later to raise '
            'your trust level.',
            style: TextStyle(fontSize: 12.5, color: WL.inkSoft),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
