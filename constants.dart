/// Shared constants mirroring the Postgres enums and PRD catalogues.
class Availability {
  static const values = {
    'available_now': 'Available now',
    'available_today': 'Available today',
    'available_tomorrow': 'Available tomorrow',
    'available_this_week': 'This week',
    'busy': 'Busy',
    'offline': 'Offline',
  };
}

class VerificationLevels {
  /// level number shown on the copper seal (L1–L5)
  static int levelOf(String v) => switch (v) {
        'top_rated' => 5,
        'reference' => 4,
        'face' => 3,
        'nrc' => 2,
        _ => 1,
      };
}

class PayProviders {
  static const values = {
    'mtn_momo': 'MTN MoMo',
    'airtel_money': 'Airtel Money',
    'zamtel_money': 'Zamtel Money',
    'bank_transfer': 'Bank transfer',
  };
}

String zmw(num n) => 'ZMW ${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2)}';
