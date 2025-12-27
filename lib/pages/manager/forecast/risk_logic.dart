class RiskResult {
  final String riskLevel;
  final int riskValue;
  final List<String> reasons;

  RiskResult({
    required this.riskLevel,
    required this.riskValue,
    required this.reasons,
  });
}

class RiskLogic {
  static RiskResult calculateRisk({
    required double forecastDemand,
    required int currentStock,
    required int daysToExpiry,
  }) {
    // ===== 1. DETERMINE RISK LEVEL =====
    String riskLevel;

    if (forecastDemand <= 0 && currentStock > 0) {
      riskLevel = "High";
    } else if (forecastDemand <= 0 && currentStock == 0) {
      riskLevel = "Low";
    } else {
      final ratio = currentStock / forecastDemand;

      if (daysToExpiry <= 7 && ratio >= 1.5) {
        riskLevel = "High";
      } else if (daysToExpiry <= 14 || ratio >= 1.0) {
        riskLevel = "Medium";
      } else {
        riskLevel = "Low";
      }
    }

    // ===== 2. CALCULATE RISK VALUE (Your Custom Formula) =====
    // Ratio logic
    final ratio = (forecastDemand > 0) ? currentStock / forecastDemand : 3.0;

    // Stock Score (max 60)
    double stockScore = ratio * 40;
    if (stockScore > 60) stockScore = 60;

    // Expiry Score (max 40)
    int expiryScore;
    if (daysToExpiry <= 7) {
      expiryScore = 40;
    } else if (daysToExpiry <= 14) {
      expiryScore = 25;
    } else {
      expiryScore = 10;
    }

    // Total Score (max 100)
    int riskValue = (stockScore + expiryScore).round();
    if (riskValue > 100) riskValue = 100;

    // ===== 3. GENERATE REASONS =====
    final reasons = generateRiskReasons(
      riskLevel: riskLevel,
      forecastDemand: forecastDemand,
      currentStock: currentStock,
      daysToExpiry: daysToExpiry,
    );

    return RiskResult(
      riskLevel: riskLevel,
      riskValue: riskValue,
      reasons: reasons,
    );
  }

  static List<String> generateRiskReasons({
    required String riskLevel,
    required double forecastDemand,
    required int currentStock,
    required int daysToExpiry,
  }) {
    List<String> reasons = [];
    final ratio = (forecastDemand > 0) ? currentStock / forecastDemand : 999.0;

    if (riskLevel == "High") {
      if (ratio >= 1.5) reasons.add("Stock is significantly higher than forecast");
      if (daysToExpiry <= 7) reasons.add("Expiry is critical (in $daysToExpiry days)");
      if (ratio > 3.0) reasons.add("Severe overstocking detected");
    }

    if (riskLevel == "Medium") {
      if (ratio >= 1.0) reasons.add("Stock slightly higher than forecast");
      if (daysToExpiry <= 14) reasons.add("Expiry within 14 days");
    }

    if (riskLevel == "Low") {
      reasons.add("Stock matches forecast");
      if (daysToExpiry > 14) reasons.add("Expiry > 14 days (Safe)");
      reasons.add("Good sales stability");
    }

    return reasons;
  }
}