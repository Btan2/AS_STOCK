import 'package:universal_html/html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

enum Action{blank, edit, view, compare, upload}
enum CellFormat{words, datetime, decimals, integers, multiline}

String versionStr = "0.23.08+1";

String loadingMsg = "";

List<List<String>> jobTable = [];
List<Map<String, dynamic>> jobHeader = [{}];

List<List<String>> bkpTable = [];
List<List<String>> masterTable = [];
List<Map<String, dynamic>> masterHeader = [{}];

List<String> jobCategory = [];
List<String> masterCategory = [];

TextStyle get whiteText{ return const TextStyle(color: Colors.white, fontSize: 20.0);}
TextStyle get blackText{ return const TextStyle(color: Colors.black, fontSize: 20.0);}
TextStyle get greyText{ return const TextStyle(color: Colors.black12, fontSize: 20.0);}
TextStyle get cellText{ return const TextStyle(color: Colors.black, fontSize: 12.0);}

final Color colorOk = Colors.blue.shade400;
const Color colorError = Colors.redAccent;
final Color colorWarning = Colors.deepPurple.shade200;

class Index {
  static int masterIndex = 0;
  static int masterBarcode = 1;
  static int masterCategory = 2;
  static int masterDescript = 3;
  static int masterUOM = 4;
  static int masterPrice = 5;
  static int masterDate = 6;
  static int masterOrdercode = 7;
  static int jobTableIndex = 0;
  static int jobMasterIndex = 1;
  static int jobCategory = 2;
  static int jobDescript = 3;
  static int jobUOM = 4;
  static int jobQTY = 5;
  static int jobPrice = 6;
  static int jobBarcode = 7;
  static int jobNof = 8;
  static int jobDate = 9;
  static int jobOrdercode = 10;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 10.0,),
        child: Text("version $versionStr", style: cellText, textAlign: TextAlign.center),
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
                            pass = value;
                            setState(() {});
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
  }

  Future<void> filePicker() async {
    // Load xlsx from file browser
    FileUploadInputElement uploadInput = FileUploadInputElement();
    uploadInput.click();

    uploadInput.onAbort.listen((e){
      return;
    });

    uploadInput.onChange.listen((e) {
      // read file content as dataURL
      List<File> files = List.empty();
      files = uploadInput.files as List<File>;
      FileReader reader = FileReader();
      final file = files[0];
      reader.readAsArrayBuffer(file);

      reader.onAbort.listen((e) {
        return;
      });

      reader.onError.listen((fileEvent) {
        return;
      });

      reader.onLoadEnd.listen((e) async {
        await _loadMasterFile(reader.result as List<int>);
        debugPrint(masterTable.length.toString());
        setState((){
          _isLoading = false;
          showAlert(context: context, text: const Text("MASTERFILE loaded successfully"));
        });
      });
    });
  }

  Future<void> _loadMasterFile(List<int> bytes) async {
    if(bytes.isEmpty){
      loadingMsg = "...";
      return;
    }

    masterTable = List.empty();
    setState((){
      loadingMsg = "Decoding spreadsheet...";
    });
    await Future.delayed(const Duration(seconds: 1));

    try{
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
        _loadingMsg = "Creating header row...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      masterHeader = List.generate(
          table.rows[0].length, (index) => <String, dynamic>{"text" : table.rows[0][index].toString().toUpperCase(), "format" : CellFormat.words}
      );

      setState((){
        _loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      masterCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][2].toString().toUpperCase()).toSet().toList();

      setState((){
        _loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      masterTable = List.generate(table.rows.length, (index) => List<String>.generate(masterHeader.length, (index2) => table.rows[index][index2].toString().toUpperCase()));
      masterTable.removeAt(0); // Remove header from main

      setState((){
        _loadingMsg = "Creating backup table...";
      });
      await Future.delayed(const Duration(milliseconds:500));
      bkpTable = List.of(masterTable); // Copy loaded masterTable for later use

      setState((){
        _loadingMsg = "The spreadsheet was imported.";
      });
    }
    catch (e){
      debugPrint("The Spreadsheet has errors:\n ---> $e");
      _loadingMsg = "The Spreadsheet has errors:\n ---> $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset("AS_logo_light.svg", height: 50),
      ),
      body: SingleChildScrollView(
          child: Center(
              child: Column(
                children: _isLoading ? [
                  SizedBox(height: MediaQuery.of(context).size.height/3),
                  Text(_loadingMsg, textAlign: TextAlign.center, style: blackText),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
                  )
                ] : [
                  SizedBox(
                    height: MediaQuery.of(context).size.height/3,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: () async {
                          setState((){
                            _isLoading = true;
                          });

                          filePicker();

                        },
                        child: const Text("Load MASTERFILE")
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if(masterTable.isNotEmpty){
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const GridView()));
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
                        onPressed: () {
                          // Go back
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

class GridView extends StatefulWidget{
  const GridView({super.key});
  @override
  State<GridView> createState() => _GridView();
}
class _GridView extends State<GridView> {
  // int _selectRow = -1;
  // int _selectCell = -1;
  // int _searchColumn = 0;

  bool _selectAll = false;
  String _loadingMsg = "Loading...";
  bool _isLoading = false;

  List<Map<String, dynamic>> _header = [];
  List<List<String>> _filterList = [];
  List<List<String>> _addList = [];
  List<bool> _isChecked = [];

  @override
  void initState() {
    super.initState();
    if(jobTable.isEmpty){
      filePicker();
    }
  }

  Future<void> filePicker() async {
    setState(() {
      _isLoading = true;
    });

    // Load xlsx from file browser
    FileUploadInputElement uploadInput = FileUploadInputElement();
    uploadInput.click();

    uploadInput.onAbort.listen((e){
      return;
    });

    uploadInput.onChange.listen((e) {
      // read file content as dataURL
      List<File> files = List.empty();
      files = uploadInput.files as List<File>;
      FileReader reader = FileReader();
      final file = files[0];
      reader.readAsArrayBuffer(file);

      reader.onAbort.listen((e) {
        return;
      });

      reader.onError.listen((fileEvent) {
        return;
      });

      reader.onLoadEnd.listen((e) async {
        await _loadJobSheet(reader.result as List<int>);
        //debugPrint(jobTable.length.toString());
        setState((){
          _isLoading = false;
        });
      });
    });
  }

  Future<void> _loadJobSheet(List<int> bytes) async{
    if(bytes.isEmpty){
      setState((){
        _loadingMsg = "...";
      });
      return;
    }

    jobTable = List.empty(growable: true);

    setState((){
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
        _loadingMsg = "Creating header row...";
      });

      await Future.delayed(const Duration(milliseconds:500));
      jobHeader = List.generate(
          table.rows[0].length, (index) => <String, dynamic>{"text" : table.rows[0][index].toString().toUpperCase(), "format" : CellFormat.words}
      );

      setState((){
        _loadingMsg = "Creating categories...";
      });

      await Future.delayed(const Duration(milliseconds:500));
      jobCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][0].toString().toUpperCase()).toSet().toList();

      setState((){
        _loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      jobTable = List.generate(table.rows.length, (index) => [(index-1).toString()] + List<String>.generate(jobHeader.length, (index2) => table.rows[index][index2].toString().toUpperCase()));
      jobTable.removeAt(0); // Remove header from main

      setState((){
        _header = List.of(jobHeader);
        _filterList = List.of(jobTable);
        _isChecked = List<bool>.filled(jobTable.length, false);
      });
    }
    catch (e){
      debugPrint("The Spreadsheet has errors:\n ---> $e");
      _loadingMsg = "The Spreadsheet has errors:\n ---> $e";
    }
  }

  Widget tableHeader(){
    double height = MediaQuery.of(context).size.height / 2.0;
    double cellHeight = height / 8.0;
    return Row(
        children: [
          Expanded(
            flex: 1,
            child: Checkbox(
              value: _selectAll,
              onChanged: (value){
                setState((){
                  _selectAll = _selectAll ? false : true;
                  _isChecked = List<bool>.generate(_isChecked.length, (index) => _selectAll);
                  _addList.clear();
                  if(_selectAll){
                    _addList = List.of(jobTable);
                  }
                });
              }
            )
          ),
          Expanded(
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
                child: const Text(
                  "Table Index",
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  softWrap: true,
                ),
              )
          )
        ] + List.generate(_header.length, (index) =>
            Expanded(
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
                  child: Text(
                    _header[index]["text"],
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    softWrap: true,
                  ),
                )
            )
      )
    );
  }

  Widget getRow(int tableIndex){
    double height = MediaQuery.of(context).size.height / 2.0;
    double cellHeight = height / 8.0;
    return Row(
        children: [
          Expanded(
            flex: 1,
            child: Checkbox(
              value: _isChecked[tableIndex],
              onChanged: (value){
                setState((){
                  _isChecked[tableIndex] = _isChecked[tableIndex] ? false : true;
                  if(_isChecked[tableIndex]){
                    _addList.add(jobTable[tableIndex]);
                  }
                  else{
                    _addList.remove(jobTable[tableIndex]);
                  }
                });
              }
            )
          )
        ] + List.generate(jobTable[tableIndex].length, (index) =>
            Expanded(
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
                  child: Text(
                    jobTable[tableIndex][index],
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    softWrap: true,
                  ),
                )
            )
        )
    );
  }

  void selectChangedItems() {
    // Go through both tables and check for any differences
    for(int i = 0; i < jobTable.length; i++){
      for(int m = 0; m < masterTable.length; m++){
        if(jobTable[i][Index.jobMasterIndex] == masterTable[m][Index.masterIndex]){
          if(jobTable[i][Index.jobBarcode] != masterTable[m][Index.masterBarcode] ||
            jobTable[i][Index.jobCategory] != masterTable[m][Index.masterCategory] ||
            jobTable[i][Index.jobDescript] != masterTable[m][Index.masterDescript] ||
            jobTable[i][Index.jobPrice] != masterTable[m][Index.masterPrice] ||
            jobTable[i][Index.jobOrdercode] != masterTable[m][Index.masterOrdercode]){
            _isChecked[i] = true;
          }
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width / 1.2;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SvgPicture.asset("AS_logo_light.svg", height: 50),
      ),
      body: SingleChildScrollView(
          child:
          Padding(
              padding: const EdgeInsets.all(8.0),
              child: _isLoading ?
              Center(
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
              ) : Column (
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
                        return tableHeader();
                      },
                    ),
                  ),
                  Container(
                    width: width,
                    height: MediaQuery.of(context).size.height / 2,
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
                      prototypeItem: getRow(int.parse(_filterList.first[0])),
                      itemBuilder: (context, index) {
                        final int tableIndex = int.parse(_filterList[index][0]);
                        return getRow(tableIndex);
                      },
                    ) :
                    Expanded(
                        flex: 1,
                        child: Text("EMPTY", style: greyText, textAlign: TextAlign.center,)
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        selectChangedItems();
                      },
                      child: const Text("Select Changed Items"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterList = _filterList.length != jobTable.length ? List.of(jobTable) :
                          jobTable.where((row) => row[Index.jobNof].toString().toUpperCase() == "TRUE").toList();
                        });
                      },
                      child: _filterList.length == jobTable.length ? const Text("Show NOF List") : const Text("Show Full List"),
                    ),
                  ),
                  _addList.isNotEmpty ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: () {
                          setState((){
                            String fString = "";
                            for(int i = 0; i < _addList.length; i++){
                              fString += "${_addList[i]}\n";
                            }
                            showAlert(context: context, text: Text(fString));
                          });
                        },
                        child: const Text("Update MASTERFILE")
                    ),
                  ) : Container(),
                ],
              )
          )
      )
    );
  }
}

updateMasterFile(List<List<String>> addList){
  for(int i = 0; i < masterTable.length; i++){
    
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

showAlert({required BuildContext context, required Text text, Color? color}) {
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

String getDateString(String d){
  String newDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
  if(d.isNotEmpty) {
    try{
      int timestamp = int.tryParse(d) ?? -1;
      if(timestamp != -1){
        const gsDateBase = 2209161600 / 86400;
        const gsDateFactor = 86400000;
        final millis = (timestamp - gsDateBase) * gsDateFactor;
        String date = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true).toString();
        date = date.substring(0, 10);
        List<String> dateSplit = date.split("-");
        newDate = "${dateSplit[2]}/${dateSplit[1]}/${dateSplit[0]}";
      }
    }
    catch (e){
      return newDate;
    }
  }

  return newDate;
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

// class MainPage2 extends StatefulWidget{
//   const MainPage2({super.key});
//   @override
//   State<MainPage2> createState() => _MainPage2();
// }
// class _MainPage2 extends State<MainPage2>{
//   Action action = Action.blank;
//   TextEditingController masterSearchCtrl = TextEditingController();
//   TextEditingController jobSearchCtrl = TextEditingController();
//   List<List<String>> jobFilterList = [[]];
//   List<List<String>> masterFilterList = [[]];
//   List<String> masterEdit = [];
//   List<String> jobEdit = [];
//   String loadingMsg = "Loading...";
//   int masterRow = -1;
//   int masterCell = -1;
//   int jobRow = -1;
//   int jobCell = -1;
//   int searchColumn = 0;
//   bool isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   void dispose(){
//     masterSearchCtrl.dispose();
//     jobSearchCtrl.dispose();
//     super.dispose();
//   }
//
//   // void _filePicker({bool? job}) {
//   //   // Load xlsx from file browser
//   //   FileUploadInputElement uploadInput = FileUploadInputElement();
//   //   uploadInput.click();
//   //
//   //   uploadInput.onAbort.listen((e){
//   //     setState(() {
//   //       isLoading = false;
//   //     });
//   //     return;
//   //   });
//   //
//   //   uploadInput.onChange.listen((e) {
//   //     // read file content as dataURL
//   //     List<File> files = List.empty();
//   //     files = uploadInput.files as List<File>;
//   //
//   //     FileReader reader = FileReader();
//   //
//   //     final file = files[0];
//   //     reader.readAsArrayBuffer(file);
//   //
//   //     reader.onAbort.listen((e) {
//   //       setState(() {
//   //         isLoading = false;
//   //       });
//   //       return;
//   //     });
//   //
//   //     reader.onError.listen((fileEvent) {
//   //       return;
//   //     });
//   //
//   //     reader.onLoadEnd.listen((e) async {
//   //       bool master = (job ?? false) == false;
//   //       if(master){
//   //         await loadMasterSheet(bytes: reader.result as List<int>, master: master).then((value){
//   //           setState(() {
//   //             masterFilterList = List.of(masterTable);
//   //             //jobFilterList = List.of(jobTable);
//   //             isLoading = false;
//   //           });
//   //         });
//   //       }
//   //       else {
//   //         await loadJobSheet(bytes: reader.result as List<int>).then((value) {
//   //           setState(() {
//   //             jobFilterList = List.of(jobTable);
//   //             debugPrint(jobTable[2].toString());
//   //             isLoading = false;
//   //           });
//   //         });
//   //       }
//   //     });
//   //   });
//   // }
//
//   Widget _blank(){
//     double height = MediaQuery.of(context).size.height;
//     return SizedBox(
//       height: height,
//       child: SvgPicture.asset("AS_logo_symbol.svg", width: height/2)
//     );
//   }
//
//   Widget _uploadPage(){
//     return Column(
//         children: [
//           SizedBox(
//               height: MediaQuery.of(context).size.height/3
//           ),
//           ElevatedButton(
//               onPressed: (){},
//               child: const Text("Edit")
//           ),
//           const SizedBox(height: 20.0),
//           ElevatedButton(
//               onPressed: (){},
//               child: const Text("Commit")
//           ),
//           const SizedBox(height: 20.0),
//           Padding(
//             padding: const EdgeInsets.all(20.0),
//             child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
//           )
//         ]
//     );
//   }
//
//   bool showComparisons = false;
//   List<List<String>> compareTable = List.empty();
//
//   Widget _comparePage(){
//     return Column(
//       children:
//       showComparisons ? [
//         _tableView(
//           header: jobHeader,
//           table: compareTable,
//           width: MediaQuery.of(context).size.width * 0.5,
//           height: MediaQuery.of(context).size.height / 1.8,
//           padding: 10.0,
//           filterList: compareTable,
//           searchCtrl: jobSearchCtrl,
//           activeCell: jobCell,
//           activeRow: jobRow,
//           editItem: jobEdit,
//           job: true
//         )
//       ] : [
//         Row(
//           children:[
//             Expanded(
//                 child: _tableView(
//                     header: jobHeader,
//                     table: jobTable,
//                     width: MediaQuery.of(context).size.width * 0.5,
//                     height: MediaQuery.of(context).size.height / 1.8,
//                     padding: 10.0,
//                     filterList: List.of(jobFilterList),
//                     searchCtrl: jobSearchCtrl,
//                     activeCell: jobCell,
//                     activeRow: jobRow,
//                     editItem: jobEdit,
//                     job: true
//               )
//             ),
//             // Expanded(
//             //     child: _tableView(
//             //         header: masterHeader,
//             //         table: masterTable,
//             //         width: MediaQuery.of(context).size.width * 0.5,
//             //         height: MediaQuery.of(context).size.height / 1.8,
//             //         padding: 10.0,
//             //         filterList: List.of(masterFilterList),
//             //         searchCtrl: masterSearchCtrl,
//             //         activeRow: masterRow,
//             //         activeCell: masterCell,
//             //         editItem: masterEdit
//             //     )
//             // ),
//           ]
//         ),
//         ElevatedButton(
//           //width: 250,
//           child: const Text("Compare Tables"),
//           onPressed: () async{
//             await _compareTables().then((value){
//               showAlert(context: context, text: Text("Table length: ${value.length}"), color: colorOk);
//               if(value.isNotEmpty){
//                 compareTable = value;
//                 //debugPrint(compareTable[0].toString());
//                 showComparisons = true;
//                 setState((){});
//               }
//               // Show page of table that consists of comparison list.
//             });
//           }
//         ),
//
//       ],
//     );
//   }
//
//   Future<List<List<String>>> _compareTables() async{
//     // go through both tables and check for any differences
//     List<List<String>> badComparisons = List.empty(growable: true);
//     for(int i = 0; i < jobTable.length; i++){
//       for(int j = 0; j < masterHeader.length; j++){
//         if(jobTable[i][j] != masterTable[i][j]){
//           badComparisons.add(jobTable[i]);
//           break;
//         }
//       }
//     }
//     return badComparisons;
//   }
//
//   Widget _tableView({
//     bool? job,
//     required List<Map<String, dynamic>> header,
//     required List<List<String>> table,
//     required List<List<String>> filterList,
//     required double width,
//     required double height,
//     required double padding,
//     required TextEditingController searchCtrl,
//     required List<String> editItem,
//     required activeRow,
//     required activeCell,
//   }){
//
//     bool isJob = job ?? false;
//
//     double cellHeight = height/8;
//
//     setTableState(){
//       setState((){
//         if(isJob){
//           jobSearchCtrl = searchCtrl;
//           jobFilterList = filterList;
//           jobRow = activeRow;
//           jobCell = activeCell;
//           jobEdit = editItem;
//         }
//         else{
//           masterSearchCtrl = searchCtrl;
//           masterFilterList = filterList;
//           masterRow = activeRow;
//           masterCell = activeCell;
//           masterEdit = editItem;
//         }
//       });
//     }
//
//     confirmEdit(int index){
//       setState((){
//         if(isJob){
//           jobTable[index] = List.of(editItem);
//         }
//         else{
//           masterTable[index] = List.of(editItem);
//         }
//       });
//     }
//
//     Widget searchBar(double width){
//       searchWords(String searchText){
//         bool found = false;
//         List<String> searchWords = searchText.split(" ").where((String s) => s.isNotEmpty).toList();
//         List<List<String>> refined = [[]];
//
//         for (int i = 0; i < searchWords.length; i++) {
//           if (!found) {
//               filterList = table.where((row) => row[searchColumn].contains(searchWords[i])).toList();
//               found = filterList.isNotEmpty;
//           }
//           else {
//               refined = filterList.where((row) => row[searchColumn].contains(searchWords[i])).toList();
//               if(refined.isNotEmpty){
//                 filterList = List.of(refined);
//               }
//           }
//         }
//
//         if(!found){
//             filterList = List.empty();
//         }
//       }
//
//       return Container(
//           width: width,
//           decoration: BoxDecoration(
//             color: colorOk,
//             border: Border.all(
//               color: colorOk,
//               style: BorderStyle.solid,
//               width: 2.0,
//             ),
//             borderRadius: BorderRadius.circular(20.0),
//           ),
//
//           child: ListTile(
//             leading: PopupMenuButton(
//                 icon: const Icon(Icons.manage_search, color: Colors.white),
//                 itemBuilder: (context) {
//                   return List.generate(header.length, (index) =>
//                       PopupMenuItem<int> (
//                         value: index,
//                         child: ListTile(
//                           title: Text("Search ${header[index]["text"]}"),
//                           trailing: index == searchColumn ? const Icon(Icons.check) : null,
//                         ),
//                       )
//                   );
//                 },
//                 onSelected: (value) async {
//                   setState((){
//                     searchColumn = value;
//                   });
//                 }
//             ),
//
//             title: TextFormField(
//               controller: searchCtrl,
//               decoration: InputDecoration(
//                 filled: true,
//                 fillColor: Colors.white,
//                 hintText: "Search ${header[searchColumn]["text"].toLowerCase()}...",
//                 border: InputBorder.none,
//               ),
//
//               onChanged: (String value){
//                 activeRow = -1;
//
//                 if(value.isNotEmpty){
//                   searchWords(value.toUpperCase());
//                 }
//                 else{
//                     filterList = List.of(table);
//                 }
//
//                 setTableState();
//               },
//             ),
//
//             trailing: IconButton(
//               icon: const Icon(Icons.clear, color: Colors.white),
//               onPressed: () {
//                   searchCtrl.clear();
//                   filterList = table;
//                   setTableState();
//               },
//             ),
//           )
//       );
//     }
//
//     Widget tableHeader(){
//       return Row(
//         children: List.generate(header.length, (index) => Expanded(
//           child: Container(
//               height: cellHeight,
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.0),
//                 borderRadius: BorderRadius.zero,
//                 border: Border.all(
//                   color: Colors.black,
//                   style: BorderStyle.solid,
//                   width: 1.0,
//                 ),
//               ),
//               child: TapRegion(
//                 child: Center(
//                     child: Text(
//                       header[index]["text"],
//                       softWrap: true,
//                       maxLines: 3,
//                       overflow: TextOverflow.fade,
//                       style: cellText
//                   )
//               ),
//               onTapInside: (value){
//                 showAlert(
//                     context: context,
//                     text: Text("Cell Text: ${header[index]["text"]}\n\nCell Format: ${header[index]["format"]}")
//                 );
//               },
//             )
//           )
//         ))
//       );
//     }
//
//     Widget editRow(){
//       return Row(
//           children: List.generate(header.length, (index) => Expanded(
//               child: Container(
//                 height: cellHeight,
//                 width: index == 3 ? 150 : 50,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.0),
//                   borderRadius: BorderRadius.zero,
//                   border: Border.all(
//                     color: colorOk, //Colors.black,
//                     style: BorderStyle.solid,
//                     width: 2.0,
//                   ),
//                 ),
//                 child: TapRegion(
//                   onTapInside:(value) {
//                     activeCell = index;
//                     setTableState();
//                   },
//
//                   child: activeCell == index ? TextFormField(
//                     autofocus: true,
//                     initialValue: activeRow < 0 ? "" :  table[activeRow][index],
//                     textAlign: TextAlign.center,
//                     maxLines: 4,
//                     onTapOutside: (value){
//                       activeCell = -1; // Disable text edit on tap outside
//                       //editItem[index] = value as String;
//                       setTableState();
//                       // setState((){
//                       //   activeCell = -1;
//                       // });q
//                     },
//                     onChanged: (String value){
//                       editItem[index] = value;
//                       setTableState();
//                     },
//                   ) : Text(
//                     activeRow < 0 ? "" : editItem[index],
//                     textAlign: TextAlign.center,
//                     maxLines: 4,
//                     softWrap: true,
//                   ),
//                 )
//               )
//           )
//           )
//       );
//     }
//
//     Widget getRow(int tableIndex){
//       int tableLength = table[tableIndex].length;//isJob ? jobTable[tableIndex].length : masterTable[tableIndex].length;
//       return TapRegion(
//           onTapInside: (value) {
//             activeRow = tableIndex;
//             editItem = List.of(table[tableIndex]);
//             setTableState();
//           },
//           child: Row(
//               children: List.generate(tableLength, (index) => Expanded(
//                   child: Container(
//                     height: cellHeight,
//                     decoration: BoxDecoration(
//                       color: activeRow == tableIndex ? Colors.white24 : Colors.white.withOpacity(0.0),
//                       borderRadius: BorderRadius.zero,
//                       border: Border.all(
//                         color: Colors.black,
//                         style: BorderStyle.solid,
//                         width: 1.0,
//                       ),
//                     ),
//                     child: Text(
//                       table[tableIndex][index],
//                       textAlign: TextAlign.center,
//                       maxLines: 4,
//                       softWrap: true,
//                     ),
//                   )
//               )
//           )
//       ),
//       );
//     }
//
//     return Padding(
//         padding: EdgeInsets.all(padding),
//         child: TapRegion(
//             onTapOutside: (value){
//               setState(() {
//                 // if(activeCell < 0){
//                 //   activeRow = -1;
//                 // }
//               });
//             },
//
//             child: Column(
//                 children:[
//                   SizedBox(
//                     width: width,
//                     child: tableHeader(),
//                   ),
//                   Container(  // Main Scrollable list
//                     width: width,
//                     height: height,
//                     decoration: BoxDecoration(
//                       border: Border.all(
//                         color: Colors.black.withOpacity(0.5),
//                         style: BorderStyle.solid,
//                         width: 1.0,
//                       ),
//                     ),
//                     child: filterList.isNotEmpty ? ListView.builder(
//                       itemCount: filterList.length,
//                       prototypeItem: getRow(int.parse(filterList.first[0])),
//                       itemBuilder: (context, index) {
//                         final int tableIndex = int.parse(filterList[index][0]);
//                         return getRow(tableIndex);
//                       },
//                     ) :
//                     Row(
//                         children: [
//                           Expanded(child: Text("EMPTY", style: greyText, textAlign: TextAlign.center,))
//                         ]
//                     ),
//                   ),
//                   const SizedBox(
//                     height: 5.0,
//                   ),
//
//                   action != Action.compare ? searchBar(width) : Container(),
//                   const SizedBox(
//                     height: 5.0,
//                   ),
//                   Container(
//                       width: width,
//                       color: colorOk,
//                       child: Text("Edit Row", textAlign: TextAlign.center, style: whiteText)
//                   ),
//                   SizedBox(
//                     width: width,
//                     child: editRow(),
//                   ),
//                   const SizedBox(
//                     height: 5.0,
//                   ),
//                   activeRow > 0 ? SizedBox(
//                     width: width,
//                     child: Row(
//                         children:[
//                           ElevatedButton(
//                               onPressed: () {
//                                 activeRow = -1;
//                                 activeCell = -1;
//                                 setTableState();
//                               },
//                               child: const Text("CLEAR")
//                           ),
//                           ElevatedButton(
//                               onPressed: () {
//                                 int i = int.tryParse(editItem[0]) ?? -1;
//                                 if(i>- 0){
//                                   confirmEdit(i);
//                                 }
//                               },
//                               child: const Text("SAVE EDIT")
//                           )
//                         ]
//                     )
//                   ) : Container(),
//                 ]
//             )
//         )
//     );
//   }
//
//   ListView _drawerMenu(){
//     return ListView(
//       children: <Widget>[
//         const SizedBox(height: 5),
//         ListTile(
//           leading: const Icon( Icons.arrow_back_outlined, color: Colors.white),
//           hoverColor: Colors.white70,
//           onTap: (){
//             Navigator.pop(context);
//           },
//         ),
//         const SizedBox(height: 20),
//         ListTile(
//           leading: const Icon( Icons.cloud_download, color: Colors.white),
//           title: const Text("Get Master File", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//           hoverColor: Colors.white70,
//           onTap: () async {
//             setState(() {
//               loadingMsg = "Waiting for file...";
//               isLoading = true;
//               action = Action.view;
//             });
//
//             //_filePicker();
//
//             Navigator.pop(context);
//           },
//         ),
//         const SizedBox(height: 20),
//         ListTile(
//           leading: Icon( Icons.open_in_browser, color: masterTable.isNotEmpty ? Colors.white : Colors.grey),
//           title: const Text("Upload Job File & Edit", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//           hoverColor: Colors.white70,
//           onTap: () async {
//             // OPEN JOB FILE SCREEN
//             setState((){
//               loadingMsg = "Waiting for file...";
//               isLoading = true;
//               action = Action.compare;
//             });
//
//             //_filePicker(job: true);
//             Navigator.pop(context);
//
//             // if(masterTable.isNotEmpty){
//             //   setState(() {
//             //     loadingMsg = "Waiting for file...";
//             //     //isLoading = true;
//             //     action = Action.compare;
//             //   });
//             //
//             //   //_filePicker(job: true);
//             //   Navigator.pop(context);
//             // }
//             // else{
//             //   showAlert(context: context, text: const Text("MASTER table is empty.", textAlign: TextAlign.center,));
//             //   //Show pop up
//             // }
//           }
//         ),
//         const SizedBox(height: 20),
//         ListTile(
//           leading: Icon( Icons.cloud_upload, color: Colors.red.shade50),
//           title: const Text("Upload changes to Masterfile", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//           hoverColor: Colors.white70,
//           onTap: () {
//             action = Action.upload;
//             setState(() {});
//             Navigator.pop(context);
//           },
//         ),
//         const SizedBox(height: 20),
//         ListTile(
//           leading: const Icon(Icons.logout_outlined, color: Colors.white),
//           title: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//           hoverColor: Colors.white70,
//           onTap: () async {
//             await confirmDialog(context, "End session and logout?").then((value){
//               if(value){
//                 masterTable = List.empty();
//                 jobTable = List.empty();
//                 jobHeader = List.empty();
//                 masterHeader = List.empty();
//                 masterCategory = List.empty();
//                 jobCategory = List.empty();
//                 bkpTable = List.empty();
//
//                 Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => const LoginPage()));
//               }
//             });
//           },
//         ),
//       ],
//     );
//   }
//
//   Widget _getMainBody(){
//     double mediaHeight = MediaQuery.of(context).size.height;
//
//     if(action == Action.blank){
//       masterTable = List.empty();
//       return _blank();
//     }
//     else if(action == Action.upload){
//       return _uploadPage();
//     }
//     else if(action == Action.compare){
//       if(isLoading){
//         // Show loading icon animation
//         return Column(
//             children: [
//               SizedBox(height: MediaQuery.of(context).size.height/3),
//               Text(loadingMsg, textAlign: TextAlign.center, style: blackText),
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
//               )
//             ]
//         );
//       }
//       else if(jobTable.isNotEmpty){
//         return _comparePage();
//       }
//       // else if(masterTable.isNotEmpty){
//       //   return _comparePage();
//       // }
//     }
//     else if(action == Action.view){
//       if(isLoading){
//         return Column(
//             children: [
//               SizedBox(height: MediaQuery.of(context).size.height/3),
//               Text(loadingMsg, textAlign: TextAlign.center, style: blackText),
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
//               )
//             ]
//         );
//       }
//       else if(masterTable.isNotEmpty){
//         return _tableView(
//           header: masterHeader,
//             table: masterTable,
//             width: MediaQuery.of(context).size.width / 1.5,
//             height: mediaHeight / 2,
//             padding: 8.0,
//             filterList: masterFilterList,
//             searchCtrl: masterSearchCtrl,
//             activeRow: masterRow,
//             activeCell: masterCell,
//             editItem: masterEdit
//         );
//       }
//     }
//
//     return _blank();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           centerTitle: true,
//           title: SvgPicture.asset("AS_logo_light.svg", height: 50),
//           leading: Builder(
//               builder: (context) => IconButton(
//                 icon: const Icon(Icons.menu, color: Colors.white),
//                 onPressed: () => Scaffold.of(context).openDrawer(),
//               )
//           ),
//         ),
//
//         drawer: Drawer(
//             child: Material(
//                 color: Colors.blue,
//                 child: _drawerMenu()
//             )
//         ),
//
//         body: SingleChildScrollView(
//             child: Center(
//                 child: _getMainBody()
//             )
//         )
//     );
//   }
// }

// ListView drawerMenu(BuildContext context){
//   return ListView(
//     children: <Widget>[
//       const SizedBox(height: 5),
//       ListTile(
//         leading: const Icon( Icons.arrow_back_outlined, color: Colors.white),
//         hoverColor: Colors.white70,
//         onTap: (){
//           Navigator.pop(context);
//         },
//       ),
//       const SizedBox(height: 20),
//       ListTile(
//         leading: const Icon( Icons.cloud_download, color: Colors.white),
//         title: const Text("Get Master File", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//         hoverColor: Colors.white70,
//         onTap: () async {
//           // setState(() {
//           //   loadingMsg = "Waiting for file...";
//           //   isLoading = true;
//           //   action = Action.view;
//           // });
//           //
//           // _filePicker();
//
//           Navigator.pop(context);
//         },
//       ),
//       const SizedBox(height: 20),
//       ListTile(
//           leading: Icon( Icons.open_in_browser, color: masterTable.isNotEmpty ? Colors.white : Colors.grey),
//           title: const Text("Upload Job File & Edit", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//           hoverColor: Colors.white70,
//           onTap: () async {
//             // // OPEN JOB FILE SCREEN
//             // setState((){
//             //   loadingMsg = "Waiting for file...";
//             //   isLoading = true;
//             //   action = Action.compare;
//             // });
//             //
//             // _filePicker(job: true);
//             Navigator.pop(context);
//           }
//       ),
//       const SizedBox(height: 20),
//       ListTile(
//         leading: Icon( Icons.cloud_upload, color: Colors.red.shade50),
//         title: const Text("Upload changes to Masterfile", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//         hoverColor: Colors.white70,
//         onTap: () {
//           // action = Action.upload;
//           // setState(() {});
//           Navigator.pop(context);
//         },
//       ),
//       const SizedBox(height: 20),
//       ListTile(
//         leading: const Icon(Icons.logout_outlined, color: Colors.white),
//         title: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontSize: 20.0)),
//         hoverColor: Colors.white70,
//         onTap: () async {
//           await confirmDialog(context, "End session and logout?").then((value){
//             if(value){
//               masterTable = List.empty();
//               jobTable = List.empty();
//               jobHeader = List.empty();
//               masterHeader = List.empty();
//               masterCategory = List.empty();
//               jobCategory = List.empty();
//               bkpTable = List.empty();
//
//               Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => const LoginPage()));
//             }
//           });
//         },
//       ),
//     ],
//   );
// }

// Container getCell(double height, String text){
//   return Container(
//     width: 75,//cellWidth[index],
//     height: height,
//     decoration: BoxDecoration(
//       color: Colors.white24,
//       borderRadius: BorderRadius.zero,
//       border: Border.all(
//         color: Colors.black,
//         style: BorderStyle.solid,
//         width: 1.0,
//       ),
//     ),
//     child: Text(
//       text,
//       textAlign: TextAlign.center,
//       maxLines: 4,
//       softWrap: true,
//     ),
//   );
// }
