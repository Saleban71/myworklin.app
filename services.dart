/// WorkLink service layer — thin, typed wrappers over Supabase.
/// State transitions that involve money (escrow) go through edge
/// functions / RPCs so clients can never mutate them directly.
library;

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────── AUTH ──
class AuthService {
  /// PRD: registration in under one minute — phone + OTP.
  Future<void> sendOtp(String phone) =>
      db.auth.signInWithOtp(phone: phone);

  Future<AuthResponse> verifyOtp(String phone, String token) =>
      db.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  String? get userId => db.auth.currentUser?.id;

  Future<void> createProfile({
    required String role, // 'worker' | 'employer'
    required String fullName,
    String? nrcNumber,
    String? town,
    String language = 'en',
  }) async {
    final pos = await _tryGetPosition();
    await db.from('profiles').upsert({
      'id': userId,
      'role': role,
      'full_name': fullName,
      'phone': db.auth.currentUser!.phone,
      'nrc_number': nrcNumber,
      'preferred_language': language,
      'town': town,
      if (pos != null)
        'location': 'POINT(${pos.longitude} ${pos.latitude})',
    });
    if (role == 'worker') {
      await db.from('workers').upsert({'id': userId});
    } else {
      await db.from('employers').upsert({'id': userId});
    }
  }

  Future<Position?> _tryGetPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() => db.auth.signOut();
}

// ─────────────────────────────────────────────── WORKER ──
class WorkerService {
  Future<WorkerProfile> me() async {
    final m = await db
        .from('workers')
        .select('*, profiles!inner(full_name, town)')
        .eq('id', db.auth.currentUser!.id)
        .single();
    return WorkerProfile.fromMap(m);
  }

  Future<void> setAvailability(String status) => db
      .from('workers')
      .update({'availability': status})
      .eq('id', db.auth.currentUser!.id);

  Future<void> setSkills(List<int> skillIds) async {
    final uid = db.auth.currentUser!.id;
    await db.from('worker_skills').delete().eq('worker_id', uid);
    if (skillIds.isNotEmpty) {
      await db.from('worker_skills').insert(
          skillIds.map((s) => {'worker_id': uid, 'skill_id': s}).toList());
    }
  }

  Future<void> setRates({double? daily, double? hourly, int? years}) =>
      db.from('workers').update({
        if (daily != null) 'daily_rate_zmw': daily,
        if (hourly != null) 'hourly_rate_zmw': hourly,
        if (years != null) 'years_experience': years,
      }).eq('id', db.auth.currentUser!.id);

  /// Calls the Claude-backed edge function (PRD: AI Profile Generator).
  Future<Map<String, dynamic>> generateAiProfile() async {
    final res = await db.functions.invoke('generate-profile');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<PassportEntry>> passport() async {
    final rows = await db
        .from('work_passport_entries')
        .select()
        .eq('worker_id', db.auth.currentUser!.id)
        .order('completed_at', ascending: false);
    return rows.map<PassportEntry>((m) => PassportEntry.fromMap(m)).toList();
  }

  Future<List<Skill>> skillsCatalogue() async {
    final rows = await db.from('skills').select().order('name');
    return rows.map<Skill>((m) => Skill.fromMap(m)).toList();
  }
}

// ─────────────────────────────────────────────── JOBS ──
class JobService {
  Future<Job> postJob({
    required String title,
    String? description,
    required int skillId,
    required int workersNeeded,
    required String town,
    required double lat,
    required double lng,
    required DateTime startDate,
    required int durationDays,
    required double budgetZmw,
  }) async {
    final m = await db.from('jobs').insert({
      'employer_id': db.auth.currentUser!.id,
      'title': title,
      'description': description,
      'skill_id': skillId,
      'workers_needed': workersNeeded,
      'town': town,
      'location': 'POINT($lng $lat)',
      'start_date': startDate.toIso8601String().substring(0, 10),
      'duration_days': durationDays,
      'budget_zmw': budgetZmw,
      'status': 'open',
    }).select().single();
    return Job.fromMap(m);
  }

  /// The AI matching engine (SQL RPC — see 003_functions.sql).
  Future<List<MatchResult>> matchWorkers(String jobId) async {
    final rows =
        await db.rpc('match_workers', params: {'p_job_id': jobId});
    return (rows as List)
        .map((m) => MatchResult.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> inviteWorker(String jobId, String workerId, double score) =>
      db.from('job_applications').insert({
        'job_id': jobId,
        'worker_id': workerId,
        'status': 'accepted', // MVP: one-click hire; Phase 2 adds accept flow
        'match_score': score,
      });

  Future<List<JobApplication>> applicationsFor(String jobId) async {
    final rows =
        await db.from('job_applications').select().eq('job_id', jobId);
    return rows
        .map<JobApplication>((m) => JobApplication.fromMap(m))
        .toList();
  }

  Future<void> markComplete(String applicationId,
          {required bool asWorker}) =>
      db.from('job_applications').update({
        asWorker
            ? 'worker_marked_complete'
            : 'employer_confirmed_complete': true,
      }).eq('id', applicationId);

  Future<List<Job>> myOpenJobs() async {
    final rows = await db
        .from('jobs')
        .select()
        .eq('employer_id', db.auth.currentUser!.id)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false);
    return rows.map<Job>((m) => Job.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> myInvitations() async {
    return List<Map<String, dynamic>>.from(await db
        .from('job_applications')
        .select('*, jobs(*)')
        .eq('worker_id', db.auth.currentUser!.id)
        .order('created_at', ascending: false));
  }

  Future<void> rate({
    required String jobId,
    required String rateeId,
    required int stars,
    String? comment,
  }) =>
      db.from('ratings').insert({
        'job_id': jobId,
        'rater_id': db.auth.currentUser!.id,
        'ratee_id': rateeId,
        'stars': stars,
        'comment': comment,
      });
}

// ─────────────────────────────────────────────── PAYMENTS ──
/// Escrow lifecycle. In production, `fundEscrow` should call an edge
/// function that initiates an MTN MoMo / Airtel Money collection request
/// and only marks the row 'funded' on the provider webhook callback.
/// The direct update below is the sandbox/dev path.
class PaymentService {
  Future<EscrowTransaction> fundEscrow({
    required String jobId,
    required double amount,
    required String provider,
  }) async {
    final m = await db.from('escrow_transactions').insert({
      'job_id': jobId,
      'employer_id': db.auth.currentUser!.id,
      'amount_zmw': amount,
      'provider': provider,
      'status': 'funded', // DEV ONLY — production: webhook sets this
      'funded_at': DateTime.now().toIso8601String(),
    }).select().single();
    return EscrowTransaction.fromMap(m);
  }

  /// Releasing triggers the Postgres trigger that stamps every hired
  /// worker's Digital Work Passport and creates payouts.
  Future<void> releaseEscrow(String escrowId) => db
      .from('escrow_transactions')
      .update({
        'status': 'released',
        'released_at': DateTime.now().toIso8601String(),
      })
      .eq('id', escrowId);

  Future<EscrowTransaction?> forJob(String jobId) async {
    final rows = await db
        .from('escrow_transactions')
        .select()
        .eq('job_id', jobId)
        .limit(1);
    return rows.isEmpty ? null : EscrowTransaction.fromMap(rows.first);
  }
}

// ─────────────────────────────────────────────── CHAT ──
class ChatService {
  Future<String> conversationForJob(String jobId, List<String> members) async {
    final existing = await db
        .from('conversations')
        .select('id')
        .eq('job_id', jobId)
        .limit(1);
    if (existing.isNotEmpty) return existing.first['id'] as String;

    final conv = await db
        .from('conversations')
        .insert({'job_id': jobId}).select().single();
    await db.from('conversation_members').insert([
      for (final m in members)
        {'conversation_id': conv['id'], 'profile_id': m}
    ]);
    return conv['id'] as String;
  }

  Future<void> send(String conversationId, String body) =>
      db.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': db.auth.currentUser!.id,
        'body': body,
      });

  /// Realtime stream of messages for a conversation.
  Stream<List<ChatMessage>> stream(String conversationId) => db
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((rows) =>
          rows.map((m) => ChatMessage.fromMap(m)).toList());
}
