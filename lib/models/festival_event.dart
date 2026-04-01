enum CrowdLevel { low, moderate, high }

class FestivalEvent {
  final String templeId;
  final String name;
  final DateTime date;
  final CrowdLevel crowdHint;

  const FestivalEvent({
    required this.templeId,
    required this.name,
    required this.date,
    required this.crowdHint,
  });
}
