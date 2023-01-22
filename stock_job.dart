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
  //String dbPath = ""; // location of the xlsx or csv spreadsheet file (absolute path or won't work)

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is StockJob &&
              runtimeType == other.runtimeType &&
              date == other.date &&
              id == other.id &&
              name == other.name &&
              literals == other.literals &&
              nof == other.nof &&
              allLocations == other.allLocations &&
              location == other.location;
  // &&
              //dbPath == other.dbPath;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ date.hashCode ^ literals.hashCode ^ nof.hashCode ^ allLocations.hashCode ^ location.hashCode;// ^ dbPath.hashCode;

  StockJob({
    required this.id,
    required this.name,
    date,
    total,
    literals,
    nof,
    allLoctions,
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
          date : date ?? this.date,
          id : id ?? this.id,
          name : name ?? this.name,
          total: total ?? this.total,
          literals: literals ?? this.literals,
          nof: nof ?? this.nof,
          allLoctions: allLocations ?? this.allLocations
      );

  factory StockJob.fromJson(dynamic json) {
    StockJob job = StockJob(
        id: json['id'] as String,
        name: json['name'] as String
    );

    job.date = json.containsKey("date") ? json['date'] as String : "";

    job.literals = !json.containsKey("literals") || json['literals'] == null ?
    List.empty(growable: true) : [
      for (final map in jsonDecode(json['literals']))
        literalFromJson(map),
    ];

    job.nof = !json.containsKey("nof") || json['nof'] == null ?
    List.empty(growable: true) : [
      for (final n in jsonDecode(json['nof']))
        itemFromJson(n),
    ];

    job.allLocations = !json.containsKey("allLocations") || json['allLocations'] == null ?
    List.empty(growable: true) : [
          for(final l in jsonDecode(json['allLocations']))
            l as String,
    ];

    job.location = ''; // reset job location
    //job.dbPath = ""; // reset db path json['dbPath'] as String;
    return job;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
      'id': id,
      'name': name,
      'literals': jsonEncode(literals),
      'nof': jsonEncode(nof),
      'allLocations': jsonEncode(allLocations),
      //'dbPath': dbPath,
      'location': '',
    };
  }

  nofList(){
    List<List<dynamic>> n = List.empty(growable: true);
    for (var e in nof) {
      n.add(e.values.toList());
    }
    return n;
  }

  literalList(){
    List<List<dynamic>> l = List.empty(growable: true);
    for (var e in literals) {
      l.add(e.values.toList());
    }
    return l;
  }

  linearList(){
    List<List<dynamic>> l = List.empty(growable: true);
    for(int i = 0; i < literals.length; i++){
      // Add whole counts
      int count = literals[i]["count"].floor();
      while(count > 0){
        l.add(
            [
              literals[i]["index"],
              literals[i]["barcode"],
              literals[i]["category"],
              literals[i]["description"],
              literals[i]["uom"],
              1.0, // Always 1 unit
              literals[i]["price"],
              literals[i]["nof"],
            ]
        );
        count--;
      }

      // Add decimal count to last item
      double d = ((literals[i]["count"] * 10000).toInt() % 10000)/10000;
      if (d != 0) {
        l.add([
          literals[i]["index"],
          literals[i]["barcode"],
          literals[i]["category"],
          literals[i]["description"],
          literals[i]["uom"],
          d, // Remainder from whole count
          literals[i]["price"],
          literals[i]["nof"],
        ]);
      }
    }

    // Sort stock list by table index?
    l = l..sort((x, y) => (x[0] as dynamic).compareTo((y[0] as dynamic)));
    return l;
  }

  calcTotal() {
    total = 0.0;
    for(int i = 0; i < literals.length; i++) {
      total += literals[i]["count"];
    }
  }

  getFinalSheet(){
    //List<dynamic> nofRow = [-1, "MISC", "NOT ON FILE BARCODES", "MISC", 0.0, 0.0];

    List<List<dynamic>> finalSheet = [];
    for(int i =0; i < literals.length; i++){
    //   if(literal[i].nof){
    //     nofRow[4] += literal[i].count;
    //     nofRow[5] += literal[i].price * literal[i].count;
    //   }
    //   else{
        // if item(s) already exists in the final sheet append count and price
        int count = 0;
        for(int j = 0; j < finalSheet.length; j++) {
          if(finalSheet[j][0] == literals[i]["index"]){
            finalSheet[j][4] += literals[i]["count"];
            finalSheet[j][5] += literals[i]["price"] * literals[i]["count"];
          }

          // if (literal[i].category == finalSheet[j][2] && finalSheet[j][1] != "NOF") {
          //   finalSheet[j][4] += literal[i].count;
          //   finalSheet[j][5] += literal[i].price * literal[i].count;
          //   break;
          // }
          count++;
        }

        // add new item to final sheet
        // if(!literal[i].nof){
        if (count >= finalSheet.length){
          finalSheet.add([
            literals[i]['index'],
            literals[i]['category'],
            literals[i]["description"],
            literals[i]["uom"],
            literals[i]["count"],
            literals[i]["price"] * literals[i]['count'],
            literals[i]["barcode"],
            literals[i]["nof"]
          ]);
        }
        // }
      }
    // }
    // add NOF row last
    // nofRow[0] = finalSheet.length;
    // finalSheet.add(nofRow);
    return finalSheet;
  }

  bool newNOF(Map<String, dynamic> item){
    for(int n = 0; n < nof.length; n++) {
      if(nof[n]['barcode'] == item['barcode'] && nof[n]['description'] == item['description'] && nof[n]['price'] == item['price'] && nof[n]['uom'] == item['uom']){
        return false;
      }
    }
    return true;
  }
}

Map<String, dynamic> literalFromJson(Map<String, dynamic> json){
  return{
    "index" : json['index'] as int,
    "barcode" : json['barcode'] as String,
    "category" : json['category'] as String,
    "description" : json['description'] as String,
    "uom" : json['uom'] as String,
    "price" : json['price'] as double,
    "count" : json['count'] as double,
    "location" : json['location'] as String,
    "nof" : json['nof'] as bool,
  };
}

Map<String, dynamic> itemFromJson(Map<String, dynamic> json) {
  return {
    "index" : json['index'] as int,
    "barcode" : json['barcode'] as String,
    "category" : json['category'] as String,
    "description" : json['description'] as String,
    "uom" : json['uom'] as String,
    "unit" : json['unit'] as double,
    "price" : json['price'] as double,
    "nof" : json['nof'] as bool,
  };
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
    //Export Sheet Columns
    'Master Index',
    'Category',
    'Description',
    'UOM',
    'QTY',
    'Cost Ex GST',
    'Barcode',
    'NOF',
 */
