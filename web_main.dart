import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:async';

String versionStr = "0.23.09+1";
String loadingMsg = "";

List<List<String>> masterTable = [];
List<String> masterHeader = [];
List<String> masterCategory = [];
TextStyle get whiteText{ return const TextStyle(color: Colors.white, fontSize: 20.0);}
TextStyle get blackText{ return const TextStyle(color: Colors.black, fontSize: 20.0);}
TextStyle get greyText{ return const TextStyle(color: Colors.black12, fontSize: 20.0);}
final Color colorOk = Colors.blue.shade400;
const Color colorError = Colors.redAccent;
final Color colorWarning = Colors.deepPurple.shade200;

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
      _pickMasterFile();
    }
    else{
      _isLoading = false;
    }
  }

  @override
  void dispose(){
    super.dispose();
  }

  void _pickMasterFile() async{
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
      await _loadMasterFile(reader.result as List<int>);

      setState((){
        _isLoading = false;
        showAlert(context: context, text: const Text("MASTERFILE loaded successfully"));
      });
    });
  }
  
  Future<void> _loadMasterFile(List<int> bytes) async {
    if(bytes.isEmpty){
      loadingMsg = "...";
      return;
    }

    setState((){
      masterTable = List.empty();
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

      masterHeader = List.generate(table.rows[0].length, (index) => table.rows[0][index].toString().toUpperCase());

      setState((){
        _loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      masterCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][2].toString().toUpperCase()).toSet().toList();

      setState((){
        _loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      masterTable = List.generate(table.rows.length, (index) =>
        List<String>.generate(masterHeader.length, (index2) =>
            index2 == Index.masterDate ? getDateString(string: table.rows[index][index2].toString()) :
              table.rows[index][index2].toString().toUpperCase()
        )
      );
      masterTable.removeAt(0); // Remove header from main

      setState((){
        _loadingMsg = "Spreadsheet was imported successfully.";
      });
    }
    catch (e){
      _loadingMsg = "The Spreadsheet has errors:\n ---> $e";
    }
  }

  exportXLSX() async {
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
            masterTable[i][0],
            masterTable[i][1],
            masterTable[i][2],
            masterTable[i][3],
            masterTable[i][4],
            masterTable[i][5],
            masterTable[i][6],
            masterTable[i][7]
          ],
          i+1
      );
      String dateFormat = getDateString(string: masterTable[i][6]);
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
    //var fileBytes = exportExcel.save(fileName: filename);
    exportExcel.save(fileName: filename);

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
                children:_isLoading ? [
                SizedBox(height: MediaQuery.of(context).size.height/3),
                  Text(_loadingMsg, textAlign: TextAlign.center, style: blackText),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
                  )
                ] : [
                  SizedBox(
                    height: MediaQuery.of(context).size.height/4,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                        onPressed: () async {
                          if(masterTable.isEmpty){
                            setState((){
                              _isLoading = true;
                            });
                            pickFile(".xlsx");
                          }
                          else{
                            //tempMasterTable = List.of(masterTable);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterTableView()));
                          }
                        },
                        child: masterTable.isEmpty ? const Text("Get MASTERFILE") : const Text("View MASTERFILE"),
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
                        // setState((){
                        //   _isLoading = true;
                        // });

                        //uploadMasterfile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, // Background color
                      ),
                      child: const Text("Push MASTERFILE"),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async{
                        setState((){
                          _isLoading = true;
                        });
                        exportXLSX();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                      ),
                      child: const Text("Download MASTERFILE"),
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
                            await confirmDialog(context, "Logout of current session?").then((value){
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                            });
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
        _loadingMsg = "Creating header row...";
      });
      await Future.delayed(const Duration(milliseconds:500));

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
      //debugPrint("The Spreadsheet has errors:\n ---> $e");
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
        if(_jobTable[i][Index.jobBarcode] != masterTable[tableIndex][Index.masterBarcode] ||
          _jobTable[i][Index.jobCategory] != masterTable[tableIndex][Index.masterCategory] ||
          _jobTable[i][Index.jobDescript] != masterTable[tableIndex][Index.masterDescript] ||
          _jobTable[i][Index.jobPrice] != masterTable[tableIndex][Index.masterPrice] ||
          _jobTable[i][Index.jobOrdercode] != masterTable[tableIndex][Index.masterOrdercode]) {
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
        if(_jobTable[i][Index.jobBarcode] != masterTable[tableIndex][Index.masterBarcode] ||
            _jobTable[i][Index.jobCategory] != masterTable[tableIndex][Index.masterCategory] ||
            _jobTable[i][Index.jobDescript] != masterTable[tableIndex][Index.masterDescript] ||
            _jobTable[i][Index.jobPrice] != masterTable[tableIndex][Index.masterPrice] ||
            _jobTable[i][Index.jobOrdercode] != masterTable[tableIndex][Index.masterOrdercode]) {
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
                              masterTable.add([
                                masterTable.length.toString(),
                                _jobTable[index][Index.jobBarcode],
                                _jobTable[index][Index.jobCategory],
                                _jobTable[index][Index.jobDescript],
                                "EACH",
                                _jobTable[index][Index.jobPrice],
                                _jobTable[index][Index.jobDate],
                                _jobTable[index][Index.jobOrdercode]
                              ]);
                            }
                            else {
                              masterTable[index][Index.masterBarcode] = _jobTable[index][Index.jobBarcode];
                              masterTable[index][Index.masterOrdercode] = _jobTable[index][Index.jobCategory];
                              masterTable[index][Index.masterDescript] = _jobTable[index][Index.jobDescript];
                              masterTable[index][Index.masterPrice] = _jobTable[index][Index.jobPrice];
                              masterTable[index][Index.masterOrdercode] = _jobTable[index][Index.jobOrdercode];
                              masterTable[index][Index.masterDate] = _jobTable[index][Index.jobBarcode];
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
  List<List<String>> _tempMasterTable = [];
  List<List<String>> _filterList = [];
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
    _tempMasterTable.sort((x, y) => (x[Index.masterDescript]).compareTo((y[Index.masterDescript])));

    //Calc new indices from list
    for(int i = 0; i < _tempMasterTable.length; i++){
      _tempMasterTable[i][Index.masterIndex] = i.toString();
    }
  }

  Widget _headerPadding(String title, TextAlign l) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 10.0, bottom: 5),
      child: Text(title, textAlign: l, style: const TextStyle(color: Colors.blue,)),
    );
  }

  // Edit item or add new item
  _editDialog({required BuildContext context, List<String>? item, Color? color}) {
    bool newItem = false;
    List<String> editedItem = [];
    if(item == null){
      newItem = true;
      editedItem = [
        _tempMasterTable.length.toString(),
        ' ',
        'MISC',
        'NEW ITEM',
        'EACH',
        '0.0',
        getDateString(),
        ' '
      ];
    }
    else{
      editedItem = List.of(item);
    }

    editField(int itemIndex, int ctrlIndex){
      _editCtrl[ctrlIndex].text = editedItem[itemIndex];
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
                      editedItem[itemIndex] = value;
                    },
                  ),
                )
            ),
          ]
        )
      );
    }

    categoryDropField(int ctrlIndex) {
      _editCtrl[ctrlIndex].text = editedItem[Index.masterCategory];
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
                          editedItem[Index.masterCategory] = masterCategory[value];
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
                          editedItem[Index.masterBarcode] = "";
                          for(int b = 0; b < barcodeList.length; b++){
                            if(b < barcodeList.length -1){
                              editedItem[Index.masterBarcode] += "${barcodeList[b]},";
                            }
                            else{
                              editedItem[Index.masterBarcode] += barcodeList[b];
                            }
                          }
                          editedItem[Index.masterOrdercode] = "";
                          for(int o = 0; o < ordercodeList.length; o++){
                            if(o < ordercodeList.length -1){
                              editedItem[Index.masterOrdercode] += "${ordercodeList[o]},";
                            }
                            else{
                              editedItem[Index.masterOrdercode] += ordercodeList[o];
                            }
                          }
                          editedItem[Index.masterDate] = getDateString();
                          int tableIndex = int.parse(editedItem[Index.masterIndex]);

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
                List<List<String>> refined = [[]];

                for (int i = 0; i < searchWords.length; i++) {
                  if (!found){
                    _filterList = _tempMasterTable.where((row) => row[_searchColumn].contains(searchWords[i])).toList();
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

    cellFit(int index){
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
              masterHeader[index],
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
            masterHeader[index],
            textAlign: TextAlign.center,
            maxLines: 4,
            softWrap: true,
          ),
        )
      );
    }

    return Row(
      children: List.generate(masterHeader.length, (index) =>
        index != Index.masterIndex && index != Index.masterPrice ? cellFit(index) : cell(index)
      )
    );
  }

  Widget _getRow(int tableIndex){
    // Get formatted date string and check if it is old (> 1 year)
    int year = int.parse(_tempMasterTable[tableIndex][Index.masterDate].split("/").last);
    bool oldDate = (DateTime.now().year % 100) - (year % 100) > 0;
    double height = 50.0;
    double cellWidth = 75.0;
    Color cellColor = _editedItems.contains(tableIndex) ? Colors.blue.shade100 : Colors.white24;

    cellFit(int index){
      return Expanded(
        flex: 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: index == Index.masterDate && oldDate ? Colors.red[800] : cellColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: Colors.black,
              style: BorderStyle.solid,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              _tempMasterTable[tableIndex][index],
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
        height: height,
        width: cellWidth,
        decoration: BoxDecoration(
          color: index == Index.masterDate && oldDate ? Colors.red[800] : cellColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: Colors.black,
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            _tempMasterTable[tableIndex][index],
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
        barcodeList = _tempMasterTable[tableIndex][Index.masterBarcode].split(",");

        ordercodeIndex = 0;
        ordercodeList = _tempMasterTable[tableIndex][Index.masterOrdercode].split(",");
        await _editDialog(context: context, item: List.of(_tempMasterTable[tableIndex]));
      },
      child: Row(
        children: List.generate(_tempMasterTable[tableIndex].length, (index) => index != Index.masterIndex && index != Index.masterPrice ? cellFit(index) : cell(index),)
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
                    prototypeItem: _getRow(int.parse(_filterList.first[0])),
                    itemBuilder: (context, index) {
                      final int tableIndex = int.parse(_filterList[index][0]);
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
                                await _editDialog(context: context);
                              },
                              child: const Text("Add New Item")
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: ElevatedButton(
                              onPressed: () async {
                                await confirmDialog(context, "Confirm changes to MASTERFILE? \n Edited item count: ${_editedItems.length}").then((value){
                                  if(value){
                                    setState((){
                                      _sortList();
                                      masterTable = List.of(_tempMasterTable);
                                      _filterList = List.of(masterTable);
                                      _editedItems = [];
                                    });
                                  }
                                });
                              },
                              child: const Text("Update MASTERFILE")
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
