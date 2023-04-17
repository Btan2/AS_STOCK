import 'dart:convert';

/*=================
  StockJob
=================*/
class StockJob {
  String date = '';
  String id;
  String name;
  double total = 0;
  List<Map<String, dynamic>> literals = List.empty(growable: true);
  List<Map<String, dynamic>> nof = List.empty(growable: true);
  List<String> allLocations = List.empty(growable: true);
  String location = "";

  @override
  bool operator ==(Object other) => identical(this, other) || other is StockJob &&
      runtimeType == other.runtimeType &&
      date == other.date &&
      id == other.id &&
      name == other.name &&
      literals == other.literals &&
      nof == other.nof &&
      allLocations == other.allLocations &&
      location == other.location;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ date.hashCode ^ literals.hashCode ^ nof.hashCode ^ allLocations.hashCode ^ location.hashCode; // ^ dbPath.hashCode;

  StockJob({
    required this.id,
    required this.name,
    date,
    total,
    literals,
    nof,
    allLocations,
  });

  StockJob copy({
    String? date,
    String? id,
    String? name,
    double? total,
    List<Map<String, dynamic>>? literals,
    List<Map<String, dynamic>>? nof,
    List<String>? allLocations,
  }) =>
      StockJob(
          date: date ?? this.date,
          id: id ?? this.id,
          name: name ?? this.name,
          total: total ?? this.total,
          literals: literals ?? this.literals,
          nof: nof ?? this.nof,
          allLocations: allLocations ?? this.allLocations
      );

  // Import job file from json
  factory StockJob.fromJson(dynamic json) {
    StockJob job = StockJob(id: json['id'] as String, name: json['name'] as String);

    job.date = json.containsKey("date") ? json['date'] as String : "";

    job.literals = !json.containsKey("literals") || json['literals'] == null ? List.empty(growable: true) : [
      for (final map in jsonDecode(json['literals'])){
        // literal from json
        "index": int.parse(map['index'].toString()),
        "count": double.parse(map['count'].toString()),
        "location": map['location'].toString(),
      },
    ];

    job.nof = !json.containsKey("nof") || json['nof'] == null ? List.empty(growable: true) : [
      for (final map in jsonDecode(json['nof'])){
        // item from json
        "index": map['index'] as int,
        "barcode": map['barcode'] as String,
        "category": map['category'] as String,
        "description": map['description'] as String,
        "uom": map['uom'] as String,
        "price": map['price'] as double,
        "datetime": map['datetime'] as String,
        "ordercode": map['ordercode'] as String,
        "nof": map['nof'] as bool,
      }
    ];

    job.allLocations = !json.containsKey("allLocations") || json['allLocations'] == null ? List.empty(growable: true) : [
      for(final l in jsonDecode(json['allLocations']))
        l as String,
    ];

    job.location = ''; // reset job location
    return job;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.isEmpty ? "${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}" : date,
      'id': id,
      'name': name,
      'literals': jsonEncode(literals),
      'nof': jsonEncode(nof),
      'allLocations': jsonEncode(allLocations),
      'location': location,
    };
  }

  nofList() {
    List<List<dynamic>> n = List.empty(growable: true);
    for (var e in nof) {
      n.add(e.values.toList());
    }
    return n;
  }

  literalList() {
    List<List<dynamic>> l = List.empty(growable: true);
    for (var e in literals) {
      l.add(e.values.toList());
    }
    return l;
  }

  calcTotal() {
    total = 0.0;
    for (int i = 0; i < literals.length; i++) {
      total += literals[i]["count"];
    }
  }
}
