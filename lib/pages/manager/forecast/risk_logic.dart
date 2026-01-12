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
    String riskLevel;

    // Priority 1: Out of Stock (0 units) -> URGENT
    if (currentStock <= 0 && forecastDemand > 0) {
      riskLevel = "Urgent";
    }
    // Priority 2: Expiry Risk -> HIGH
    else if (daysToExpiry <= 7) {
      riskLevel = "High";
    }
    // Priority 3: Dead Stock -> HIGH
    else if (forecastDemand <= 0 && currentStock > 0) {
      riskLevel = "High";
    }
    else {
      final ratio = (forecastDemand > 0) ? currentStock / forecastDemand : 0.0;

      // Overstock Check
      if (ratio >= 1.5) {
        riskLevel = "High";
      } else if (daysToExpiry <= 14 || ratio >= 1.0) {
        riskLevel = "Medium";
      } else {
        // Safe Range
        riskLevel = "Low";
      }
    }

    // Risk Value Calculation
    int riskValue = 0;
    if (currentStock <= 0 && forecastDemand > 0) {
      riskValue = 95;
    } else if (daysToExpiry <= 0) {
      riskValue = 100;
    } else {
      final ratio = (forecastDemand > 0) ? currentStock / forecastDemand : 1.0;
      double stockScore = (ratio * 30).clamp(0, 60);
      int expiryScore = (daysToExpiry <= 7) ? 40 : (daysToExpiry <= 14 ? 20 : 5);
      riskValue = (stockScore + expiryScore).round().clamp(0, 100);
    }

    final reasons = generateRiskReasons(
      riskLevel: riskLevel,
      forecastDemand: forecastDemand,
      currentStock: currentStock,
      daysToExpiry: daysToExpiry,
    );

    return RiskResult(riskLevel: riskLevel, riskValue: riskValue, reasons: reasons);
  }

  static List<String> generateRiskReasons({
    required String riskLevel,
    required double forecastDemand,
    required int currentStock,
    required int daysToExpiry,
  }) {
    List<String> reasons = [];

    // --- URGENT REASONS ---
    if (currentStock <= 0 && forecastDemand > 0) {
      reasons.add("URGENT: Product is out of stock");
      reasons.add("Action: Restock immediately to fulfill demand");
      return reasons;
    }

    // --- HIGH/MEDIUM REASONS (Expiry & Overstock) ---
    if (daysToExpiry <= 0) {
      reasons.add("CRITICAL: Product already expired");
    } else if (daysToExpiry <= 7) {
      reasons.add("High Risk: Expiry in $daysToExpiry days");
    }

    final ratio = (forecastDemand > 0) ? currentStock / forecastDemand : 0.0;
    if (ratio >= 1.5) {
      reasons.add("Overstock: Stock is significantly higher than forecast");
    }

    // --- LOW RISK REASONS (UPDATED LOGIC) ---
    if (riskLevel == "Low") {
      reasons.add("Expiry date is safe (> 14 days)");

      // NEW: Specific check for low stock but safe expiry
      if (currentStock <= 10 && currentStock > 0) {
        reasons.add("Stock level is low ($currentStock remaining)");
        reasons.add("Suggestion: Need to stock up soon");
      } else {
        reasons.add("Stock level is healthy");
      }
    }

    if (reasons.isEmpty) {
      reasons.add("Inventory levels and expiry are safe");
    }

    return reasons;
  }
}