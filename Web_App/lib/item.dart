import 'dart:convert';

class ImportItem{
  String id;
  String barcode;
  String category;
  String description;
  String uom;
  String price;
  String date;
  String ordercode;
  String nof;
  String quantity;

  ImportItem({
    required this.id,
    required this.barcode,
    required this.category,
    required this.description,
    required this.uom,
    required this.price,
    required this.date,
    required this.ordercode,
    required this.nof,
    required this.quantity
  });

  /*
    indexTable = 0;
    int indexID = 0;
    int indexMaster = 1;
    int indexCategory = 2;
    int indexDescript = 3;
    int indexUOM = 4;
    int indexQTY = 5;
    int indexPrice = 6;
    int indexBarcode = 7;
    int indexNof = 8;
    int indexDate = 9;
    int indexOrdercode = 10;
  */
  factory ImportItem.fromXLSX(List<dynamic> row, int i){
    return
      ImportItem(
        id: i.toString(),
        category: row[1].toString(),
        description: row[2].toString(),
        uom: row[3].toString(),
        quantity: row[4].toString(),
        price: row[5].toString(),
        barcode: row[6] == null ? "" : row[6].toString(),
        nof: row[7].toString(),
        date: row[8].toString(),
        ordercode: row[9]  == null ? "" : row[9].toString(),
      );
  }

  String get(int index) {
    switch(index){
      case 0:
        return id;
      case 1:
        return category;
      case 2:
        return description;
      case 3:
        return uom;
      case 4:
        return quantity;
      case 5:
        return price;
      case 6:
        return barcode;
      case 7:
        return nof;
      case 8:
        return date;
      case 9:
        return ordercode;
      default:
        return "";
    }
  }
}

class Item {
  String id;
  String barcode;
  String category;
  String description;
  String uom;
  String price;
  String date;
  String ordercode;

  Item({
    required this.id,
    required this.barcode,
    required this.category,
    required this.description,
    required this.uom,
    required this.price,
    required this.date,
    required this.ordercode,
  });

  factory Item.fromXLSX(List<dynamic> row){
    return Item(
      id: row[0].toString(),
      barcode: row[1] == null ? "" : row[1].toString(),
      category: row[2].toString(),
      description: row[3].toString(),
      uom: row[4].toString(),
      price: row[5].toString(),
      date: row[6].toString(),
      ordercode: row[7]  == null ? "" : row[7].toString(),
    );
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return
      Item(
        id: json["id"] == null ? "0" : json["id"].toString(),
        barcode: json['barcode'].toString(),
        category: json['category'].toString(),
        description: json['description'].toString(),
        uom: json['uom'].toString(),
        price: json['price'].toString(),
        date: json['date'].toString(),
        ordercode: json['ordercode'] == null ? "0" : json['ordercode'].toString(),
      );
  }

  void setItem(int index, String value){
    switch(index){
      case 0:
        id = value;
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

  String get(int index) {
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



/*
  Widget titlePadding(String title, TextAlign l) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
        child: Text(title, textAlign: l),
      )
    );
  }
 */


// int _getEditCount(){
//   int count = 0;
//   for(int i = 0; i < _jobTable.length; i++){
//     int tableIndex = int.parse(_jobTable[i].id); //Index.jobMasterIndex
//     // Job table items that exist within the range of the masterTable can be compared for any changes
//     if(tableIndex < masterTable.length){
//       if(_jobTable[i].barcode != masterTable[tableIndex].barcode ||
//         _jobTable[i].category != masterTable[tableIndex].category ||
//         _jobTable[i].description != masterTable[tableIndex].description ||
//         _jobTable[i].price != masterTable[tableIndex].price ||
//         _jobTable[i].ordercode != masterTable[tableIndex].ordercode) {
//           count += 1;
//       }
//     }
//   }
//   return count;
// }
//
//
// Future<void> _filePicker() async {
//   // Load xlsx from file browser
//   html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
//   uploadInput.click();
//
//   uploadInput.onChange.listen((e) {
//     // read file content as dataURL
//     List<html.File> files = List.empty();
//     files = uploadInput.files as List<html.File>;
//     html.FileReader reader = html.FileReader();
//     final file = files[0];
//     reader.readAsArrayBuffer(file);
//
//     reader.onLoadEnd.listen((e) async {
//       if(reader.result == null){
//         setState((){
//           _isLoading = false;
//         });
//         return;
//       }
//       await _loadMasterFile(reader.result as List<int>);
//       //debugPrint(masterTable.length.toString());
//       setState((){
//         _isLoading = false;
//         showAlert(context: context, text: const Text("MASTERFILE loaded successfully"));
//       });
//     });
//   });
// }

// onChanged: (String value) {
//   setState((){
//     _filterList = List.of(_tempMasterTable);
//     if(value.isEmpty){
//         return;
//     }
//     else{
//       String searchText = value.toUpperCase();
//       bool found = false;
//       List<String> searchWords = searchText.split(" ").where((String s) => s.isNotEmpty).toList();
//       for (int i = 0; i < searchWords.length; i++) {
//         if (!found) {
//           List<List<String>> first = _filterList.where((row) =>
//               row[_searchColumn].toString().split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
//           if(first.isNotEmpty){
//             _filterList = List.of(first);
//             found = true;
//           }
//         }
//         else {
//           List<List<String>> refined =
//           _filterList.where((row) =>
//               row[_searchColumn].toString().split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
//           if(refined.isNotEmpty){
//             _filterList = List.of(refined);
//           }
//         }
//       }
//       if(!found){
//         _filterList = List.empty();
//       }
//     }
//     //setTableState();
//   });
// },

//  Future<int> httpPost({required int postType, required String email, required String pass, String? name, String? newpass}) async {
//     Map<String, String> args = {};
//     String apiCall = "";
//
//     if(postType == 1){
//       apiCall = "/api/login";
//       args = {
//         "email":email,
//         "password":pass,
//       };
//     }
//     else if(postType == 2){
//       apiCall = "/api/register";
//       args = {
//         "name":name ?? "",
//         "email":email,
//         "password":pass,
//       };
//     }
//     else if(postType == 3){
//       if(newpass == null) {
//         return -1;
//       }
//       apiCall = "/api/change";
//       args = {
//         "email":email,
//         "password":pass,
//         "newpass": newpass,
//       };
//     }
//
//     var body = json.encode(args);
//
//     Map<String, String> headers = {
//       'Content-Type': 'application/json',
//       'Charset': 'utf-8'
//     };
//
//     int statusCode = -1;
//     try{
//       await http.post(Uri.http("127.0.0.1:8000", apiCall), body: body, headers: headers).then((var response){
//         var r = jsonDecode(response.body);
//         statusCode = r["status"];
//       });
//     }
//     catch(e){
//       showNotification(context, Colors.red, whiteText, e.toString());
//     }
//
//     return statusCode;
//   }
