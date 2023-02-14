/*
   This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
   To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
   This program is distributed WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart';
import 'stock_job.dart';

Permission storageType = Permission.storage;
StockJob job = StockJob(id: "EMPTY", name: "EMPTY");
String dbPath = '';
Directory? rootDir;
SpreadsheetTable? mainTable;
List<String> masterCategory = [];
List<String> jobList = [];
Map<String, dynamic> sFile = {};
enum TableType {literal, linear, export, full, search}
enum ActionType {edit, add, addNOF, view}

// COLORS & STYLES
Color colorOk = Colors.blue.shade400;
Color colorEdit = Colors.blueGrey;
Color colorWarning = Colors.deepPurple.shade200;
Color colorDisable = Colors.blue.shade200;
Color colorBack = Colors.redAccent;
TextStyle get warningText{ return TextStyle(color: Colors.red[900], fontSize: sFile["fontScale"]);}
TextStyle get whiteText{ return TextStyle(color: Colors.white, fontSize: sFile["fontScale"]);}
TextStyle get greyText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}
TextStyle get blackText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}

// Main
void main() {
  runApp(
    const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomePage()
    ),
  );
}

// Home Page
class HomePage extends StatefulWidget{
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePage();
}
class _HomePage extends State<HomePage> {
  late String versionNum = "";
  late String buildNum = "";

  @override
  void initState() {
    super.initState();
    getVersion();
  }

  getVersion() async{
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    versionNum = packageInfo.version;
    buildNum = packageInfo.buildNumber;
    refresh(this);

    // Check for new version
    // Link to new version/download new version and install option?
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: SingleChildScrollView(
              child: Center(
                  child: Column(
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 35.0),
                          child: Center(
                            child: SizedBox(
                              width: 470,
                              height: 200,
                              child: Image(image: AssetImage('assets/AS_Logo2.png')),
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
                            context,
                            Colors.blue,
                            TextButton(
                              child: const Text('Jobs', style: TextStyle(color: Colors.white, fontSize: 20.0)),
                              onPressed: () async {

                                if(mainTable == null) {
                                  //mPrint("LOADING TABLE");
                                  loadingAlert(context);
                                  refresh(this);

                                  // load default spreadsheet
                                  await loadMasterSheet().then((value) async{
                                    if(mainTable != null || mainTable!.maxRows > 0){
                                      await showAlert(context, "", 'Master Spreadsheet was loaded successfully', colorOk).then((value) async{
                                        await getSession().then((value){
                                          refresh(this);
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const JobsPage()));
                                        });
                                      });
                                    }
                                  });
                                }
                                else{
                                  await getSession().then((value){
                                    refresh(this);
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const JobsPage()));
                                  });
                                }
                              },
                            )
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height/40.0,
                        ),
                        rBox(
                            context,
                            Colors.deepPurpleAccent.shade100,
                            TextButton(
                              child: const Text('Sync Master Database', style: TextStyle(color: Colors.white, fontSize: 20.0)),
                              onPressed: () async {
                                loadingAlert(context);
                                refresh(this);
                                await loadMasterSheet().then((value) async {
                                  await showAlert(context, "", 'Master Spreadsheet was loaded successfully', colorOk).then((value) {
                                    refresh(this);
                                    goToPage(context, const HomePage(), false);
                                  });
                                });
                              },
                            )
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height/40.0,
                        ),
                        rBox(
                          context,
                          Colors.redAccent.shade200,
                          TextButton(
                            child: const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 20.0)),
                            onPressed: () async {

                              // Load default if not loaded
                              if(mainTable == null){
                                //mPrint("LOADING TABLE");
                                loadingAlert(context);
                                refresh(this);

                                await loadMasterSheet().then((value) async {
                                  await showAlert(context, "", 'Master Spreadsheet was loaded successfully', colorOk).then((value) async{
                                    await getSession().then((value){
                                      goToPage(context, const AppSettings(), false);
                                    });
                                  });
                                });
                              }
                              else{
                                await getSession().then((value){
                                  goToPage(context, const AppSettings(), false);
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height/10.0 + 50.0,
                        ),

                        SizedBox(
                          height: MediaQuery.of(context).size.height/40.0,
                        ),
                        SizedBox(
                          height: 32,
                          width: MediaQuery.of(context).size.width,
                          child: Text('Version: $versionNum+$buildNum', style: const TextStyle(color: Colors.blueGrey), textAlign: TextAlign.center,),
                        ),
                      ]
                  )
              )
          ),
        )
    );
  }
}

// App Settings
class AppSettings extends StatefulWidget{
  const AppSettings({ super.key, });
  @override
  State<AppSettings> createState() => _AppSettings();
}
class _AppSettings extends State<AppSettings> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
          resizeToAvoidBottomInset: false,

          appBar: AppBar(
            centerTitle: true,
            title: const Text('App Settings'),
            automaticallyImplyLeading: false,
          ),

          body: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerPadding('Rows per Page', TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 5),
                        child: Card(
                            child: ListTile(
                              title: Text(sFile["pageCount"].toString(), textAlign: TextAlign.center,),
                              leading: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  sFile["pageCount"] -= sFile["pageCount"] - 1 > 0 ? 1 : 0;
                                  refresh(this);
                                },
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  sFile["pageCount"] += sFile["pageCount"] + 1 < 31 ? 1 : 0;
                                  refresh(this);
                                },
                              ),
                            )
                        )
                    ),

                    headerPadding('Font Size', TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: ListTile(
                              title: Text(sFile["fontScale"].toString(), textAlign: TextAlign.center),
                              leading: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  sFile["fontScale"] -= sFile["fontScale"] - 1 > 8 ? 1 : 0;
                                  refresh(this);
                                },
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  sFile["fontScale"] += sFile["fontScale"] + 1 < 30 ? 1 : 0;
                                  refresh(this);
                                },
                              ),
                            )
                        )
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height/10.0),
                    headerPadding("Load MASTER_SHEET from Phone Storage", TextAlign.left),
                    Card(
                      child: ListTile(
                        title: mainTable == null ? Text( "NO SPREADSHEET DATA", style: warningText) : Text(shortFilePath(dbPath)),
                        subtitle: mainTable == null ? Text("Tap here to load a spreadsheet...", style: warningText) : Text("Count: ${mainTable?.maxRows}"),
                        leading: mainTable == null ? const Icon(Icons.warning_amber, color: Colors.red) : const Icon(Icons.list_alt, color: Colors.green),
                        onTap: (){
                          goToPage(context, const LoadSpreadsheet(), false);
                        },
                      ),
                    ),

                    headerPadding('Storage Permission Type', TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 5),
                        child: Card(
                          child: ListTile(
                            title: DropdownButton(
                              //menuMaxHeight: MediaQuery.sizeOf(context).height/2.0,

                              value: storageType,
                              icon: const Icon(Icons.keyboard_arrow_down, textDirection: TextDirection.rtl,),
                              items: ([Permission.manageExternalStorage, Permission.storage]).map((index) {
                                return DropdownMenuItem(
                                  value: index,
                                  child: Text(index.toString()),
                                );
                              }).toList(),
                              onChanged: ((pValue) async {
                                await confirmDialog(context, "!! Warning !!\n -> Confirm only if you know what you are doing..").then((value){
                                  if(value){
                                    storageType = pValue as Permission;
                                  }
                                });

                                refresh(this);

                              }),
                            ),
                          ),
                        )
                    ),
                  ],
                )
              )
          ),

          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(
                      children: [
                        rBox(
                            context,
                            colorBack,
                            TextButton(
                              child: Text('Back', style: whiteText),
                              onPressed: () async {
                                await writeSession().then((value)
                                {
                                  goToPage(context, const HomePage(), true);
                                });
                                //goToPage(context, const HomePage());
                              },
                            )
                        ),
                      ]
                  )
              )
          ),
      ),
    );
  }
}

// Load Spreadsheet
class LoadSpreadsheet extends StatefulWidget {
  const LoadSpreadsheet({super.key});

  @override
  State<LoadSpreadsheet> createState() => _LoadSpreadsheet();
}
class _LoadSpreadsheet extends State<LoadSpreadsheet> {
  var sheets = [];
  String loadSheet = "";

  @override
  void initState() {
    super.initState();
    _prepareStorage();
    if(mainTable != null){
      _getSheets(dbPath);
    }
  }

  _getSheets(String path) {
    if(dbPath.isNotEmpty){
      File file = File(dbPath);
      var bytes = file.readAsBytesSync();
      var decoder = SpreadsheetDecoder.decodeBytes(bytes);
      sheets = decoder.tables.keys.toList();
      refresh(this);
    }
  }

  Future<void> _loadSpreadsheet(String sheetName) async {
    File file = File(dbPath);
    var bytes = file.readAsBytesSync();
    var decoder = SpreadsheetDecoder.decodeBytes(bytes);
    mainTable = decoder.tables[sheetName];

    var header = mainTable!.rows[0];
    var cIndex = -1;
    for(int j = 0; j < header.length; j++){
      if(header[j].toString().toUpperCase() == "CATEGORY" || header[j].toString().toUpperCase() == "CATEGORIES") {
        cIndex = j;
        break;
      }
    }

    if(cIndex != -1){
      masterCategory = List<String>.empty(growable: true);
      for(int i = 1; i < mainTable!.rows.length; i++){
        var row = mainTable!.rows[i].toList();
        masterCategory.add(row[cIndex].toString().toUpperCase());
      }
      masterCategory = masterCategory.toSet().toList();
    }
    else{
      masterCategory = defCategory();
      //mPrint("using def categories");
    }

    // Remove header and cell description rows
    mainTable!.rows.removeRange(0, 1);

    // Do not load spreadsheets with null indices
    for(int i = 0; i < mainTable!.maxRows; i++){
      var c = mainTable!.rows[i];
      bool err1 = c[0] == null;
      bool err2 = c[0] < 0;
      bool err3 = c[0] is double;

      if(err1 || err2 || err3) {
        mainTable = null;
        String errStr = err1 ?
        "The selected spreadsheet contains null indices which will cause conflicts with the main database."
            "\n -> Open the spreadsheet elsewhere and ensure each row has a non-duplicate index number (unsigned integers only)" : "";
        errStr += err2 ?
        "\nThe selected spreadsheet contains negative indices which will cause conflicts with the main database."
            "\n -> Open the spreadsheet elsewhere and ensure each row has a non-negative index number" : "";
        errStr += err3 ?
        "\nThe selected spreadsheet contains decimal indices which will cause conflicts with the main database."
            "\n -> Open the spreadsheet elsewhere and ensure each row has index number that is whole (non-negative)" : "";

        showAlert(context, "Error", errStr, colorWarning);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
                centerTitle: true,
                automaticallyImplyLeading: false,
                title: const Text("Load Spreadsheet Data for Job", textAlign: TextAlign.center)
            ),

            body: SingleChildScrollView(
              child: Column(
                  children:[
                    headerPadding("Spreadsheet File:", TextAlign.left),
                    Card(
                      child: ListTile(
                          leading: mainTable == null ? const Icon(Icons.question_mark) : null,
                          title: Text(shortFilePath(dbPath), textAlign: TextAlign.left),
                          onTap: () async {
                            dbPath = await pickSpreadsheet(context);
                            _getSheets(dbPath);
                          }
                      ),
                    ),
                    headerPadding("Available Sheets:", TextAlign.left),
                    Column(
                        children: List.generate(sheets.length, (index) => Card(
                          child: ListTile(
                            selectedColor: Colors.greenAccent,
                            title: Text(sheets.elementAt(index).toString()),
                            trailing: loadSheet == sheets.elementAt(index).toString() ? const Icon(Icons.arrow_back, color: Colors.green) : null,
                            onTap: () async {
                              loadSheet = sheets.elementAt(index).toString();
                              refresh(this);
                            },
                          ),
                        )
                        )
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height/10.0,
                    )
                  ]
              ),
            ),
            bottomSheet: SingleChildScrollView(
                child: Center(
                  child: Column(
                    children: [
                      rBox(
                          context,
                          loadSheet.isNotEmpty ? colorOk : colorDisable,
                          TextButton(
                            child: Text('LOAD SPREADSHEET', style: whiteText),
                            onPressed: () async{
                              if(loadSheet.isNotEmpty){
                                loadingAlert(context);
                                refresh(this);
                                await _loadSpreadsheet(loadSheet).then((value) async{
                                  if(mainTable != null || mainTable!.maxRows > 0){
                                    await showAlert(context, "", "Master spreadsheet was loaded successfully!", colorOk).then((value){
                                      goToPage(context, const AppSettings(), true);
                                    });
                                  }
                                });
                              }
                            },
                          )
                      ),
                      rBox(
                          context,
                          colorEdit,
                          TextButton(
                            child: Text('LOAD DEFAULT', style: whiteText),
                            onPressed: () async{
                              loadingAlert(context);
                              refresh(this);

                              await loadMasterSheet().then((value) async{
                                if(mainTable != null || mainTable!.maxRows > 0){
                                  await showAlert(context, "", "Master spreadsheet was loaded successfully!", colorOk).then((value){
                                    goToPage(context, const AppSettings(), true);
                                  });
                                }
                              });
                            },
                          )
                      ),
                      rBox(
                          context,
                          colorBack,
                          TextButton(
                            child: Text('Back', style: whiteText),
                            onPressed: () {
                              goToPage(context, const AppSettings(), true);
                            },
                          )
                      ),
                    ],
                  ),
                )
            )
        )
    );
  }
}

// Jobs Page
class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
  });
  @override
  State<JobsPage> createState() => _JobsPage();
}
class _JobsPage extends State<JobsPage> {
  bool access = false;

  @override
  void initState() {
    super.initState();
    _prepareStorage();
    _access();
  }

  _access() async{
    access = await storageType.isGranted;
  }

  _copyJobFile(String path) async {
    var spt = path.split("/");
    String str = spt[spt.length - 1];

    if (str.startsWith("job_")){
      //String newPath = path;
      bool copyJob = false;

      if(path.contains('sdcard')){
        if(!path.contains("sdcard/Documents")){
          //newPath = 'sdcard/Documents/$str';
          copyJob = true;
        }
      }
      else if(!path.contains("storage/emulated/0/Documents")){
        //newPath = 'storage/emulated/0/Documents/$str';
        copyJob = true;
      }

      // Copy and move job to default documents directory (if it isn't there already)
      if(copyJob){
        var jsn = File(path);
        String fileContent = await jsn.readAsString();
        var dynamic = json.decode(fileContent);
        var j = StockJob.fromJson(dynamic);
        writeJob(j);

        //mPrint("Job file copied from [ $path ] to [ $newPath ]");
      }
    }

    refresh(this);
  }

  _readJob(String path) async {
    var jsn = File(path);
    String fileContent = await jsn.readAsString(); //await
    var dynamic = json.decode(fileContent);
    job = StockJob.fromJson(dynamic);
    job.calcTotal();

    //mPrint("JOB: ${job.id}_${job.name}_${job.date}");

    // // REMOVE ME
    // var sp = path.split("_");
    // var d = sp[sp.length - 1];
    // var dStr = "${d[0]}${d[1]}_${d[2]}_${d[3]}${d[4]}${d[5]}${d[6]}";
    // job.date = dStr;

    // REMOVE ME
    //job.date = job.date.replaceAll("/", "_");
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Jobs'),
            automaticallyImplyLeading: false,
            actions: [
              PopupMenuButton(
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem<TableType>(
                        value: TableType.full,
                        child: Text("View MASTER_SHEET"),
                      ),
                      const PopupMenuItem<int>(
                        value: -1,
                        child: Text("Clear Job List"),
                      )
                    ];
                  },
                  onSelected: (value) async {
                    if(value is int){
                      jobList.clear();
                      refresh(this);
                    }
                    else{
                      goToPage(context, StaticTable(dataList: mainTable!.rows, tableType: value as TableType), true);
                    }
                  }
              ),
            ],
          ),
          body: SingleChildScrollView(
              child: Center(
                  child: Column(
                    children: [
                      headerPadding("Available Jobs:", TextAlign.left),
                      Column(
                          children: List.generate(jobList.length, (index) => Card(
                            child: ListTile(
                                title: Text(shortFilePath(jobList[index])),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_forever_sharp),
                                  color: Colors.redAccent,
                                  onPressed: () {
                                    jobList.removeAt(index);
                                    refresh(this);
                                  },
                                ),
                                onTap: () async {
                                  if(access) {
                                    await writeSession();

                                    //String n = shortFilePath(jobList[index]);
                                    // if("job_${job.id}_${job.name}" == n){
                                    //   goToPage(context, const OpenJob(), true);
                                    // }
                                    // else{
                                    // }

                                    await _readJob(jobList[index]).then((value) {
                                      goToPage(context, const OpenJob(), true);
                                    });
                                  }
                                  else{
                                    showNotification(
                                      context,
                                      Colors.redAccent,
                                      whiteText,
                                      "!! ALERT !!",
                                      "* Read/Write permissions were DENIED\n * Try changing permissions via -> 'App Settings'",
                                    );
                                  }
                                }
                            ),
                          ),
                          )
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height/10.0,
                      ),
                      Center(
                        child: Column(
                            children: [
                              rBox(
                                  context,
                                  Colors.lightBlue,
                                  TextButton(
                                    child: Text('New Job', style: whiteText),
                                    onPressed: () {
                                      writeSession();
                                      goToPage(context, const NewJob(), false);
                                    },
                                  )
                              ),
                              rBox(
                                  context,
                                  Colors.blue[800]!,
                                  TextButton(
                                    child: Text('Load from Storage', style: whiteText),
                                    onPressed: () async{
                                      if(access){
                                        String path = "";
                                        await pickFile(context).then((String value){
                                          path = value;
                                        });

                                        // Check if path is valid
                                        if(path.isEmpty || path == "null" || !path.contains("job_")){
                                          return;
                                        }
                                        if(!jobList.contains(path)){
                                          jobList.add(path);
                                        }

                                        await writeSession();

                                        // copy job file to documents folder if it is not there
                                        await _copyJobFile(path);
                                        await _readJob(path).then((value) {
                                          goToPage(context, const OpenJob(), true);
                                        });
                                      }
                                      else {
                                        showNotification(
                                            context,
                                            Colors.red[900]!,
                                            whiteText,
                                            "!! ALERT !!",
                                            "* Read/Write permissions were DENIED\n * Try changing permissions via -> 'App Settings'"
                                        );
                                      }
                                    },
                                  )
                              )
                            ]
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height/10.0,
                      ),
                    ],
                  )
              )
          ),
          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(
                      children: [
                        rBox(
                            context,
                            colorBack,
                            TextButton(
                              child: Text('Back', style: whiteText),
                              onPressed: () {
                                writeSession();
                                job = StockJob(id: "EMPTY", name: "EMPTY");
                                goToPage(context, const HomePage(), true);
                              },
                            )
                        ),
                      ]
                  )
              )
          ),
        )
    );
  }
}

// New Job
class NewJob extends StatefulWidget {
  const NewJob({
    super.key,
  });

  @override
  State<NewJob> createState() => _NewJob();
}
class _NewJob extends State<NewJob> {
  StockJob newJob = StockJob(id: "NULL", name: "EMPTY");
  TextEditingController idCtrl = TextEditingController();
  var idFocus = FocusNode();
  TextEditingController nameCtrl = TextEditingController();
  var nameFocus = FocusNode();

  _clearFocus(){
    idFocus.unfocus();
    nameFocus.unfocus();
  }

  Future<bool> _checkFile(String path) async{
    // Show confirmation window if job file already exists
    await File(path).exists().then((value) async{
      if(value){
        return await confirmDialog(context, "Job file with the same path already exists! \n\n -> Confirm overwrite?");
      }
    });

    return true;
  }

  @override
  void initState() {
    super.initState();
    _clearFocus();
    _prepareStorage();
  }

  @override
  Widget build(BuildContext context) {
    // double keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            centerTitle: true,
            title: const Text("New Job"),
            automaticallyImplyLeading: false,
          ),
          body: GestureDetector(
              onTapDown: (_) => _clearFocus(),
              child:SingleChildScrollView(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerPadding("Job Id:", TextAlign.left),
                        Padding(
                            padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                            child: Card(
                                child: TextFormField(
                                  // scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
                                  controller: idCtrl,
                                  focusNode: idFocus,
                                  textAlign: TextAlign.left,
                                )
                            )
                        ),
                        headerPadding("Job Name:", TextAlign.left),
                        Padding(
                            padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                            child: Card(
                                child: TextFormField(
                                  // scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
                                  controller: nameCtrl,
                                  focusNode: nameFocus,
                                  textAlign: TextAlign.left,
                                )
                            )
                        ),
                      ]
                  )
              )
          ),
          bottomSheet: GestureDetector(
              onTapDown: (_) => _clearFocus,
              child: SingleChildScrollView(
                  child: Center(
                      child: Column(children: [
                        rBox(
                            context,
                            colorOk,
                            TextButton(
                              child: Text('Create Job', style: whiteText),
                              onPressed: () async {

                                // job must need id
                                if(idCtrl.text.isEmpty){
                                  showNotification(context, Colors.orange, whiteText, "!! ALERT", "\n* Job ID is empty: ${idCtrl.text.isEmpty}");
                                  return;
                                }

                                newJob.id = idCtrl.text;
                                newJob.name = nameCtrl.text;
                                newJob.date = "${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}";
                                String date = newJob.date.replaceAll("_", "");
                                String path = "storage/emulated/0/Documents/job_${newJob.id}_${newJob.name}_$date";

                                await _checkFile(path).then((value){
                                  if(value){
                                    writeJob(newJob);

                                    job = newJob;
                                    job.calcTotal();

                                    // manually check through job list?
                                    for(int i = 0; i < jobList.length; i++)
                                    {
                                      var s = jobList[i].split("_");
                                      if(s.contains(newJob.id) && s.contains(newJob.name) && s.contains(date)){
                                        break;
                                      }

                                      if(i >= jobList.length-1){
                                        jobList.add(path);
                                      }
                                    }

                                    showNotification(context, colorOk, whiteText, "Job Created", "* Save path: $path");
                                    goToPage(context, const OpenJob(), true);
                                  }
                                });
                              },
                            )
                        ),
                        rBox(
                            context,
                            colorBack,
                            TextButton(
                              child:
                              Text('Cancel', style: whiteText),
                              onPressed: () {
                                goToPage(context, const JobsPage(), false);
                              },
                            )
                        )
                      ]
                      )
                  )
              )
          ),
        )
    );
  }
}

// Open Job
class OpenJob extends StatelessWidget {
  const OpenJob({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,

        appBar: AppBar(
          centerTitle: true,
          title: Text("Job -> ${job.id.toString()}", textAlign: TextAlign.center),
          automaticallyImplyLeading: false,
          actions: [
            PopupMenuButton(
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem<TableType>(
                      value: TableType.literal,
                      child: Text("View Stock Sheet"),
                    ),
                    const PopupMenuItem<TableType>(
                      value: TableType.linear,
                      child: Text("View FULL Stock Sheet"),
                    ),
                    const PopupMenuItem<TableType>(
                      value: TableType.full,
                      child: Text("View MASTER_SHEET + NOF"),
                    ),
                  ];
                },
                onSelected: (value) {
                  if(value == TableType.literal){
                    goToPage(context, StaticTable(dataList: job.literalList(), tableType: value), true);
                  }
                  else if (value == TableType.linear){
                    goToPage(context, StaticTable(dataList: job.linearList(), tableType: value), true);
                  }
                  else if(value == TableType.full){
                    goToPage(context, StaticTable(dataList: mainTable!.rows + job.nofList(), tableType: value), true);
                  }
                }
            ),
          ],
        ),

        body: SingleChildScrollView(
          child: Column(
              children: [
                Card(
                  child: ListTile(
                    title: Text(job.date.replaceAll("_", "/")),
                    leading: const Icon(Icons.date_range, color: Colors.blueGrey),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height/40.0,
                ),
                Center(
                    child: Column(
                        children: [
                          rBox(
                              context,
                              Colors.blue,
                              TextButton(
                                child: Text('Stocktake', style: whiteText),
                                onPressed: () {
                                  if(mainTable == null || mainTable!.rows.isEmpty){
                                    showAlert(context, "Alert", "No spreadsheet data!\n* Press 'Sync with Server' to get latest MASTER SHEET. \n*You can also load a spreadsheet file from storage via the Settings page", colorOk);
                                  }
                                  else{
                                    goToPage(context, const Stocktake(), false);
                                  }
                                },
                              )
                          ),
                          rBox(
                              context,
                              Colors.blue,
                              TextButton(
                                child: Text('Export Spreadsheet', style: whiteText),
                                onPressed: () {
                                  goToPage(context, StaticTable(dataList: job.getFinalSheet(), tableType: TableType.export), true);
                                },
                              )
                          ),
                          rBox(
                              context,
                              Colors.green,
                              TextButton(
                                child: Text('Save Job', style: whiteText),
                                onPressed: () async {
                                  await writeJob(job).then((value){
                                    String date = job.date.replaceAll("_", "");
                                    showAlert(context, "Job Saved", "Save path: \n /Documents/job_${job.id}_${job.name}_$date", Colors.orange);
                                  });
                                },
                              )
                          ),
                        ]
                    )
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height/10.0,
                )
              ]
          ),
        ),
        bottomSheet: SingleChildScrollView(
            child: Center(
                child: Column(
                    children: [
                      rBox(
                          context,
                          colorBack,
                          TextButton(
                            child: Text('Close Job', style: whiteText),
                            onPressed: () async {
                              await writeJob(job).then((value){
                                goToPage(context, const JobsPage(), true);
                              });
                            },
                          )
                      ),
                    ]
                )
            )
        ),
      ),
    );
  }
}

// Stocktake
class Stocktake extends StatelessWidget{
  const Stocktake({super.key});

  Map<String, dynamic> _blankItem(){
    return {
      "index" : 0,
      "barcode" : 0,
      "category" : "MISC",
      "description" : "",
      "uom" : "EACH",
      "price" : 0.0,
      "count" : 0.0,
      "location" : job.location.isEmpty ? "LOCATION1" : job.location,
      "nof" : true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          // resizeToAvoidBottomInset: false,
            appBar: AppBar(
              centerTitle: true,
              title: Text("Stocktake - Total: ${job.total}", textAlign: TextAlign.center),
              automaticallyImplyLeading: false,
            ),
            body:SingleChildScrollView( child: Center(
                child: Column(
                    children: [
                      headerPadding("Current Location:", TextAlign.left),
                      Card(
                        child: ListTile(
                          title: job.location.isEmpty ?
                          Text("Tap to select a location...", style: greyText) :
                          Text(job.location, textAlign: TextAlign.center),
                          leading: job.location.isEmpty ? const Icon(Icons.warning_amber, color: Colors.red) : null,
                          onTap: () {
                            goToPage(context, const Location(), false);
                          },
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height / 10.0,
                      ),
                      rBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Scan Item', style: whiteText),
                            onPressed: () {
                              if (job.location.isNotEmpty) {
                                goToPage(context, const ScanItem(), false);
                              } else {
                                showAlert(context,
                                    "Alert",
                                    'Create and set location before scanning.',
                                    Colors.red.withOpacity(0.8)
                                );
                              }
                            },
                          )
                      ),
                      rBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Search Item', style: whiteText),
                            onPressed: () {
                              if (job.location.isNotEmpty) {
                                goToPage(
                                    context,
                                    DynamicTable(tableType: TableType.search, action: ActionType.add),
                                    true // animate
                                );
                              } else {
                                showAlert(context,
                                    "Alert",
                                    'Create and set location before adding items.',
                                    Colors.red.withOpacity(0.8)
                                );
                              }
                            },
                          )
                      ),
                      rBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Add NOF', style: whiteText),
                            onPressed: () {
                              goToPage(context, StockItem(item: _blankItem(), action: ActionType.addNOF, index: -1,), false);
                            },
                          )
                      ),
                      rBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Edit Stocktake', style: whiteText),
                            onPressed: () {
                              job.literals.isNotEmpty ? goToPage(context, DynamicTable(tableType: TableType.literal, action: ActionType.edit), true)
                                  : showAlert(context, "Alert", "Stocktake is empty.", colorDisable);
                            },
                          )
                      ),
                    ]
                )
            ),
            ),
            bottomSheet: SingleChildScrollView(
                child: Center(
                    child: Column(
                        children: [
                          rBox(
                              context,
                              colorBack,
                              TextButton(
                                child: Text('Back', style: whiteText),
                                onPressed: () {
                                  goToPage(context, const OpenJob(), false);
                                },
                              )
                          ),
                        ]
                    )
                )
            )
        )
    );
  }
}

// Scan Item
class ScanItem extends StatefulWidget{
  const ScanItem({super.key});

  @override
  State<ScanItem> createState() => _ScanItem();
}
class _ScanItem extends State<ScanItem>{
  TextEditingController searchCtrl= TextEditingController();
  FocusNode searchFocus = FocusNode();
  TextEditingController countCtrl = TextEditingController();
  var countFocus = FocusNode();
  late List<List<dynamic>> dataList;
  List<List<dynamic>> filterList = List.empty();
  bool found = false;
  bool wholeBarcode = true;
  int itemIndex = 0;

  @override
  void initState() {
    super.initState();
    searchFocus.unfocus();
    dataList = mainTable!.rows + job.nofList();
    countCtrl.text = "0.0";
    found = false;
  }

  _clearFocus(){
    searchFocus.unfocus();
    countFocus.unfocus();
  }
  _scanString(String value){
    if(value.isEmpty){
      filterList.clear();
      found = false;
    }
    else{
      itemIndex = 0;
      filterList = dataList.where(
              (List<dynamic> item) => wholeBarcode ? item[1] == value : item[1].contains(value)
      ).toList(growable: true);

      // Sort by barcode number
      //filterList = filterList..sort((x, y) => (x[1] as dynamic).compareTo((y[1] as dynamic)));
      found = filterList.isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    double keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;

    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: const Text("Barcode Scanning", textAlign: TextAlign.center),
            actions: [
              PopupMenuButton(
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem<int>(
                          value: 0,
                          child: Card(
                            child: ListTile(
                              title: const Text("Check Full Barcode"),
                              trailing: wholeBarcode ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                            ),
                          )
                      ),];
                  },
                  onSelected: (value) async {
                    _clearFocus();
                    searchCtrl.clear();
                    wholeBarcode = wholeBarcode ? false : true;
                    refresh(this);
                  }
              ),
            ],
          ),

          body: GestureDetector(
              onTapDown: (_) => _clearFocus(),
              child:  SingleChildScrollView(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 30, bottom: 5),
                      ),

                      headerPadding("Barcode:", TextAlign.left),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                            child: ListTile(
                              // trailing: IconButton(
                              //   onPressed: () async {
                              //     // String value = await FlutterBarcodeScanner.scanBarcode(
                              //     //     Colors.redAccent.toString(),
                              //     //     'Cancel',
                              //     //     true,
                              //     //     ScanMode.BARCODE
                              //     // );
                              //     // mPrint(value);
                              //     //_scanString(value);
                              //     refresh(this);
                              //   },
                              //   icon: const Icon(Icons.camera_enhance_outlined, color: Colors.blueGrey),
                              // ),
                              title: TextField(
                                scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
                                controller: searchCtrl,
                                focusNode: searchFocus,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.name,
                                onChanged: (String? value){
                                  _scanString(value as String);
                                  refresh(this);
                                },
                              ),
                            ),
                          )
                      ),

                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height / 10.0,
                      ),

                      headerPadding("Result:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => _clearFocus(),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height/5,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: <Widget>[
                                Container(
                                    width: MediaQuery.of(context).size.width / 10,
                                    color: Colors.grey.shade200,
                                    child: IconButton(
                                        onPressed: () {
                                          _clearFocus();
                                          countCtrl.text = "0.0";
                                          if(filterList.isNotEmpty){
                                            itemIndex = (itemIndex - 1) % filterList.length;
                                          }
                                          refresh(this);
                                        },
                                        icon: const Icon(Icons.arrow_back)
                                    )
                                ),
                                SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.8,
                                    child: SingleChildScrollView(
                                        child: Column(
                                            children: [
                                              Card(
                                                child: ListTile(
                                                  title: Text("${found ? filterList[itemIndex][3] : ""}", textAlign: TextAlign.center,),
                                                ),
                                              ),
                                              Card(
                                                  child: ListTile(
                                                    trailing: IconButton(
                                                      icon: const Icon(Icons.add_circle_outline),
                                                      onPressed: () {
                                                        _clearFocus();
                                                        if(found){
                                                          double count = double.parse(countCtrl.text) + 1;
                                                          countCtrl.text = count.toString();
                                                        }
                                                        refresh(this);
                                                      },
                                                    ),
                                                    title: TextField(
                                                      scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
                                                      controller: countCtrl,
                                                      focusNode: countFocus,
                                                      textAlign: TextAlign.center,
                                                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                                    ),
                                                    leading: IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline),
                                                      onPressed: () {
                                                        _clearFocus();
                                                        if(found){
                                                          double count = double.parse(countCtrl.text) - 1.0;
                                                          countCtrl.text = max(count, 0).toString();
                                                        }
                                                        refresh(this);
                                                      },
                                                    ),
                                                  )
                                              ),
                                              Card(
                                                child: Text("$itemIndex of ${filterList.length-1}", textAlign: TextAlign.left, style: greyText),
                                              )
                                              // headerPadding("$itemIndex of ${filterList.length-1}", TextAlign.left),
                                            ]
                                        )
                                    )
                                ),
                                Container(
                                    width: MediaQuery.of(context).size.width / 10,
                                    color: Colors.grey.shade200,
                                    child: IconButton(
                                        onPressed: () {
                                          _clearFocus();
                                          countCtrl.text = "0.0";
                                          if(filterList.isNotEmpty){
                                            itemIndex = (itemIndex + 1) % filterList.length;
                                          }
                                          refresh(this);
                                        },
                                        icon: const Icon(Icons.arrow_forward)
                                    )
                                ),
                              ],
                            ),
                          )
                      ),

                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height / 10.0,
                      ),
                      rBox(
                        context,
                        found ? colorOk : colorDisable,
                        TextButton(
                            child: Text('ADD ITEM', style: whiteText),
                            onPressed: () {
                              if(found){
                                double count = double.parse(countCtrl.text);

                                if(count <= 0){
                                  showNotification(context, colorWarning, whiteText, "Count is zero (0), can't add zero items", "");
                                  return;
                                }

                                countCtrl.text = "0.0";
                                var item = rowToItem(filterList[itemIndex], false);
                                item['count'] = count;
                                item['location'] = job.location;
                                job.literals.add(item);
                                job.calcTotal();
                                showNotification(context, colorOk, whiteText, "Item Added:\n${item['description']} \nCount: $count","");
                                refresh(this);
                              }
                            }
                        ),
                      ),
                      GestureDetector(
                          onTapDown: (_) => _clearFocus(),
                          child: SingleChildScrollView(
                              child: Center(
                                child: Column(
                                    children: [
                                      rBox(context, colorBack, TextButton(
                                        child: Text("Back", style: whiteText),
                                        onPressed: () {
                                          goToPage(context, const Stocktake(), false);
                                        },
                                      )),
                                    ]
                                ),
                              )
                          )
                      ),
                    ],
                  )
              )
          ),
          // bottomSheet:
        )
    );
  }
}

// Location
class Location extends StatefulWidget {
  const Location({super.key});

  @override
  State<Location> createState() => _Location();
}
class _Location extends State<Location> {
  @override
  void initState() {
    super.initState();
  }

  Future<String> _textEditDialog(BuildContext context, String str) async{
    String originalText = str;
    String newText = originalText;
    var textFocus = FocusNode();
    TextEditingController txtCtrl = TextEditingController();

    txtCtrl.text = originalText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) => GestureDetector(
          onTapDown: (_) => textFocus.unfocus(),
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.spaceAround,
            title: const Text("Edit Text Field"),
            content: Card(
                child: ListTile(
                  title: TextField(
                    controller: txtCtrl,
                    focusNode: textFocus,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '', border: InputBorder.none),
                    keyboardType: TextInputType.name,
                    onChanged: (value) {
                      txtCtrl.value = TextEditingValue(text: value.toUpperCase(), selection: txtCtrl.selection);
                    },
                  ),
                )
            ),
            actions: <Widget>[
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                onPressed: () {
                  txtCtrl.clear();
                  newText = originalText;
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                onPressed: () {
                  newText = txtCtrl.text;
                  Navigator.pop(context);
                },
                child: const Text("Confirm"),
              ),
            ],
          )
      ),
    );

    //mPrint(newText);
    return newText;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: const Text("Select Location", textAlign: TextAlign.center),
          ),
          body: SingleChildScrollView(
              child: Column(children: [
                const Padding(
                  padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 30, bottom: 5),
                ),
                Column(
                  children: job.allLocations.isNotEmpty ? List.generate(job.allLocations.length, (index) => Card(
                      child: ListTile(
                        title: Text(job.allLocations[index], textAlign: TextAlign.justify),
                        selected: job.allLocations[index] == job.location,
                        selectedColor: Colors.black,
                        selectedTileColor: Colors.greenAccent.withOpacity(0.4),

                        // EDIT LOCATION
                        trailing: IconButton(
                          icon: Icon(Icons.edit_note, color: Colors.yellow.shade800),
                          onPressed: () async {
                            await _textEditDialog(context, job.allLocations[index]).then((value){
                              if(value.isNotEmpty){
                                job.allLocations[index] = value;
                                job.allLocations = job.allLocations.toSet().toList();
                              }
                              else{
                                showNotification(context, colorDisable, blackText, "Cannot add empty text", "");
                              }
                            });

                            refresh(this);
                          },
                        ),

                        // DELETE LOCATION
                        onLongPress: () async {
                          bool b = await confirmDialog(context, "Delete location '${job.allLocations[index]}'?");
                          if(b){
                            // check if deleting a location we are currently using
                            if(job.location == job.allLocations[index]) {
                              job.location = "";
                            }
                            job.allLocations.removeAt(index);
                            refresh(this);
                          }
                        },

                        // SET LOCATION
                        onTap: () {
                          job.location = job.allLocations[index];
                          refresh(this);
                          goToPage(context, const Stocktake(), true);
                        },
                      )
                  )) : [
                    Card(
                        child: ListTile(
                          title: Text("No locations, create a new location...", style: greyText, textAlign: TextAlign.justify),
                        )
                    )
                  ],
                ),
              ])
          ),
          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(
                      children: [
                        // ADD LOCATION
                        rBox(
                            context,
                            Colors.lightBlue,
                            TextButton(
                              child: Text('Add Location', style: whiteText),
                              onPressed: () async {
                                await _textEditDialog(context, "").then((value) {
                                  if(value.isNotEmpty && !job.allLocations.contains(value)){
                                    job.allLocations.add(value);
                                  }
                                  else{
                                    showNotification(context, colorDisable, blackText, "Cannot add empty text", "");
                                  }
                                });

                                refresh(this);
                              },
                            )
                        ),

                        // BACK
                        rBox(
                            context,
                            colorBack,
                            TextButton(
                              child: Text('Back', style: whiteText),
                              onPressed: () {
                                goToPage(context, const Stocktake(), false);
                              },
                            )
                        )
                      ]
                  )
              )
          ),
        )
    );
  }
}

// StockItem
class StockItem extends StatefulWidget {
  final Map<String,dynamic> item;
  final ActionType action;
  final int index;

  const StockItem({
    super.key,
    required this.item,
    required this.action,
    required this.index,
  });

  @override
  State<StockItem> createState() => _StockItem();
}
class _StockItem extends State<StockItem>{
  TextEditingController uomCtrl = TextEditingController();
  var uomFocus = FocusNode();
  TextEditingController barcodeCtrl = TextEditingController();
  var barcodeFocus = FocusNode();
  TextEditingController descriptionCtrl = TextEditingController();
  var descriptionFocus = FocusNode();
  TextEditingController priceCtrl = TextEditingController();
  var priceFocus = FocusNode();
  TextEditingController countCtrl = TextEditingController();
  var countFocus = FocusNode();
  TextEditingController locationCtrl = TextEditingController();
  var locationFocus = FocusNode();

  String categoryValue = "MISC";
  late double keyboardHeight;

  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    _clearFocus();

    barcodeCtrl.text = widget.item['barcode'].toString().toUpperCase();

    String catCheck = widget.item['category'].toString().toUpperCase();
    categoryValue = catCheck != "NULL" ? catCheck : "MISC";

    descriptionCtrl.text = widget.item['description'];

    String uomCheck = widget.item['uom'].toString().toUpperCase();
    uomCtrl.text = uomCheck != "NULL" ? uomCheck : "EACH";

    priceCtrl.text = widget.item['price'].toString();
    countCtrl.text = widget.item['count'].toString();
    locationCtrl.text = widget.item['location'].toString();
    //isNof = widget.item['nof'];

    isEditing = widget.action == ActionType.addNOF || widget.action == ActionType.edit;
  }

  _clearFocus(){
    uomFocus.unfocus();
    barcodeFocus.unfocus();
    descriptionFocus.unfocus();
    priceFocus.unfocus();
    countFocus.unfocus();
    locationFocus.unfocus();
  }

  _actionsEdit(){
    return [
      // DELETE item
      GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: IconButton(
              icon: const Icon(Icons.delete_forever_sharp),
              onPressed: () async {
                _clearFocus();
                await confirmDialog(context, "Remove Item from stock count?").then((bool value2) async{
                  if(value2){
                    job.literals.removeAt(widget.index);
                    job.calcTotal();
                    showNotification(context, colorWarning.withOpacity(0.8), whiteText, "", "Item at table index [${widget.index}] was removed.");
                    goToPage(context, job.literals.isNotEmpty ? DynamicTable(tableType: TableType.literal, action: ActionType.edit) : const Stocktake(), false);
                  }
                });
              }
          )
      ),
    ];
  }

  _addItem(){
    return <Widget>[
      headerPadding("Description:", TextAlign.left),
      Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
        child: Card(
            child: ListTile(
              title: Text(widget.item["description"]),
            )
        ),
      ),

      headerPadding("Location:", TextAlign.left),
      _editLocation(),

      headerPadding("Count:", TextAlign.left),
      _editCount(),

      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 10.0,
      ),

      GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: Center(
            child: rBox(
                context,
                colorOk,
                TextButton(
                    child: Text('Add Item', style: whiteText),
                    onPressed: () {
                      double count = double.parse(countCtrl.text);
                      if(count <= 0){
                        showNotification(context, colorWarning, whiteText, "Cannot add zero (0) items","",);
                        return;
                      }

                      var item = widget.item;
                      item['count'] = count;
                      item['location'] = locationCtrl.text;

                      job.literals.add(item);
                      job.calcTotal();

                      showNotification(context, colorOk, whiteText, "Item Added:", " ${item['description']}\n Count: ${countCtrl.text}");
                      Navigator.pop(context);
                    }
                )
            ),
          )
      ),
      _backBtn(),
    ];
  }

  _addNOF(){
    int newIndex =mainTable!.maxRows + job.nof.length;
    var nofItem = {
      "index" : newIndex,
      "barcode" : barcodeCtrl.text,
      "category" : categoryValue,
      "description" : descriptionCtrl.text,
      "uom" : uomCtrl.text,
      "unit" : 1.0,
      "price" : double.parse(priceCtrl.text),
      "nof" : true,
    };

    if(job.newNOF(nofItem)){
      job.nof.add(nofItem);
    }

    if(double.parse(countCtrl.text) > 0){
      var item = {
        "index" : newIndex,
        "barcode" : barcodeCtrl.text,
        "category" : categoryValue,
        "description" : descriptionCtrl.text,
        "uom" : uomCtrl.text,
        "price" : double.parse(priceCtrl.text),
        "count" : double.parse(countCtrl.text),
        "location" : locationCtrl.text,
        "nof" : true,
      };

      job.literals.add(item);
      job.calcTotal();
    }

    showNotification(context, colorOk, whiteText, "NOF Added", "${descriptionCtrl.text} \nCount: ${countCtrl.text}");
    goToPage(context, const Stocktake(), true);
  }

  _editItem(){
    return <Widget>[
      headerPadding("Barcode:", TextAlign.left),
      _editBarcode(),
      headerPadding("Category:", TextAlign.left),
      _editCategory(),
      headerPadding("Description:", TextAlign.left),
      _editDescription(),
      headerPadding("UOM:", TextAlign.left),
      _editUOM(),
      headerPadding("Price:", TextAlign.left),
      _editPrice(),
      headerPadding("Location:", TextAlign.left),
      _editLocation(),
      headerPadding("Count:", TextAlign.left),
      _editCount(),

      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 10.0,
      ),

      GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: Center(
            child: rBox(
                context,
                colorOk,
                TextButton(
                    child: Text(widget.action == ActionType.edit ? 'Save Changes' : "Add NOF", style: whiteText),
                    onPressed: () async {
                      _clearFocus();

                      locationCtrl.text = locationCtrl.text.isEmpty ? "LOCATION1" : locationCtrl.text;
                      descriptionCtrl.text = descriptionCtrl.text.isEmpty ? "NO DESCRIPTION" : descriptionCtrl.text;

                      // ADD NOF
                      if(widget.action == ActionType.addNOF){
                        _addNOF();
                      }
                      // SAVE EDIT
                      if (widget.action == ActionType.edit){
                        _saveEdit();
                      }
                    }
                )
            ),
          )
      ),
      _backBtn(),
    ];
  }

  _editLocation(){
    return GestureDetector(
        onTapDown: (_) => _clearFocus(),
        child: Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
            child: Card(
              child: ListTile(
                title: TextField(
                  scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
                  controller: locationCtrl,
                  focusNode: locationFocus,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.name,
                  onChanged: (value){
                    locationCtrl.value = TextEditingValue(text: value.toUpperCase(), selection: locationCtrl.selection);
                  },
                ),
              ),
            )
        )
    );
  }

  _editCount(){
    return Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
        child: Card(
            child: ListTile(
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  _clearFocus();
                  double count = double.parse(countCtrl.text) + 1;
                  countCtrl.text = count.toString();
                  refresh(this);
                },
              ),
              title: TextField(
                scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
                controller: countCtrl,
                focusNode: countFocus,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
              ),
              leading: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  _clearFocus();
                  double count = double.parse(countCtrl.text) - 1.0;
                  countCtrl.text = max(count, 0).toString();
                  refresh(this);
                },
              ),
            )
        )
    );
  }

  _editBarcode(){
    return Padding(
      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
      child: Card(
          child: ListTile(
            title: TextField(
              scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
              decoration: const InputDecoration(hintText: 'e.g 123456789', border: InputBorder.none),
              controller: barcodeCtrl,
              focusNode: barcodeFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          )
      ),
    );
  }

  _editCategory(){
    return GestureDetector(
        onTapDown: (_) => _clearFocus(),
        child: Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
          child: Card(
            child: DropdownButton(
              value: categoryValue,
              isExpanded: true,
              menuMaxHeight: MediaQuery.of(context).size.height/2.0,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: masterCategory.map((String items) {
                return DropdownMenuItem(
                  value: items,
                  child: Center(
                      child: Text(items, textAlign: TextAlign.center,)
                  ),
                );}).toList(),

              onChanged: (String? newValue) {
                setState(() {
                  categoryValue = newValue!;
                });
              },
            ),
          ),
        )
    );
  }

  _editDescription(){
    return Padding(
      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
      child: Card(
          child: ListTile(
            title: TextField(
              scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
              decoration: const InputDecoration(hintText: 'E.g. PETERS I/CREAM VAN 1L', border: InputBorder.none),
              controller: descriptionCtrl,
              focusNode: descriptionFocus,
              keyboardType: TextInputType.name,
              onChanged: (value){
                descriptionCtrl.value = TextEditingValue(text: value.toUpperCase(), selection: descriptionCtrl.selection);
              },
            ),
          )
      ),
    );
  }

  _editUOM(){
    return Padding(
      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
      child: Card(
          child: ListTile(
            title: TextField(
              scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
              decoration: const InputDecoration(hintText: 'E.g. EACH, 24 PACK, 1.5 L', border: InputBorder.none),
              controller: uomCtrl,
              focusNode: uomFocus,
              keyboardType: TextInputType.name,
              onChanged: (value){
                uomCtrl.value = TextEditingValue(text: value.toUpperCase(), selection: uomCtrl.selection);
              },
            ),
          )
      ),
    );
  }

  _editPrice(){
    return Padding(
      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
      child: Card(
          child: ListTile(
            title: TextField(
              scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight * 0.5),
              controller: priceCtrl,
              focusNode: priceFocus,
              keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
            ),
          )
      ),
    );
  }

  _saveEdit() async{
    if(double.parse(countCtrl.text) <= 0){
      await confirmDialog(context, "Item count is <= 0\n -> Remove item from stocktake?").then((bool value) async{
        if(value){
          job.literals.removeAt(widget.index);
          job.calcTotal();
          showNotification(context, colorWarning.withOpacity(0.8), whiteText, "", "Item at table index [${widget.index}] was removed.");
          goToPage(context, job.literals.isNotEmpty ? DynamicTable(tableType: TableType.literal, action: ActionType.edit) : const Stocktake(), false);
        }
      });
    }
    else{
      await confirmDialog(context, "Confirm changes to stock item?").then((bool value) async {
        if (value) {

          job.literals[widget.index] = {
            "index" : widget.item['index'],
            "barcode" : barcodeCtrl.text,
            "category" : categoryValue,
            "description" : descriptionCtrl.text,
            "uom" : uomCtrl.text,
            "price" : double.parse(priceCtrl.text),
            "count" : double.parse(countCtrl.text),
            "location" : locationCtrl.text,
            "nof" : widget.item['nof'],
          };

          job.calcTotal();

          // Add location to list if it doesn't exist
          if(!job.allLocations.contains(locationCtrl.text)){
            job.allLocations.add(locationCtrl.text);
          }

          goToPage(context, DynamicTable(tableType: TableType.literal, action: ActionType.edit), false);

          // Ask to apply changes to other items with same index?
          // Automatically create a new NOF?
        }
      });
    }
  }

  _backBtn(){
    return GestureDetector(
        onTapDown: (_) => _clearFocus(),
        child:Center(
            child: rBox(
              context,
              colorBack,
              TextButton(
                child: Text('Cancel', style: whiteText),
                onPressed: () async {
                  if(widget.action == ActionType.edit){
                    goToPage(context, DynamicTable(tableType: TableType.literal, action: ActionType.edit), false);
                  }
                  else if(widget.action == ActionType.addNOF) {
                    goToPage(context, const Stocktake(), false);
                  }
                  else{
                    //if(widget.itemType == ItemType.view) {
                    //if(widget.itemType == ItemType.add) {
                    Navigator.pop(context);
                    // go back to last page?
                  }
                },
              ),
            )
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              centerTitle: true,
              title: const Text("Stock Item Details"),
              automaticallyImplyLeading: false,
              actions: isEditing ? _actionsEdit() : [],
            ),
            body: GestureDetector(
                onTapDown: (_) => _clearFocus(),
                child:SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: isEditing ? _editItem() : _addItem(),
                    )
                )
            )
        )
    );
  }
}

// Static Table
class StaticTable extends StatelessWidget {
  final TableType tableType;
  final List dataList;

  const StaticTable({
    super.key,
    required this.tableType,
    required this.dataList,
  });

  getIndex() {
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text("Spreadsheet View: ${job.id}", textAlign: TextAlign.center),
              automaticallyImplyLeading: false,
            ),
            body: Center(
                child: Column(
                    children: [
                      Expanded(
                          child: SingleChildScrollView(
                            child: PaginatedDataTable(
                              sortColumnIndex: 0,
                              sortAscending: true,
                              showCheckboxColumn: false,
                              showFirstLastButtons: true,
                              rowsPerPage: sFile["pageCount"],
                              controller: ScrollController(),
                              columns: getColumns(tableType,MediaQuery.of(context).size.width),
                              source: RowSource(parent: this, dataList: dataList, type: tableType),
                            ),
                          )
                      ),
                      Center(
                          child: Column(
                              children: [
                                tableType == TableType.export ?
                                rBox(
                                    context,
                                    Colors.blue,
                                    TextButton(
                                      child: Text('Export Spreadsheet', style: whiteText),
                                      onPressed: () async {
                                        exportJobToXLSX(job.getFinalSheet());
                                        showAlert(context, "Job Export", "Stocktake exported to: /Documents/stocktake_${job.id}.xlsx", Colors.orange);
                                        //showNotification(context, Colors.orange, whiteText, 'Exported Spreadsheet', '* Save Path: stocktake_${job.id}');
                                      },
                                    )
                                ) :  Container(),
                                rBox(
                                    context,
                                    colorBack,
                                    TextButton(
                                      child: Text("Back", style: whiteText),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    )
                                )
                              ]
                          )
                      )
                    ]
                )
            )
        )
    );
  }
}

// Dynamic Table
class DynamicTable extends StatefulWidget{
  final TableType tableType;
  final ActionType action;
  final tableKey = GlobalKey<PaginatedDataTableState>();

  DynamicTable({
    super.key,
    required this.tableType,
    required this.action,
  });

  @override
  State<DynamicTable> createState() => _DynamicTable();
}
class _DynamicTable extends State<DynamicTable>{
  late List<List<dynamic>> dataList;
  List<List<dynamic>> filterList = [[]];
  TextEditingController searchCtrl = TextEditingController();
  var textFocus = FocusNode();
  var filters = [true, false, false];
  late int selectIndex;

  @override
  void initState() {
    super.initState();
    selectIndex = -1;

    // Get dataList
    switch(widget.tableType){
      case TableType.literal:
        dataList = job.literalList();
        break;
      case TableType.linear:
        dataList = job.linearList();
        break;
      case TableType.full:
        dataList = mainTable!.rows + job.nofList();
        break;
      case TableType.search:
        dataList = mainTable!.rows + job.nofList();
        break;
      default:
        dataList = mainTable!.rows;
        break;
    }

    filterList = dataList;
  }

  bool _findWord(String word, String search) {
    return word.split(' ').where((s) => s.isNotEmpty).toList().contains(search);
  }

  _searchList(){
    return Card(
      child: ListTile(
        leading: const Icon(Icons.search),
        title: TextField(
            controller: searchCtrl,
            focusNode: textFocus,
            decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none),
            onChanged: (String value) {
              widget.tableKey.currentState?.pageTo(0);
              if(value.isEmpty){
                filterList = dataList;
                refresh(this);
                return;
              }

              String search = value.toUpperCase();
              List<String> searchWords = search.split(' ').where((s) => s.isNotEmpty).toList();

              bool found = false;
              for(int i = 0; i < searchWords.length; i++){
                if(!found){
                  // Return filtered list of MASTER SHEET items that match the search string
                  var first = dataList.where((List<dynamic> column) => _findWord(column[3], searchWords[i])).toList();
                  if(first.isNotEmpty){
                    filterList = first;
                    found = true;
                  }
                  else{
                    filterList = dataList;
                  }
                }
                else{
                  // Check remaining search strings and return a refined search list
                  var refined = filterList.where((List<dynamic> column) => _findWord(column[3], searchWords[i])).toList();
                  if(refined.isNotEmpty){
                    filterList = refined;
                  }
                }
              }

              refresh(this);
            }
        ),
      ),
    );
  }

  setIndex(int selectIndex) {
    //masterIndex = filterList[listIndex][0]; // position of the item in the MainList
    this.selectIndex = selectIndex; // position of selection on screen
    //mPrint("SELECT INDEX: $selectIndex");
    //if(selectIndex != -1){
    //  mPrint(filterList[selectIndex].toString());
   // }
    textFocus.unfocus();
    refresh(this);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            centerTitle: true,
            title: Text("Spreadsheet View: ${job.id}", textAlign: TextAlign.center),
            automaticallyImplyLeading: false,
          ),

          body: GestureDetector(
              onTapDown: (_) => textFocus.unfocus(),
              child: Center(
                  child: Column(
                      children: [
                        widget.tableType == TableType.search ? _searchList() : Container(),
                        dataList.isNotEmpty ? Expanded(
                            child: SingleChildScrollView(
                              child: PaginatedDataTable(
                                sortColumnIndex: 0,
                                key: widget.tableKey,
                                sortAscending: true,
                                showCheckboxColumn: false,
                                showFirstLastButtons: true,
                                rowsPerPage: sFile["pageCount"],
                                controller: ScrollController(),
                                columns: getColumns(widget.tableType, MediaQuery.of(context).size.width),
                                source: RowSource(parent: this, dataList: filterList, select: true, type: widget.tableType),
                              ),
                            )
                        ) : const Text("EMPTY LIST!\n GO BACK!", textAlign: TextAlign.center),

                        GestureDetector(
                            onTapDown: (_) => textFocus.unfocus(),
                            child: SingleChildScrollView(
                                child: Center(
                                  child: Column(
                                      children: [
                                        widget.action == ActionType.edit || widget.action == ActionType.add ?
                                        rBox(
                                          context,
                                          selectIndex > -1 ? colorOk : colorDisable,
                                          TextButton(
                                              child: Text(widget.action == ActionType.edit ? 'EDIT ITEM' : 'ADD ITEM', style: whiteText),
                                              onPressed: () {
                                                goToPage(
                                                    context,
                                                    StockItem(
                                                        item: rowToItem(filterList[selectIndex], widget.tableType == TableType.literal),
                                                        action: widget.action,
                                                        index: widget.action == ActionType.add ? filterList[selectIndex][0] : selectIndex
                                                    ),
                                                    false);
                                              }
                                          ),
                                        ) : Container(),
                                        rBox(context, colorBack, TextButton(
                                          child: Text("Back", style: whiteText),
                                          onPressed: () {
                                            goToPage(context, const Stocktake(), false);
                                          },
                                        )),
                                      ]
                                  ),
                                )
                            )
                        ),
                      ]
                  )
              )
          ),
        )
    );
  }
}

// Get Table Columns
List<DataColumn> getColumns(TableType t, double width) {
  List<int>? showColumn;
  List<DataColumn> dataColumns;

  switch (t){
    case TableType.literal:
      dataColumns = <DataColumn>[
        DataColumn(label: SizedBox(width: width * 0.5, child: const Text("Description"))),
        const DataColumn(label: Text("Count")),
        DataColumn(label: SizedBox(width: width * 0.3, child: const Text("UOM"))),
        const DataColumn(label: Text("Location")),
        const DataColumn(label: Text("Barcode"))
      ];
      break;

    case TableType.export:
      dataColumns = <DataColumn>[
        const DataColumn(label: Text('Index')),
        const DataColumn(label: Text('Category')),
        DataColumn(label: SizedBox(width: width * 0.5, child: const Text("Description"))),
        DataColumn(label: SizedBox(width: width * 0.3, child: const Text("UOM"))),
        const DataColumn(label: Text('QTY')),
        const DataColumn(label: Text('Cost Ex GST')),
        const DataColumn(label: Text('Barcode')),
        const DataColumn(label: Text('NOF'))
      ];
      break;

    case TableType.linear:
      dataColumns = <DataColumn>[
        const DataColumn(label: Text('Index')),
        const DataColumn(label: Text('Barcode')),
        const DataColumn(label: Text('Category')),
        DataColumn(label: SizedBox(width: width * 0.5, child: const Text("Description"))),
        DataColumn(label: SizedBox(width: width * 0.3, child: const Text("UOM"))),
        const DataColumn(label: Text('Count')),
      ];
      break;

    case TableType.search:
      dataColumns = <DataColumn>[
        const DataColumn(label: Text('Index')),
        const DataColumn(label: Text('Barcode')),
        const DataColumn(label: Text('Category')),
        DataColumn(label: SizedBox(width: width * 0.5, child: const Text("Description"))),
        DataColumn(label: SizedBox(width: width * 0.3, child: const Text("UOM"))),
        const DataColumn(label: Text('Price')),
      ];
      showColumn = [3,4];
      break;

    default:
      dataColumns = <DataColumn>[
        const DataColumn(label: Text('Index')),
        const DataColumn(label: Text('Barcode')),
        const DataColumn(label: Text('Category')),
        DataColumn(label: SizedBox(width: width * 0.5, child: const Text("Description"))),
        DataColumn(label: SizedBox(width: width * 0.3, child: const Text("UOM"))),
        const DataColumn(label: Text('Price')),
      ];
      break;
  }

  // Not hiding anything
  if (showColumn == null || showColumn.isEmpty) {
    return dataColumns;
  }

  // Create list of columns in order of [showColumn]
  List<DataColumn> dc = [];
  for (int i = 0; i < showColumn.length; i++) {
    int col = showColumn[i];
    if (col < dataColumns.length) {
      dc.add(dataColumns[col]);
    }
  }

  return dc;
}

// Get Table Rows
class RowSource extends DataTableSource {
  List dataList;
  TableType type;
  bool? select = false;
  dynamic parent;

  RowSource({
    required this.parent,
    required this.dataList,
    required this.type,
    this.select,
  });

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList.length;
  @override
  int get selectedRowCount => (select == true && parent.selectIndex > -1) ? 1 : 0;

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if (index >= rowCount) {
      return null;
    }

    List<DataCell> dataCells = [];
    if (type == TableType.export) {
      dataCells = <DataCell>[
        DataCell(Text(dataList[index][0].toString())),
        DataCell(Text(dataList[index][1].toString())),
        DataCell(Text(dataList[index][2].toString())),
        DataCell(Text(dataList[index][3].toString())),
        DataCell(Text(dataList[index][4].toString())),
        DataCell(Text(dataList[index][5].toString())),
        DataCell(Text(dataList[index][6].toString())),
        DataCell(Text(dataList[index][7].toString())),
        //const DataCell(Text("10.0")),
      ];
    }
    else if(type == TableType.literal) {
      dataCells = <DataCell>[
        DataCell(Text(dataList[index][3].toString())),
        DataCell(Text(dataList[index][6].toString())),
        DataCell(Text(dataList[index][4].toString())),
        DataCell(Text(dataList[index][7].toString())),
        DataCell(Text(dataList[index][1].toString())),
      ];
    }
    else {
      dataCells = <DataCell>[
        DataCell(Text((dataList[index][0]).toString())),
        DataCell(Text(dataList[index][1].toString())),
        DataCell(Text(dataList[index][2].toString())),
        DataCell(Text(dataList[index][3].toString())),
        DataCell(Text(dataList[index][4].toString())),
        DataCell(Text(dataList[index][5].toString())),
      ];
    }

    List<int> showCells = [];

    if(type == TableType.search){
      showCells = [3, 4];
    }

    // Sort cells in order of [showCells]
    if (showCells.isNotEmpty) {
      List<DataCell> dc = [];
      for (int i = 0; i < showCells.length; i++) {
        int cell = showCells[i];
        if (cell < dataCells.length) {
          dc.add(dataCells[cell]);
        }
      }
      dataCells = dc;
    }

    // Select and highlight rows
    return DataRow.byIndex(
      index: index,
      selected: (select == true) ? index == parent.selectIndex : false,
      onSelectChanged: (value) {
        if (select == true) {
          int selectIndex = parent.selectIndex != index ? index : -1;
          parent.setIndex(selectIndex);
          notifyListeners();
        }
      },

      cells: dataCells,
    );
  }
}

// RE-USABLE WIDGETS
// mPrint(var s) {
//   // "Safely" prints something to terminal, otherwise IDE notifications chucks a sissy fit
//   if (s == null) {
//     return;
//   }
//   if (!kReleaseMode) {
//     if (kDebugMode) {
//       print(s.toString());
//     }
//   }
// }

refresh(var widget) {
  widget.setState(() {});
}

shortFilePath(String s) {
  var sp = s.split("/");
  return sp[sp.length - 1];
}

Map<String, dynamic> rowToItem(List<dynamic> row, bool literal){
  return
    {
      "index" : row[0],
      "barcode" : row[1],
      "category" : row[2],
      "description" : row[3],
      "uom" : row[4],
      "price" : row[5],
      "count" : literal ? row[6] : 0.0,
      "location" : literal ? row[7] : job.location,
      "nof" : row[0] >= mainTable!.maxRows, // if index is greater than master list it must be a NOF
    };
}

defCategory(){
  return <String> [
    "BAKERY",
    "CATERING",
    "CHEMICAL",
    "CHEMICALS",
    "CONSUMABLE",
    "CONSUMABLES",
    "DEPOSITS",
    "DIESEL",
    "DRINKS",
    "FREIGHT",
    "FUEL",
    "GAS",
    "INVOICE",
    "LASER TONER",
    "MISC",
    "PACKAGING",
    "UNIFORMS",
    "VEG CRATES",
    "WATER"
  ];
}

headerPadding(String title, TextAlign l){
  return Padding(
    padding: const EdgeInsets.all(15.0),
    child: Text(
        title,
        textAlign: l,
        style: const TextStyle(color: Colors.blue, fontSize: 20.0)),
  );
}

goToPage(BuildContext context, Widget page, bool animate) {
  Navigator.push(
    context,
    animate ? MaterialPageRoute(
        builder: (BuildContext context) {return page;}
    ) :
    PageRouteBuilder(
      fullscreenDialog: true,
      pageBuilder: (context, animation1, animation2) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

rBox(BuildContext context, Color c, Widget w){
  return Padding(
    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
    child: Container(
      height: 50,
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: w,
    ),
  );
}

showNotification(BuildContext context,  Color bkgColor, TextStyle textStyle, String title, String message,) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title\n$message', style: textStyle),
        backgroundColor: bkgColor,
        duration: const Duration(milliseconds: 2000),
        padding: const EdgeInsets.all(15.0),  // Inner padding for SnackBar content.
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.8,
            right: 20,
            left: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      )
  );
}

showAlert(BuildContext context, String txtTitle, String txtContent, Color c) {
  return showDialog(
    barrierDismissible: false,
    context: context,
    barrierColor: c,
    builder: (context) => AlertDialog(
      title: Text(txtTitle),
      content: Text(txtContent),
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
  );
}

loadingAlert(BuildContext context){
  showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
              children: [
                Container(
                    margin: const EdgeInsets.only(left: 10),
                    child: const Text("Loading...")),
              ]
          ),
        );
      });
}

Future<bool> confirmDialog(BuildContext context, String str) async {
  bool confirmation = false;
  await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) =>

          AlertDialog(
            actionsAlignment: MainAxisAlignment.spaceAround,
            title: Text(str),
            actions: <Widget>[
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorBack),
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
  );

  return confirmation;
}

// READ/WRITE OPERATIONS
Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<void> _prepareStorage() async {
  var path = 'storage/emulated/0';//!isEmulating ? 'storage/emulated/0' : 'sdcard';
  rootDir = Directory(path);
  var storage = await storageType.status;
  if (storage != PermissionStatus.granted) {
    await storageType.request();
  }
  //bool b = storage == PermissionStatus.granted;
  //mPrint("STORAGE ACCESS IS : $b");
}

Future<String> pickFile(BuildContext context) async {
  String val = "";
  await FilesystemPicker.open(
    title: rootDir.toString(),
    context: context,
    rootDirectory: rootDir!,
    fsType: FilesystemType.file,
    pickText: 'Select file',
    folderIconColor: Colors.blue,
    fileTileSelectMode: FileTileSelectMode.wholeTile,
    requestPermission: () async => await storageType.request().isGranted,
  ).then((value){
    //mPrint(value.toString());
    val = value.toString();
  });
  return val;
}

Future<String> pickSpreadsheet(BuildContext context) async {
  String val = "";
  await FilesystemPicker.open(
    title: rootDir.toString(),
    context: context,
    rootDirectory: rootDir!,
    fsType: FilesystemType.file,
    fileTileSelectMode: FileTileSelectMode.wholeTile,
    pickText: 'Select .xlsx or .csv file',
    allowedExtensions: ['.xlsx', '.csv'],
    folderIconColor: Colors.teal,
    requestPermission: () async => await storageType.request().isGranted,
  ).then((value){
    val = value.toString();
  });
  return val;
}

Future<void> loadMasterSheet() async{
  Uint8List bytes;
  final path = await _localPath;
  String filePath = "$path/FD_TEMPLATE.xlsx";
  await Future.delayed(const Duration(microseconds: 0));
  if(!File(filePath).existsSync()){
    //mPrint("No master sheet in app dir, copying asset file to app dir...");
    ByteData data = await rootBundle.load("assets/FD_TEMPLATE.xlsx");
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(filePath).writeAsBytes(bytes);
  }
  else{
    //mPrint("Master sheet exists! Grabbing the file...");
    File file = File(filePath);
    bytes = file.readAsBytesSync();
  }

  var decoder = SpreadsheetDecoder.decodeBytes(bytes);
  var sheets = decoder.tables.keys.toList();
  mainTable = decoder.tables[sheets[0]];

  var header = mainTable!.rows[0];
  var cIndex = -1;
  for(int j = 0; j < header.length; j++){
    if(header[j].toString().toUpperCase() == "CATEGORY" || header[j].toString().toUpperCase() == "CATEGORIES") {
      cIndex = j;
      break;
    }
  }

  if(cIndex != -1){
    masterCategory = List<String>.empty(growable: true);
    for(int i = 1; i < mainTable!.rows.length; i++){
      var row = mainTable!.rows[i].toList();
      masterCategory.add(row[cIndex].toString().toUpperCase());
    }
    masterCategory = masterCategory.toSet().toList();
  }
  else{
    masterCategory = defCategory();
    //mPrint("using def categories");
  }

  //mPrint(masterCategory);

  // Remove header row
  mainTable!.rows.removeRange(0, 1);

  dbPath = filePath;
}

exportJobToXLSX( List<dynamic> fSheet) async{
  var path = 'storage/emulated/0/Documents';
  var excel = Excel.createExcel();
  var sheetObject = excel['Sheet1'];
  sheetObject.isRTL = false;
  // Add header row
  sheetObject.insertRowIterables(["Master Index", "Category", "Description", "UOM", 'QTY', "Cost Ex GST", "Barcode", "NOF"], 0);
  for(int i = 0; i < fSheet.length; i++){
    List<String> dataList = [];
    for(int j = 0; j < fSheet[i].length; j++){
      dataList.add(fSheet[i][j].toString());
    }

    sheetObject.insertRowIterables(dataList, i+1);
  }
  var fileBytes = excel.save();
  File("$path/stocktake_${job.id}.xlsx")
    ..createSync(recursive: true)
    ..writeAsBytesSync(fileBytes!);
}

writeJob(StockJob job) async {

  var filePath = 'storage/emulated/0/Documents/';

  // If "/Documents" folder does not exist, create it.
  await Directory(filePath).exists().then((value){
    if(!value){
      Directory('storage/emulated/0/Documents/').create().then((Directory directory) {
        //mPrint("Documents dir was created: ${directory.path}");
      });
    }
  });

  String date = job.date.replaceAll("_", "");
  filePath += 'job_${job.id}_${job.name}_$date';

  //mPrint(filePath);

  var jobFile = File(filePath);
  Map<String, dynamic> jMap = job.toJson();
  var jString = jsonEncode(jMap);
  jobFile.writeAsString(jString);
}

writeSession() async {
  Map<String, dynamic> jMap = {
    "dirs" : jsonEncode(sFile["dirs"]),
    "uid" : "",
    "pageCount" : sFile["pageCount"],
    'fontScale' : sFile["fontScale"],
    'dropScale' : sFile["dropScale"],
  };
  var jString = jsonEncode(jMap);
  final path = await _localPath;
  final filePath = File('$path/session_file');
  filePath.writeAsString(jString);
}

getSession() async {
  final path = await _localPath;
  var filePath = File('$path/session_file');
  if(!await filePath.exists()) {
    // Make new session file
    sFile = {
      "dirs" : [],
      "uid" : "",
      "pageCount" : 15,
      'fontScale' : 12.0,
      'dropScale' : 50.0,
    };
    writeSession();
    return true;
  }
  else{
    // Load session file
    String fileContent = await filePath.readAsString();
    var jsn = json.decode(fileContent);
    sFile = {
      "dirs" : jsn["dirs"] == null || jsn["dirs"].isEmpty ? [] : jsonDecode(jsn['dirs']),
      "uid" : jsn['uid'] == null || jsn["uid"].isEmpty ? "USER" :  jsn['uid'] as String,
      "pageCount" : jsn['pageCount'] == null ? 12 : jsn['pageCount'] as int,
      "fontScale" : jsn['fontScale'] == null ? 20.0 : jsn['fontScale'] as double,
      "dropScale" : jsn['dropScale'] == null ? 50.0 : jsn['dropScale'] as double
    };
    return false;
  }
}

/*
*/
