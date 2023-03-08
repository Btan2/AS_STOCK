/*
LEGAL:
   This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
   To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.

   This program is distributed WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

BUILD CMD:
      flutter build apk --no-pub --target-platform android-arm64,android-arm --split-per-abi --build-name=1.0.0 --build-number=1 --obfuscate --split-debug-info build/app/outputs/symbols
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
//import 'package:flutter/foundation.dart'; // REQUIRED FOR DEBUG PRINTING
import 'package:flutter/services.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart';
import 'stock_job.dart';

Permission storageType = Permission.storage; //Permission.manageExternalStorage;
String jobStartStr = "ASJob_";
StockJob job = StockJob(id: "EMPTY", name: "EMPTY");
List<String> jobList = [];
List<List<dynamic>> jobTable = List.empty(growable: true);
String dbPath = '';
Directory? rootDir;
SpreadsheetTable? mainTable;
List<String> masterCategory = [];
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
TextStyle get rText{ return TextStyle(color: Colors.red.shade400, fontSize: 16.0);}
TextStyle get greyText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}
TextStyle get blackText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}
TextStyle get titleText{ return const TextStyle(color: Colors.black87, fontSize: 20.0, fontWeight: FontWeight.bold);}
TextStyle get blueText{ return const TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold);}

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
class HomePage extends StatefulWidget {
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
                        // rBox(
                        //   context,
                        //   Colors.black,
                        //   TextButton(
                        //       child: const Text("TEST TABLE"),
                        //       onPressed: (){
                        //         if(mainTable != null || mainTable!.rows.isNotEmpty) {
                        //             jobTable = mainTable!.rows;
                        //             goToPage(context, const TableView2(action: ActionType.view), false);
                        //           }
                        //         },
                        //   ),
                        // ),

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
class AppSettings extends StatefulWidget {
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

                    // SizedBox(height: MediaQuery.of(context).size.height/10.0),
                    // headerPadding("Load MASTER_SHEET from Phone Storage", TextAlign.left),
                    // Card(
                    //   child: ListTile(
                    //     title: mainTable == null ? Text( "NO SPREADSHEET DATA", style: warningText) : Text(shortFilePath(dbPath)),
                    //     subtitle: mainTable == null ? Text("Tap here to load a spreadsheet...", style: warningText) : Text("Count: ${mainTable?.maxRows}"),
                    //     leading: mainTable == null ? const Icon(Icons.warning_amber, color: Colors.red) : const Icon(Icons.list_alt, color: Colors.green),
                    //     onTap: (){
                    //       goToPage(context, const LoadSpreadsheet(), false);
                    //     },
                    //   ),
                    // ),

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

    if (str.startsWith(jobStartStr)){
      //String newPath = path;
      bool copyJob = false;

      if(path.contains('sdcard')){
        if(!path.contains("sdcard/Documents")){
          //newPath = 'sdcard/Documents/$str';
          copyJob = true;
        }
      }
      else if(!path.contains("/storage/emulated/0/Documents")){
        //newPath = 'storage/emulated/0/Documents/$str';
        copyJob = true;
      }

      // Copy and move job to default documents directory (if it isn't there already)
      if(copyJob){
        var jsn = File(path);
        String fileContent = await jsn.readAsString();
        var dynamic = json.decode(fileContent);
        var j = StockJob.fromJson(dynamic);
        writeJob(j, false);

        // mPrint("Job file copied from [ $path ] to [ $newPath ]");
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

    //mPrint("JOB: $jobStartStr${job.id}_[x]");

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
                      //goToPage(context, StaticTable(dataList: mainTable!.rows, tableType: value as TableType), true);
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
                                    // jobTable = mainTable!.rows + job.nofList();
                                    await writeSession();


                                    //String n = shortFilePath(jobList[index]);
                                    // if("job_${job.id}_${job.name}" == n){
                                    //   goToPage(context, const OpenJob(), true);
                                    // }
                                    // else{
                                    // }

                                    await _readJob(jobList[index]).then((value) {
                                      jobTable = mainTable!.rows + job.nofList();
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
                                        if(path.isEmpty || path == "null" || !path.contains(jobStartStr)){
                                          return;
                                        }

                                        //mPrint(jobList);

                                        if(!jobList.contains(path)){
                                          jobList.add(path);
                                        }

                                        await writeSession();

                                        // copy job file to documents folder if it is not there
                                        await _copyJobFile(path);
                                        await _readJob(path).then((value) {
                                          jobTable = mainTable!.rows + job.nofList();
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

  // Future<bool> _checkFile(String path) async{
  //   // Show confirmation window if job file already exists
  //   await File(path).exists().then((value) async{
  //     if(value){
  //       return await confirmDialog(context, "Job file with the same path already exists! \n\n -> Confirm overwrite?");
  //     }
  //   });
  //
  //   return true;
  // }

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
          //resizeToAvoidBottomInset: false,
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
                                //String date = newJob.date.replaceAll("_", "");
                                String path = "/storage/emulated/0/Documents/$jobStartStr${newJob.id}_0";

                                // Do not overwrite any other existing jobs
                                writeJob(newJob, false);

                                job = newJob;
                                job.calcTotal();

                                if(!jobList.contains(path)){
                                  jobList.add(path);
                                }

                                // // manually check through job list?
                                // for(int i = 0; i < jobList.length; i++)
                                // {
                                //   if (jobList[i] == path){
                                //     break;
                                //   }
                                //
                                //   if(i >= jobList.length-1){
                                //     jobList.add(path);
                                //   }
                                // }

                                //showNotification(context, colorOk, whiteText, "Job Created", "* Save path: $path");
                                jobTable = mainTable!.rows;
                                goToPage(context, const OpenJob(), true);
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
                    //goToPage(context, StaticTable(dataList: job.literalList(), tableType: value), true);
                  }
                  else if (value == TableType.linear){
                    //goToPage(context, StaticTable(dataList: job.linearList(), tableType: value), true);
                  }
                  else if(value == TableType.full){
                    //goToPage(context, StaticTable(dataList: jobTable, tableType: value), true);
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
                                  if(jobTable.isEmpty){
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
                                  goToPage(context, const StaticTable(tableType: TableType.export), true);
                                },
                              )
                          ),
                          rBox(
                              context,
                              Colors.green,
                              TextButton(
                                child: Text('Save Job', style: whiteText),
                                onPressed: () async {
                                  await writeJob(job, true).then((value){
                                    // String date = job.date.replaceAll("_", "");
                                    showAlert(context, "Job Saved", "Save path: \n /Documents/$jobStartStr${job.id}...", Colors.orange);
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
                              await writeJob(job, true).then((value){
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
class Stocktake extends StatelessWidget {
  const Stocktake({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
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
                                goToPage(context, const TableView2(action: ActionType.add), false);
                              } else {
                                showAlert(context, "Alert", 'Create and set location before adding items.', Colors.red.withOpacity(0.8));
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
                              addNOF(context);
                            },
                          )
                      ),
                      rBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Edit Stocktake', style: whiteText),
                            onPressed: () {
                              job.literals.isNotEmpty ? goToPage(context, const TableView2(action: ActionType.edit), false) : showAlert(context, "Alert", "Stocktake is empty.", colorDisable);
                              // goToPage(context, DynamicTable(tableType: TableType.literal, action: ActionType.edit), true)
                            },
                          )
                      ),
                    ]
                )),
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
class ScanItem extends StatefulWidget {
  const ScanItem({super.key});

  @override
  State<ScanItem> createState() => _ScanItem();
}
class _ScanItem extends State<ScanItem> {
  TextEditingController searchCtrl= TextEditingController();
  FocusNode searchFocus = FocusNode();
  TextEditingController countCtrl = TextEditingController();
  var countFocus = FocusNode();
  late List<List<dynamic>> dataList;
  List<List<dynamic>> filterList = List.empty();
  bool found = false;
  bool wholeBarcode = true;
  bool autofocusSearch = false;
  int itemIndex = 0;

  @override
  void initState() {
    super.initState();
    searchFocus.unfocus();
    autofocusSearch = true;
    dataList = mainTable!.rows + job.nofList();
    countCtrl.text = "0.0";
    found = false;

    searchFocus.requestFocus();
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
                      ),
                      PopupMenuItem<int>(
                          value: 1,
                          child: Card(
                            child: ListTile(
                              title: const Text("Autofocus Search Field"),
                              trailing: autofocusSearch ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                            ),
                          )
                      ),
                    ];
                  },
                  onSelected: (value) async {
                    _clearFocus();
                    searchCtrl.clear();
                    if(value == 0){
                      wholeBarcode = wholeBarcode ? false : true;
                    }
                    else if(value == 1){
                      autofocusSearch = autofocusSearch ? false : true;
                    }

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
                                // var item =;
                                // item['count'] = count;
                                // item['location'] = job.location;
                                job.literals.add( rowToItem(filterList[itemIndex], count));
                                job.calcTotal();
                                //showNotification(context, colorOk, whiteText, "Item Added:\n${item['description']} \nCount: $count","");
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
                                    //showAlert(context, "", "Cannot add empty text as location", colorWarning);
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

// TableView2
class TableView2 extends StatefulWidget {
  final ActionType action;
  const TableView2({
    super.key,
    required this.action,
  });

  @override
  State<TableView2>  createState() => _TableView2();
}
class _TableView2 extends State<TableView2> {
  TextEditingController barcodeCtrl = TextEditingController();
  var barcodeFocus = FocusNode();
  TextEditingController priceCtrl = TextEditingController();
  var priceFocus = FocusNode();
  TextEditingController descriptionCtrl = TextEditingController();
  var descriptionFocus = FocusNode();
  TextEditingController uomCtrl = TextEditingController();
  var uomFocus = FocusNode();
  TextEditingController countCtrl = TextEditingController();
  var countFocus = FocusNode();
  TextEditingController locationCtrl = TextEditingController();
  var locationFocus = FocusNode();
  String categoryValue = "MISC";

  List<List<dynamic>> filterList = List.empty(growable: true);
  TextEditingController searchCtrl = TextEditingController();
  var searchFocus = FocusNode();
  int pageLength = 20;
  double keyboardHeight = 20.0;
  final int iIndex = 0;
  final int barcode = 1;
  final int category = 2;
  final int description = 3;
  final int uom = 4;
  final int price = 5;
  final int iCount = 6;
  final int location = 7;

  @override
  void initState() {
    super.initState();
    filterList = widget.action == ActionType.edit ? job.literalList() : jobTable;
    pageLength = filterList.length;
  }

  setText(var item){
    clearFocus();
    barcodeCtrl.text = item[barcode].toString().toUpperCase();
    String catCheck = item[category].toString().toUpperCase();
    categoryValue = catCheck != "NULL" ? catCheck : "MISC";
    descriptionCtrl.text = item[description];
    String uomCheck = item[uom].toString().toUpperCase();
    uomCtrl.text = uomCheck != "NULL" ? uomCheck : "EACH";
    priceCtrl.text = item[price].toString();
    countCtrl.text = widget.action == ActionType.edit ? item[iCount].toString() : "0.0";
    locationCtrl.text = widget.action == ActionType.edit ? item[location].toString() : job.location;
  }

  void clearFocus(){
    uomFocus.unfocus();
    barcodeFocus.unfocus();
    descriptionFocus.unfocus();
    priceFocus.unfocus();
    countFocus.unfocus();
    locationFocus.unfocus();
  }

  bool _findWord(String word, String search) {
    return word.split(' ').where((s) => s.isNotEmpty).toList().contains(search);
  }

  Widget _searchList() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.search),
        title: TextField(
            controller: searchCtrl,
            focusNode: searchFocus,
            decoration: const InputDecoration(
                hintText: 'Search', border: InputBorder.none),
            onChanged: (String value) {
              if (value.isEmpty) {
                filterList = widget.action == ActionType.edit ? job.literalList() : jobTable;
                refresh(this);
                return;
              }

              String search = value.toUpperCase();
              List<String> searchWords = search.split(' ').where((s) =>
              s.isNotEmpty).toList();

              bool found = false;
              for (int i = 0; i < searchWords.length; i++) {
                if (!found) {
                  // Return filtered list of items that match the search string
                  var first = (widget.action == ActionType.edit ? job.literalList() : jobTable).where((List<dynamic> column) =>
                      _findWord(column[3], searchWords[i])).toList();
                  if (first.isNotEmpty) {
                    filterList = first;
                    found = true;
                  }
                  else {
                    filterList = widget.action == ActionType.edit ? job.literalList() : jobTable;
                  }
                }
                else {
                  // Check remaining search strings with the filtered list
                  var refined = filterList.where((List<dynamic> column) =>
                      _findWord(column[3], searchWords[i])).toList();
                  if (refined.isNotEmpty) {
                    filterList = refined;
                  }
                }
              }

              pageLength = filterList.length;

              refresh(this);
            }
        ),
      ),
    );
  }

  Widget editCount() {
    return Padding(
        padding: const EdgeInsets.only(
            left: 15.0, right: 15.0, top: 0, bottom: 5),
        child: Card(
            child: ListTile(
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  clearFocus();
                  double count = double.parse(countCtrl.text) + 1;
                  countCtrl.text = count.toString();
                  // refresh(this);
                },
              ),
              title: TextField(
                scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight),
                controller: countCtrl,
                focusNode: countFocus,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: false, decimal: true),
              ),
              leading: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  clearFocus();
                  double count = double.parse(countCtrl.text) - 1.0;
                  countCtrl.text = max(count, 0.0).toString();
                  // refresh(this);
                },
              ),
            )
        )
    );
  }

  Widget editCategory() {
    return GestureDetector(
        onTapDown: (_) => clearFocus(),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 15.0, right: 15.0, top: 0, bottom: 5),
          child: Card(
            child: DropdownButton(
              value: categoryValue,
              isExpanded: true,
              menuMaxHeight: MediaQuery.of(context).size.height / 2.0,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: masterCategory.map((String items) {
                return DropdownMenuItem(
                  value: items,
                  child: Center(
                      child: Text(items, textAlign: TextAlign.center,)
                  ),
                );
              }).toList(),

              onChanged: (String? newValue) {
                categoryValue = newValue!;
                // setState(() {
                //   categoryValue = newValue!;
                // });
              },
            ),
          ),
        )
    );
  }

  deleteItem(int index) {
    job.literals.removeAt(index);
    job.calcTotal();
    pageLength = job.literals.length;
    refresh(this);
    goToPage(context, const TableView2(action: ActionType.edit), false);

    // job.literals.removeAt(index);
    // job.calcTotal();
    // pageLength = job.literals.length;
    // refresh(this);
    // goToPage(context, const TableView2(action: ActionType.edit), false);
    // Navigator.pop(context);
  }

  checkFields(){
    if(barcodeCtrl.text.isEmpty){
      barcodeCtrl.text = '0';
    }
    if(uomCtrl.text.isEmpty){
      uomCtrl.text = "EACH";
    }
    if(priceCtrl.text.isEmpty){
      priceCtrl.text = '0.0';
    }
    if(countCtrl.text.isEmpty){
      countCtrl.text = '0.0';
    }
    if(locationCtrl.text.isEmpty){
      locationCtrl.text = job.location;
    }
  }

  confirmEdit(int index) async{
    List<dynamic> item = filterList[index];
    if (double.parse(countCtrl.text) <= 0) {
      await confirmDialog(context, "Item count is 0\nRemove item from stocktake?").then((bool value) async {
        if(value){
          deleteItem(index);
        }
        // if (value) {
        //   job.literals.removeAt(index);
        //   job.calcTotal();
        //   pageLength = job.literals.length;
        //   refresh(this);
        //   Navigator.pop(context);
        // }
      });
    }
    else {
      await confirmDialog(context, "Confirm changes to stock item?").then((bool value) async {
        if(descriptionCtrl.text.isEmpty){
          item[barcode].toString().toUpperCase();
        }

        checkFields();

        if (value) {
          job.literals[index] = {
            "index": item[iIndex],
            "barcode": barcodeCtrl.text,
            "category": categoryValue,
            "description": descriptionCtrl.text,
            "uom": uomCtrl.text,
            "price": double.parse(priceCtrl.text),
            "count": double.parse(countCtrl.text),
            "location": locationCtrl.text,
            "nof": item[7], //nof
          };

          job.calcTotal();

          // Add location to list if it doesn't exist
          if (!job.allLocations.contains(locationCtrl.text)) {
            job.allLocations.add(locationCtrl.text);
          }

          Navigator.pop(context);

          //Navigator.pop(context);
          //refresh(context);

          //goToPage(context, TableView2(tableType: TableType.literal, action: ActionType.edit), false);
          // Ask to apply changes to other items with same index?
          // Automatically create a new NOF?
        }
      });
    }
  }

  editFields(int index) {
    return <Widget>[
      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height/20.0,
      ),
      Padding(
          padding: const EdgeInsets.only(left:15, bottom: 5, top: 5),
          child: Card(
              color: Colors.white.withOpacity(0.0),
              child: ListTile(
                title: Text("DELETE ITEM", textAlign: TextAlign.center, style: warningText),
                trailing: IconButton(
                    icon: Icon(Icons.delete_forever_sharp, color: colorWarning),
                    onPressed: () async {
                      clearFocus();
                      await confirmDialog(context, "Remove Item from stock count?").then((bool value2) async{
                        if(value2){
                          deleteItem(index);
                        }
                      });
                    }
                )
              )
          )
      ),

      titlePadding("Barcode:", TextAlign.left),
      GestureDetector(
          onTapDown: (_) => clearFocus(),
          child: editTextField(barcodeCtrl, barcodeFocus, '', keyboardHeight)
      ),

      titlePadding("Category:", TextAlign.left),
      editCategory(),

      titlePadding("Description:", TextAlign.left),
      GestureDetector(
          onTapDown: (_) => clearFocus(),
          child: editTextField(descriptionCtrl, descriptionFocus, 'E.G. PETERS I/CREAM VAN 1L',  keyboardHeight)
      ),

      titlePadding("UOM:", TextAlign.left),
      GestureDetector(
          onTapDown: (_) => clearFocus(),
          child: editTextField(uomCtrl, uomFocus, 'EACH', keyboardHeight)
      ),

      titlePadding("Price:", TextAlign.left),
      Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
        child: Card(
            child: ListTile(
              title: TextField(
                scrollPadding:  EdgeInsets.symmetric(vertical: keyboardHeight),
                controller: priceCtrl,
                focusNode: priceFocus,
                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
              ),
            )
        ),
      ),

      titlePadding("Location:", TextAlign.left),
      GestureDetector(
          onTapDown: (_) => clearFocus(),
          child: editTextField(locationCtrl, locationFocus, '', keyboardHeight)
      ),

      titlePadding("Count:", TextAlign.left),
      editCount(),

      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 10.0,
      ),

      rBox(
          context,
          colorOk,
          TextButton(
            child: Text('Confirm', style: whiteText),
            onPressed: () async{
              await confirmEdit(index).then((value){
                refresh(this);
                //var s = filterList[index];
                //mPrint(s[6]);
              });
            },
          )
      ),
      rBox(
          context,
          colorBack,
          TextButton(
            child: Text('Cancel', style: whiteText),
            onPressed: (){
              Navigator.pop(context);
            },
          )
      ),
    ];
  }

  addFields(var item){
    return <Widget>[
      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height/20.0,
      ),

      titlePadding("Description:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[description], style: rText),
          )
      ),
      titlePadding("Category:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[category] ?? 'MISC', style: rText),
          )
      ),
      titlePadding("UOM:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[uom] ?? "EACH", style: rText),
          )
      ),

      titlePadding("Location:", TextAlign.left),
      GestureDetector(
          onTapDown: (_) => clearFocus(),
          child: editTextField(locationCtrl, locationFocus, '', keyboardHeight)
      ),

      titlePadding("Count:", TextAlign.left),
      editCount(),

      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 10.0,
      ),

      rBox(
          context,
          colorOk,
          TextButton(
            child: Text('Confirm', style: whiteText),
            onPressed: (){
              double count = double.parse(countCtrl.text);
              if(count <= 0){
                showAlert(context, "", "Cannot add zero (0) items", colorWarning);
                // showNotification(context, colorWarning, whiteText, "Cannot add zero (0) items","",);
                return;
              }

              // var a =
              // a['count'] = count;
              // a['location'] = locationCtrl.text;
              job.literals.add(rowToItem(item, count));
              job.calcTotal();
              Navigator.pop(context);
            },
          )
      ),

      rBox(
          context,
          colorBack,
          TextButton(
            child: Text('Cancel', style: whiteText),
            onPressed: (){
              Navigator.pop(context);
            },
          )
      ),
    ];
  }

  viewFields(var item){
    return <Widget>[
      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height/20.0,
      ),

      titlePadding("Description:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[description], style: rText),
          )
      ),

      titlePadding("Barcode:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[barcode] ?? '0', style: rText),
          )
      ),

      titlePadding("Category:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[category] ?? 'MISC', style: rText),
          )
      ),

      titlePadding("UOM:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[uom], style: rText),
          )
      ),

      titlePadding("Price:", TextAlign.left),
      Card(
          child: ListTile(
            title: Text(item[price].toString(), style: rText),
          )
      ),

      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 20.0,
      ),

      Padding(
        padding: const EdgeInsets.only(top: 15),
        child: SizedBox.expand(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorOk),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.only(top: 15),
        child: SizedBox.expand(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorBack),
            onPressed: (){
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
    var size = MediaQuery.of(context).size; /*24 is for notification bar on Android*/
    final double itemHeight = (size.height - kToolbarHeight - 24) / 2;
    final double itemWidth = size.width / 2;

    return Scaffold(
      //resizeToAvoidBottomInset: false,
        floatingActionButton: _searchList(),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              // actions: [],
              backgroundColor: Colors.blue,
              floating: false,
              pinned: true,
              expandedHeight: 15.0,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  widget.action == ActionType.edit ? "Total Count: ${job.total}" :
                    "Item Count: ${jobTable.length}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold
                    ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.black,
                        width: 4.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: (itemWidth / itemHeight) * 6.0,
              ),

              delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  if (index >= pageLength) return null; //index >= pageLength
                  var row = filterList[index];
                  return Container(
                    height: 25.0,
                    color: Colors.white.withOpacity(0.01),
                    child: Center(
                      child: TextButton(
                        child: widget.action == ActionType.edit ?
                        Card(
                            child: ListTile(
                                title: Text(row[3]),
                                subtitle: Text( (job.literals[index])["count"].toString(),)
                            )
                        ) : Text(row[3]),
                        onPressed: () async {
                          if(widget.action == ActionType.edit || widget.action == ActionType.add || widget.action == ActionType.addNOF){
                            setText(filterList[index]);
                            await showGeneralDialog(
                              context: context,
                              barrierColor: Colors.black12.withOpacity(0.8), // Background color
                              barrierDismissible: false,
                              barrierLabel: 'Dialog',
                              transitionDuration: const Duration(milliseconds: 400),
                              pageBuilder: (_, __, ___) {
                                keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
                                return Scaffold(
                                    backgroundColor: Colors.black.withOpacity(0.6),
                                    resizeToAvoidBottomInset: widget.action == ActionType.edit,
                                    body: GestureDetector(
                                        onTapDown: (_) => clearFocus(),
                                        child: SingleChildScrollView(
                                            child: Column(
                                                children: widget.action == ActionType.add ? addFields(filterList[index]) :
                                                widget.action == ActionType.view ? viewFields(filterList[index]) : editFields(index)
                                            )
                                        )
                                    )
                                );
                              },
                            ).then((value) {
                              refresh(this);
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),

        bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(8.0),
            child: rBox(context, colorBack,
              TextButton(
                child: Text('Back', style: whiteText),
                onPressed: () {
                  goToPage(context, const Stocktake(), false);

                  // switch (widget.action) {
                  //   case ActionType.add:
                  //     goToPage(context, const Stocktake(), false);
                  //     break;
                  //   case ActionType.edit:
                  //     goToPage(context, const Stocktake() , false);
                  //     break;
                  //   default:
                  //     Navigator.pop(context);
                  //     break;
                  // }
                },
              ),
            )
        )
    );
  }
}

// addNOF
void addNOF(BuildContext context){
  TextEditingController barcodeCtrl = TextEditingController();
  var barcodeFocus = FocusNode();
  TextEditingController priceCtrl = TextEditingController();
  var priceFocus = FocusNode();
  TextEditingController descriptionCtrl = TextEditingController();
  var descriptionFocus = FocusNode();
  TextEditingController uomCtrl = TextEditingController();
  var uomFocus = FocusNode();
  TextEditingController countCtrl = TextEditingController();
  var countFocus = FocusNode();
  TextEditingController locationCtrl = TextEditingController();
  var locationFocus = FocusNode();
  String categoryValue = "MISC";

  double keyboardHeight = 20.0;

  void clearFocus(){
    uomFocus.unfocus();
    barcodeFocus.unfocus();
    descriptionFocus.unfocus();
    locationFocus.unfocus();
    priceFocus.unfocus();
    countFocus.unfocus();
  }

  widgetInit(){
    clearFocus();
    barcodeCtrl.text = "";

    // Auto focus on Barcode text field to make barcode scanning easier
    barcodeFocus.requestFocus();

    categoryValue = "MISC";
    descriptionCtrl.text = "";
    uomCtrl.text = "EACH";
    priceCtrl.text = "0.0";
    countCtrl.text = "0.0";
    locationCtrl.text = job.location;
  }

  confirmNOF(){

    if(barcodeCtrl.text.isEmpty){
      barcodeCtrl.text = '0';
    }

    if(uomCtrl.text.isEmpty){
      uomCtrl.text = "EACH";
    }

    if(priceCtrl.text.isEmpty){
      priceCtrl.text = '0.0';
    }

    if(countCtrl.text.isEmpty){
      countCtrl.text = '0.0';
    }

    if(locationCtrl.text.isEmpty){
      locationCtrl.text = job.location;
    }

    if(descriptionCtrl.text.isNotEmpty) {
      int newIndex = jobTable.length;
      var nofItem = {
        "index": newIndex,
        "barcode": barcodeCtrl.text,
        "category": categoryValue,
        "description": descriptionCtrl.text,
        "uom": uomCtrl.text,
        "unit": 1.0,
        "price": double.parse(priceCtrl.text),
        "nof": true,
      };

      if (job.newNOF(nofItem)) {
        job.nof.add(nofItem);
      }

      if (double.parse(countCtrl.text) > 0) {
        var item = {
          "index": newIndex,
          "barcode": barcodeCtrl.text,
          "category": categoryValue,
          "description": descriptionCtrl.text,
          "uom": uomCtrl.text,
          "price": double.parse(priceCtrl.text),
          "count": double.parse(countCtrl.text),
          "location": locationCtrl.text,
          "nof": true,
        };


        job.literals.add(item);
        job.calcTotal();
      }

      jobTable = mainTable!.rows + job.nofList();
      Navigator.pop(context);
    }
    else{
      showAlert(context, "", "Description text must not be empty!", colorWarning);
    }
  }

  showGeneralDialog(
    context: context,
    barrierColor: Colors.black12.withOpacity(0.8),
    barrierDismissible: false,
    barrierLabel: 'Dialog',
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, __, ___) {
      keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
      widgetInit();
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.black.withOpacity(0.6),
        body: GestureDetector(
            onTapDown: (_) => clearFocus(),
            child: SingleChildScrollView(
                child: Column(
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height/20.0,
                      ),

                      titlePadding("Barcode:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => clearFocus(),
                          child: editTextField(barcodeCtrl, barcodeFocus, '', keyboardHeight)
                      ),

                      titlePadding("Category:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => clearFocus(),
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 15.0, right: 15.0, top: 0, bottom: 5),
                            child: Card(
                              child: DropdownButton(
                                value: categoryValue,
                                isExpanded: true,
                                menuMaxHeight: MediaQuery.of(context).size.height / 2.0,
                                icon: const Icon(Icons.keyboard_arrow_down),
                                items: masterCategory.map((String items) {
                                  return DropdownMenuItem(
                                    value: items,
                                    child: Center(
                                        child: Text(items, textAlign: TextAlign.center,)
                                    ),
                                  );
                                }).toList(),

                                onChanged: (String? newValue) {
                                  categoryValue = newValue!;
                                  // setState(() {
                                  //   categoryValue = newValue!;
                                  // });
                                },
                              ),
                            ),
                          )
                      ),

                      titlePadding("Description:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => clearFocus(),
                          child: editTextField(descriptionCtrl, descriptionFocus, 'E.G. PETERS I/CREAM VAN 1L', keyboardHeight)
                      ),

                      titlePadding("UOM:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => clearFocus(),
                          child: editTextField(uomCtrl, uomFocus, 'EACH', keyboardHeight)
                      ),

                      titlePadding("Price:", TextAlign.left),
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: ListTile(
                              title: TextField(
                                scrollPadding:  EdgeInsets.symmetric(vertical: keyboardHeight),
                                controller: priceCtrl,
                                focusNode: priceFocus,
                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                onChanged: (value) {
                                },
                              ),
                            )
                        ),
                      ),

                      titlePadding("Location:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => clearFocus(),
                          child: editTextField(locationCtrl, locationFocus, '', keyboardHeight)
                      ),

                      titlePadding("Count:", TextAlign.left),
                      Padding(
                          padding: const EdgeInsets.only(
                              left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                              child: ListTile(
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    clearFocus();
                                    double count = double.parse(countCtrl.text) + 1;
                                    countCtrl.text = count.toString();
                                    // refresh(this);
                                  },
                                ),
                                title: TextField(
                                  scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight),
                                  controller: countCtrl,
                                  focusNode: countFocus,
                                  textAlign: TextAlign.center,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      signed: false, decimal: true),
                                ),
                                leading: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    clearFocus();
                                    double count = double.parse(countCtrl.text) - 1.0;
                                    countCtrl.text = max(count, 0.0).toString();
                                    // refresh(this);
                                  },
                                ),
                              )
                          )
                      ),

                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height / 10.0,
                      ),

                      rBox(
                          context,
                          colorOk,
                          TextButton(
                            child: Text('Confirm', style: whiteText),
                            onPressed: () {

                              confirmNOF();
                            },
                          )
                      ),

                      rBox(
                          context,
                          colorBack,
                          TextButton(
                            child: Text('Cancel', style: whiteText),
                            onPressed: (){
                              Navigator.pop(context);
                            },
                          )
                      ),
                    ]
                )
            )
        )
      );
      },
  ).then((value) {
    goToPage(context, const Stocktake(), false);
  });
}

// Static Table
class StaticTable extends StatelessWidget {
  final TableType tableType;

  const StaticTable({
    super.key,
    required this.tableType,
  });

  _exportColumns(BuildContext context, double width){
    return <DataColumn>[
      const DataColumn(label: Text('Index')),
      const DataColumn(label: Text('Category')),
      DataColumn(label: SizedBox(width: width * 0.5, child: const Text("Description"))),
      DataColumn(label: SizedBox(width: width * 0.3, child: const Text("UOM"))),
      const DataColumn(label: Text('QTY')),
      const DataColumn(label: Text('Cost Ex GST')),
      const DataColumn(label: Text('Barcode')),
      const DataColumn(label: Text('NOF'))
    ];
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
                              columns: _exportColumns(context, MediaQuery.of(context).size.width),
                              source: RowSource(),
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
                                        exportJobToXLSX();
                                        showAlert(context, "Job Export", "Stocktake exported: "'/storage/emulated/0/Documents/stocktake_${job.id}_[num].xlsx', Colors.orange);
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

// Get Table Rows
class RowSource extends DataTableSource {
  var dataList = job.literalList();

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList.length;

  @override
  int get selectedRowCount => 0; //(select == true && parent.selectIndex > -1) ? 1 :

  _exportCells(int index){
    return <DataCell>[
      DataCell(Text(dataList[index][0].toString())),
      DataCell(Text(dataList[index][2].toString())),
      DataCell(Text(dataList[index][3].toString())),
      DataCell(Text(dataList[index][4].toString())),
      DataCell(Text(dataList[index][6].toString())),
      DataCell(Text(dataList[index][5].toString())),
      DataCell(Text(dataList[index][1].toString())),
      DataCell(Text(dataList[index][8].toString())),
    ];
  }

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);
    if (index >= rowCount) {
      return null;
    }

    List<DataCell> dataCells = _exportCells(index);

    // if(type == TableType.search){
    //   List<int> showCells = [];
    //   showCells = [3, 4];
    //
    //   // Sort cells in order of [showCells]
    //   if (showCells.isNotEmpty) {
    //     List<DataCell> dc = [];
    //     for (int i = 0; i < showCells.length; i++) {
    //       int cell = showCells[i];
    //       if (cell < dataCells.length) {
    //         dc.add(dataCells[cell]);
    //       }
    //     }
    //     dataCells = dc;
    //   }
    // }

    // Select and highlight rows
    return DataRow.byIndex(
      index: index,
      selected: false, // (select == true) ? index == parent.selectIndex : false,
      cells: dataCells,

      // onSelectChanged: (value) {
      //   if (select == true) {
      //     int selectIndex = parent.selectIndex != index ? index : -1;
      //     parent.setIndex(selectIndex);
      //     notifyListeners();
      //   }
      // },
    );
  }
}

refresh(var widget) {
  widget.setState(() {});
}

shortFilePath(String s) {
  var sp = s.split("/");
  return sp[sp.length - 1];
}

Map<String, dynamic> rowToItem(List<dynamic> row, double count){
  return
    {
      "index" : row[0],
      "barcode" : row[1].toString(),
      "category" : row[2].toString(),
      "description" : row[3].toString(),
      "uom" : row[4].toString(),
      "price" : row[5],
      "count" : count,
      "location" : job.location,
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

Widget headerPadding(String title, TextAlign l){
  return Padding(
    padding: const EdgeInsets.all(15.0),
    child: Text(
        title,
        textAlign: l,
        style: const TextStyle(color: Colors.blue, fontSize: 20.0)),
  );
}

Widget titlePadding(String title, TextAlign l){
  return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: DefaultTextStyle(
        style: blueText,
        child: Text(title, textAlign: l),
      )
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

rBox(BuildContext context, Color c, Widget w) {
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

loadingAlert(BuildContext context) {
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

Widget editTextField(TextEditingController txtCtrl, FocusNode focus, String hint, double keyHeight){
  return Padding(
      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
      child: Card(
        child: ListTile(
          title: TextField(
            decoration: hint.isNotEmpty ? InputDecoration(hintText: hint, border: InputBorder.none) : null,
            controller: txtCtrl,
            scrollPadding: EdgeInsets.symmetric(vertical: keyHeight),
            focusNode: focus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.name,
            onChanged: (value) {
              txtCtrl.value = TextEditingValue(text: value.toUpperCase(), selection: txtCtrl.selection);
            },
          ),
        ),
      )
  );
}

// READ/WRITE OPERATIONS
Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<void> _prepareStorage() async {
  var path = '/storage/emulated/0';//!isEmulating ? '/storage/emulated/0' : 'sdcard';
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

Future<void> loadMasterSheet() async {
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

exportJobToXLSX() async {
  List<dynamic> finalSheet = job.getFinalSheet();
  var excel = Excel.createExcel();
  var sheetObject = excel['Sheet1'];
  sheetObject.isRTL = false;

  // Add header row
  sheetObject.insertRowIterables(["Master Index", "Category", "Description", "UOM", 'QTY', "Cost Ex GST", "Barcode", "NOF"], 0);

  for(int i = 0; i < finalSheet.length; i++){
    List<String> dataList = [];
    for(int j = 0; j < finalSheet[i].length; j++){
      dataList.add(finalSheet[i][j].toString());
    }
    sheetObject.insertRowIterables(dataList, i+1);
  }

  // Set column widths
  sheetObject.setColWidth(0, 15.0);
  sheetObject.setColWidth(1, 25.0);
  sheetObject.setColWidth(2, 75.0);
  sheetObject.setColWidth(3, 25.0);
  sheetObject.setColWidth(4, 15.0);
  sheetObject.setColWidth(5, 25.0);
  sheetObject.setColWidth(6, 25.0);
  sheetObject.setColWidth(7, 15.0);

  String filePath = "/storage/emulated/0/Documents/stocktake_${job.id}_0.xlsx";
  int num = 0;

  bool readyWrite = false;
  while(!readyWrite){
    await File(filePath).exists().then((value){
      if(value){
        num += 1;
        filePath = '/storage/emulated/0/Documents/stocktake_${job.id}_$num.xlsx';
      }
      else{
        readyWrite = true;
      }
    });
  }

  var fileBytes = excel.save();
  File(filePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(fileBytes!);
}

writeJob(StockJob job, bool overwrite) async {
  var filePath = '/storage/emulated/0/Documents/';

  // If "/Documents" folder does not exist, create it.
  await Directory(filePath).exists().then((value){
    if(!value){
      Directory('/storage/emulated/0/Documents/').create().then((Directory directory) {
        //mPrint("Documents dir was created: ${directory.path}");
      });
    }
  });

  //String date = job.date.replaceAll("_", "");
  //filePath += 'job_${job.id}_${job.name}_$date';

  filePath = '/storage/emulated/0/Documents/$jobStartStr${job.id}_0';
  //mPrint(filePath);

  if(!overwrite){
    String num = '0';
    bool readyWrite = false;

    while(!readyWrite){
      await File(filePath).exists().then((value){
        if(value){
          num = (int.parse(num) + 1).toString();
          filePath = '/storage/emulated/0/Documents/$jobStartStr${job.id}_$num';
        }
        else{
          readyWrite = true;
        }
      });
    }
  }

  var jobFile = File(filePath);
  Map<String, dynamic> jMap = job.toJson();
  var jString = jsonEncode(jMap);
  jobFile.writeAsString(jString);

  // if(!jobList.contains(filePath)){
  //   jobList.add(filePath);
  // }
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
