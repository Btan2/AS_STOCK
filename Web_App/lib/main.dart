import 'dart:async';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart' as excel;
import 'package:http/http.dart' as http;
import 'item.dart';

const String versionStr = "0.24.04+1";

// If you are using an Android emulator then localhost is -> https://10.0.2.2:8000,
// otherwise localhost is -> https://127.0.0.1:8000
const String localhost = "https://127.0.0.1:8000";

List<Item> masterTable = [];
List<String> masterCategory = [];

TextStyle get whiteText{ return const TextStyle(color: Colors.white, fontSize: 20.0);}
TextStyle get blackText{ return const TextStyle(color: Colors.black, fontSize: 20.0);}
TextStyle get greyText{ return const TextStyle(color: Colors.black12, fontSize: 20.0);}

final Color colorOk = Colors.blue.shade400;
const Color colorError = Colors.redAccent;
final Color colorWarning = Colors.deepPurple.shade200;
bool masterfileChanged = false;

enum Action {main, import}

String user = "";

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
  bool _isLoading = false;
  String isConnected = "NOT CONNECTED";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 10.0,),
        child: Text("version $versionStr", style: TextStyle(color: Colors.black, fontSize: 12.0), textAlign: TextAlign.center),
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
                    setState(() {
                      username = value;
                    });
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
                  setState((){
                   _isLoading = true;
                  });

                  var body = json.encode({
                    "email": "big2@chungusmail.com",
                    "password": "pass2"
                  });

                  Map<String, String> headers = {
                    'Content-Type': 'application/json',
                    'Charset': 'utf-8'
                  };

                  try{
                    await http.post(Uri.http("127.0.0.1:8000", "/api/login"), body: body, headers: headers).then((var response){
                      var r = jsonDecode(response.body);
                      if(r["status"] == 200){

                        setState((){
                          user = "big2@chungusmail.com";
                          //user = username;
                        });

                        Navigator.push(context, MaterialPageRoute(builder: (context) => const MainPage()));
                      }
                      else{
                        showNotification(context, Colors.red, whiteText, r["message"], 5000);
                      }
                    });
                  }
                  catch(e){
                    showNotification(context, Colors.red, whiteText, e.toString(), 3000); //"connection error"
                  }

                  setState((){
                    _isLoading = false;
                  });
                },

                child: _isLoading ? const Padding(
                    padding: EdgeInsets.all(5.0),
                    child: CircularProgressIndicator(),
                  ) : rBox(
                    width: MediaQuery.of(context).size.width/4.0,
                    child: Material(
                      color: colorOk,
                      borderRadius: BorderRadius.circular(20.0),
                      child: const Center(child: Text("Login", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20.0))),
                    )
                  )
              ),
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
  static const double menuPadding = 60;

  @override
  void initState() {
    super.initState();
    if(masterTable.isEmpty){
      _isLoading = true;
      _loadFromServer();
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
                          title: const Text("Change Masterfile", textAlign: TextAlign.center,),
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
                                        child: const Text("Import from LOCAL STORAGE"),
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
    reader.readAsArrayBuffer(file);
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
      _isLoading = true;
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

  _logout() async{
    if(masterfileChanged){
      await confirmDialog(context, "ALERT: \nMASTERFILE was edited. Commit changes to database?").then((value) async{
        if(value){
          await _postRequest().then((){
            setState((){
              user = "";
              masterTable = [];
              masterCategory = [];
            });

            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
          });
        }
      });
    }
    else {
      setState((){
        user = "";
        masterTable = [];
        masterCategory = [];
      });

      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset("AS_logo_light.svg", height: 50),
        leading: IconButton(
          onPressed: (){
            _logout();
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading? SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height/3),
              Text(_loadingMsg, textAlign: TextAlign.center, style: blackText),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              )
            ]
          )
        )
      ) : CustomScrollView(
        primary: false,
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid.count(
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              crossAxisCount: 4,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(menuPadding),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent[400], // Background color
                    ),
                    onPressed:() async{
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
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        Icon(Icons.swap_horiz),
                        Text("Change MASTERFILE", textAlign: TextAlign.center)
                      ]
                    )
                  )
                ),
                Container(
                  padding: const EdgeInsets.all(menuPadding),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[400], // Background color
                    ),
                    onPressed:(){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const TableView()));
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        Icon(Icons.table_chart),
                        Text("Tables", textAlign: TextAlign.center)
                      ]
                    )
                  )
                ),
                Container(
                  padding: const EdgeInsets.all(menuPadding),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[400], // Background color
                    ),
                    onPressed:(){
                      _exportXLSX();
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        Icon(Icons.download),
                        Text("Export MASTERFILE", textAlign: TextAlign.center)
                      ]
                    )
                  )
                ),
                Container(
                  padding: const EdgeInsets.all(menuPadding),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent[300], // Background color
                    ),
                    onPressed:(){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const UserSettings()));
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        Icon(Icons.settings),
                        Text("Settings", textAlign: TextAlign.center,)
                      ]
                    ),
                  )
                ),
                Container(
                  padding: const EdgeInsets.all(menuPadding),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent[200], // Background color
                    ),
                    onPressed:() async{
                      _logout();
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        Icon(Icons.logout),
                        Text("LOGOUT", textAlign: TextAlign.center,)
                      ]
                    ),
                  )
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}

class TableView extends StatefulWidget{
  const TableView({super.key});
  @override
  State<TableView> createState() => _TableView();
}
class _TableView extends State<TableView>{
  Action action = Action.main;

  int _searchColumn = 3;
  bool _selectAll = false;
  bool _isLoading = false;
  String _loadingMsg = "...";

  List<int> _editedItems = [];
  List<int> _checkList = [];

  final List<String> _masterHeader = ["Barcode", "Category", "Description", "UOM", "Price", "Date", "Ordercode"];
  final List<String> _importHeader = ["Category", "Description", "UOM", "Price", "Barcode", "Date", "Ordercode"];

  List<Item> _tempMasterTable = [];
  List<ImportItem> _importTable = [];
  List<dynamic> _filterList = [];

  final TextEditingController _searchCtrl = TextEditingController();
  final List<TextEditingController> _editCtrl = List.generate(6, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();

    // Deep copy, otherwise original masterTable list will be changed
    _tempMasterTable = List.empty(growable: true);
    for(int i = 0; i < masterTable.length; i++){
      _tempMasterTable.add(
          Item(
            id: masterTable[i].id,
            barcode: masterTable[i].barcode,
            category: masterTable[i].category,
            description: masterTable[i].description,
            uom: masterTable[i].uom,
            price: masterTable[i].price,
            date: masterTable[i].date,
            ordercode: masterTable[i].ordercode,
          )
      );
    }

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

  bool isDuplicate(int i){
    // Get list of items that share same description as index i
    // only check first word/letter to make search faster

    // FIX ME?
    String check = _tempMasterTable[i].description.split(" ").first;
    var searchList = _tempMasterTable.where((row) => row.description.split(" ").first == check && int.parse(row.id) != i).toList();

    for(Item item in searchList){
      if(item.description == _tempMasterTable[i].description){
        return true;
      }
    }

    return false;
  }

  _addToMasterfile(){
    _checkList.sort((x, y) => (x).compareTo(y));

    while(_checkList.isNotEmpty){
      int index = _checkList.last;
      masterTable.add(
          Item(
              id: masterTable.length.toString(),
              barcode: _importTable[index].barcode,
              category: _importTable[index].category,
              description: _importTable[index].description,
              uom: _importTable[index].uom,
              price: _importTable[index].price,
              date: _importTable[index].date,
              ordercode: _importTable[index].ordercode
          )
      );

      _checkList.removeLast();
      _importTable.removeAt(index);
    }

    sortTable(masterTable);
    sortTable(_importTable);

    //_filterList = List.from(_importTable);
  }

  _editDialog({required BuildContext context, Item? item, Color? color}) {
    // Edit item or add new item
    const int indexDescript = 3;
    const int indexUOM = 4;
    const int indexPrice = 5;

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
      editedItem = Item(
          id: item.id,
          barcode: item.barcode,
          category: item.category,
          description: item.description,
          uom: item.uom,
          price: item.price,
          date: getDateString(),
          ordercode: item.ordercode
      );
    }

    headerPadding(String title, TextAlign l) {
      return Padding(
        padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 10.0, bottom: 5),
        child: Text(title, textAlign: l, style: const TextStyle(color: Colors.blue,)),
      );
    }

    textField(String title, String text, int field, int ctrlIndex){
      _editCtrl[ctrlIndex].text = text;

      return Padding(
          padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 5.0, bottom: 5),
          child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: headerPadding(title, TextAlign.left),
                ),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextFormField(
                        controller: _editCtrl[ctrlIndex],
                        maxLines: 1,
                        onChanged: (value){

                          editedItem.setItem(field, value);
                        },
                      ),
                    )
                ),
              ]
          )
      );
    }

    categoryField(int ctrlIndex) {
      _editCtrl[ctrlIndex].text = editedItem.category;
      return Padding(
          padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 5.0, bottom: 5),
          child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: headerPadding("Category", TextAlign.left),
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

    listField(String title, String codeString, int ctrlIndex){
      _editCtrl[ctrlIndex].text = "";
      List<String> list = codeString.split(",");
      for(int i = 0; i < list.length; i++){
        _editCtrl[ctrlIndex].text += "${list[i]}\n";
      }

      return Padding(
          padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 5.0, bottom: 5),
          child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: headerPadding(title, TextAlign.left),
                ),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: SingleChildScrollView(
                          child: TextFormField(
                              maxLines: 20,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              controller: _editCtrl[ctrlIndex],
                              onChanged:(String value){
                                if(ctrlIndex == 4){
                                  editedItem.barcode = value.replaceAll("\n", ",");
                                }
                                else{
                                  editedItem.ordercode = value.replaceAll("\n", ",");
                                }
                              }
                          ),
                        )
                    )
                )
              ]
          )
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
                            textField("Description", editedItem.description, indexDescript, 0),
                            textField("Price", editedItem.price, indexPrice, 1),
                            categoryField(2),
                            textField("UOM", editedItem.uom, indexUOM, 3),
                            listField("Barcodes", editedItem.barcode, 4),
                            listField("Ordercodes", editedItem.ordercode, 5),
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
                        editedItem.date = getDateString();

                        int tableIndex = int.parse(editedItem.id)-1;

                        if(newItem){
                          _tempMasterTable.add(editedItem);
                        }
                        else{
                          //item = editedItem;
                          // Replace existing item
                          _tempMasterTable[tableIndex] = editedItem;
                        }

                        // Reset filter list
                        _filterList = List.of(_tempMasterTable);

                        if(!_editedItems.contains(tableIndex)){
                          _editedItems.add(tableIndex);
                        }

                        setState((){});
                        Navigator.pop(context);
                      }
                  ),
                ],
              ),
            )
        )
    );
  }

  Future<void> _pickImportFile() async{
    setState((){
      _isLoading = true;
      _loadingMsg = "...";
    });

    var file = await pickFile('xlsx');
    if(file == null){
      setState((){
        _isLoading = false;
      });
      return;
    }

    html.FileReader reader = html.FileReader();
    reader.readAsArrayBuffer(file);
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
        _loadingMsg = "...";
      });
    });
  }

  Future<void> _decodeXLSX(List<int> bytes) async {
    if(bytes.isEmpty){
      _loadingMsg = "...";
      return;
    }

    setState((){
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
      if(table!.rows.isEmpty){ //|| table.rows[0].length  10){
        return;
      }

      setState((){
        _loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      _importTable = List.empty(growable:true);
      for(int i = 1; i < table.rows.length; i++) {
        _importTable.add(ImportItem.fromXLSX(table.rows[i], i-1));
      }

      //_filterList = List.of(_importTable);

      setState((){
        _loadingMsg = "...";
      });
    }
    catch (e){
      //debugPrint("The Spreadsheet has errors:\n ---> $e");
      showAlert(context: context, text: Text("An error occurred:\n ---> $e"));
    }
  }

  Widget _searchBar(double width){
    List<String> searchHeader = action == Action.main ? _masterHeader : _importHeader;

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
                return List.generate(searchHeader.length, (index) =>
                    PopupMenuItem<int> (
                      value: index,
                      child: ListTile(
                        title: Text("Search ${searchHeader[index]}"),
                        trailing: index == _searchColumn ? const Icon(Icons.check) : null,
                      ),
                    )
                );
              },
              onSelected: (value) async {
                setState((){
                  if(action == Action.import){
                    List<int> indices = [2, 3, 4, 6, 7, 9, 10];
                    _searchColumn = indices[value];
                  }
                  else{
                    _searchColumn = value;
                  }
                });
              }
          ),
          title: TextFormField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: "Search ${searchHeader[_searchColumn].toLowerCase()}...",
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
                List<dynamic> refined = [];

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
          trailing: IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              setState((){
                // Clear search text
                _searchCtrl.clear();
                _filterList = action == Action.main ? List.of(_tempMasterTable) : List.of(_importTable);
              });
            },
          ),
        )
    );
  }

  List<Widget> _importButtons(){
    return [
      Padding( //_searchCtrl.text.isEmpty ?
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: (){
            setState((){
              _filterList = _filterList.length != _importTable.length ?
              List.of(_importTable) : _importTable.where((row) => row.nof.toString().toUpperCase() == "TRUE").toList();
            });
          },
          child: _filterList.length == _importTable.length ? const Text("Show NOF List") : const Text("Show Full List"),
        ),
      ),
      _checkList.isNotEmpty ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
            onPressed: () async {
              await confirmDialog(context, "Add selected items to MASTERFILE?\nAdd count: ${_checkList.length}\n").then((value){
                setState((){
                  _addToMasterfile();
                });
              });
            },
            child: const Text("Add to MASTERFILE")
        ),
      ) : Container(),
      _importTable.isNotEmpty ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
            onPressed: () async {
              await confirmDialog(context, "Clear job table?").then((value){
                setState((){
                  _importTable = [];
                  _filterList = [];
                });
              });
            },
            child: const Text("Clear Job Table")
        ),
      ) : Container(),
    ];
  }

  List<Widget> _mainButtons(){
    return [
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: ElevatedButton(
            onPressed: () async{
              // _barcodeIndex = 0;
              // _barcodeList = [''];
              // _ordercodeIndex = 0;
              // _ordercodeList = [''];
              await _editDialog(context: context);
            },
            child: const Text("Add New Item")
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: ElevatedButton(
            onPressed: () async {
              await confirmDialog(context, "Save changes to MASTERFILE? \n Edited items: ${_editedItems.length}").then((value){
                if(value){
                  setState((){
                    sortTable(_tempMasterTable);
                    masterTable = List.of(_tempMasterTable);
                    _filterList = List.of(_tempMasterTable);
                    _editedItems = [];
                    masterfileChanged = true;
                  });
                }
              });
            },
            child: const Text("Update Database")
        ),
      ),
    ];
  }

  Widget _masterHeaderRow(){
    return Row(
        children: [
          _cell("ID", 75),
          _cell("BARCODE", 150),
          _cell("CATEGORY", 150),
          _cell("DESCRIPTION", 400),
          _cell("UOM", 75),
          _cell("PRICE", 75),
          _cellFit("DATE"),
          _cellFit("ORDERCODE")
        ]
    );
  }

  Widget _importHeaderRow(){
    return Row(
        children:
        <Widget>[
          SizedBox(
              height: 35.0,
              width: 75.0,
              child: Checkbox(
                  value: _selectAll,
                  onChanged: (value){
                    setState((){
                      _selectAll = _selectAll ? false : true;
                      _checkList.clear();
                      if(_selectAll){
                        for(int f = 0; f < _filterList.length; f++){
                          _checkList.add(int.parse(_filterList[f].id)); //[indexMaster]
                        }
                      }
                    });
                  }
              )
          ),

          // _cell("ID", 75.0),
          _cell("CATEGORY", 150.0),
          _cell("DESCRIPTION", 400.0),
          _cell("UOM", 75.0),
          //_cell("QTY", 75.0),
          _cell("PRICE", 75.0),
          _cell("BARCODE", 150.0),
          _cell("NOF", 75.0),
          _cellFit("DATE"),
          _cellFit("ORDERCODE"),
        ]
    );
  }

  Widget _listViewMain(){
    return _filterList.isNotEmpty ? ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filterList.length,
      prototypeItem: _rowMain(int.parse(_filterList.first.id)),
      itemBuilder: (context, index) {
        //final int tableIndex = int.parse(_filterList[index].id);
        //return _getRow(tableIndex);
        return _rowMain(index);
      },
    ) : Text("EMPTY", style: greyText, textAlign: TextAlign.center);
  }

  Widget _listViewImport(){
    double tableWidth = MediaQuery.of(context).size.width * 0.98;
    return _isLoading ? Center(
        child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height/3),
              Text(_loadingMsg, textAlign: TextAlign.center, style: blackText),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              )
            ]
        )
    ) : _filterList.isNotEmpty ? ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filterList.length,
      prototypeItem: _rowImport(int.parse(_filterList.first.id)),
      itemBuilder: (context, index) {
        return _rowImport(int.parse(_filterList[index].id));
      },
    ) : Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height/3.8, bottom: MediaQuery.of(context).size.height/3.8, left: tableWidth/3, right: tableWidth/3),
        child: ElevatedButton(
            onPressed: () async{
              _pickImportFile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
            child: Text("Import Job File..", style: blackText, textAlign: TextAlign.center)
        )
    );
  }

  Widget _cell(String text, double cellWidth, [Color? cellColor]){
    cellColor ??= Colors.white24;
    return Container(
        width: cellWidth,
        height: 35.0,
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
            text,
            textAlign: TextAlign.center,
            maxLines: 4,
            softWrap: true,
          ),
        )
    );
  }

  Widget _cellFit(String text, [Color? cellColor]){
    cellColor??=Colors.white24;
    return Expanded(
        flex: 1,
        child: Container(
            height: 35.0,
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
                text,
                textAlign: TextAlign.center,
                maxLines: 4,
                softWrap: true,
              ),
            )
        )
    );
  }

  Widget _rowImport(int index){
    Widget checkBox(int index){
      return SizedBox(
          height: 35.0,
          width: 75.0,
          child: Checkbox(
              value: _checkList.contains(index),
              onChanged: (value){
                setState((){
                  _checkList.contains(index) ? _checkList.remove(index) : _checkList.add(index);
                });
              }
          )
      );
    }

    return Row(
        children: <Widget>[
          checkBox(index),
          _cell(_importTable[index].category, 150.0),
          _cell(_importTable[index].description, 400.0),
          _cell(_importTable[index].uom, 75.0),
          //_cell("QTY", 75.0),
          _cell(_importTable[index].price, 75.0),
          _cell(_importTable[index].barcode, 150.0),
          _cell(_importTable[index].nof, 75.0),
          _cellFit(_importTable[index].date),
          _cellFit(_importTable[index].ordercode),
        ]
    );
  }

  Widget _rowMain(int index){
    // Get formatted date string and check if it is old (> 1 year)
    String date = _tempMasterTable[index].date;
    int year;
    if(date.contains("/")) {
      year = int.parse(date.split("/").last);
    }
    else{
      year = int.parse(date.split("-").first);
    }

    bool oldDate = (DateTime.now().year % 100) - (year % 100) > 0;
    Color cellColor = _editedItems.contains(index) ? Colors.blue.shade100 : Colors.white24; //isDuplicate(tableIndex) ? Colors.yellow.shade100 :

    int barcodeCount = _tempMasterTable[index].barcode.split(",").length - 1;
    String barcodeString = _tempMasterTable[index].barcode.split(",").first;
    barcodeString += barcodeCount > 0 ? " (+$barcodeCount)" : "";

    int ordercodeCount = _tempMasterTable[index].ordercode.split(",").length - 1;
    String ordercodeString = _tempMasterTable[index].ordercode.split(",").first;
    ordercodeString += ordercodeCount > 0 ? " (+$ordercodeCount)" : "";

    return TapRegion(
      onTapInside: (value) async{
        await _editDialog(context: context, item: _tempMasterTable[index]);
      },
      child: Row(
          children: [
            _cell(_tempMasterTable[index].id, 75, cellColor),
            _cell(barcodeString, 150, cellColor),
            _cell(_tempMasterTable[index].category, 150, cellColor),
            _cell(_tempMasterTable[index].description, 400, cellColor),
            _cell(_tempMasterTable[index].uom,75, cellColor),
            _cell(_tempMasterTable[index].price,75, cellColor),
            _cellFit(_tempMasterTable[index].date, oldDate ? Colors.red[800] : cellColor),
            _cellFit(ordercodeString, cellColor),
          ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double tableWidth = MediaQuery.of(context).size.width * 0.98;
    return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: SvgPicture.asset("AS_logo_light.svg", height: 50),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if(_editedItems.isNotEmpty){
                  await confirmWithCancel(context, "Table was edited!\nConfirm changes to MASTERFILE?\nEdit count:${_editedItems.length}\n\nPress 'Cancel' to continue editing.").then((int value) async {
                    if(value == 1){
                      setState((){
                        masterTable = List.of(_tempMasterTable);
                      });
                    }
                    // setState((){
                    //   _importTable = [];
                    //   _tempMasterTable = [];
                    //   _filterList = [];
                    // });
                    Navigator.pop(context);
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
                        padding: EdgeInsets.zero,
                        width: tableWidth,
                        height: MediaQuery.of(context).size.height / 12.0,
                        child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: (){
                                  if(action != Action.main){
                                    setState((){
                                      action = Action.main;
                                      _filterList = List.of(_tempMasterTable);
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: action == Action.main ? Colors.white : Colors.grey[400]),
                                child: Text("MASTERFILE", style: blackText),
                              ),
                              ElevatedButton(
                                  onPressed:(){
                                    if(action != Action.import){
                                      setState((){
                                        action = Action.import;
                                        _filterList = List.of(_importTable);
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: action == Action.import ? Colors.white : Colors.grey[400]),
                                  child: Text("Import File", style: blackText)
                              )
                            ]
                        ),
                      ),
                      Container(
                        width: tableWidth,
                        height: 35,//MediaQuery.of(context).size.height/12.0,
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
                            return action == Action.main ? _masterHeaderRow() : _importHeaderRow();
                          },
                        ),
                      ),
                      Container(
                        width: tableWidth,
                        height: MediaQuery.of(context).size.height * 0.6,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.black.withOpacity(0.5),
                            style: BorderStyle.solid,
                            width: 1.0,
                          ),
                        ),
                        child: action == Action.main ? _listViewMain() : _listViewImport(),
                      ),
                      const SizedBox(
                        height: 5.0,
                      ),
                      _searchBar(tableWidth),
                      Center(
                          child: Row(
                              children: action == Action.main ? _mainButtons() : _importButtons()
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

class UserSettings extends StatefulWidget{
  const UserSettings({super.key});
  @override
  State<UserSettings> createState() => _UserSettings();
}
class _UserSettings extends State<UserSettings>{
  String _loadingMsg = "Loading...";
  bool _isLoading = false;

  TextEditingController emailCtrl = TextEditingController();
  TextEditingController pwdCtrl = TextEditingController();
  TextEditingController changeCtrl = TextEditingController();

  static const double menuPadding = 60;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose(){
    emailCtrl.dispose();
    pwdCtrl.dispose();
    changeCtrl.dispose();
    super.dispose();
  }

  Future<void> _postChangeEmail(String pwd, String newEmail) async{

    Map<String, String> args = {
      "email":user, //"big2@chungusmail.com"
      "password":pwd,
      "newemail":newEmail,
    };
    var body = json.encode(args);

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Charset': 'utf-8'
    };

    setState((){
      _isLoading = true;
      _loadingMsg = "Performing POST request...";
    });

    try{
      await http.post(Uri.http("127.0.0.1:8000", "/api/change_email"), body: body, headers: headers).then((var response){
        var r = jsonDecode(response.body);
        showNotification(context, Colors.red, whiteText, r["message"].toString(), 2000);
        //String e = response.statusCode.toString();
        //showNotification(context, Colors.red, whiteText, "Response Code: $e", 2000);
      });
    }
    catch(e){
      showAlert(context: context, text: Text("An Error Occurred: \n$e"), color: Colors.red);
    }

    setState((){
      _isLoading = false;
      _loadingMsg = "...";
    });
  }

  Future<void> _postChangePwd(String oldPwd, String newPwd) async{
    // if(oldPwd.isEmpty || newPwd.isEmpty){
    //   showAlert(context: context, text: const Text("Password(s) must not be empty"));
    // }

    Map<String, String> args = {
      "email":user,
      "password":oldPwd,
      "newpass":newPwd,
    };
    var body = json.encode(args);

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Charset': 'utf-8'
    };

    setState((){
      _isLoading = true;
      _loadingMsg = "Performing POST request...";
    });

    try{
      await http.post(Uri.http("127.0.0.1:8000", "/api/change_pwd"), body: body, headers: headers).then((var response){
        var r = jsonDecode(response.body);
        showNotification(context, Colors.red, whiteText, r["message"].toString(), 2000);
        //String e = response.statusCode.toString();
        //showNotification(context, Colors.red, whiteText, "Response Code: $e", 2000);
      });
    }
    catch(e){
      showAlert(context: context, text: Text("An Error Occurred: \n$e"), color: Colors.red);
    }

    setState((){
      _isLoading = false;
      _loadingMsg = "...";
    });

  }

  Future<void> _changeEmailDialog(BuildContext context) async{
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
                          title: const Text("Change Email Address", textAlign: TextAlign.center,),
                          actions: <Widget>[
                            Center(
                                child: Column(
                                    children: <Widget>[
                                      const SizedBox(height: 5.0),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 15.0),
                                          child: DefaultTextStyle(
                                            style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                            child: Text("Current Email:", textAlign: TextAlign.left),
                                          )
                                      ),
                                      Text(user),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 15.0),
                                          child: DefaultTextStyle(
                                            style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                            child: Text("New Email:", textAlign: TextAlign.left),
                                          )
                                      ),
                                      TextField(
                                          controller: changeCtrl
                                      ),
                                      const SizedBox(height: 15.0),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 15.0),
                                          child: DefaultTextStyle(
                                            style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                            child: Text("Password:", textAlign: TextAlign.left),
                                          )
                                      ),
                                      TextField(
                                        controller: pwdCtrl, // This is the old password
                                      ),
                                      const SizedBox(height: 25.0),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                                          onPressed:(){
                                            _postChangeEmail(pwdCtrl.text, changeCtrl.text);
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Confirm")
                                      ),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                                          onPressed:(){
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
  }

  Future<void> _changePwdDialog(BuildContext context) async{
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
                          title: const Text("Change Password", textAlign: TextAlign.center,),
                          actions: <Widget>[
                            Center(
                                child: Column(
                                    children: <Widget>[
                                      const SizedBox(height: 5.0),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 15.0),
                                          child: DefaultTextStyle(
                                            style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                            child: Text("Current Password:", textAlign: TextAlign.left),
                                          )
                                      ),
                                      TextField(
                                        controller: pwdCtrl, // This is old password, just using name text controller
                                      ),
                                      const SizedBox(height: 15.0),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 15.0),
                                          child: DefaultTextStyle(
                                            style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                            child: Text("New Password:", textAlign: TextAlign.left),
                                          )
                                      ),
                                      TextField(
                                          controller: changeCtrl
                                      ),
                                      const SizedBox(height: 25.0),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                                          onPressed:(){
                                            _postChangePwd(pwdCtrl.text, changeCtrl.text);
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Confirm")
                                      ),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                                          onPressed:(){
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: SvgPicture.asset("AS_logo_light.svg", height: 50),
        ),
        body: _isLoading ? SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height/3),
                Text(_loadingMsg, textAlign: TextAlign.center, style: blackText),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),//SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
                )
              ]
            )
          )
        ) : CustomScrollView(
            primary: false,
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid.count(
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  crossAxisCount: 4,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(menuPadding),
                      child: ElevatedButton(
                        onPressed:(){
                          _changeEmailDialog(context);
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:[
                            Icon(Icons.email_outlined),
                            Text("Change Email", textAlign: TextAlign.center,)
                          ]
                        ),
                      )
                    ),
                    Container(
                      padding: const EdgeInsets.all(menuPadding),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400], // Background color
                        ),
                        onPressed:(){
                          _changePwdDialog(context);
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:[
                            Icon(Icons.lock),
                            Text("Change Password", textAlign: TextAlign.center,)
                          ]
                        ),
                      )
                    ),
                    Container(
                      padding: const EdgeInsets.all(menuPadding),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[300], // Background color
                        ),
                        onPressed:(){
                          Navigator.pop(context);
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:[
                            Icon(Icons.exit_to_app),
                            Text("Back", textAlign: TextAlign.center,)
                          ]
                        ),
                      )
                    ),
                  ]
                )
              )
            ]
        )
    );
  }
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

void sortTable(List<dynamic> list){
  list.sort((x, y) => (x.description).compareTo((y.description)));

  //Calc new indices from list
  for(int i = 0; i < list.length; i++){
    list[i].id = i.toString();
  }
}

void showNotification(BuildContext context, Color bkgColor, TextStyle textStyle, String message, int msec) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: textStyle, maxLines: 2, softWrap: true, overflow: TextOverflow.fade),
        backgroundColor: bkgColor,
        duration: Duration(milliseconds: msec), //1200
        padding: const EdgeInsets.only(top: 20, bottom: 20, left: 15.0, right: 15.0),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.none,
        margin: const EdgeInsets.only(right: 10, left: 10, bottom: 10.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      )
  );
}

Widget rBox({required double width, required Widget child}){
  return Padding(
    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
    child: SizedBox(
        height: 50,
        width: width,
        child: child
    ),
  );
}

Future<void> showAlert({required BuildContext context, required Text text, Color? color}){
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

//
// USE THIS TO REGISTER NEW USERS
//
/*
  Future<void> _postRegister(String name, String email, String pwd) async{
    if(name.isEmpty || email.isEmpty || pwd.isEmpty){
      String errString = name.isEmpty ? "-> Username must not be empty" : "";
      errString += email.isEmpty ? "\n-> Email must not be empty" : "";
      errString += pwd.isEmpty? "\n-> Password must not be empty" : "";
      showAlert(context: context, text: Text("Invalid User Credentials: \n$errString"));
      return;
    }

    Map<String, String> args = {
      "name":name,
      "email":email,
      "password":pwd,
    };
    var body = json.encode(args);

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Charset': 'utf-8'
    };

    setState((){
      _isLoading = true;
      _loadingMsg = "Performing POST request...";
    });

    try{
      await http.post(Uri.http("127.0.0.1:8000", "/api/register"), body: body, headers: headers).then((var response){
        String e = response.statusCode.toString();
        String b = response.body.toString();
        showAlert(context: context, text: Text("$b\nResponse Code: $e"));
      });
    }
    catch(e){
      showAlert(context: context, text: Text("An Error Occurred: \n$e"), color: Colors.red);
    }

    setState((){
      _isLoading = false;
      _loadingMsg = "...";
    });
  }

  Padding(
    padding: const EdgeInsets.all(8.0),
    child: ElevatedButton(
      onPressed: () {
        _registerDialog(context);
      },
      child: const Text("Register New User"),
    ),
  ),

  Future<void> _registerDialog(BuildContext context) async {
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
                          title: const Text("Register New User", textAlign: TextAlign.center,),
                          actions: <Widget>[
                            Center(
                                child: Column(
                                    children: <Widget>[
                                      const SizedBox(height: 5.0),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 15.0),
                                          child: DefaultTextStyle(
                                            style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                            child: Text("Name:", textAlign: TextAlign.left),
                                          )
                                      ),
                                      TextField(
                                        controller: nameCtrl,
                                      ),
                                      const SizedBox(height: 15.0),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 15.0),
                                          child: DefaultTextStyle(
                                            style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                            child: Text("Email:", textAlign: TextAlign.left),
                                          )
                                      ),
                                      TextField(
                                        controller: emailCtrl,
                                      ),
                                      const SizedBox(height: 25.0),
                                      const Padding(
                                        padding: EdgeInsets.only(top: 15.0),
                                        child: DefaultTextStyle(
                                          style: TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
                                          child: Text("Password:", textAlign: TextAlign.left),
                                        )
                                      ),
                                      TextField(
                                        controller: passwordCtrl
                                      ),
                                      const SizedBox(height: 25.0),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                                          onPressed:(){
                                            _postRegister(nameCtrl.text, emailCtrl.text, passwordCtrl.text);
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Register User")
                                      ),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: colorWarning),
                                          onPressed:(){
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
  }
 */
