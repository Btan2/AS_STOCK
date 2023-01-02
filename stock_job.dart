import 'dart:convert';

/*
=================
  Session File
=================
*/
class SessionFile {
  List<String> dirs = [];
  String uid;
  int pageCount;
  double fontScale;
  // storageType?

  SessionFile({
    this.uid = "",
    this.pageCount = 15,
    this.fontScale = 12.0
  });

  Map<String, dynamic> toJson() {
    return {
      'dirs': jsonEncode(dirs),
      'uid': uid,
      'pageCount': pageCount,
      'fontScale' : fontScale,
    };
  }

  factory SessionFile.fromJson(dynamic json) {
    SessionFile sf = SessionFile();
    sf.uid = json['uid'] as String;
    sf.pageCount = json['pageCount'] as int;
    sf.fontScale = json['fontScale'] as double;
    for(final entry in jsonDecode(json['dirs'])) {
      sf.dirs.add(entry as String);
    }
    return sf;
  }
}

/*
=================
  StockJob
=================
*/
class StockJob {
  String date = '';
  String id;
  String name;
  double total = 0;
  List<StockLiteral> literal = [];
  List<StockItem> nof = [];
  List<String> allLocations = [];
  String location = "";
  String dbPath = ""; // location of the xlsx or csv spreadsheet file (absolute path or won't work)

  StockJob({
    required this.id,
    required this.name,
  });

  getList(){
    List<StockItem> stk = [];
    for(int i = 0; i < literal.length; i++){

      // Add whole count
      int count = literal[i].count.floor();
      while(count > 0){
        stk.add(
            StockItem(
              index: literal[i].index,
              barcode: literal[i].barcode,
              category: literal[i].category,
              description: literal[i].description,
              nof: literal[i].nof,
              uom: literal[i].uom,
              price: literal[i].price,
            )
        );

        count--;
      }

      // Add decimal count
      double d = ((literal[i].count * 10000).toInt() % 10000)/10000;
      if (d != 0) {
        StockItem stockD = StockItem(
          index: literal[i].index,
          barcode: literal[i].barcode,
          category: literal[i].category,
          description: literal[i].description,
          nof: literal[i].nof,
          uom: literal[i].uom,
          price: literal[i].price,
        );

        stockD.unit = d;
        stk.add(stockD);
      }
    }

    // Sort stock list by table index?
    stk = stk
      ..sort((x, y) => (x.index as dynamic)
          .compareTo((y.index as dynamic)));
    return stk;
  }

  // Calc Total
  calcTotal() {
    total = 0.0;
    for(int i = 0; i < literal.length; i++) {
      total += literal[i].count;
    }
  }

  // Total
  getTotal(){
    return total;
  }

  // Add Stock
  addStock(StockItem item, double count) {
    // .. but don't add negatives
    if (count.sign == -1){
      return;
    }

    literal.add(StockLiteral(item.index, item.barcode, item.category, item.description, item.uom, item.nof, item.price, count, location));
    calcTotal();
  }

  // Get Final Sheet
  getFinalSheet(){
    var fSheet = [];

    // fuck it, do two loops
    for(int i =0; i < literal.length; i++){
      int c = 0;

      for(int j = 0; j < fSheet.length; j++) {
        if(literal[i].category == fSheet[j][2]){
          fSheet[j][4] += literal[i].count;
          fSheet[j][5] += (literal[i].price * literal[i].count);
          break;
        }
        c++;
      }

      if (c >= fSheet.length){
        fSheet.add(
            [
              fSheet.length,
              "MISC",
              literal[i].category,
              literal[i].uom,
              literal[i].count,
              literal[i].price * literal[i].count
            ]
        );
      }
    }

    return fSheet;
  }

  // Removed Stock
  removeStock(int literalIndex, StockItem stockItem, double count ) {
    // Don't remove negatives
    if (count.sign == -1) {
      return;
    }

    // Only counting to 4 decimal places
    //double d = ((count * 10000).toInt() % 10000)/10000;
    //int whole = count.floor();

    if(literal[literalIndex].count - count <= 0) {
      literal.removeAt(literalIndex);
    }
    else{
      literal[literalIndex].count -= count;
    }

    total -= count;
    if(total < 0) {
      total = 0;
    }

    calcTotal();
  }

  // Add NOF
  addNOF(StockItem st){
    for(int n = 0; n < nof.length; n++) {
      if(nof[n].barcode == st.barcode){
        return false;
      }
    }

    nof.add(st);
    return true;
  }

  // Set Location
  setLocation(int index){
    location = allLocations[index];
  }

  // Add Location
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

    // j.stock = [
    //   for (final map in jsonDecode(json['stock']))
    //     StockItem.fromJson(map),
    // ];

    j.literal = [
      for (final map in jsonDecode(json['literal']))
        StockLiteral.fromJson(map),
    ];

    j.nof = [
      for (final map in jsonDecode(json['nof']))
        StockItem.fromJson(map),
    ];

    j.allLocations.clear();
    for(final entry in jsonDecode(json['allLocations'])) {
      j.allLocations.add(entry as String);
    }

    j.location = ''; // reset job location
    j.dbPath = json['dbPath'] as String;
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
        "unit": e.unit,
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
        "category": e.category,
        "description": e.description,
        "uom": e.uom,
        "price": e.price,
        "nof": e.nof.toString(),
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
      // 'stock': jsonEncode(itemToJson(stock)),
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
              // stock == other.stock &&
              literal == other.literal &&
              nof == other.nof &&
              location == other.location &&
              dbPath == other.dbPath;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ date.hashCode ^ literal.hashCode ^ nof.hashCode ^ location.hashCode ^ dbPath.hashCode;
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
  double unit = 1;
  final double price;
  final bool nof;

  // Set Unit
  setUnit(double unit){
    this.unit = unit;
  }

  StockItem({
    required this.index,
    required this.barcode,
    required this.category,
    required this.description,
    required this.uom,
    required this.price,
    required this.nof,
  });

  // From JSON
  StockItem.fromJson(Map<String, dynamic> json)
      : index = json['index'] as int,
        barcode = json['barcode'] ?? '',
        category = json['category'] ?? '',
        description = json['description'] ?? '',
        uom = json['uom'] ?? '',
        unit = json['unit'] as double,
        price = json['price'] as double,
        nof = json['nof'] == 'true' ? true : false;

  StockItem copy({
    int? index,
    String? barcode,
    String? category,
    String? description,
    String? uom,
    double? price,
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
              unit == other.unit &&
              price == other.price &&
              nof == other.nof;

  @override
  int get hashCode => index.hashCode ^ barcode.hashCode ^ category.hashCode ^ description.hashCode ^ uom.hashCode ^ unit.hashCode ^ price.hashCode ^ nof.hashCode;
}

/*
=======================
  StockLiteral
=======================
*/
class StockLiteral {
  final int index;
  final String barcode;
  final String category;
  final String description;
  final String uom;
  final bool nof;
  final double price;

  double count = 0;
  String location = "";

  StockLiteral(
      this.index,
      this.barcode,
      this.category,
      this.description,
      this.uom,
      this.nof,
      this.price,
      this.count,
      this.location,
      );

  StockLiteral.fromJson(Map<String, dynamic> json)
      : index = json['index'] as int,
        barcode = json['barcode'] ?? '',
        category = json['category'] ?? '',
        description = json['description'] ?? '',
        uom = json['uom'] ?? '',
        nof = json['nof'] == 'true' ? true : false,
        price = json['price'] ?? '',
        count = json['count'] as double,
        location = json['location'] ?? '';

  StockLiteral copy({
    int? index,
    String? barcode,
    String? category,
    String? description,
    String? uom,
    bool? nof,
    double? price,
    double? count,
    String? location,
  }) =>
      StockLiteral(
          index ?? this.index,
          barcode ?? this.barcode,
          category ?? this.category,
          description ?? this.description,
          uom ?? this.uom,
          nof ?? this.nof,
          price ?? this.price,
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
              price == other.price &&
              count == other.count &&
              location == other.location;

  @override
  int get hashCode => index.hashCode ^ barcode.hashCode ^ description.hashCode ^ uom.hashCode ^ nof.hashCode ^ price.hashCode ^ count.hashCode ^ location.hashCode;
}
