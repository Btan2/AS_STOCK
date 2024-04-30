import 'dart:convert';

class Item {
  int id;
  String barcode;
  String category;
  String description;
  String uom;
  String price;
  String date;
  String ordercode;

  bool nof = false;

  Item({
    required this.id,
    required this.barcode,
    required this.category,
    required this.description,
    required this.uom,
    required this.price,
    required this.date,
    required this.ordercode,
    nof = false,
  });

  factory Item.fromXLSX(List<dynamic> row, int index){
    return Item(
      id: index,
      barcode: (row[1]??"").toString(),
      category: row[2].toString(),
      description: row[3].toString(),
      uom: row[4].toString(),
      price: row[5].toString(),
      date: row[6].toString(),
      ordercode: (row[7]??"").toString(),
      nof: false,
    );
  }

  factory Item.fromImport(List<dynamic> row, int index){
    return
      Item(
        id: index,
        category: row[1].toString(),
        description: row[2].toString(),
        uom: row[3].toString(),
        price: row[5].toString(),
        barcode: (row[6]??"").toString(),
        date: row[8].toString(),
        ordercode: (row[9]??"").toString(),
        nof: row[7].toString().toLowerCase() == "true",
      );
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return
      Item(
        id: json["id"] == null ? 0 : int.parse(json["id"].toString()),
        barcode: (json['barcode']?? "").toString(),
        category: json['category'].toString(),
        description: json['description'].toString(),
        uom: json['uom'].toString(),
        price: json['price'].toString(),
        date: json['date'].toString(),
        ordercode: (json['ordercode']??"").toString(),
        nof: false,
      );
  }

  void setItem(int index, String value){
    switch(index){
      case 0:
        id = int.tryParse(value) ?? id;
        break;
      case 1:
        barcode = value;
        break;
      case 2:
        category = value;
        break;
      case 3:
        description = value;
        break;
      case 4:
        uom = value;
        break;
      case 5:
        price = value;
        break;
      case 6:
        date = value;
        break;
      case 7:
        ordercode = value;
        break;
      default:
        return;
    }
  }

  get(int index) {
    switch(index){
      case 0:
        return id;
      case 1:
        return barcode;
      case 2:
        return category;
      case 3:
        return description;
      case 4:
        return uom;
      case 5:
        return price;
      case 6:
        return date;
      case 7:
        return ordercode;
      default:
        return "";
    }
  }

  String toJson(){
    Map<String, dynamic> args = {
      "id" : id,
      "barcode" : barcode,
      "category" : category,
      "description" : description,
      "uom" : uom,
      "price" : price,
      "ordercode" : ordercode,
    };

    return json.encode(args);
  }
}
