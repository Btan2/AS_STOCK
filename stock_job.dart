import 'dart:convert';

/*=================
  StockJob
=================*/
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
    stk = stk..sort((x, y) => (x.index as dynamic).compareTo((y.index as dynamic)));
    return stk;
  }

  calcTotal() {
    total = 0.0;
    for(int i = 0; i < literal.length; i++) {
      total += literal[i].count;
    }
  }

  getTotal(){
    return total;
  }

  addLiteral(StockItem item, double count) {
    if (count <= 0){
      return;
    }

    literal.add(StockLiteral(item.index, item.barcode, item.category, item.description, item.uom, item.nof, item.price, count, location));
    calcTotal();
  }

  getFinalSheet(){
    List<List<dynamic>> finalSheet = [];
    List<dynamic> nofRow = [0, "NOF", "NOT ON FILE BARCODES", "MISC", 0.0, 0.0];
    for(int i =0; i < literal.length; i++){
      if(literal[i].nof){
        nofRow[4] += literal[i].count;
        nofRow[5] += literal[i].price * literal[i].count;
      }
      else{
        // if item(s) already exists in the final sheet append count and price
        int count = 0;
        for(int j = 0; j < finalSheet.length; j++) {
          if (literal[i].category == finalSheet[j][2] && finalSheet[j][1] != "NOF") {
            finalSheet[j][4] += literal[i].count;
            finalSheet[j][5] += literal[i].price * literal[i].count;
            break;
          }
          count++;
        }
        // add new item to final sheet
        if(!literal[i].nof){
          if (count >= finalSheet.length){
            finalSheet.add([
              finalSheet.length,
              "MISC",
              literal[i].category,
              literal[i].uom,
              literal[i].count,
              literal[i].price * literal[i].count
            ]);
          }
        }
      }
    }
    // add NOF row last
    nofRow[0] = finalSheet.length;
    finalSheet.add(nofRow);
    return finalSheet;
  }


  removeLiteral(int literalIndex, double count ) {
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

  addNOF(StockItem st){
    for(int n = 0; n < nof.length; n++) {
      if(nof[n].barcode == st.barcode){
        return false;
      }
    }

    nof.add(st);
    return true;
  }

  setLocation(int index){
    location = allLocations[index];
  }

  addLocation(String s){
    allLocations.add(s);
  }

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
    if (json['allLocations'] != null && json["allLocations"].isNotEmpty){
      for(final entry in jsonDecode(json['allLocations'])) {
        j.allLocations.add(entry as String);
      }
    }

    j.location = ''; // reset job location
    j.dbPath = "";// reset db path json['dbPath'] as String;
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

/*================
  StockItem
================*/
class StockItem {
  final int index;
  final String barcode;
  final String category;
  final String description;
  final String uom;
  double unit = 1;
  final double price;
  final bool nof;

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

  StockItem.fromJson(Map<String, dynamic> json)
      : index = json['index'] as int,
        barcode = json['barcode'] as String,
        category = json['category'] as String,
        description = json['description'] as String,
        uom = json['uom'] as String,
        unit = json['unit'] as double,
        price = json['price'] as double,
        nof = json['nof'] as bool;

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

/*=======================
  StockLiteral
=======================*/
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
        barcode = json['barcode'] as String,
        category = json['category'] as String,
        description = json['description'] as String,
        uom = json['uom'] as String,
        nof = json['nof'] as bool,
        price = json['price'] as double,
        count = json['count'] as double,
        location = json['location'] as String;

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

/*=======================
  masterCategory
=======================*/
List<String> masterCategory = [
    "ADMINISTRATION",
    'APPAREL',
    "AUTOMOTIVE",
    "BABY",
    "BARGAIN BIN",
    "BARGAIN BUYS",
    "BEEF",
    "BEVERAGES",
    "BEVERAGES F/S",
    "BISCUITS",
    "BREAKFAST FOODS",
    "CANNED SEAFOOD",
    "CAT FOOD",
    "CAT LITTER",
    "CHEESE",
    "CHILLED BREAD",
    "CHILLED HEALTH",
    "CHILLED JUICES & DRINKS",
    "CHILLED SPREADS",
    "CIGARETTES",
    "CIGARS",
    "CLEANING",
    "CLEANING MATERIALS",
    "CLIPSTRIPS",
    "COFFEE",
    "CONDIMENTS",
    "CONFECTIONERY",
    "COOKING NEEDS",
    "CORDIALS",
    "COSMETICS",
    "CREAM",
    "DELICATESSEN",
    "DEODORANTS",
    "DESSERT",
    "DESSERTS",
    "DESSERTS & TOPPINGS",
    "DIPS",
    "DISHWASHING",
    "DISPOSABLE",
    "DOG FOOD",
    "DRY GROCERY F/S",
    "EGGS",
    "ELECTRICAL",
    "ENERGY DRINKS",
    "FACIAL TISSUES",
    "FEMININE HYGIENE",
    "FROZEN BREAD & PASTRY",
    "FROZEN DESSERTS",
    "FROZEN DIETARY",
    "FROZEN F/S",
    "FROZEN FRUIT & SMOOTHIES",
    "FROZEN MEALS",
    "FROZEN PIES & PASTRIES",
    "FROZEN PIZZA",
    "FROZEN POTATO",
    "FROZEN POULTRY",
    "FROZEN SEAFOOD",
    "FROZEN SNACK/ENTERTAINING",
    "FROZEN VEGETABLES",
    "FRUIT",
    "GAME",
    "GARDENING PRODUCTS",
    "GENERAL MERCHANDISE F/S",
    "GM CONTINUITY",
    "GRAINS & PASTA",
    "GREEN LIFE",
    "HABERDASHERY",
    "HAIR CARE",
    "HAIR COLOUR",
    "HAIR STYLING",
    "HARDWARE",
    "HEALTH FOOD",
    "HOME BREW",
    "HOT & COLD MEALS",
    "HOUSEHOLD CLEANERS",
    "HOUSEHOLD CLEANING GM",
    "HOUSEHOLD NEEDS",
    "HOUSEWARES",
    "ICE",
    "ICE CREAM",
    "ICE TEA",
    "IN STORE BAKERY",
    "INCONTINENCE",
    "INTERNATIONAL FOOD",
    "JUICE",
    "LAMB",
    "LAUNDRY NEEDS",
    "LIFESTYLE BEVERAGES",
    "MANCHESTER",
    "MATCHES & LIGHTER",
    "MEALS",
    "MEDICINAL",
    "MENS GROOMING",
    "MILK",
    "MISC",
    "NON ALCOHOLIC BEVERAGES",
    "NON FOODS F/S",
    "NON-PRODUCT",
    "NUTRITIONAL SNACKS",
    "NUTS & JERKY",
    "OFFAL",
    "ORAL CARE",
    "OUTDOOR / LEISURE",
    "PACKAGED",
    "PAPER GOODS",
    "PARTY",
    "PASTA - FRESH",
    "PERSONAL NEEDS",
    "PET ACCESSORIES",
    "PET FOOD",
    "PET NEEDS - GM",
    "PIZZA",
    "PORK",
    "POULTRY",
    "PREPACK SALADS",
    "PRICE DRIVERS",
    "PRODUCE BEVERAGE",
    "PROPRIETARY",
    "PUBLICATIONS",
    "QUICHES & PIES",
    "REFRIGERATED & DAIRY F/S",
    "RYO",
    "SANDWICHES/WRAPS/ROLLS",
    "SEAFOOD",
    "SEAFOOD - PRE-PACKED",
    "SEASONAL",
    "SEASONAL LINES",
    "SKINCARE",
    "SMALL ANIMAL FOOD",
    "SMALLGOODS",
    "SMALLGOODS - PRE-PACKED",
    "SMOKING ACCESSORIES",
    "SNACKS",
    "SOAP & BATH",
    "SOAP & BATH",
    "SOFT DRINKS",
    "SOUPS",
    "SOUP",
    "SPORTS DRINKS",
    "SPREADS",
    "STATIONERY",
    "STORE FIXTURES",
    "STORE USE EQUIPMENT",
    "STORE USE SUPPLIES",
    "SUN CARE",
    "TOILET TISSUE",
    "TOYS",
    "TRAVEL",
    "VEGETABLES & SALADS",
    "VIRTUAL PRODUCT",
    "VITAMINS & SUPPLEMENTS",
    "WATER",
    "WIPES / WET TOWELS",
    "WOMEN'S HAIR REMOVAL",
    "YOGHURTS",
];

/*
/*=================
  Session File
=================*/

class SessionFile {
  // List<String> dirs = [];
  // String uid;
  // int pageCount;
  // double fontScale;
  // double dropScale;
  //
  // SessionFile({
  //   this.uid = "",
  //   this.pageCount = 15,
  //   this.fontScale = 12.0,
  //   this.dropScale = 50.0,
  // });

  Map<String, dynamic> newFile() {
    return{
      "dirs" : <String>[],
      "uid" : "",
      "pageCount" : 0,
      'dropScale' : 0.0,
      'fontScale' : 0.0,
    };
  }

  // Map<String, dynamic> toJson() {
  //   return {
  //     'dirs': jsonEncode(dirs),
  //     'uid': uid,
  //     'pageCount': pageCount,
  //     'dropScale' : dropScale,
  //     'fontScale' : fontScale,
  //   };
  // }

  Map<String, dynamic> fromJson(dynamic json) {
    return {
      "dirs" : jsonDecode(json['dirs']) as List<String>,
      "uid" : json['uid'] as String,
      "pageCount" : json['pageCount'] as int,
      "fontScale" : json['fontScale'] as double,
      "dropScale" : 50.0,
    };

    // for(final entry in jsonDecode(json['dirs'])) {
    //   sf["dirs"].add(entry as String);
    // }
    // sf["uid"] = json['uid'] as String;
    // sf["pageCount"] = json['pageCount'] as int;
    // sf["fontScale"] = json['fontScale'] as double;
    // //sf.dropScale = json['dropScale'] as double;
    //return sf;
  }
}
 */
