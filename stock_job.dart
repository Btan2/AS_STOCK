/*
==============
  StockJob
==============
*/
import 'dart:convert';

/*
=================
  StockJob
=================
*/
class StockJob {
  final String date = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
  String id;
  String name;
  List<StockItem> stock = [];
  List<StockLiteral> literal = [];
  List<StockItem> nof = [];
  List<String> allLocations = [];
  String location = "";
  String dbPath = ""; // file location of the xlsx or csv file

  StockJob({
    required this.id,
    required this.name,
  });

  addStock(StockItem item, int count) {
    literal.add(StockLiteral(item.index, item.barcode, item.description, item.nof, count, location));
    for(int i = 0; i < count; i++){
        stock.add(item);
    }
  }

  setLocation(int index) {
    location = allLocations[index];
  }

  addLocation(String s){
    allLocations.add(s);
  }

  StockJob.fromJson(Map<String, dynamic> json) :
        id = json['id'],
        name = json['name'],
        stock = json['stock'],
        literal = json['literal'],
        nof = json['nof'],
        allLocations = json['allLocations'],
        dbPath = json['dbPath'],
        location = json['stock'];

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
        "nof": e.nof,
        "count": e.count,
        "location": e.location,
      };
    });

    return map.toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stock': jsonEncode(itemToJson(stock)),
      'literal': jsonEncode(literalToJson(literal)),
      'nof': nof,
      'allLocations': jsonEncode(allLocations),
      'dbPath': dbPath,
      'location': '',
    };
  }

  //
  // Avoid pointer aliasing? Deep copy?
  //

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
              nof == other.nof &&
              location == other.location &&
              dbPath == other.dbPath;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ date.hashCode ^ stock.hashCode ^ nof.hashCode ^ location.hashCode ^ dbPath.hashCode;
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
  final dynamic price;
  final bool nof;

  const StockItem({
    required this.index,
    required this.barcode,
    required this.category,
    required this.description,
    required this.uom,
    required this.price,
    required this.nof
  });

  StockItem copy({
    int? index,
    String? barcode,
    String? category,
    String? description,
    int? count,
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

  isNOF()
  {
    return nof == true;
  }

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
  final bool nof;

  int count = 0;
  String location = "";

  StockLiteral(
      this.index,
      this.barcode,
      this.description,
      this.nof,
      this.count,
      this.location,
      );

  StockLiteral copy({
    int? index,
    String? barcode,
    String? description,
    bool? nof,
    int? count,
    String? location,
  }) =>
      StockLiteral(
          index ?? this.index,
          barcode ?? this.barcode,
          description ?? this.description,
          nof ?? this.nof,
          count ?? this.count,
          location ?? this.location
      );

  isNOF() {
    return nof == true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StockLiteral &&
              runtimeType == other.runtimeType &&
              index == other.index &&
              barcode == other.barcode &&
              description == other.description &&
              nof == other.nof &&
              count == other.count &&
              location == other.location;

  @override
  int get hashCode => index.hashCode ^ barcode.hashCode ^ description.hashCode ^ nof.hashCode ^ count.hashCode ^ location.hashCode;
}
