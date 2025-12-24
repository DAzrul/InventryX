import 'dart:math';

class ForecastLogic {

  // 1. Calculate Variance
  static double calculateVariance(List<int> sales) {
    if (sales.isEmpty) return 0.0;
    final mean = sales.reduce((a, b) => a + b) / sales.length;
    double squaredDiffSum = 0;
    for (final s in sales) {
      squaredDiffSum += pow((s - mean), 2);
    }
    return squaredDiffSum / sales.length;
  }

  // 2. Simple Moving Average (SMA – last 5 days)
  static double calculateSMA(List<int> sales) {
    if (sales.length < 5) {
      // For real system: if less than 5 days, just average what we have to prevent crash
      return sales.isNotEmpty
          ? sales.reduce((a, b) => a + b) / sales.length
          : 0.0;
    }
    final lastFive = sales.sublist(sales.length - 5);
    final sum = lastFive.reduce((a, b) => a + b);
    return sum / 5;
  }

  // 3. Single Exponential Smoothing (SES)
  static double calculateSES(List<int> sales, {double alpha = 0.5}) {
    if (sales.isEmpty) return 0.0;
    double forecast = sales.first.toDouble();
    for (int i = 1; i < sales.length; i++) {
      forecast = alpha * sales[i] + (1 - alpha) * forecast;
    }
    return forecast;
  }

  // 4. Trend Calculation
  static double average(List<int> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static String calculateTrend(List<int> sales) {
    if (sales.length < 4) {
      return "Insufficient Data";
    }

    int mid = sales.length ~/ 2;
    final earlierSales = sales.sublist(0, mid);
    final recentSales = sales.sublist(mid);

    final earlierAvg = average(earlierSales);
    final recentAvg = average(recentSales);

    const double trendThreshold = 5; // tolerance

    if (recentAvg > earlierAvg + trendThreshold) {
      return "Increasing";
    } else if (recentAvg < earlierAvg - trendThreshold) {
      return "Decreasing";
    } else {
      return "Stable";
    }
  }

  // 5. MAIN GENERATOR: Automatic Method Selection
  static Map<String, dynamic> generateForecast(List<int> sales) {
    const double varianceThreshold = 20;

    final variance = calculateVariance(sales);
    final trend = calculateTrend(sales);

    double forecast;
    String methodUsed;

    // Logic: If variance is high, use SES. If stable, use SMA.
    if (variance >= varianceThreshold) {
      forecast = calculateSES(sales, alpha: 0.5);
      methodUsed = "SES";
    } else {
      forecast = calculateSMA(sales);
      methodUsed = "SMA";
    }

    return {
      "forecast": forecast.round(), // Round to nearest whole unit for display
      "method": methodUsed,
      "trend": trend,
      "variance": variance,
    };
  }
}
