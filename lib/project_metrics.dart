class ActivityForecast {
  const ActivityForecast(this.start, this.finish);

  final DateTime start;
  final DateTime finish;
}

class EarnedValueMetrics {
  const EarnedValueMetrics({
    required this.plannedValue,
    required this.earnedValue,
    required this.actualCost,
  });

  final double plannedValue;
  final double earnedValue;
  final double actualCost;

  double get cpi => actualCost == 0 ? 1 : earnedValue / actualCost;
  double get spi => plannedValue == 0 ? 1 : earnedValue / plannedValue;

  factory EarnedValueMetrics.calculate(
    List<Map<String, Object?>> activities, {
    required DateTime asOf,
  }) {
    final reportDate = DateTime.utc(asOf.year, asOf.month, asOf.day);
    var pv = 0.0;
    var ev = 0.0;
    var ac = 0.0;
    for (final activity in activities) {
      final cost = (activity['cost'] as num).toDouble();
      final parsedStart = DateTime.parse(activity['start_date'] as String);
      final start = DateTime.utc(
        parsedStart.year,
        parsedStart.month,
        parsedStart.day,
      );
      final finish = start.add(Duration(days: activity['duration'] as int));
      final plannedFraction = reportDate.isBefore(start)
          ? 0.0
          : !reportDate.isBefore(finish)
          ? 1.0
          : reportDate.difference(start).inDays /
                finish.difference(start).inDays;
      pv += cost * plannedFraction;
      ev += cost * (activity['progress'] as num).toDouble();
      ac += (activity['actual_cost'] as num).toDouble();
    }
    return EarnedValueMetrics(
      plannedValue: pv,
      earnedValue: ev,
      actualCost: ac,
    );
  }
}

Map<String, ActivityForecast> forecastActivities(
  List<Map<String, Object?>> activities, {
  required DateTime asOf,
}) {
  final reportDate = DateTime.utc(asOf.year, asOf.month, asOf.day);
  final forecasts = <String, ActivityForecast>{};
  final byCode = <String, Map<String, Object?>>{
    for (final activity in activities) activity['code'] as String: activity,
  };
  final resolving = <String>{};

  ActivityForecast resolve(Map<String, Object?> activity) {
    final code = activity['code'] as String;
    final cached = forecasts[code];
    if (cached != null) return cached;
    final parsedStart = DateTime.parse(activity['start_date'] as String);
    final plannedStart = DateTime.utc(
      parsedStart.year,
      parsedStart.month,
      parsedStart.day,
    );
    final duration = activity['duration'] as int;
    final plannedFinish = plannedStart.add(Duration(days: duration));
    final progress = (activity['progress'] as num).toDouble().clamp(0.0, 1.0);
    var forecastStart = plannedStart;
    if (!resolving.add(code)) {
      return ActivityForecast(plannedStart, plannedFinish);
    }
    final predecessors = (activity['dependency'] as String)
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    for (final predecessor in predecessors) {
      final predecessorActivity = byCode[predecessor];
      final predecessorFinish = predecessorActivity == null
          ? null
          : resolve(predecessorActivity).finish;
      if (predecessorFinish != null &&
          predecessorFinish.isAfter(forecastStart)) {
        forecastStart = predecessorFinish;
      }
    }
    late final DateTime finish;
    if (progress >= 1) {
      forecastStart = plannedStart;
      finish = plannedFinish;
    } else if (plannedStart.isBefore(reportDate)) {
      if (forecastStart.isBefore(reportDate)) forecastStart = reportDate;
      finish = forecastStart.add(
        Duration(days: (duration * (1 - progress)).ceil()),
      );
    } else {
      finish = forecastStart.add(Duration(days: duration));
    }
    forecasts[code] = ActivityForecast(forecastStart, finish);
    resolving.remove(code);
    return forecasts[code]!;
  }

  for (final activity in activities) {
    resolve(activity);
  }
  return forecasts;
}
