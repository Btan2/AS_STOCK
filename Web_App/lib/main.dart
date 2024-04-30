import 'dart:async';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart' as excel;
import 'package:http/http.dart' as http;
import 'item.dart';
import 'table.dart';

/*
      REQUIRES THIS RUN COMMAND FOR NOW, LOOK UP AND CHANGE WHEN ONLINE SERVER IS ESTABLISHED
        flutter run -d chrome --web-browser-flag "--disable-web-security"
 */

const String versionStr = "0.24.04+1";
// If you are using an Android emulator then localhost is -> https://10.0.2.2:8000,
// otherwise localhost is -> https://127.0.0.1:8000
const String localhost = "https://127.0.0.1:8000";

TextStyle get whiteText{ return const TextStyle(color: Colors.white, fontSize: 20.0);}
TextStyle get blackText{ return const TextStyle(color: Colors.black, fontSize: 20.0);}
TextStyle get greyText{ return const TextStyle(color: Colors.black12, fontSize: 20.0);}
final Color colorOk = Colors.blue.shade400;
const Color colorError = Colors.redAccent;
final Color colorWarning = Colors.deepPurple.shade200;

enum Action {main, import}

List<Item> MASTERFILE = [];
String user = "";
bool masterfileChanged = false;
bool firstLoad = false;

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

  Widget _textButton({required double width, required Widget child}){
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
      child: SizedBox(
          height: 50,
          width: width,
          child: child
      ),
    );
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
              _textButton(
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
              _textButton(
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
                    "email": "",
                    "password": ""
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
                  ) : _textButton(
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
    if(!firstLoad){
      firstLoad = true;
      _getMasterfile();
    }
  }

  Future<void> _getMasterfile() async{
    setState((){
      _isLoading = true;
      _loadingMsg = "Performing GET request...";
    });

    await loadFromServer().then((value){
      if(value == 0){
        showAlert(context: context, text: const Text("Error: couldn't download table."));
      }

      setState((){
        _isLoading = false;
        _loadingMsg = "...";
      });
    });
  }

  @override
  void dispose(){
    super.dispose();
  }

  _postUpdateAll() async{
    var args = MASTERFILE.map((Item e){
      return {
        "barcode" : e.barcode.toLowerCase() == "null" ? "" : e.barcode,
        "category" : e.category,
        "description" : e.description,
        "uom" : e.uom,
        "date" : getDateString(string: e.date),
        "price" : double.tryParse(e.price) ?? 0.0,
        "ordercode" : e.ordercode.toLowerCase() == "null" ? "" : e.ordercode,
      };
    }).toList();

    var body = json.encode(args);

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Charset': 'utf-8'
    };

    try{
      await http.post(Uri.http("127.0.0.1:8000", "/api/updateItems"), body: body, headers: headers).then((var response){
        var r = jsonDecode(response.body);
        String message = "Status Code: ${r['status']}\nMessage: ${r['message']}";
        showAlert(context: context, text: Text("Response:\n\n$message"));
      });
    }
    catch(e){
      showAlert(context: context, text: Text("Response:\n\n$e"));
    }
  }

  _logout() async{
    if(masterfileChanged){
      await confirmDialog(context, "ALERT: \nMASTERFILE was edited. Commit changes to database?").then((value) async{
        if(value){

          setState((){
            _isLoading = true;
            _loadingMsg = "Sending POST request...";
          });

          await Future.delayed(const Duration(seconds: 1));

          await _postUpdateAll().then((value){
            setState((){
              _isLoading = false;
              _loadingMsg = "...";
              firstLoad = false;
              user = "";
              MASTERFILE = [];
            });

            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
          });
        }
      });
    }
    else {
      setState((){
        firstLoad = false;
        user = "";
        MASTERFILE = [];
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
                    onPressed:(){
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation1, animation2) => const TablePage(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
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
                      backgroundColor: Colors.blue[400], // Background color
                    ),
                    onPressed:(){
                      Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation1, animation2) => const DatabasePage(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                      );
                    },
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:[
                        Icon(Icons.download),
                        Text("Database", textAlign: TextAlign.center)
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
                      Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation1, animation2) => const SettingsPage(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                      );
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
                // Container(
                //   padding: const EdgeInsets.all(menuPadding),
                // ),
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

class TablePage extends StatefulWidget{
  const TablePage({super.key});
  @override
  State<TablePage> createState() => _TablePage();
}
class _TablePage extends State<TablePage>{
  Action action = Action.main;
  int _searchColumn = 3;
  bool _selectAll = false;
  bool _isLoading = false;
  String _loadingMsg = "...";

  List<int> _editedItems = [];
  List<int> _checkList = [];

  late ItemTable _mainTable;
  late ItemTable _importTable;
  List<Item> _filterList = [];

  final TextEditingController _searchCtrl = TextEditingController();
  final List<TextEditingController> _editCtrl = List.generate(6, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _mainTable = ItemTable.fromList(MASTERFILE);
    _filterList = List.of(MASTERFILE);
    _importTable = ItemTable.fromList([]);
  }

  @override
  void dispose(){
    for(int c = 0; c < _editCtrl.length; c++){
      _editCtrl[c].dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
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

      await _importXLSX(reader.result as List<int>);

      setState((){
        _isLoading = false;
        _loadingMsg = "...";
      });
    });
  }

  Future<void> _importXLSX(List<int> bytes) async {
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

      List<Item> import = List.empty(growable:true);

      // give header row id -1 then remove, kinda hacky
      import = List.generate(table.rows.length, (index) => Item.fromImport(table.rows[index], index-1));
      import.removeAt(0);

      setState((){
        _importTable = ItemTable.fromList(import);
        _filterList = List.of(_importTable.items);
      });
    }
    catch (e){
      showAlert(context: context, text: Text("An error occurred:\n ---> $e"));
    }
  }

  bool _isDuplicate(int i){
    // Get list of items that share same description as index i
    // only check first word/letter to make search faster
    // FIX ME?
    String check = _mainTable.items[i].description.split(" ").first;
    var searchList = _mainTable.items.where((row) => row.description.split(" ").first == check && row.id != i).toList();
    for(Item item in searchList){
      if(item.description == _mainTable.items[i].description){
        return true;
      }
    }
    return false;
  }

  _importToMain(){
    _checkList.sort((x, y) => (x).compareTo(y));
    while(_checkList.isNotEmpty){
      int index = _checkList.last;
      setState((){
        _mainTable.addItem(
          Item(
            id: _mainTable.items.length,
            barcode: _importTable.items[index].barcode,
            category: _importTable.items[index].category,
            description: _importTable.items[index].description,
            uom: _importTable.items[index].uom,
            price: _importTable.items[index].price,
            date: _importTable.items[index].date,
            ordercode: _importTable.items[index].ordercode
          )
        );

        _mainTable.sortTable();
        _checkList.removeLast();
        _importTable.removeItem(index);
      });
    }
  }

  _tableSwitch(){
    return Container(
        padding: EdgeInsets.zero,
        height: MediaQuery.of(context).size.height / 12.0,
        child: Row(
            children: <Widget>[
              ElevatedButton(
                onPressed: (){
                  if(action != Action.main){
                    setState((){
                      action = Action.main;
                      _filterList = List.of(_mainTable.items);
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
                        _filterList = List.of(_importTable.items);
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: action == Action.import ? Colors.white : Colors.grey[400]),
                  child: Text("Import File", style: blackText)
              )
            ]
        )
    );
  }

  List<Widget> _footer(){
    return action == Action.main ?
    <Widget>[
      //
      // Main Table Actions
      //
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: ElevatedButton(
            onPressed: () async{
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
                    _mainTable.sortTable();
                    _filterList = List.of(_mainTable.items);
                    _editedItems = [];
                    masterfileChanged = true;
                  });
                }
              });
            },
            child: const Text("Save Changes")
        ),
      ),
    ] : <Widget>[
      //
      // Import Table Actions
      //
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: (){
            setState((){
              _filterList = _filterList.length != _importTable.items.length ?
              List.of(_importTable.items) : _importTable.items.where((row) => row.nof.toString().toUpperCase() == "TRUE").toList();
            });
          },
          child: _filterList.length == _importTable.items.length ? const Text("Show NOF List") : const Text("Show Full List"),
        ),
      ),
      _checkList.isNotEmpty ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
            onPressed: () async {
              await confirmDialog(context, "Add selected items to Main table?\nAdd count: ${_checkList.length}\n").then((value){
                if(value){
                  _importToMain();
                }
              });
            },
            child: const Text("Import ticked items")
        ),
      ) : Container(),
      _importTable.items.isNotEmpty ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
            onPressed: () async {
              await confirmDialog(context, "Clear Import table?").then((value){
                setState((){
                  _importTable.items = [];
                  _filterList = [];
                });
              });
            },
            child: const Text("Clear Table")
        ),
      ) : Container(),
    ];
  }

  _header(){
    List<Widget> row = _mainTable.header();
    return action == Action.main ? Container(
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black.withOpacity(0.5),
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        child: Row(
            children: row.getRange(0, row.length-1).toList()
        )
    ) : Container(
        height: 35,//MediaQuery.of(context).size.height/12.0,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black.withOpacity(0.5),
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        child: Row(
            children: <Widget>[
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
                              _checkList.add(_filterList[f].id); //[indexMaster]
                            }
                          }
                        });
                      }
                  )
              )
            ] + row.getRange(1, row.length).toList()
        )
    );
  }

  _row(int index, {bool? import}){
    Color cellColor = _editedItems.contains(index) ? Colors.blue.shade100 : _isDuplicate(index) ? Colors.green.shade100 : Colors.white24;
    List<Widget> row = !(import ?? false) ? _mainTable.row(index, cellColor: cellColor) : _importTable.row(index, cellColor: cellColor);

    return (import ?? false) ?
      Row(
        children: <Widget>[
          SizedBox(
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
          )
        ] + row.getRange(1, row.length).toList()
      ) :
      TapRegion(
        onTapInside: (value) async{
          await _editDialog(context: context, item: !(import ?? false) ? _mainTable.items[index] : _importTable.items[index]);
        },
        child: Row(children: row.getRange(0, row.length-1).toList())
      );
  }

  _table({required double height, required double width}){
    final double insetX = MediaQuery.of(context).size.width / 3;
    final double insetY = MediaQuery.of(context).size.height / 3.8;

    if(action == Action.main){
      return Container(
        padding: EdgeInsets.zero,
        // width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black.withOpacity(0.5),
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        child: _mainTable.items.isNotEmpty ? ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: _mainTable.items.length,
          prototypeItem: _row(_mainTable.items.first.id),
          itemBuilder: (context, index) {
            return _row(index);
          },
        ) : const Center(child: Text("EMPTY", textAlign: TextAlign.center))
      );
    }

    return _isLoading ? Padding(
      padding: const EdgeInsets.all(5.0),
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
    ) : _importTable.items.isEmpty ? Padding(
      padding: EdgeInsets.only(top: insetY, bottom: insetY, left: insetX, right: insetX),
      child: ElevatedButton(
        onPressed: () async{
          _pickImportFile();
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
        child: Text("Import Job File..", style: blackText, textAlign: TextAlign.center)
      )
    ) : ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filterList.length,
      prototypeItem: _row(_filterList.first.id, import: true),
      itemBuilder: (context, index) {
        return _row(index, import: true);
      },
    );
  }

  _searchBar({required double width}){
    List<String> searchHeader = ["Barcode", "Category", "Description", "UOM", "Price", "Date", "Ordercode"];

    return Padding(
      padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
      child: Container(
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
                _filterList = List.of(_mainTable.items);

                if(value.isEmpty){
                  return;
                }

                String searchText = value.toUpperCase();
                bool found = false;
                List<String> searchWords = searchText.split(" ").where((String s) => s.isNotEmpty).toList();
                List<Item> refined = [];

                for (int i = 0; i < searchWords.length; i++) {
                  if (!found){
                    _filterList = _mainTable.items.where((row) => row.get(_searchColumn).contains(searchWords[i])).toList();
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
                _filterList = action == Action.main ? List.of(_mainTable.items) : List.of(_importTable.items);
              });
            },
          ),
        )
    )
    );
  }

  _editDialog({required BuildContext context, Item? item, Color? color}) {
    const int indexDescript = 3;
    const int indexUOM = 4;
    const int indexPrice = 5;

    bool newItem = item == null;

    Item editedItem = newItem ? Item(
      id: -1,
      barcode: ' ',
      category: 'MISC',
      description: 'NEW ITEM',
      uom: 'EACH',
      price: '0.0',
      date: getDateString(),
      ordercode: ' '
    ): Item(
        id: item.id,
        barcode: item.barcode,
        category: item.category,
        description: item.description,
        uom: item.uom,
        price: item.price,
        date: getDateString(),
        ordercode: item.ordercode
    );

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
                          return List.generate(_mainTable.column.length, (index) =>
                              PopupMenuItem<int>(
                                value: index,
                                child: ListTile(
                                  title: Text(_mainTable.column[index]),
                                ),
                              )
                          );
                        },
                        onSelected: (value) async{
                          setState(() {
                            _editCtrl[ctrlIndex].text = _mainTable.column[value];
                            editedItem.category = _mainTable.column[value];
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
              newItem ? Container() : ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorError),
                child: Text("Delete", style: whiteText),
                onPressed: () async {
                  await confirmDialog(context, "Delete item: \n${editedItem.description}\n").then((value){
                    if(value){
                      setState((){
                        _mainTable.removeItem(editedItem.id);
                        _mainTable.sortTable();
                        _filterList = List.of(_mainTable.items);
                      });

                      Navigator.pop(context);
                    }
                  });
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                child: Text("Save", style: whiteText),
                onPressed: () {
                  if(newItem){
                    _mainTable.addItem(editedItem);
                    _mainTable.sortTable();
                  }
                  else{
                    // Replace existing item
                    _mainTable.items[editedItem.id] = editedItem;
                  }

                  // Reset filter list
                  _filterList = List.of(_mainTable.items);

                  // index to list of new/edited items
                  if(!_editedItems.contains(editedItem.id)){
                    _editedItems.add(editedItem.id);
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

  @override
  Widget build(BuildContext context) {
    double tableWidth = MediaQuery.of(context).size.width * 0.98;
    double tableHeight = MediaQuery.of(context).size.height * 0.6;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset("AS_logo_light.svg", height: 50),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if(_editedItems.isEmpty){
              Navigator.pop(context);
            }
            else{
              String msg = "Table was edited!\n";
              msg += "Save changes to MASTERFILE?\n";
              msg+= "Edit count:${_editedItems.length}\n";
              msg+= "\nPress 'Cancel' to continue editing.";
              await confirmWithCancel(context, msg).then((int value) async {
                if(value == 1){
                  setState((){
                    MASTERFILE = List.of(_mainTable.items);
                  });
                }
                Navigator.pop(context);
              });
            }
          },
        )
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Center(
            child: Column(
              children: <Widget>[
                _tableSwitch(),
                _header(),
                _table(height: tableHeight, width: tableWidth),
                _searchBar(width: tableWidth),
              ] + _footer()
            )
          ),
        )
      )
    );
  }
}

class DatabasePage extends StatefulWidget{
  const DatabasePage({super.key});
  @override
  State<DatabasePage> createState() => _DatabasePage();
}
class _DatabasePage extends State<DatabasePage>{
  static const double menuPadding = 60;
  String _loadingMsg = "Loading...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose(){
    super.dispose();
  }

  _decodeXLSX(List<int> bytes) async {
    if(bytes.isEmpty){
      _loadingMsg = "...";
      return;
    }

    setState((){
      MASTERFILE = List.empty();
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

      setState((){
        _loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      setState((){
        _loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      MASTERFILE = [];
      // Remove header row
      MASTERFILE = List<Item>.generate(table.rows.length, (index) => Item.fromXLSX(table.rows[index], index-1));
      MASTERFILE.removeAt(0);

      // masterTable = List.empty(growable:true);
      // for(var row in table.rows) {
      //   masterTable.add(Item.fromXLSX(row));
      // }

      setState((){
        _loadingMsg = "...";
      });
    }
    catch (e){
      showAlert(context: context, text: Text("An error occurred:\n ---> $e"));
    }
  }

  _loadFromStorage() async{
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
    sheetObject.insertRowIterables(["Product ID", "Barcode (multi) #", "Category", "Description", 'UOM', "Price", "Datetime", "Ordercode"], 0,);

    setState((){
      _loadingMsg = "Creating table rows...";
    });
    await Future.delayed(const Duration(milliseconds:500));

    for(int i = 0; i < MASTERFILE.length; i++){
      sheetObject.insertRowIterables(
          <String> [
            MASTERFILE[i].id.toString(),
            MASTERFILE[i].barcode,
            MASTERFILE[i].category,
            MASTERFILE[i].description,
            MASTERFILE[i].uom,
            MASTERFILE[i].price,
            MASTERFILE[i].date,
            MASTERFILE[i].ordercode
          ],
          i+1
      );

      // Fix me
      // String dateFormat = getDateString(string: MASTERFILE[i].date);
      // int yearThen = int.parse(dateFormat.split("/").last);
      //
      // // Get last two year digits using modulus
      // int diff = (DateTime.now().year % 100) - (yearThen % 100);
      //
      // // Color code cell if date is older than 1 year
      // if(diff > 0){
      //   excel.CellIndex cellIndex = excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i+1);
      //   sheetObject.cell(cellIndex).cellStyle = excel.CellStyle(backgroundColorHex: '#FF8980', fontSize: 10, fontFamily: excel.getFontFamily(excel.FontFamily.Arial));
      // }
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

    setState((){
      _isLoading = false;
      _loadingMsg = "Loading...";
    });
  }

  _loadFromServer() async{
    setState((){
      _isLoading = true;
      _loadingMsg = "Performing GET request...";
    });

    await loadFromServer().then((value){
      if(value == 0){
        showAlert(context: context, text: const Text("Error: couldn't download table."));
      }

      setState((){
        _isLoading = false;
        _loadingMsg = "...";
      });
    });
  }

  _postUpdateAll() async{
    setState((){
      _isLoading = true;
      _loadingMsg = "Sending POST request";
    });

    try{
      await Future.delayed(const Duration(seconds: 1));

      var args = MASTERFILE.map((Item e){
        return {
          "barcode" : e.barcode.toLowerCase() == "null" ? "" : e.barcode,
          "category" : e.category,
          "description" : e.description,
          "uom" : e.uom,
          "date" : getDateString(string: e.date),
          "price" : double.tryParse(e.price) ?? 0.0,
          "ordercode" : e.ordercode.toLowerCase() == "null" ? "" : e.ordercode,
        };
      }).toList();

      var body = json.encode(args);

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Charset': 'utf-8'
      };
      await http.post(Uri.http("127.0.0.1:8000", "/api/updateItems"), body: body, headers: headers).then((var response){
        var r = jsonDecode(response.body);
        String message = "Status Code: ${r['status']}\nMessage: ${r['message']}";
        showAlert(context: context, text: Text("Response:\n\n$message"));
      });
    }
    catch(e){
      showAlert(context: context, text: Text("Response:\n\n$e"));
    }

    setState((){
      _isLoading = false;
      _loadingMsg = "...";
    });
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
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent[400]),
                            onPressed:() async{
                              int value = await confirmWithCancel(context, "Load MASTERFILE", button0: "Load from SERVER", button1: "Load from STORAGE");
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
                                Icon(Icons.email_outlined),
                                Text("Change MASTERFILE", textAlign: TextAlign.center,)
                              ]
                            ),
                          )
                        ),
                        Container(
                          padding: const EdgeInsets.all(menuPadding),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[400]),
                            onPressed:() async {
                              _exportXLSX();
                            },
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children:[
                                Icon(Icons.lock),
                                Text("Download .xlsx", textAlign: TextAlign.center,)
                              ]
                            ),
                          )
                        ),
                        Container(
                            padding: const EdgeInsets.all(menuPadding),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[400]),
                              onPressed:() async {
                                _postUpdateAll();
                              },
                              child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children:[
                                    Icon(Icons.lock),
                                    Text("Update Database", textAlign: TextAlign.center,)
                                  ]
                              ),
                            )
                        ),
                        Container(
                            padding: const EdgeInsets.all(menuPadding),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400], // Background color
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

class SettingsPage extends StatefulWidget{
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPage();
}
class _SettingsPage extends State<SettingsPage>{
  static const double menuPadding = 60;
  String _loadingMsg = "Loading...";
  bool _isLoading = false;
  TextEditingController emailCtrl = TextEditingController();
  TextEditingController pwdCtrl = TextEditingController();
  TextEditingController changeCtrl = TextEditingController();

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
    var body = json.encode( {
      "email":user, //"big2@chungusmail.com"
      "password":pwd,
      "newemail":newEmail,
    });

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

    var body = json.encode({
      "email":user,
      "password":oldPwd,
      "newpass":newPwd,
    });

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

Future<int> loadFromServer() async {
  try {
    await Future.delayed(const Duration(seconds: 1));

    Map<String, String> headers = {'Content-Type': 'application/json', 'Charset': 'utf-8'};
    Uri uri = Uri.http('127.0.0.1:8000', '/api/items');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      return 0;
    }

    var jsn = jsonDecode(response.body.toString());
    MASTERFILE = List.generate(jsn.length, (index) => Item.fromJson(jsn[index]));
    return 1;
  }
  catch(e){
    //
  }

  return 0;
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

Future<int> confirmWithCancel(BuildContext context, String str, {String? button0, String? button1}) async {
  // 0 = NO  1 = YES  -1 = CANCEL,
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
                  child: Text(button0 ?? "YES"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                  onPressed: () {
                    confirmation = 0;
                    Navigator.pop(context);
                  },
                  child: Text(button1 ?? "NO"),
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
