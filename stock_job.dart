import 'dart:convert';

/*
=================
  StockJob
=================
*/
class StockJob {
  String date = '';
  String id;
  String name;
  List<StockItem> stock = [];
  List<StockLiteral> literal = [];
  List<StockItem> nof = []; // contains stock items that are NOF
  List<String> allLocations = [];
  String location = "";
  String dbPath = ""; // file location of the xlsx or csv file

  StockJob({
    required this.id,
    required this.name,
  });

  addStock(StockItem item, int count) {
    if (count <= 0){
      return;
    }

    literal.add(StockLiteral(item.index, item.barcode, item.description, item.uom, item.nof, count, location));
    for(int i = 0; i < count; i++){
        stock.add(item);
    }
  }

  removeStock(int literalIndex, StockItem stockItem, int count ) {
    if (count <= 0){
      return;
    }

    // Remove literal item(s)
    if(literal[literalIndex].count - count <= 0) {
      literal.removeAt(literalIndex);
    }
    else{
      literal[literalIndex].count -= count;
    }

    // Remove stock item(s)
    int del = 0;
    while(stock.contains(stockItem)){
      if(del >= count){
        break;
      }
      stock.remove(stockItem);
      del++;
    }
  }

  setLocation(int index) {
    location = allLocations[index];
  }

  addLocation(String s){
    allLocations.add(s);
  }

  // Convert from JSON to StockJob object
  factory StockJob.fromJson(dynamic json) {
    StockJob j = StockJob(
        id: json['id'] as String,
        name: json['name'] as String
    );

    j.date = json.containsKey("date") ? json['date'] as String : "";

    j.stock = [
      for (final map in jsonDecode(json['stock']))
        StockItem.fromJson(map),
    ];

    j.literal = [
      for (final map in jsonDecode(json['literal']))
        StockLiteral.fromJson(map),
    ];

    // FIX THIS
    // j.nof = [
    //   for (final map in jsonDecode(json['nof']))
    //     StockItem.fromJson(map),
    // ];

    j.allLocations.clear();
    for(final entry in jsonDecode(json['allLocations'])) {
      j.allLocations.add(entry as String);
    }

    j.location = ''; // reset job location //json['location'] as String;
    j.dbPath = json['dbPath'] as String; // file location of the xlsx or csv file
    return j;
  }

  itemToJson(List l) {
    var map = l.map((e){
      return {
        "index": e.index,
        "barcode": e.barcode,
        "category": e.category,
        "description": e.description,
        "uom": e.uom,
        "price": e.price,
        "nof": e.nof,
      };
    });

    return map.toList();
  }

  literalToJson(List l) {
    var map = l.map((e){
      return {
        "index": e.index,
        "barcode": e.barcode,
        "description": e.description,
        "uom": e.uom,
        "nof": e.nof,
        "count": e.count,
        "location": e.location,
      };
    });

    return map.toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'date': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
      'id': id,
      'name': name,
      'stock': jsonEncode(itemToJson(stock)),
      'literal': jsonEncode(literalToJson(literal)),
      'nof': jsonEncode(itemToJson(nof)),
      'allLocations': jsonEncode(allLocations),
      'dbPath': dbPath,
      'location': '',
    };
  }

  StockJob copy({
    String? id,
    String? name,
  }) =>
      StockJob(
        id : id ?? this.id,
        name : name ?? this.name,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StockJob &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name &&
              date == other.date &&
              stock == other.stock &&
              literal == other.literal &&
              nof == other.nof &&
              location == other.location &&
              dbPath == other.dbPath;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ date.hashCode ^ stock.hashCode ^ literal.hashCode ^ nof.hashCode ^ location.hashCode ^ dbPath.hashCode;
}

/*
================
  StockItem
================
*/
class StockItem {
  final int index;
  final String barcode;
  final String category;
  final String description;
  final String uom;
  //final double unit; // value from 0.0 to 1.0 indicating unit amount; for stock that uses volume as  e.g alchol.
  final dynamic price;
  final bool nof;

  const StockItem({
    required this.index,
    required this.barcode,
    required this.category,
    required this.description,
    required this.uom,
    //required this.unit,
    required this.price,
    required this.nof
  });

  StockItem.fromJson(Map<String, dynamic> json)
      : index = json['index'] as int,
        barcode = json['barcode'] ?? '',
        category = json['category'] ?? '',
        description = json['description'] ?? '',
        uom = json['uom'] ?? '',
        price = json['price'] as dynamic ?? '',
        nof = json['nof'] as bool;

  StockItem copy({
    int? index,
    String? barcode,
    String? category,
    String? description,
    String? uom,
    dynamic price,
    bool? nof,
  }) =>
      StockItem(
        index : index ?? this.index,
        barcode : barcode ?? this.barcode,
        category : category ?? this.category,
        description : description ?? this.description,
        uom : uom ?? this.uom,
        price : price ?? this.price,
        nof : nof ?? this.nof,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StockItem &&
              runtimeType == other.runtimeType &&
              index == other.index &&
              barcode == other.barcode &&
              category == other.category &&
              description == other.description &&
              uom == other.uom &&
              price == other.price &&
              nof == other.nof;

  @override
  int get hashCode => index.hashCode ^ barcode.hashCode ^ category.hashCode ^ description.hashCode ^ uom.hashCode ^ price.hashCode ^ nof.hashCode;
}

/*
=======================
  StockLiteral
=======================
*/
class StockLiteral {
  final int index;
  final String barcode;
  final String description;
  final String uom;
  final bool nof;

  int count = 0;
  String location = "";

  StockLiteral(
      this.index,
      this.barcode,
      this.description,
      this.uom,
      this.nof,
      this.count,
      this.location,
      );

  StockLiteral.fromJson(Map<String, dynamic> json)
      : index = json['index'] as int,
        barcode = json['barcode'] ?? '',
        description = json['description'] ?? '',
        uom = json['uom'] ?? '',
        nof = json['nof'] as bool,
        count = json['count'] as int,
        location = json['location'] ?? '';

  StockLiteral copy({
    int? index,
    String? barcode,
    String? description,
    String? uom,
    bool? nof,
    int? count,
    String? location,
  }) =>
      StockLiteral(
          index ?? this.index,
          barcode ?? this.barcode,
          description ?? this.description,
          uom ?? this.uom,
          nof ?? this.nof,
          count ?? this.count,
          location ?? this.location
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StockLiteral &&
              runtimeType == other.runtimeType &&
              index == other.index &&
              barcode == other.barcode &&
              description == other.description &&
              uom == other.uom &&
              nof == other.nof &&
              count == other.count &&
              location == other.location;

  @override
  int get hashCode => index.hashCode ^ barcode.hashCode ^ description.hashCode ^ uom.hashCode ^ nof.hashCode ^ count.hashCode ^ location.hashCode;
}
