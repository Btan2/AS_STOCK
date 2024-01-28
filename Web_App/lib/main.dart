// flutter build web --web-renderer html  
// flutter run -d chrome --web-renderer html

import 'dart:convert';

import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:async';
import 'package:http/http.dart' as http;

String versionStr = "0.23.09+1";

//If you are using an Android emulator then localhost is -> https://10.0.2.2:8000,
// otherwise localhost is -> https://127.0.0.1:8000
String localhost = "https://127.0.0.1:8000";

List<Item> masterTable = [];
List<String> masterHeader = ["ID", "Barcode", "Category", "Description", "UOM", "Price", "Date", "Ordercode"];
List<String> masterCategory = [];
TextStyle get whiteText{ return const TextStyle(color: Colors.white, fontSize: 20.0);}
TextStyle get blackText{ return const TextStyle(color: Colors.black, fontSize: 20.0);}
TextStyle get greyText{ return const TextStyle(color: Colors.black12, fontSize: 20.0);}
final Color colorOk = Colors.blue.shade400;
const Color colorError = Colors.redAccent;
final Color colorWarning = Colors.deepPurple.shade200;
bool masterfileChanged = false;

class Index {
  static const int masterIndex = 0;
  static const int masterBarcode = 1;
  static const int masterCategory = 2;
  static const int masterDescript = 3;
  static const int masterUOM = 4;
  static const int masterPrice = 5;
  static const int masterDate = 6;
  static const int masterOrdercode = 7;
  static const int jobTableIndex = 0;
  static const int jobMasterIndex = 1;
  static const int jobCategory = 2;
  static const int jobDescript = 3;
  static const int jobUOM = 4;
  static const int jobQTY = 5;
  static const int jobPrice = 6;
  static const int jobBarcode = 7;
  static const int jobNof = 8;
  static const int jobDate = 9;
  static const int jobOrdercode = 10;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /*
    RUN FUNCTIONS THAT NEED TO BE LOADED FIRST HERE
  */

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
      theme: ThemeData(
        bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
        navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget{
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPage();
}
class _LoginPage extends State<LoginPage>{
  String pass = "";
  String username = "";
  Color splashColor = colorOk;

  String isConnected = "NOT CONNECTED";

  @override
  void initState() {
    super.initState();
    splashColor = colorOk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 10.0,),
        child: Text("version $versionStr", style: const TextStyle(color: Colors.black, fontSize: 12.0), textAlign: TextAlign.center),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 35.0),
                child: Center(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height/10.0,
                    child: SvgPicture.asset("AS_logo_light.svg"),
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                width: MediaQuery.of(context).size.width,
                child: const Text('Serving Australian businesses for over 30 years!', style: TextStyle(color: Colors.blueGrey), textAlign: TextAlign.center,),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height / 10.0,
                width: MediaQuery.of(context).size.width,
              ),
              rBox(
                width: MediaQuery.of(context).size.width/4.0,
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Enter username', border: OutlineInputBorder()),
                  textAlign: TextAlign.center,
                  onChanged: (String value) {
                    username = value;
                    setState(() {});
                  }
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height/40.0,
              ),
              rBox(
                width: MediaQuery.of(context).size.width/4.0,
                child: TextField(
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Enter password', border: OutlineInputBorder()),
                  textAlign: TextAlign.center,
                  onChanged: (String value) {
                    setState(() {
                      pass = value;
                    });
                  }
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height/40.0,
              ),
              TapRegion(
                onTapInside: (value) async{
                  setState(() {
                    splashColor = Colors.green;
                  });
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MainPage()));
                  // if(pass == "pass" && username == "andy"){
                  //   setState(() {
                  //     splashColor = Colors.green;
                  //   });
                  //   Navigator.push(context, MaterialPageRoute(builder: (context) => const MainPage()));
                  //   return;
                  // }
                  // else{
                  //  setState((){
                  //    splashColor = colorError;
                  //  });
                  //  await Future.delayed(const Duration(milliseconds: 500));
                  //  setState(() {
                  //    splashColor = colorOk;
                  //  });
                  // }
                  },
                  child: rBox(
                    width: MediaQuery.of(context).size.width/4.0,
                    child: Material(
                      color: splashColor,
                      borderRadius: BorderRadius.circular(20.0),
                      child: const Center(child: Text("Login", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20.0))),
                    )
                  )
              ),
              SizedBox(height:25),
              ElevatedButton(
                onPressed:() async{
                  Map<String, String> headers = {
                    'Content-Type': 'application/json',
                    'Charset': 'utf-8'
                  };

                  Map<String,String> args = {
                      "barcode" : "12345",
                      "category" : "CONSUMABLE",
                      "description" : "NUKA COLA QUANTUM",
                      "uom" : "EACH",
                      "price" : '3.50',
                      "ordercode" : '54321',
                  };

                  var body = json.encode(args);
                  //await http.get(Uri.http("127.0.0.1:8000", "/api/addTest"));
                  await http.post(Uri.http("127.0.0.1:8000", "/api/addTest"), body: body, headers: headers).then((var response){
                     String e = response.statusCode.toString();
                     showAlert(context: context, text: Text("Response: $e"));
                  });
                },
                child:Text("TEST UPLOAD"),
              )
            ]
          )
        )
      ),
    );
  }
}

class MainPage extends StatefulWidget{
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPage();
}
class _MainPage extends State<MainPage>{
  String _loadingMsg = "Loading...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    if(masterTable.isEmpty){
      _loadFromServer();
    }
    else{
     _isLoading = false;
    }
  }

  @override
  void dispose(){
    super.dispose();
  }

  Future<int> _loadDBDialog(BuildContext context) async {
    // 0 = SERVER,
    // 1 = STORAGE,
    // -1 = CANCEL,
    int confirmation = -1;

    await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: colorOk.withOpacity(0.8),
        builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: SingleChildScrollView(
                child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Center(
                        child: AlertDialog(
                          actionsAlignment: MainAxisAlignment.spaceAround,
                          actionsPadding: const EdgeInsets.all(20.0),
                          titlePadding: const EdgeInsets.all(20.0),
                          title: const Text("Load Masterfile", textAlign: TextAlign.center,),
                          actions: <Widget>[
                            Center(
                                child: Column(
                                    //crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      const SizedBox(height: 5.0),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: colorError),
                                        onPressed: () {
                                          confirmation = 0;
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Load from SERVER"),
                                      ),
                                      const SizedBox(height: 15.0),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                                        onPressed: () {
                                          confirmation = 1;
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Load from LOCAL STORAGE"),
                                      ),
                                      const SizedBox(height: 25.0),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                                          onPressed:(){
                                            confirmation = -1;
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Cancel")
                                      )
                                    ]
                                )
                            )
                          ],
                        )
                    )
                )
            )
        )
    );

    return confirmation;
  }

  Future<void> _loadFromServer() async {
    /*
      REQUIRES THIS RUN COMMAND FOR NOW, LOOK UP AND CHANGE WHEN ONLINE SERVER IS ESTABLISHED
        flutter run -d chrome --web-browser-flag "--disable-web-security"
    */
    try{
      setState((){
        _loadingMsg = "Performing GET request...";
      });
      await Future.delayed(const Duration(seconds: 1));

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Charset': 'utf-8'
      };

      Uri uri = Uri.http('127.0.0.1:8000', '/api/items');

      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) {
        setState(() {
          _isLoading = false;
          showAlert(context: context, text: const Text("Failed to get response from server..."));
        });

        return;
      }

      var jsn = jsonDecode(response.body.toString());

      masterTable = List.empty(growable: true);

      setState(() {
        _loadingMsg = "Loading table...";
      });
      await Future.delayed(const Duration(seconds: 1));

      for (final map in jsn) {
        masterTable.add(Item.fromJson(map));
      }

      setState(() {
        _loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(seconds: 1));

      masterCategory = List<String>.generate(masterTable.length, (index) => masterTable[index].category.toString().toUpperCase()).toSet().toList();

      setState(() {
        _isLoading = false;
      });
    }
    catch(e){
      showAlert(context: context, text: Text("!! Error while loading MASTERFILE !!\n$e"), color: Colors.red);
    }
  }

  Future<void> _loadFromStorage() async{
    var file = await pickFile('xlsx');
    if(file == null){
      setState((){
        _isLoading = false;
      });
      return;
    }

    html.FileReader reader = html.FileReader();
    reader.readAsArrayBuffer(file);// as html.File);
    reader.onLoadEnd.listen((e) async {
      if(reader.result == null){
        setState((){
          _isLoading = false;
        });
        return;
      }

      await _decodeXLSX(reader.result as List<int>);

      setState((){
        _isLoading = false;
      });
    });
  }

  Future<void> _decodeXLSX(List<int> bytes) async {
    if(bytes.isEmpty){
      _loadingMsg = "...";
      return;
    }

    setState((){
      masterTable = List.empty();
      _loadingMsg = "Decoding spreadsheet...";
    });

    try{
      await Future.delayed(const Duration(seconds: 1));

      var decoder = SpreadsheetDecoder.decodeBytes(bytes);
      var sheets = decoder.tables.keys.toList();
      if(sheets.isEmpty){
        return;
      }

      SpreadsheetTable? table = decoder.tables[sheets.first];
      if(table!.rows.isEmpty || table.rows[0].length != 8){
        return;
      }

      //setState((){
      //  _loadingMsg = "Creating header row...";
      //});
      //await Future.delayed(const Duration(milliseconds:500));

      //masterHeader = List.generate(table.rows[0].length, (index) => table.rows[0][index].toString().toUpperCase());

      setState((){
        _loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      masterCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][2].toString().toUpperCase()).toSet().toList();

      setState((){
        _loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      masterTable = List.empty(growable:true);
      for(var row in table.rows) {
        masterTable.add(Item.fromXLSX(row));
      }

      //masterTable = List.generate(table.rows.length, (index) => Item.fromXLSX(table.rows[index]));
        // List<String>.generate(masterHeader.length, (index2) =>
        //     index2 == Index.masterDate ? getDateString(string: table.rows[index][index2].toString()) :
        //       table.rows[index][index2].toString().toUpperCase()
        // )
      //);

      masterTable.removeAt(0); // Remove header from main

      setState((){
        _loadingMsg = "...";
      });
    }
    catch (e){
      //debugPrint("The Spreadsheet has errors:\n ---> $e");
      showAlert(context: context, text: Text("An error occurred:\n ---> $e"));
    }
  }

  _exportXLSX() async {
    setState((){
      _loadingMsg = "Creating XLSX document...";
    });
    await Future.delayed(const Duration(milliseconds:500));

    var exportExcel = excel.Excel.createExcel();
    var sheetObject = exportExcel['Sheet1'];
    sheetObject.isRTL = false;

    setState((){
      _loadingMsg = "Creating table header...";
    });
    await Future.delayed(const Duration(milliseconds:500));

    // Add header row
    sheetObject.insertRowIterables(["Poduct ID", "Barcode (multi) #", "Category", "Description", 'UOM', "Price", "Datetime", "Ordercode"], 0,);

    setState((){
      _loadingMsg = "Creating table rows...";
    });
    await Future.delayed(const Duration(milliseconds:500));

    for(int i = 0; i < masterTable.length; i++){
      sheetObject.insertRowIterables(
          <String> [
            masterTable[i].id,
            masterTable[i].barcode,
            masterTable[i].category,
            masterTable[i].description,
            masterTable[i].uom,
            masterTable[i].price,
            masterTable[i].date,
            masterTable[i].ordercode
          ],
          i+1
      );
      String dateFormat = getDateString(string: masterTable[i].date);
      int yearThen = int.parse(dateFormat.split("/").last);

      // Get last two year digits using modulus
      int diff = (DateTime.now().year % 100) - (yearThen % 100);

      // Color code cell if date is older than 1 year
      if(diff > 0){
        excel.CellIndex cellIndex = excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i+1);
        sheetObject.cell(cellIndex).cellStyle = excel.CellStyle(backgroundColorHex: '#FF8980', fontSize: 10, fontFamily: excel.getFontFamily(excel.FontFamily.Arial));
      }
    }

    setState((){
      _loadingMsg = "Setting column widths...";
    });
    await Future.delayed(const Duration(milliseconds:500));

    // Set column widths
    sheetObject.setColWidth(0, 15.0); // INDEX
    sheetObject.setColWidth(1, 25.0); // Barcode
    sheetObject.setColWidth(2, 25.0); // Category
    sheetObject.setColWidth(3, 75.0); // Description
    sheetObject.setColWidth(4, 15.0); // UOM
    sheetObject.setColWidth(5, 25.0); // Price
    sheetObject.setColWidth(6, 25.0); // Datetime
    sheetObject.setColWidth(7, 15.0); // Ordercode

    String filename = "MASTERFILE_${DateTime.now().month}_${DateTime.now().year}.xlsx";
    exportExcel.save(fileName: filename);

    //var fileBytes = exportExcel.save(fileName: filename);
    // html.AnchorElement()
    //   ..href = ("data:application/octet-stream;charset=utf-16le;base64,${base64.encode(fileBytes!)}")//'${Uri.dataFromBytes(fileBytes!, mimeType: 'text/xlsx')}'
    //   ..download = filename
    //   ..setAttribute("download", filename)
    //   ..style.display = 'none'
    //   ..click();

    setState((){
      _isLoading = false;
      _loadingMsg = "Loading...";
    });
  }

  _postRequest() async{
    var args = masterTable.map((e){
      return {
        "barcode" : e.barcode,
        "category" : e.category,
        "description" : e.description,
        "uom" : e.uom,
        "date" : getDateString(string: e.date),
        "price" : e.price,
        "ordercode" : e.ordercode,
      };
    }).toList();
    var body = json.encode(args);

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Charset': 'utf-8'
    };

    //Map<String, String> headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};

    setState((){
      _isLoading = true;
      _loadingMsg = "Performing POST request...";
    });

    try{
      await Future.delayed(const Duration(seconds: 1));

      await http.post(Uri.http("127.0.0.1:8000", "/api/updateItems"), body: body, headers: headers).then((var response){
        if(response.statusCode != 200){
          showAlert(context: context, text: Text("POST request was performed with possible errors...\nStatus code: ${response.statusCode}"), color: colorWarning);
        }
        else {
          showAlert(context: context, text: const Text("POST request completed successfully."));
        }

        setState((){
          masterfileChanged = false;
          _isLoading = false;
          _loadingMsg = "...";
        });
      });
    }
    catch(e){
      setState((){
        _isLoading = false;
        _loadingMsg = "...";
      });

      showAlert(context: context, text: Text("An Error Occurred: \n$e"), color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset("AS_logo_light.svg", height: 50),
        leading: null,
        // need to pop context correctly
      ),
      body: SingleChildScrollView(
          child: Center(
              child: Column(
                children: _isLoading ? [
                  SizedBox(height: MediaQuery.of(context).size.height/3),
                  Text(_loadingMsg, textAlign: TextAlign.center, style: blackText),
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),//SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
                  )
                ] : [
                  SizedBox(
                    height: MediaQuery.of(context).size.height/4,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        int value = await _loadDBDialog(context);
                        if(value == 0){
                          setState((){
                            _isLoading = true;
                            _loadingMsg = "...";
                          });
                          await _loadFromServer();
                        }
                        else if(value == 1){
                          setState((){
                            _isLoading = true;
                            _loadingMsg = "...";
                          });
                          await _loadFromStorage();
                        }
                      },
                      child: const Text("Sync MASTERFILE"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if(masterTable.isNotEmpty){
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterTableView()));
                        }
                      },
                      child: const Text("View MASTERFILE"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if(masterTable.isNotEmpty){
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const JobTableView()));
                        }
                        else{
                          showAlert(context: context, text: const Text("Load MASTERFILE before opening Job File!"));
                        }
                      },
                      child: const Text("Load Job File"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async{
                        await confirmDialog(context, "Commit changes to database?").then((value){
                          if(value){
                            _postRequest();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, // Background color
                      ),
                      child: const Text("Update DATABASE"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async{
                        setState((){
                          _isLoading = true;
                        });
                        _exportXLSX();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                      ),
                      child: const Text("Export MASTERFILE (.xlsx)"),
                    ),
                  ),
                  const SizedBox(
                    height: 25.0,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: () async {
                          if(!_isLoading){
                             if(masterfileChanged){
                               await confirmDialog(context, "ALERT: \nMASTERFILE was edited. Commit changes to database?").then((value) async{
                                 if(value){
                                    await _postRequest().then((){
                                      masterTable = [];
                                      masterHeader = [];
                                      masterCategory = [];
                                      Navigator.pop(context);
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                                    });
                                 }
                               });
                             }
                            else {
                               masterTable = [];
                               masterHeader = [];
                               masterCategory = [];
                               Navigator.pop(context);
                               Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                             }
                          }
                        },
                        child: const Text("LOGOUT")
                    ),
                  ),
                ]
              )
          )
      )
    );
  }
}

class JobTableView extends StatefulWidget{
  const JobTableView({super.key});
  @override
  State<JobTableView> createState() => _JobTableView();
}
class _JobTableView extends State<JobTableView>{
  final TextEditingController _searchCtrl = TextEditingController();
  String _loadingMsg = "Loading...";
  bool _selectAll = false;
  bool _isLoading = false;
  int _searchColumn = Index.jobDescript;
  int nofCount = 0;
  int editCount = 0;
  List<List<String>> _jobTable = [];
  List<String> _jobHeader = [];
  List<List<String>> _filterList = [];
  List<int> checkList = [];

  @override
  void initState() {
    super.initState();
    _pickJobFile();
  }

  @override
  void dispose(){
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _searchBar(double width){
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colorOk,
        border: Border.all(
          color: colorOk,
          style: BorderStyle.solid,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(20.0),
      ),

      child: ListTile(
        leading: PopupMenuButton(
          icon: const Icon(Icons.manage_search, color: Colors.white),
          itemBuilder: (context) {
            return List.generate(_jobHeader.length, (index) =>
                PopupMenuItem<int> (

                  value: index,
                  child: ListTile(
                    title: Text("Search ${_jobHeader[index]}"),
                    trailing: index == _searchColumn ? const Icon(Icons.check) : null,
                  ),
                )
            );
          },
          onSelected: (value) async {
            setState((){
              _searchColumn = value;
            });
          }
        ),

        title: TextFormField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: "Search ${_jobHeader[_searchColumn].toLowerCase()}...",
            border: InputBorder.none,
          ),

          onChanged: (String value) {
            setState((){
              _filterList = List.of(_jobTable);
              if(value.isEmpty){
                return;
              }

              String searchText = value.toUpperCase();
              bool found = false;
              List<String> searchWords = searchText.split(" ").where((String s) => s.isNotEmpty).toList();
              List<List<String>> refined = [[]];

              for (int i = 0; i < searchWords.length; i++) {
                if (!found){
                  _filterList = _jobTable.where((row) => row[_searchColumn].contains(searchWords[i])).toList();
                  found = _filterList.isNotEmpty;
                }
                else{
                  refined = _filterList.where((row) => row[_searchColumn].contains(searchWords[i])).toList();
                  if(refined.isNotEmpty){
                    _filterList = List.of(refined);
                  }
                }
              }
              if(!found){
                _filterList = List.empty();
              }
            });
          },
        ),

        trailing: IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () {
            setState((){
              _searchCtrl.clear();
              _filterList = List.of(_jobTable);
              //setTableState();
            });
          },
        ),
      )
    );
  }

  void _pickJobFile() async{
    final file = await pickFile('');
    if(file == null){
      setState((){
        _isLoading = false;
      });

      return;
    }

    html.FileReader reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onError.listen((fileEvent) {
      setState((){_isLoading = false;});
      return;
    });

    reader.onLoadEnd.listen((e) async {
      if(reader.result == null){
        setState((){
          _isLoading = false;
        });
      }
      else{
        await _loadJobSheet(reader.result as List<int>);
        setState((){
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadJobSheet(List<int> bytes) async{
    if(bytes.isEmpty){
      setState((){
        _loadingMsg = "...";
      });
      return;
    }

    setState((){
      _jobTable = List.empty();
      _loadingMsg = "Decoding spreadsheet...";
    });
    await Future.delayed(const Duration(seconds: 1));

    try{
      var decoder = SpreadsheetDecoder.decodeBytes(bytes);
      var sheets = decoder.tables.keys.toList();
      if(sheets.isEmpty){
        return;
      }

      SpreadsheetTable? table = decoder.tables[sheets.first];
      if(table!.rows.isEmpty){
        return;
      }

      setState((){
        _loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      //_jobCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][0].toString().toUpperCase()).toSet().toList();

      setState((){
        _loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      _jobTable = List.generate(table.rows.length, (index) =>
        // Need to add extra index column as the MASTER INDEX will not be linear
        [(index-1).toString()] + List<String>.generate(table.rows[0].length, (index2) =>
            index2 - 1 == Index.jobDate ? getDateString(string: table.rows[index][index2].toString().toUpperCase())
                : table.rows[index][index2].toString().toUpperCase()
        )
      );

      _jobHeader = ["INDEX"] + List.generate(
          table.rows[0].length, (index) => table.rows[0][index].toString().toUpperCase()
      );

      _jobTable.removeAt(0); // Remove header from main

      setState((){
        _filterList = List.of(_jobTable);
        //_isChecked = List<bool>.filled(_jobTable.length, false);
      });
    }
    catch (e){
      _loadingMsg = "The Spreadsheet has errors:\n ---> $e";
    }
  }

  Widget _getHeader(){
    double cellHeight = 50.0;
    double cellWidth = 75.0;

    cellFit(int index){
      return Expanded(
          flex: 1,
          child: Container(
              height: cellHeight,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: Colors.black,
                  style: BorderStyle.solid,
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  _jobHeader[index],
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  softWrap: true,
                ),
              )
          )
      );
    }

    cell(int index){
      return Container(
          width: cellWidth,
          height: cellHeight,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: Colors.black,
              style: BorderStyle.solid,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              _jobHeader[index],
              textAlign: TextAlign.center,
              maxLines: 4,
              softWrap: true,
            ),
          )
      );
    }

    return Row(
        children:
        <Widget>[
          SizedBox(
          height: cellHeight,
          width: cellWidth,
          child: Checkbox(
              value: _selectAll,
              onChanged: (value){
                setState((){
                  _selectAll = _selectAll ? false : true;
                  checkList.clear();
                  if(_selectAll){
                    for(int f = 0; f < _filterList.length; f++){
                      checkList.add(int.parse(_filterList[f][Index.masterIndex]));
                    }
                  }
                });
              }
          )
        )] + List.generate(_jobHeader.length, (index) =>
          index != Index.jobMasterIndex && index != Index.jobTableIndex && index != Index.jobPrice && index != Index.jobQTY ? cellFit(index) : cell(index)
        )
    );
  }

  Widget _getRow(int tableIndex){
    double cellHeight = 50.0;
    double cellWidth = 75.0;

    cellFit(int index){
      return Expanded(
          flex: 1,
          child: Container(
              height: cellHeight,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: Colors.black,
                  style: BorderStyle.solid,
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  _jobTable[tableIndex][index],
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  softWrap: true,
                ),
              )
          )
      );
    }

    cell(int index){
      return Container(
          height: cellHeight,
          width: cellWidth,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: Colors.black,
              style: BorderStyle.solid,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              _jobTable[tableIndex][index],
              textAlign: TextAlign.center,
              maxLines: 4,
              softWrap: true,
            ),
          )
      );
    }

    return Row(
      children: <Widget>[
        SizedBox(
          height: cellHeight,
          width: cellWidth,
          child: Checkbox(
              value: checkList.contains(tableIndex),
              onChanged: (value){
                setState((){
                  //_isChecked[tableIndex] = _isChecked[tableIndex] ? false : true;
                  if(checkList.contains(tableIndex)){
                    checkList.remove(tableIndex);
                  }
                  else{
                    checkList.add(tableIndex);
                    //_addList.remove(_jobTable[tableIndex]);
                  }
                });
              }
          )
        )
      ] + List.generate(_jobTable[tableIndex].length, (index) =>
      index != Index.jobMasterIndex && index != Index.jobPrice && index != Index.jobTableIndex && index != Index.jobQTY ? cellFit(index) : cell(index),
      )
    );
  }

  int _getEditCount(){
    int count = 0;
    for(int i = 0; i < _jobTable.length; i++){
      int tableIndex = int.parse(_jobTable[i][Index.jobMasterIndex]);
      if(tableIndex < masterTable.length){
        if(_jobTable[i][Index.jobBarcode] != masterTable[tableIndex].barcode ||
          _jobTable[i][Index.jobCategory] != masterTable[tableIndex].category ||
          _jobTable[i][Index.jobDescript] != masterTable[tableIndex].description ||
          _jobTable[i][Index.jobPrice] != masterTable[tableIndex].price ||
          _jobTable[i][Index.jobOrdercode] != masterTable[tableIndex].ordercode) {
            count += 1;
        }
      }
    }
    return count;
  }

  void _showChangedItems() {
    _filterList = List.empty(growable: true);

    // Go through both tables and check for any differences
    for(int i = 0; i < _jobTable.length; i++){
      int tableIndex = int.parse(_jobTable[i][Index.jobMasterIndex]);
      if(tableIndex < masterTable.length){
        if(_jobTable[i][Index.jobBarcode] != masterTable[tableIndex].barcode ||
            _jobTable[i][Index.jobCategory] != masterTable[tableIndex].category ||
            _jobTable[i][Index.jobDescript] != masterTable[tableIndex].description ||
            _jobTable[i][Index.jobPrice] != masterTable[tableIndex].price ||
            _jobTable[i][Index.jobOrdercode] != masterTable[tableIndex].ordercode) {
          _filterList.add(_jobTable[i]);
        }
      }
    }

    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width * 0.9;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset("AS_logo_light.svg", height: 50),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: (){
            Navigator.pop(context);
          },
        )
      ),
      body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _isLoading ? Center(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height/3),
                  Text(_loadingMsg, textAlign: TextAlign.center, style: blackText),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
                  )
                ]
              )
            ) : Center(
                child: Column(
              children: [
                Container(
                  width: width,
                  height: MediaQuery.of(context).size.height/12.0,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withOpacity(0.5),
                      style: BorderStyle.solid,
                      width: 1.0,
                    ),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: 1,
                    itemBuilder: (context, index) {
                      return _getHeader();
                    },
                  ),
                ),
                Container(
                  width: width,
                  height: MediaQuery.of(context).size.height * 0.56,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withOpacity(0.5),
                      style: BorderStyle.solid,
                      width: 1.0,
                    ),
                  ),
                  child: _filterList.isNotEmpty ? ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filterList.length,
                    prototypeItem: _getRow(int.parse(_filterList.first[0])),
                    itemBuilder: (context, index) {
                      return _getRow(int.parse(_filterList[index][0]));
                    },
                  ) : Text("EMPTY", style: greyText, textAlign: TextAlign.center,)
                ),
                const SizedBox(
                  height: 5.0,
                ),
                _searchBar(width),
                const SizedBox(
                  height: 5.0,
                ),
                _searchCtrl.text.isEmpty ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      _showChangedItems();
                    },
                    child: const Text("Show Edited Items"),
                  ),
                ) : Container(),
                _searchCtrl.text.isEmpty ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: (){
                      setState((){
                        _filterList = _filterList.length != _jobTable.length ? List.of(_jobTable) :
                        _jobTable.where((row) => row[Index.jobNof].toString().toUpperCase() == "TRUE").toList();
                      });
                    },
                    child: _filterList.length == _jobTable.length ? const Text("Show NOF List") : const Text("Show Full List"),
                  ),
                ) : Container(),
                checkList.isNotEmpty ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      //int nofCount = jobTable.where((row) => row[Index.jobNof].toString().toUpperCase() == "TRUE").length;
                      int editCount = _getEditCount();
                      await confirmDialog(context, "Add selected items to MASTERFILE?\nAdd Items: ${checkList.length} \nEdited Items: $editCount").then((value){
                        setState((){
                          for(int j = 0; j < checkList.length; j++){
                            int index = checkList[j];
                            bool isNof = _jobTable[index][Index.jobNof].toString().toUpperCase() == "TRUE";
                            if(isNof){
                              masterTable.add(
                                Item(
                                  id: masterTable.length.toString(),
                                  barcode: _jobTable[index][Index.jobBarcode],
                                  category: _jobTable[index][Index.jobCategory],
                                  description: _jobTable[index][Index.jobDescript],
                                  uom: "EACH",
                                  price: _jobTable[index][Index.jobPrice],
                                  date: _jobTable[index][Index.jobDate],
                                  ordercode: _jobTable[index][Index.jobOrdercode]
                                )
                              );
                            }
                            else {
                              masterTable[index].barcode = _jobTable[index][Index.jobBarcode];
                              masterTable[index].category = _jobTable[index][Index.jobCategory];
                              masterTable[index].description = _jobTable[index][Index.jobDescript];
                              masterTable[index].price = _jobTable[index][Index.jobPrice];
                              masterTable[index].ordercode = _jobTable[index][Index.jobOrdercode];
                              masterTable[index].date = _jobTable[index][Index.jobBarcode];
                            }
                          }
                        });
                      });
                    },
                    child: const Text("Add to MASTERFILE")
                ),
              ) : Container(),
            ],
          ))
        )
      )
    );
  }
}

class MasterTableView extends StatefulWidget{
  const MasterTableView({super.key});
  @override
  State<MasterTableView> createState() => _MasterTableView();
}
class _MasterTableView extends State<MasterTableView>{
  int _searchColumn = Index.masterDescript;
  List<int> _editedItems = [];
  final List<TextEditingController> _editCtrl = List.generate(6, (index) => TextEditingController());
  final TextEditingController _searchCtrl = TextEditingController();
  List<Item> _tempMasterTable = [];
  List<Item> _filterList = [];
  int barcodeIndex = 0;
  int ordercodeIndex = 0;
  List<String> barcodeList = [];
  List<String> ordercodeList = [];

  @override
  void initState() {
    super.initState();
    _tempMasterTable = List.of(masterTable);
    _filterList = List.of(_tempMasterTable);
  }

  @override
  void dispose(){
    for(int c = 0; c < _editCtrl.length; c++){
      _editCtrl[c].dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  _sortList(){
    // sort by desciption text 0-9->a-z
    // calc new indices
    _tempMasterTable.sort((x, y) => (x.description).compareTo((y.description)));

    //Calc new indices from list
    for(int i = 0; i < _tempMasterTable.length; i++){
      _tempMasterTable[i].id = i.toString();
    }
  }

  Widget _headerPadding(String title, TextAlign l) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 10.0, bottom: 5),
      child: Text(title, textAlign: l, style: const TextStyle(color: Colors.blue,)),
    );
  }

  // Edit item or add new item
  _editDialog({required BuildContext context, Item? item, Color? color}) {
    bool newItem = false;
    Item editedItem;
    if(item == null){
      newItem = true;
      editedItem = Item(
        id: '-1',
        barcode: ' ',
        category: 'MISC',
        description: 'NEW ITEM',
        uom: 'EACH',
        price: '0.0',
        date: getDateString(),
        ordercode: ' '
      );
    }
    else{
      editedItem = item;
    }

    editField(int itemIndex, int ctrlIndex){
      _editCtrl[ctrlIndex].text = editedItem.id;
      return Padding(
        padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 5.0, bottom: 5),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _headerPadding(masterHeader[itemIndex], TextAlign.left),
            ),
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: TextFormField(
                  controller: _editCtrl[ctrlIndex],
                    maxLines: 1,
                    onChanged: (value){
                      editedItem.set(itemIndex, value);
                    },
                  ),
                )
            ),
          ]
        )
      );
    }

    categoryDropField(int ctrlIndex) {
      _editCtrl[ctrlIndex].text = editedItem.category;
      return Padding(
        padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 5.0, bottom: 5),
        child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _headerPadding(masterHeader[Index.masterCategory], TextAlign.left),
              ),
              ListTile(
                  trailing: PopupMenuButton(
                      icon: const Icon(Icons.arrow_downward, color: Colors.black),
                      itemBuilder: (context){
                        return List.generate(masterCategory.length, (index) =>
                            PopupMenuItem<int>(
                              value: index,
                              child: ListTile(
                                title: Text(masterCategory[index]),
                              ),
                            )
                        );
                      },
                      onSelected: (value) async{
                        setState(() {
                          _editCtrl[ctrlIndex].text = masterCategory[value];
                          editedItem.category = masterCategory[value];
                        });
                      }
                  ),
                  title: TextFormField(
                    textAlign: TextAlign.center,
                    controller: _editCtrl[ctrlIndex],
                    style: const TextStyle(color: Colors.black),
                    maxLines: 1,
                    enabled: false,
                  )
              )
            ]
        )
      );
    }

    listField(int itemIndex, int ctrlIndex){
      bool isBarcode = itemIndex == Index.masterBarcode;
      _editCtrl[ctrlIndex].text = isBarcode ? barcodeList[barcodeIndex] : ordercodeList[ordercodeIndex];
      return Column(
        children:[
          Align(
            alignment: Alignment.centerLeft,
            child: _headerPadding(masterHeader[itemIndex], TextAlign.left),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: (){
                  setState((){
                    if(isBarcode){
                      if(barcodeIndex > 0){
                        barcodeIndex--;
                        _editCtrl[ctrlIndex].text = barcodeList[barcodeIndex];
                      }
                    }
                    else{
                      if(ordercodeIndex > 0){
                        ordercodeIndex--;
                        _editCtrl[ctrlIndex].text = ordercodeList[ordercodeIndex];
                      }
                    }
                  });
                },
              ),
              Flexible(
                child: TextFormField(
                    textAlign: TextAlign.center,
                    controller: _editCtrl[ctrlIndex],
                    maxLines: 1,
                    onChanged: (value){
                      setState((){
                        if(isBarcode){
                          barcodeList[barcodeIndex] = value;
                        }
                        else{
                          ordercodeList[ordercodeIndex] = value;
                        }
                      });
                    }
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: (){
                    setState((){
                      if(isBarcode){
                        if(barcodeIndex < barcodeList.length - 1){
                          barcodeIndex++;
                          _editCtrl[ctrlIndex].text = barcodeList[barcodeIndex];
                        }
                      }
                      else{
                        if(ordercodeIndex < ordercodeList.length - 1){
                          ordercodeIndex++;
                          _editCtrl[ctrlIndex].text = ordercodeList[ordercodeIndex];
                        }
                      }
                    });
                  }
              )
            ],
          ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                    icon: const Icon(Icons.fiber_new, color: Colors.blue),
                    onPressed: (){
                      setState((){
                        if(isBarcode){
                          barcodeList.add("");
                          barcodeIndex = barcodeList.length - 1;
                          _editCtrl[ctrlIndex].text = barcodeList[barcodeIndex];
                        }
                        else{
                          ordercodeList.add("");
                          ordercodeIndex = ordercodeList.length - 1;
                          _editCtrl[ctrlIndex].text = ordercodeList[ordercodeIndex];
                        }
                      });
                    }
                ),
                Flexible(
                    child: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: (){
                          setState((){
                            if(isBarcode){
                              // Remove if more than 1 barcode in list
                              if(barcodeList.length > 1){
                                barcodeList.removeAt(barcodeIndex);
                                barcodeIndex--;
                              }
                              else{
                                // Clear barcode at index 0
                                barcodeList[barcodeIndex] = "";
                              }
                              _editCtrl[ctrlIndex].text = barcodeList[barcodeIndex];
                            }
                            else{
                              // Remove if more than 1 barcode in list
                              if(ordercodeList.length > 1){
                                ordercodeList.removeAt(ordercodeIndex);
                                ordercodeIndex--;
                              }
                              else{
                                // Clear barcode at index 0
                                ordercodeList[ordercodeIndex] = "";
                              }
                              _editCtrl[ctrlIndex].text = ordercodeList[ordercodeIndex];
                            }
                          });
                        }
                    )
                ),
              ]
          ),
        ],
      );
    }

    return showDialog(
        barrierDismissible: false,
        context: context,
        barrierColor: color ?? colorOk,
        builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: SingleChildScrollView(
              child: AlertDialog(
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actionsPadding: const EdgeInsets.all(20.0),
                content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: MediaQuery.of(context).size.height * 0.75,
                    child: SingleChildScrollView(
                      child: Column(
                        textDirection: TextDirection.ltr,
                        children: [
                          editField(Index.masterDescript, 0),
                          editField(Index.masterPrice,1),
                          categoryDropField(2),
                          editField(Index.masterUOM,3),
                          listField(Index.masterBarcode,4),
                          listField(Index.masterOrdercode,5)
                        ]
                      ),
                    )
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                    child: Text("Cancel", style: whiteText),
                    onPressed: (){
                      Navigator.pop(context);
                    },
                  ),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                      child: Text("Save", style: whiteText),
                      onPressed: () {
                        setState((){
                          // format bcodeList
                          editedItem.id = ""; //[Index.masterBarcode]
                          for(int b = 0; b < barcodeList.length; b++){
                            if(b < barcodeList.length -1){
                              editedItem.barcode += "${barcodeList[b]},";
                            }
                            else{
                              editedItem.barcode += barcodeList[b];
                            }
                          }
                          editedItem.ordercode = "";
                          for(int o = 0; o < ordercodeList.length; o++){
                            if(o < ordercodeList.length -1){
                              editedItem.ordercode += "${ordercodeList[o]},";
                            }
                            else{
                              editedItem.ordercode += ordercodeList[o];
                            }
                          }

                          editedItem.date = getDateString();

                          int tableIndex = int.parse(editedItem.id); //masterIndex

                          if(newItem){
                            _tempMasterTable.add(editedItem);
                            _filterList = List.of(_tempMasterTable);
                          }
                          else{
                            _tempMasterTable[tableIndex] = editedItem;
                          }

                          if(!_editedItems.contains(tableIndex)){
                            _editedItems.add(tableIndex);
                          }
                        });
                        Navigator.pop(context);
                      }
                  ),
                ],
              ),
            )
        )
    );
  }

  Widget _searchBar(double width){
    return Container(
        width: width,
        decoration: BoxDecoration(
          color: colorOk,
          border: Border.all(
            color: colorOk,
            style: BorderStyle.solid,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(20.0),
        ),

        child: ListTile(
          // Change search column
          leading: PopupMenuButton(
              icon: const Icon(Icons.manage_search, color: Colors.white),
              itemBuilder: (context) {
                return List.generate(masterHeader.length, (index) =>
                    PopupMenuItem<int> (
                      value: index,
                      child: ListTile(
                        title: Text("Search ${masterHeader[index]}"),
                        trailing: index == _searchColumn ? const Icon(Icons.check) : null,
                      ),
                    )
                );
              },
              onSelected: (value) async {
                setState((){
                  _searchColumn = value;
                });
              }
          ),

          title: TextFormField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: "Search ${masterHeader[_searchColumn].toLowerCase()}...",
              border: InputBorder.none,
            ),
            onChanged: (String value) {
              setState((){
                _filterList = List.of(_tempMasterTable);

                if(value.isEmpty){
                  return;
                }

                String searchText = value.toUpperCase();
                bool found = false;
                List<String> searchWords = searchText.split(" ").where((String s) => s.isNotEmpty).toList();
                List<Item> refined = [];

                for (int i = 0; i < searchWords.length; i++) {
                  if (!found){
                    _filterList = _tempMasterTable.where((row) => row.get(_searchColumn).contains(searchWords[i])).toList();
                    found = _filterList.isNotEmpty;
                  }
                  else{
                    refined = _filterList.where((row) => row.get(_searchColumn).contains(searchWords[i])).toList();
                    if(refined.isNotEmpty){
                      _filterList = List.of(refined);
                    }
                  }
                }
                if(!found){
                  _filterList = List.empty();
                }
              });
            },
          ),

          // Clear search text
          trailing: IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              setState((){
                _searchCtrl.clear();
                _filterList = List.of(_tempMasterTable);
                //setTableState();
              });
            },
          ),
        )
    );
  }

  Widget _getHeader(){
    double height = 50.0;
    double cellWidth = 75.0;

    cellFit(String headerText){
      return Expanded(
        flex: 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: Colors.black,
              style: BorderStyle.solid,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              headerText,
              textAlign: TextAlign.center,
              maxLines: 4,
              softWrap: true,
            ),
          )
        )
      );
    }

    cell(String headerText){
      return Container(
        width: cellWidth,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: Colors.black,
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            headerText,
            textAlign: TextAlign.center,
            maxLines: 4,
            softWrap: true,
          ),
        )
      );
    }

    return Row(
      children: [
        cell("ID"),
        cellFit("BARCODE"),
        cellFit("CATEGORY"),
        cellFit("DESCRIPTION"),
        cellFit("UOM"),
        cell("PRICE"),
        cellFit("DATE"),
        cellFit("ORDERCODE")
      ]
      //List.generate(masterHeader.length, (index) =>index != Index.masterIndex && index != Index.masterPrice ? cellFit(index) : cell(index)
    );
  }

  Widget _getRow(int tableIndex){
    // Get formatted date string and check if it is old (> 1 year)
    int year = int.parse(_tempMasterTable[tableIndex].date.split("-").first);
    bool oldDate = (DateTime.now().year % 100) - (year % 100) > 0;
    double height = 50.0;
    double cellWidth = 75.0;
    Color cellColor = _editedItems.contains(tableIndex) ? Colors.blue.shade100 : Colors.white24;

    cellFit(String columnText, [bool? isDate]){
      isDate ??= false;

      return Expanded(
        flex: 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isDate && oldDate ? Colors.red[800] : cellColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: Colors.black,
              style: BorderStyle.solid,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              columnText,
              //_tempMasterTable[tableIndex][index],
              textAlign: TextAlign.center,
              maxLines: 4,
              softWrap: true,
            ),
          )
        )
      );
    }

    cell(String columnText){
      return Container(
        height: height,
        width: cellWidth,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: Colors.black,
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            columnText,
            textAlign: TextAlign.center,
            maxLines: 4,
            softWrap: true,
          ),
        )
      );
    }

    return TapRegion(
      onTapInside: (value) async{
        barcodeIndex = 0;
        barcodeList = _tempMasterTable[tableIndex].barcode.split(",");

        ordercodeIndex = 0;
        ordercodeList = _tempMasterTable[tableIndex].ordercode.split(",");
        //await _editDialog(context: context, item: List.of(_tempMasterTable[tableIndex]));
      },
      child: Row(
        children: [
          cell(_tempMasterTable[tableIndex].id),
          cellFit(_tempMasterTable[tableIndex].barcode),
          cellFit(_tempMasterTable[tableIndex].category),
          cellFit(_tempMasterTable[tableIndex].description),
          cellFit(_tempMasterTable[tableIndex].uom),
          cell(_tempMasterTable[tableIndex].price),
          cellFit(_tempMasterTable[tableIndex].date, true),
          cellFit(_tempMasterTable[tableIndex].ordercode),
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width * 0.9;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset("AS_logo_light.svg", height: 50),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if(_editedItems.isNotEmpty){
              await confirmWithCancel(context, "Table was edited!\nConfirm changes to MASTERFILE?\nEdit count:${_editedItems.length}\nPress 'Cancel' to continue editing.").then((int value) async {
                if(value == 1){
                  setState((){
                    masterTable = List.of(_tempMasterTable);
                    Navigator.pop(context);
                  });
                }
                else if(value == 0){
                  _tempMasterTable = List.of(masterTable);
                  Navigator.pop(context);
                }
              });
            }
            else{
              Navigator.pop(context);
            }
          },
        )
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Column(
              children: [
                Container(
                  width: width,
                  height: MediaQuery.of(context).size.height/12.0,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withOpacity(0.5),
                      style: BorderStyle.solid,
                      width: 1.0,
                    ),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: 1,
                    itemBuilder: (context, index) {
                      return _getHeader();
                    },
                  ),
                ),
                Container(
                  width: width,
                  height: MediaQuery.of(context).size.height * 0.65,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withOpacity(0.5),
                      style: BorderStyle.solid,
                      width: 1.0,
                    ),
                  ),
                  child: _filterList.isNotEmpty ? ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filterList.length,
                    prototypeItem: _getRow(int.parse(_filterList.first.id)),
                    itemBuilder: (context, index) {
                      final int tableIndex = index;//nt.parse(_filterList[index].id);
                      return _getRow(tableIndex);
                    },
                  ) : Text("EMPTY", style: greyText, textAlign: TextAlign.center,)
                ),
                const SizedBox(
                  height: 5.0,
                ),
                _searchBar(width),
                Center(
                  child: Row(
                      children:[
                        // ElevatedButton(
                        //   onPressed: () async{
                        //     setState((){});
                        //   },
                        //   child: const Text("Sort Table")
                        // ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: ElevatedButton(
                              onPressed: () async{
                                barcodeIndex = 0;
                                barcodeList = [''];
                                ordercodeIndex = 0;
                                ordercodeList = [''];
                                //await _editDialog(context: context);
                              },
                              child: const Text("Add New Item")
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: ElevatedButton(
                              onPressed: () async {
                                await confirmDialog(context, "Save changes to MASTERFILE? \n Edited item count: ${_editedItems.length}").then((value){
                                  if(value){
                                    setState((){
                                      _sortList();
                                      masterTable = List.of(_tempMasterTable);
                                      _filterList = List.of(masterTable);
                                      _editedItems = [];
                                      masterfileChanged = true;
                                    });
                                  }
                                });
                              },
                              child: const Text("Update Database")
                          ),
                        ),
                      ]
                  )
                ),
              ],
            )
          ),
        )
      )
    );
  }
}

rBox({required double width, required Widget child}){
  return Padding(
    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
    child: SizedBox(
        height: 50,
        width: width,
        child: child
    ),
  );
}

showAlert({required BuildContext context, required Text text, Color? color}){
  return showDialog(
      barrierDismissible: false,
      context: context,
      barrierColor: color ?? colorOk,
      builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: SingleChildScrollView(
              child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Center(
                    child: AlertDialog(
                      actionsPadding: const EdgeInsets.all(20.0),
                      content: text,
                      actions: [
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                            child: Text("Ok", style: whiteText),
                            onPressed: () {
                              Navigator.pop(context);
                            }
                        ),
                      ],
                    ),
                  )
              )
          )
      )
  );
}

String getDateString({String? string}){
  String d = string ?? "";
  String newDate = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";//"${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}";
  if(d.isNotEmpty) {
    try{
      int timestamp = int.tryParse(d) ?? -1;
      if(timestamp != -1){
        const gsDateBase = 2209161600 / 86400;
        const gsDateFactor = 86400000;
        final millis = (timestamp - gsDateBase) * gsDateFactor;
        String date = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true).toString();
        date = date.substring(0, 10);
        //List<String> dateSplit = date.split("-");
        newDate = date;//"${dateSplit[2]}-${dateSplit[1]}-${dateSplit[0]}";
      }
    }
    catch (e){
      return newDate;
    }
  }

  return newDate;
}

Future<int> confirmWithCancel(BuildContext context, String str) async {
  // 0 = NO,
  // 1 = YES,
  // -1 = CANCEL,
  int confirmation = -1;

  await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: SingleChildScrollView(
              child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Center(
                      child: AlertDialog(
                        actionsAlignment: MainAxisAlignment.spaceAround,
                        actionsPadding: const EdgeInsets.all(20.0),
                        titlePadding: const EdgeInsets.all(20.0),
                        title: Text(str, textAlign: TextAlign.center,),
                        actions: <Widget>[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: colorError),
                            onPressed: () {
                              confirmation = 1;
                              Navigator.pop(context);
                            },
                            child: const Text("YES"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                            onPressed: () {
                              confirmation = 0;
                              Navigator.pop(context);
                            },
                            child: const Text("NO"),
                          ),
                          const SizedBox(height: 5.0),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                            onPressed:(){
                              confirmation = -1;
                              Navigator.pop(context);
                            },
                            child: const Text("Cancel")
                          )
                        ],
                      )
                  )
              )
          )
      )
  );

  return confirmation;
}

Future<bool> confirmDialog(BuildContext context, String str) async {
  bool confirmation = false;
  await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: SingleChildScrollView(
              child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Center(
                      child: AlertDialog(
                        actionsAlignment: MainAxisAlignment.spaceAround,
                        actionsPadding: const EdgeInsets.all(20.0),
                        titlePadding: const EdgeInsets.all(20.0),
                        title: Text(str, textAlign: TextAlign.center,),
                        actions: <Widget>[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: colorError),
                            onPressed: () {
                              confirmation = false;
                              Navigator.pop(context);
                            },
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                            onPressed: () {
                              confirmation = true;
                              Navigator.pop(context);
                            },
                            child: const Text("Confirm"),
                          ),
                        ],
                      )
                  )
              )
          )
      )
  );

  return confirmation;
}

Future<html.File?> pickFile(String type) async {
  final completer = Completer<List<html.File>?>();
  final input = html.FileUploadInputElement() as html.InputElement;
  input.accept = '$type/*';

  var changeEventTriggered = false;
  void changeEventListener(html.Event e) {
    if (changeEventTriggered) return;
    changeEventTriggered = true;

    final files = input.files!;
    final resultFuture = files.map<Future<html.File>>((file) async {
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onError.listen(completer.completeError);
      return file;
    });
    Future.wait(resultFuture).then((results) => completer.complete(results));
  }

  void cancelledEventListener(html.Event e) {
    html.window.removeEventListener('focus', cancelledEventListener);

    // This listener is called before the input changed event,
    // and the `uploadInput.files` value is still null
    // Wait for results from js to dart
    Future.delayed(const Duration(milliseconds: 500)).then((value) {
      if (!changeEventTriggered) {
        changeEventTriggered = true;
        completer.complete(null);
      }
    });
  }

  input.onChange.listen(changeEventListener);
  input.addEventListener('change', changeEventListener);

  // Listen focus event for cancelled
  html.window.addEventListener('focus', cancelledEventListener);

  input.click();

  final results = await completer.future;
  if(results == null || results.isEmpty){
    return null;
  }

  return results.first;
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
    return
    Item(
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

  void set(int index, String value){
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
