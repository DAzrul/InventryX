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

    // Special Case: No demand but we have stock = Immediate High Risk (Overstock/Dead stock)
    if (forecastDemand <= 0 && currentStock > 0) {
      riskLevel = "High";
    }
    // Special Case: No demand and no stock = Safe (Low Risk)
    else if (forecastDemand <= 0 && currentStock == 0) {
      riskLevel = "Low";
    }
    else {
      final ratio = currentStock / forecastDemand;

      // High Risk: Expires in a week OR we have way too much stock (1.5x demand)
      if (daysToExpiry <= 7 || ratio >= 1.5) {
        riskLevel = "High";
      }
      // Medium Risk: Expires in 2 weeks OR we have slightly too much stock (1.0x demand)
      else if (daysToExpiry <= 14 || ratio >= 1.0) {
        riskLevel = "Medium";
      }
      // Low Risk: Healthy stock and far expiry
      else {
        riskLevel = "Low";
      }
    }

    // ===== 2. CALCULATE RISK VALUE (Stock Score + Expiry Score) =====
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

    // ===== 3. GENERATE REASONS (UPDATED LOGIC) =====
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

    // ================= HIGH RISK REASONS =================
    if (riskLevel == "High") {
      // 1. EXPIRY RISK (Even if stock is not low)
      if (daysToExpiry <= 7) {
        reasons.add("URGENT: Stock expires in $daysToExpiry days");
        if (currentStock > 0) {
          reasons.add("High risk of waste (Sell immediately)");
        }
      }

      // 2. OVERSTOCK RISK (Too much compared to demand)
      if (ratio >= 1.5) {
        reasons.add("Stock is significantly higher than forecast");
        if (ratio > 3.0) reasons.add("Severe overstocking detected");
      }

      // 3. DEAD STOCK (Stock exists but 0 demand)
      if (forecastDemand <= 0 && currentStock > 0) {
        reasons.add("Dead Stock: No predicted demand");
      }
    }

    // ================= MEDIUM RISK REASONS =================
    if (riskLevel == "Medium") {
      // 1. EXPIRY WARNING
      if (daysToExpiry <= 14 && daysToExpiry > 7) {
        reasons.add("Warning: Expiry within 14 days");
        if (currentStock > 0) {
          reasons.add("Monitor stock to prevent spoilage");
        }
      }

      // 2. STOCK BALANCE WARNING
      if (ratio >= 1.0 && ratio < 1.5) {
        reasons.add("Stock slightly higher than forecast");
      }
    }

    // ================= LOW RISK REASONS =================
    if (riskLevel == "Low") {
      // Healthy states
      if (daysToExpiry > 14) {
        reasons.add("Expiry date is safe (> 14 days)");
      }

      if (ratio < 1.0) {
        reasons.add("Stock level is healthy (Matches forecast)");
      } else {
        reasons.add("Stock matches forecast demand");
      }

      reasons.add("Good sales stability");
    }

    return reasons;
  }
}