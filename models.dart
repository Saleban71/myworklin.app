/// WorkLink data models — one file for the Phase 1 surface.
/// Each maps to a table or RPC result in supabase/migrations.
library;

class Skill {
  final int id;
  final String slug;
  final String name;
  final String category;
  Skill.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        slug = m['slug'],
        name = m['name'],
        category = m['category'];
}

class WorkerProfile {
  final String id;
  final String fullName;
  final String? town;
  final String? bio;
  final int yearsExperience;
  final double? dailyRate;
  final String availability;
  final String verification;
  final int trustScore;
  final double ratingAvg;
  final int ratingCount;
  final int jobsCompleted;
  final List<String> languages;

  WorkerProfile.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        fullName = m['profiles']?['full_name'] ?? m['full_name'] ?? '',
        town = m['profiles']?['town'] ?? m['town'],
        bio = m['bio'],
        yearsExperience = m['years_experience'] ?? 0,
        dailyRate = (m['daily_rate_zmw'] as num?)?.toDouble(),
        availability = m['availability'] ?? 'offline',
        verification = m['verification'] ?? 'phone',
        trustScore = m['trust_score'] ?? 0,
        ratingAvg = (m['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount = m['rating_count'] ?? 0,
        jobsCompleted = m['jobs_completed'] ?? 0,
        languages = List<String>.from(m['languages'] ?? const []);
}

class Job {
  final String id;
  final String employerId;
  final String title;
  final String? description;
  final int skillId;
  final int workersNeeded;
  final String town;
  final DateTime startDate;
  final int durationDays;
  final double budget;
  final String status;

  Job.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        employerId = m['employer_id'],
        title = m['title'],
        description = m['description'],
        skillId = m['skill_id'],
        workersNeeded = m['workers_needed'],
        town = m['town'],
        startDate = DateTime.parse(m['start_date']),
        durationDays = m['duration_days'],
        budget = (m['budget_zmw'] as num).toDouble(),
        status = m['status'];
}

/// Result row of the `match_workers` RPC — the AI matching engine.
class MatchResult {
  final String workerId;
  final String fullName;
  final double score;
  final double distanceKm;
  final double ratingAvg;
  final double? dailyRate;
  final String availability;
  final String verification;
  final int jobsCompleted;

  MatchResult.fromMap(Map<String, dynamic> m)
      : workerId = m['worker_id'],
        fullName = m['full_name'],
        score = (m['match_score'] as num).toDouble(),
        distanceKm = (m['distance_km'] as num).toDouble(),
        ratingAvg = (m['rating_avg'] as num).toDouble(),
        dailyRate = (m['daily_rate_zmw'] as num?)?.toDouble(),
        availability = m['availability'],
        verification = m['verification'],
        jobsCompleted = m['jobs_completed'];
}

class JobApplication {
  final String id;
  final String jobId;
  final String workerId;
  final String status;
  final bool workerMarkedComplete;
  final bool employerConfirmedComplete;

  JobApplication.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        jobId = m['job_id'],
        workerId = m['worker_id'],
        status = m['status'],
        workerMarkedComplete = m['worker_marked_complete'] ?? false,
        employerConfirmedComplete = m['employer_confirmed_complete'] ?? false;
}

class EscrowTransaction {
  final String id;
  final String jobId;
  final double amount;
  final String provider;
  final String status;

  EscrowTransaction.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        jobId = m['job_id'],
        amount = (m['amount_zmw'] as num).toDouble(),
        provider = m['provider'],
        status = m['status'];
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? body;
  final DateTime createdAt;

  ChatMessage.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        conversationId = m['conversation_id'],
        senderId = m['sender_id'],
        body = m['body'],
        createdAt = DateTime.parse(m['created_at']);
}

class PassportEntry {
  final String employerName;
  final String jobTitle;
  final String? town;
  final int? durationDays;
  final double? amountPaid;
  final int? stars;
  final DateTime completedAt;

  PassportEntry.fromMap(Map<String, dynamic> m)
      : employerName = m['employer_name'],
        jobTitle = m['job_title'],
        town = m['town'],
        durationDays = m['duration_days'],
        amountPaid = (m['amount_paid_zmw'] as num?)?.toDouble(),
        stars = m['stars'],
        completedAt = DateTime.parse(m['completed_at']);
}
