/*
   This script was programmed by Callum Jack Buchanan.
   Any derivatives of this work must include or mention my name in the final build as part of the copyright agreement below.
   This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
   To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.

   This program is distributed WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart';
import 'stock_job.dart';

bool isEmulating = true; // DEBUG VARS
Permission storageType = Permission.manageExternalStorage;

StockJob job = StockJob(id: "EMPTY", name: "EMPTY");
Directory? rootDir;
Map<String, dynamic> sFile = {};
String dbPath = '';
SpreadsheetTable? mainTable;
List<String> jobList = [];

enum TableType { literal, linear, export, full, search}
enum ActionType {edit, add, addNOF, view}

/*========
  main
========*/
void main() {
  runApp(
    const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomePage()
    ),
  );
}

/*=============
  Home Page
=============*/
class HomePage extends StatefulWidget{
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePage();
}
class _HomePage extends State<HomePage> {
  late String defSheet;

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
          body: SingleChildScrollView(
            child: Center(
              child: Column(
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 30.0),
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
                              mPrint("LOADING TABLE");
                              //isLoading = true;
                              loadingDialog(context, true);
                              // load default spreadsheet
                              await loadMasterSheet();
                            }

                            await getSession().then((value){
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const JobsPage()));
                            });
                          },
                        )
                    ),
                    rBox(
                        context,
                        Colors.blue,
                        TextButton(
                          child: const Text('Sync Master Database', style: TextStyle(color: Colors.white, fontSize: 20.0)),
                          onPressed: () async {
                            loadMasterSheet();

                            //goToPage(context, const LoadSpreadsheet(), false);
                          },
                        )
                    ),
                    rBox(
                        context,
                        colorEdit,
                        TextButton(
                          child: const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 20.0)),
                          onPressed: () async {

                            // Load default if not loaded
                            if(mainTable == null){
                              mPrint("LOADING TABLE");
                              loadingDialog(context, true);
                              await loadMasterSheet();
                            }

                            await getSession().then((value){
                              goToPage(context, const AppSettings(), false);
                            });
                            },
                        ),
                    ),
                  ]
              )
            )
          ),
            bottomSheet: SingleChildScrollView(
              child: Center(
                child: Platform.isIOS ? SizedBox(width: MediaQuery.sizeOf(context).width, height: 5.0) :
                rBox(
                    context,
                    colorBack,
                    TextButton(
                      child: const Text("Close App", style: TextStyle(color: Colors.white, fontSize: 20.0)),
                      onPressed: () async {
                        await writeSession().then((value){
                          mPrint("CLOSE APP: Probably shouldn't do this according to official documentation");
                          // SystemNavigator.pop();
                        });
                        },
                    ),
                ),
              ),
            )
        )
    );
  }
}

/*=================
  App Settings
=================*/
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
                      headerPadding('Storage Permission Type', TextAlign.left),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                            child: ListTile(
                              title: DropdownButton(
                                menuMaxHeight: MediaQuery.sizeOf(context).height/2.0,
                                value: storageType,
                                icon: const Icon(Icons.keyboard_arrow_down, textDirection: TextDirection.rtl,),
                                items: ([Permission.manageExternalStorage, Permission.storage]).map((index) {
                                  return DropdownMenuItem(
                                    value: index,
                                    child: Text(index.toString()),
                                  );
                                }).toList(),
                                onChanged: ((value) {
                                  storageType = value as Permission;
                                  refresh(this);
                                }),
                              ),
                            ),
                          )
                      ),
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
                      headerPadding("Load Spreadsheet From Storage", TextAlign.left),
                      Card(
                        child: ListTile(
                          title: mainTable == null ? Text( "NO SPREADSHEET DATA", style: warningText) : Text(shortFilePath(dbPath)),
                          subtitle: mainTable == null ? Text("Tap here to load a sheet...", style: warningText) : Text("Count: ${mainTable?.maxRows}"),
                          leading: mainTable == null ? const Icon(Icons.warning_amber, color: Colors.red) : const Icon(Icons.list_alt, color: Colors.green),
                          onTap: (){
                            goToPage(context, const LoadSpreadsheet(), false);
                          },
                        ),
                      ),
                    ],
                  )
              )
          ),

          bottomSheet: SingleChildScrollView(
            child: Center(
              child: mBox(
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
            ),
          )
        )
    );
  }
}

/*======================
  Load Spreadsheet
======================*/
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
    if(mainTable != null && dbPath.isNotEmpty){
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
    // Remove header and cell description rows
    mainTable!.rows.removeRange(0, 1);
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
                      mBox(
                          context,
                          loadSheet.isNotEmpty ? colorOk : colorDisable,
                          TextButton(
                            child: Text('LOAD SPREADSHEET', style: whiteText),
                            onPressed: () async{
                              if(loadSheet.isNotEmpty){
                                _loadSpreadsheet(loadSheet);
                                goToPage(context, const AppSettings(), true);
                              }
                            },
                          )
                      ),
                      mBox(
                          context,
                          colorEdit,
                          TextButton(
                            child: Text('LOAD MASTER SHEET', style: whiteText),
                            onPressed: () async{
                              loadMasterSheet();
                              goToPage(context, const AppSettings(), true);
                            },
                          )
                      ),
                      mBox(
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

/*===============
  Jobs Page
===============*/
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
      String newPath = path;
      bool copyJob = false;

      if(path.contains('sdcard')){
        if(!path.contains("sdcard/Documents")){
          newPath = 'sdcard/Documents/$str';
          copyJob = true;
        }
      }
      else if(!path.contains("storage/emulated/0/Documents")){
        newPath = 'storage/emulated/0/Documents/$str';
        copyJob = true;
      }

      // Copy and move job to default documents directory (if it isn't there already)
      if(copyJob){
        var jsn = File(path);
        String fileContent = await jsn.readAsString();
        var dynamic = json.decode(fileContent);
        var j = StockJob.fromJson(dynamic);
        writeJob(j);

        mPrint("Job file copied from [ $path ] to [ $newPath ]");
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
                                  writeSession(); //update session file

                                  String n = shortFilePath(jobList[index]);
                                  if("job_${job.id}_${job.name}" == n){
                                    goToPage(context, const OpenJob(), true);
                                  }
                                  else{
                                    await writeSession();
                                    await _readJob(jobList[index]).then((value) {
                                      goToPage(context, const OpenJob(), true);
                                    });
                                  }
                                  return;
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
                                mBox(
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
                                mBox(
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
                                          if(path.isEmpty){
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
                        mBox(
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

/*=================
  New Job
=================*/
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

  @override
  void initState() {
    super.initState();
    _clearFocus();
    _prepareStorage();
  }

  @override
  Widget build(BuildContext context) {
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
                                  controller: nameCtrl,
                                  focusNode: nameFocus,
                                  textAlign: TextAlign.left,
                                )
                            )
                        ),
                        SizedBox(
                            width: MediaQuery.sizeOf(context).width,
                            height: 10.0
                        ),

                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Text(
                              "NOTE:\n "
                              "* New Job files will automatically overwrite Job files with the same name.\n"
                              "* Job files located outside of '../Documents' directory will not be affected.",
                              textAlign: TextAlign.left,
                              style: warningText,
                          ),
                        )
                      ]
                  )
            )
          ),
          bottomSheet: GestureDetector(
              onTapDown: (_) => _clearFocus,
              child: SingleChildScrollView(
                  child: Center(
                      child: Column(children: [
                      mBox(
                          context,
                          colorOk,
                          TextButton(
                            child: Text('Create Job', style: whiteText),
                            onPressed: () async {
                              if(idCtrl.text.isEmpty){
                                showNotification(context, Colors.orange, whiteText, "!! ALERT", "\n* Job ID is empty: ${idCtrl.text.isEmpty}");
                                return;
                              }

                              newJob.id = idCtrl.text;
                              newJob.name = nameCtrl.text;
                              writeJob(newJob);

                              String path = "storage/emulated/0/Documents/job_${newJob.id}_${newJob.name}";
                              if(!jobList.contains(path)){
                                jobList.add(path);
                              }

                              showNotification(context, colorOk, whiteText, "Job Created", "* File name: job_${newJob.id}_${newJob.name} \n* Save path: storage/emulated/0/Documents/job_${newJob.id}_${newJob.name}");
                              job = newJob;
                              job.calcTotal();
                              goToPage(context, const OpenJob(), true);
                            },
                          )
                      ),
                      mBox(
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

/*==============
  Open Job
==============*/
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
                    title: Text(job.date),
                    leading: const Icon(Icons.date_range, color: Colors.blueGrey),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  height: MediaQuery.of(context).size.height/40.0,
                ),
                Center(
                    child: Column(
                        children: [
                          mBox(
                              context,
                              Colors.blue,
                              TextButton(
                                child: Text('Stocktake', style: whiteText),
                                onPressed: () {
                                  if(mainTable == null || mainTable!.rows.isEmpty){
                                    showAlert(context, "Alert", "* No spreadsheet data! \n* Press 'Sync with Server' to get latest MASTER SHEET. \n*You can also load a spreadsheet file from storage via the Settings page", colorOk);
                                     return;
                                  }
                                  goToPage(context, const Stocktake(), false);
                                },
                              )
                          ),
                          mBox(
                              context,
                              Colors.blue,
                              TextButton(
                                child: Text('Export Spreadsheet', style: whiteText),
                                onPressed: () {
                                  // goToPage(context, const StaticTable(dataList:job.getFinalSheet(), tableType: TableType.export), true);
                                  },
                              )
                          ),
                          mBox(
                              context,
                              Colors.green,
                              TextButton(
                                child: Text('Save Job', style: whiteText),
                                onPressed: () {
                                  writeJob(job);
                                  showNotification(context, colorOk, whiteText, "Job Saved", "* File name: job_${job.id}_${job.name} \n* Saved to: /storage/emulated/0/Documents/");
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
                mBox(
                    context,
                    colorBack,
                    TextButton(
                      child: Text('Close Job', style: whiteText),
                      onPressed: () {
                        writeJob(job);
                        goToPage(context, const JobsPage(), true);
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

/*====================
  Stocktake
====================*/
class Stocktake extends StatelessWidget{
  const Stocktake({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              centerTitle: true,
              title: Text("Stocktake - Total: ${job.total}", textAlign: TextAlign.center),
              automaticallyImplyLeading: false,
            ),
            body: Center(
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
                      mBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Scan Item', style: whiteText),
                            onPressed: () {
                              if (job.location.isNotEmpty) {
                                // goToPage(context, const ScanItem());
                              } else {
                                showAlert(context,
                                    "Alert",
                                    'User Action Error: \n* Create and set location before scanning.',
                                    Colors.red.withOpacity(0.8)
                                );
                              }
                            },
                          )
                      ),
                      mBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Search Item', style: whiteText),
                            onPressed: () {
                              if (job.location.isNotEmpty) {
                                goToPage(
                                    context,
                                    const DynamicTable(tableType: TableType.search, action: ActionType.add),
                                    true // animate
                                );
                              } else {
                                showAlert(context,
                                    "Alert",
                                    'User Action Error: \n* Create and set location before adding items.',
                                    Colors.red.withOpacity(0.8)
                                );
                              }
                            },
                          )
                      ),
                      mBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Add NOF', style: whiteText),
                            onPressed: () {
                              goToPage(context, StockItem(item: blankItem(true), action: ActionType.addNOF, index: -1,), false);
                            },
                          )
                      ),
                      mBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Edit Stocktake', style: whiteText),
                            onPressed: () {
                              goToPage(context, const DynamicTable(tableType: TableType.literal, action: ActionType.edit), true);
                            },
                          )
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height / 10.0,
                      ),
                    ]
                )
            ),
            bottomSheet: SingleChildScrollView(
                child: Center(
                    child: Column(
                        children: [
                          mBox(
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

/*==============
  Scan Item
==============*/
class ScanItem extends StatefulWidget{
  const ScanItem({super.key});

  @override
  State<ScanItem> createState() => _ScanItem();
}
class _ScanItem extends State<ScanItem>{
  bool camera = false;
  bool scanner = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          appBar: AppBar(
              centerTitle: true,
              automaticallyImplyLeading: false,
              title: const Text("Barcode Scanning", textAlign: TextAlign.center)
          ),
        )
    );
  }
}

/*==============
  Location
==============*/
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
                        trailing: IconButton(
                          icon: Icon(Icons.edit_note, color: Colors.yellow.shade800),
                          onPressed: () async {
                            var s = await textEditDialog(context, job.allLocations[index]);
                            job.allLocations[index] = s.toUpperCase();
                            refresh(this);
                          },
                        ),

                        // Remove location
                        onLongPress: () async {
                          bool b = await confirmDialog(context, "Delete location '${job.allLocations[index]}'?");
                          if(b){
                            job.allLocations.removeAt(index);
                            refresh(this);
                          }
                        },

                        // Set location
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
                  child: Column(children: [
                    mBox(
                        context,
                        Colors.lightBlue,
                        TextButton(
                          child: Text('Add Location', style: whiteText),
                          onPressed: () async {
                            var s = await textEditDialog(context, "");
                            if(s.isNotEmpty){
                              job.allLocations.add(s.toUpperCase());
                              refresh(this);
                            }
                          },
                        )
                    ),
                    mBox(
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

/*================
  StockItem
================*/
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
  List<String> uomList = ["EACH", "6 PACK", "12 PACK", "PER CARTON", "PER LITRE", "PER GALLON", "PER KG", "PER TONNE"];
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

  String locationValue = "LOCATION -1";
  String uomValue = "EACH";
  String categoryValue = "MISC";
  late bool isNof;

  _clearFocus(){
    barcodeFocus.unfocus();
    descriptionFocus.unfocus();
    priceFocus.unfocus();
    countFocus.unfocus();
    locationFocus.unfocus();
  }

  @override
  void initState() {
    super.initState();
    _clearFocus();
    barcodeCtrl.text = widget.item['barcode'].toString();
    categoryValue = widget.item['category'];
    descriptionCtrl.text = widget.item['description'];
    uomValue = widget.item['uom'].toString();
    priceCtrl.text = widget.item['price'].toString();
    countCtrl.text = widget.item['count'].toString();
    locationCtrl.text = widget.item['location'];
    isNof = widget.item['nof'];
  }

  bool get changed {
    return widget.item['barcode'] != barcodeCtrl.text &&
        widget.item['category'] != categoryValue &&
        widget.item['description'] != descriptionCtrl.text &&
        widget.item['uom'] != uomValue &&
        widget.item['price'] != double.parse(priceCtrl.text);
  }

  _editLocation(){
    return GestureDetector(
        onTapDown: (_) => _clearFocus(),
        child: Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
            child: Card(
              child: ListTile(
                title: TextField(
                  controller: locationCtrl,
                  focusNode: locationFocus,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.name,
                  onChanged: (String? value){
                    locationValue = locationCtrl.text;
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

  _addNOF(){
    var nofItem = {
      "index" : mainTable!.maxRows + job.nof.length,
      "barcode" : barcodeCtrl.text,
      "category" : categoryValue,
      "description" : descriptionCtrl.text.isEmpty ? "NO DESCRIPTION" : descriptionCtrl.text.toUpperCase(),
      "uom" : uomValue,
      "unit" : 1.0,
      "price" : double.parse(priceCtrl.text),
      "nof" : true,
    };

    if(job.newNOF(nofItem)){
      job.nof.add(nofItem);
    }

    if(double.parse(countCtrl.text) > 0){
      var item = {
        "index" : mainTable!.maxRows + job.nof.length,
        "barcode" : barcodeCtrl.text,
        "category" : categoryValue,
        "description" : descriptionCtrl.text.isEmpty ? "NO DESCRIPTION" : descriptionCtrl.text.toUpperCase(),
        "uom" : uomValue,
        "price" : double.parse(priceCtrl.text),
        "count" : double.parse(countCtrl.text),
        "location" : locationCtrl.text.toUpperCase(),
        "nof" : true,
      };

      job.literals.add(item);
      job.calcTotal();

      goToPage(context, const Stocktake(), true);
    }
  }

  _saveChanges() async {
    // check if item details were changed, create new nof
    //bool isNew = changed;

    var item = {
      "index" : isNof ? mainTable!.maxRows + job.nof.length : widget.item['index'],
      "barcode" : barcodeCtrl.text,
      "category" : categoryValue,
      "description" : descriptionCtrl.text.isEmpty ? "NO DESCRIPTION" : descriptionCtrl.text,
      "uom" : uomValue,
      "price" : double.parse(priceCtrl.text),
      "count" : double.parse(countCtrl.text),
      "location" : job.location,
      "nof" : isNof,
    };

    if(double.parse(countCtrl.text) >= 0){
      await confirmDialog(context, "Confirm changes to stock item?").then((bool value) async {
        if (value) {
          job.literals[widget.index] = item;
          job.calcTotal();
          showNotification(context, Colors.greenAccent, blackText, "", "Item at index [${widget.index}] was changed");
          goToPage(context, const DynamicTable(tableType: TableType.literal, action: ActionType.edit), false);
          // Ask to apply changes to other items with same index?
        }
      });
    }
  }

  List<Widget> _editItem(){
    var keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return <Widget>[
      headerPadding("Barcode:", TextAlign.left),
      Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
        child: Card(
            child: ListTile(
              title: TextField(
                scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight + 15),
                decoration: const InputDecoration(hintText: 'e.g 123456789', border: InputBorder.none),
                controller: barcodeCtrl,
                focusNode: barcodeFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            )
        ),
      ),

      headerPadding("Category:", TextAlign.left),
      GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
            child: Card(
              child: DropdownButton(
                value: categoryValue,
                isExpanded: true,
                menuMaxHeight: MediaQuery.sizeOf(context).height/2.0,
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
      ),

      headerPadding("Description:", TextAlign.left),
      Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
        child: Card(
            child: ListTile(
              title: TextField(
                scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight),
                decoration: const InputDecoration(hintText: 'E.g. PETERS I/CREAM VAN 1L', border: InputBorder.none),
                controller: descriptionCtrl,
                focusNode: descriptionFocus,
                keyboardType: TextInputType.name,
              ),
            )
        ),
      ),

      headerPadding("UOM:", TextAlign.left),
      GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: Padding(
            padding:
            const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
            child: Card(
              child: DropdownButton(
                value: uomValue,
                menuMaxHeight: MediaQuery.sizeOf(context).height/2.0,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: uomList.map((String items) {
                  return DropdownMenuItem(
                    value: items,
                    child: Center(
                        child: Text(items, textAlign: TextAlign.center,)
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  uomValue = newValue!;
                },
              ),
            ),
          )
      ),

      headerPadding("Price:", TextAlign.left),
      Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
        child: Card(
            child: ListTile(
              title: TextField(
                scrollPadding: const EdgeInsets.symmetric(vertical: 0), // EdgeInsets.symmetric(vertical: keyboardHeight),
                controller: priceCtrl,
                focusNode: priceFocus,
                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
              ),
            )
        ),
      ),

      headerPadding("Location:", TextAlign.left),
      _editLocation(),

      headerPadding("Count:", TextAlign.left),
      _editCount(),

      widget.action == ActionType.edit ? headerPadding("Not On File?", TextAlign.left) : Container(),
      widget.action == ActionType.edit ? Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
          child: Card(
              child: CheckboxListTile(
                value: isNof,
                title: const Text(""),
                onChanged: (value) {
                  isNof = value as bool;
                  refresh(this);
                },
              )
          )
      ) : Container(),

      widget.action == ActionType.edit ? SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 10.0,
      ) : Container(),

      widget.action == ActionType.edit ? GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: Center(
            child: mBox(
                context,
                colorWarning,
                TextButton(
                  child: Text('Delete Item', style: whiteText),
                  onPressed: () async {
                    _clearFocus();
                    await confirmDialog(context, "Remove Item from stock count?").then((bool value) async{
                      if(value){
                        int i = widget.index;
                        job.literals.removeAt(i);
                        job.calcTotal();
                        showNotification(context, colorOk, whiteText, "", "Item at [$i] was removed");
                        goToPage(context, const DynamicTable(tableType: TableType.literal, action: ActionType.edit), false);
                        // Navigator.pop(context, refresh(this));
                      }
                    });
                  },
                )
            ),
          )
      ) : Container(),

      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 10.0,
      ),

      GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: Center(
            child: mBox(
                context,
                colorOk,
                TextButton(
                    child: Text(widget.action == ActionType.edit ? 'Save Changes' : "Add NOF", style: whiteText),
                    onPressed: () async {
                      _clearFocus();

                      if(widget.action == ActionType.addNOF){
                        _addNOF();
                      }
                      else if (widget.action == ActionType.edit){
                        _saveChanges();
                      }
                    }
                )
            ),
          )
      ),
      _backBtn(),
    ];
  }

  List<Widget> _addItem(){
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
            child: mBox(
                context,
                colorOk,
                TextButton(
                    child: Text('Add Item', style: whiteText),
                    onPressed: () {

                      var item = {
                        "index" : widget.item['index'],
                        "barcode" : widget.item['barcode'],
                        "category" : widget.item['category'],
                        "description" : widget.item['description'],
                        "uom" : widget.item['uom'],
                        "price" : widget.item['price'],
                        "count" : double.parse(countCtrl.text),
                        "location" : locationCtrl.text,
                        "nof" : widget.item['nof'],
                      };

                      if( item['count'] <= 0){
                        showNotification(context, colorWarning, whiteText, "", "Count is zero (0), can't add zero items");
                        return;
                      }

                      job.literals.add(item);
                      job.calcTotal();

                      showNotification(context, colorOk, whiteText, "Item Added", "* ${item['description']} \n * Count: ${countCtrl.text}");
                      Navigator.pop(context);
                    }
                )
            ),
          )
      ),
      _backBtn(),
    ];
  }

  _backBtn(){
    return GestureDetector(
        onTapDown: (_) => _clearFocus(),
        child:Center(
            child: mBox(
              context,
              colorBack,
              TextButton(
                child: Text('Cancel', style: whiteText),
                onPressed: () async {
                  if(widget.action == ActionType.edit){
                    goToPage(context, const DynamicTable(tableType: TableType.literal, action: ActionType.edit), false);
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
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              centerTitle: true,
              title: const Text("Stock Item Details"),
              automaticallyImplyLeading: false,
            ),
            body: GestureDetector(
                onTapDown: (_) => _clearFocus(),
                child:SingleChildScrollView(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                          widget.action == ActionType.edit ? _editItem() :
                          widget.action == ActionType.addNOF ? _editItem() :
                          _addItem()
                          //widget.action == ActionType.add ? _addItem()
                          // widget.action == ActionType.view ? _viewItem()
                    )
                )
            )
        )
    );
  }
}

/*=======================
  Spreadsheet Static
=======================*/
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

  PaginatedDataTable get _table {
    return PaginatedDataTable(
      sortColumnIndex: 0,
      sortAscending: true,
      showCheckboxColumn: false,
      showFirstLastButtons: true,
      rowsPerPage: sFile["pageCount"],
      controller: ScrollController(),

      columns: getColumns(tableType),
      source: RowSource(parent: this, dataList: dataList, type: tableType),
    );
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
                            child: _table,
                          )
                      ),
                      Center(
                          child: Column(
                              children: [
                                tableType == TableType.export ?
                                mBox(
                                    context,
                                    Colors.blue,
                                    TextButton(
                                      child: Text('Export Spreadsheet', style: whiteText),
                                      onPressed: () async {
                                        exportJobToXLSX(job.getFinalSheet());
                                        showNotification(context, Colors.orange, whiteText, 'Exported Spreadsheet', '* Save Path: stocktake_${job.id}');
                                      },
                                    )
                                ) :  Container(),
                                mBox(
                                    context,
                                    colorBack,
                                    TextButton(
                                      child: Text("Back", style: whiteText),
                                      onPressed: () {
                                        Navigator.of(context).pop();

                                        // SystemNavigator.pop();
                                        // if(tableType == TableType.editItem || tableType == TableType.addItem){
                                        //   SystemNavigator.pop();
                                        //   //Navigator.pop(context);
                                        //   //goToPage(context, const Stocktake());
                                        // }
                                        // else{
                                        //   SystemNavigator.pop();
                                        //   //Navigator.pop(context);
                                        //   //goToPage(context, const OpenJob());
                                        // }
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

/*=======================
  Spreadsheet Dynamic
=======================*/
class DynamicTable extends StatefulWidget{
  final TableType tableType;
  final ActionType action;

  const DynamicTable({
    super.key,
    required this.tableType,
    required this.action,
  });

  @override
  State<DynamicTable> createState() => _DynamicTable();
}
class _DynamicTable extends State<DynamicTable>{
  late List<List<dynamic>> dataList;
  final tableKey = GlobalKey<PaginatedDataTableState>();
  TextEditingController searchCtrl = TextEditingController();
  var textFocus = FocusNode();
  List<List<dynamic>> filterList = [[]];
  var filters = [true, false, false];
  late int selectIndex;

  @override
  void initState() {
    super.initState();
    selectIndex = -1;
    getDataList();
  }

  getDataList(){
    if(widget.tableType == TableType.literal){
      dataList = job.literalList();
    }
    else if(widget.tableType == TableType.linear){
      dataList = job.linearList();
    }
    else if(widget.tableType == TableType.full){
      dataList = mainTable!.rows + job.nofList();
    }
    else if(widget.tableType == TableType.search){
      dataList = mainTable!.rows + job.nofList();
    }
    else{
      dataList = mainTable!.rows;
    }
    filterList = dataList;
  }

  setIndex(int selectIndex) {
    //masterIndex = filterList[listIndex][0]; // position of the item in the MainList
    this.selectIndex = selectIndex; // position of selection on screen
    mPrint("SELECT INDEX: $selectIndex");
    if(selectIndex != -1){
      mPrint(filterList[selectIndex].toString());
    }
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
              actions: widget.tableType == TableType.search ? [
                PopupMenuButton(
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem<int>(
                            value: 0,
                            child: Card(
                              child: ListTile(
                                title: const Text("Description"),
                                trailing: filters[0] ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                              ),
                            )
                        ),
                        PopupMenuItem<int>(
                            value: 1,
                            child: Card(
                              child: ListTile(
                                title: const Text("Category"),
                                trailing: filters[1] ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                              ),
                            )
                        ),
                        PopupMenuItem<int>(
                            value: 2,
                            child: Card(
                              child: ListTile(
                                title: const Text("Barcode"),
                                trailing: filters[2] ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                              ),
                            )
                        ),
                      ];
                    },
                    onSelected: (value) async {
                      textFocus.unfocus();
                      filters[value] = filters[value] ? false : true;
                      // Disable other filters if barcode filter is on
                      if(filters[2]){
                        filters[0] = false;
                        filters[1] = false;
                      }
                      // Description filter is on if all filters are disabled
                      if(!filters[0] && !filters[1] && !filters[2]) {
                        filters[0] = true;
                      }
                    }
                ),
              ] : null,
            ),

            body: GestureDetector(
                onTapDown: (_) => textFocus.unfocus(),
                child: Center(
                    child: Column(
                        children: [
                          widget.tableType == TableType.search ? Card(
                            child: ListTile(
                              leading: const Icon(Icons.search),
                              title: TextField(
                                  controller: searchCtrl,
                                  focusNode: textFocus,
                                  decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none),
                                  onChanged: (value) {
                                    String search = value.toUpperCase();
                                    tableKey.currentState?.pageTo(0);
                                    filterList = dataList.where((List<dynamic> item) =>
                                      (filters[0] && item[3].contains(search)) || (filters[1] && item[2].contains(search)) || (filters[2] && item[1].contains(search))).toList(growable: true);
                                    refresh(this);
                                  }
                              ),
                            ),
                          ) : Container(),
                          dataList.isNotEmpty ? Expanded(
                              child: SingleChildScrollView(
                                child: PaginatedDataTable(
                                  sortColumnIndex: 0,
                                  key: tableKey,
                                  sortAscending: true,
                                  showCheckboxColumn: false,
                                  showFirstLastButtons: true,
                                  rowsPerPage: sFile["pageCount"],
                                  controller: ScrollController(),
                                  columns: getColumns(widget.tableType),
                                  source: RowSource(parent: this, dataList: filterList, select: true, type: widget.tableType),
                                ),
                              )
                          ) : const Text("Spreadsheet is empty!", textAlign: TextAlign.center),
                          GestureDetector(
                              onTapDown: (_) => textFocus.unfocus(),
                              child: SingleChildScrollView(
                                  child: Center(
                                    child: Column(
                                        children: [
                                          widget.action == ActionType.edit || widget.action == ActionType.add ?
                                          mBox(
                                            context,
                                            selectIndex > -1 ? colorOk : colorDisable,
                                            TextButton(
                                              child: Text(widget.action == ActionType.edit ? 'EDIT ITEM' : 'ADD ITEM', style: whiteText),
                                                onPressed: () {
                                                  goToPage(context, StockItem(item: rowToItem(filterList[selectIndex], widget.tableType == TableType.literal), action: widget.action, index: selectIndex), false);
                                                }
                                            ),
                                          ) : Container(),
                                          mBox(context, colorBack, TextButton(
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

/*===========================
  SPREADSHEET FUNCTIONS
===========================*/
List<DataColumn> getColumns(TableType t) {
  List<int>? showColumn;
  List<DataColumn> dataColumns;

  if(t == TableType.literal) {
    dataColumns = <DataColumn>[
      const DataColumn(label: Text("Description")),
      const DataColumn(label: Text("Count")),
      const DataColumn(label: Text("UOM")),
      const DataColumn(label: Text("Location")),
      const DataColumn(label: Text("Barcode"))
      ];
  }
  else if(t == TableType.export) {
    dataColumns = <DataColumn>[
      const DataColumn(label: Text('Index')),
      const DataColumn(label: Text('Category')),
      const DataColumn(label: Text('Description')),
      const DataColumn(label: Text('UOM')),
      const DataColumn(label: Text('QTY')),
      const DataColumn(label: Text('Cost Ex GST')),
      const DataColumn(label: Text('Barcode')),
      const DataColumn(label: Text('NOF'))
    ];
  }
  else{
    dataColumns = <DataColumn>[
      const DataColumn(label: Text('Index')),
      const DataColumn(label: Text('Barcode')),
      const DataColumn(label: Text('Category')),
      const DataColumn(label: Text('Description')),
      const DataColumn(label: Text('UOM')),
      const DataColumn(label: Text('Price')),
    ];
  }

  if (t == TableType.search){
    showColumn = [3,4];
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
        const DataCell(Text("10.0")),
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

/*===================
  COLORS & STYLES
===================*/
Color colorOk = Colors.blue.shade400;
Color colorEdit = Colors.blueGrey;
Color colorWarning = Colors.deepPurple.shade200;
Color colorDisable = Colors.blue.shade200;
Color colorBack = Colors.redAccent;
TextStyle get warningText{ return TextStyle(color: Colors.red[900], fontSize: sFile["fontScale"]);}
TextStyle get whiteText{ return TextStyle(color: Colors.white, fontSize: sFile["fontScale"]);}
TextStyle get greyText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}
TextStyle get blackText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}

mPrint(var s) {
  // "Safely" prints something to terminal, otherwise IDE notifications chucks a sissy fit
  if (s == null) {
    return;
  }
  if (!kReleaseMode) {
    if (kDebugMode) {
      print(s.toString());
    }
  }
}

refresh(var widget) {
  widget.setState(() {});
}

shortFilePath(String s) {
  var sp = s.split("/");
  return sp[sp.length - 1];
}

/*=====================
  RE-USABLE WIDGETS
=====================*/
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

mBox(BuildContext context, Color c, Widget w){
  return Padding(
    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
    child: Container(
      height: 50,
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(color: c),
      child: w,
    ),
  );
}

rBox(BuildContext context, Color c, Widget w){
  return Padding(
    padding: const EdgeInsets.all(10.0),
    child: Container(
      height: 50,
      width: MediaQuery.sizeOf(context).width * 0.8,
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
      duration: const Duration(milliseconds: 2500),
      width: MediaQuery.sizeOf(context).width * 0.9, // Width of the SnackBar.
      padding: const EdgeInsets.all(15.0),  // Inner padding for SnackBar content.
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      //margin: const EdgeInsets.all(15.0),
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

loadingDialog(BuildContext context, bool loading) {
  loading ?
  showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
              children: [
                const CircularProgressIndicator(backgroundColor: Colors.white,),
                Container(
                    margin: const EdgeInsets.only(left: 10),
                    child: const Text("Loading...")),
              ]
          ),
        );
      }) : Container();
}

Future<String> textEditDialog(BuildContext context, String str) async{
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

  mPrint(newText);
  return newText;
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

/*=========================
  READ/WRITE OPERATIONS
=========================*/
Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<void> _prepareStorage() async {
  var path = isEmulating ? 'storage/emulated/0' : 'sdcard';
  rootDir = Directory(path);
  var storage = await storageType.status;
  if (storage != PermissionStatus.granted) {
    await storageType.request();
  }
  bool b = storage == PermissionStatus.granted;
  mPrint("STORAGE ACCESS IS : $b");
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

loadMasterSheet() async{
  // // Load Excel spreadsheet
  final path = await _localPath;
  var filename = 'MASTER_SHEET.xlsx'; // change to user defined -> show list of available books

  var sheets = [];
  if (File("$path/$filename").existsSync()) {
    File file = File("$path/$filename");
    var bytes = file.readAsBytesSync();
    var decoder = SpreadsheetDecoder.decodeBytes(bytes);
    sheets = decoder.tables.keys.toList();
    mainTable = decoder.tables[sheets[0]];

    // Remove first row as it contains header/title info
    mainTable!.rows.removeRange(0, 1);

    dbPath = "$path/$filename";
    mPrint(mainTable?.maxRows);
  }
  else{
    mPrint("NO SPREADSHEET");
  }
}

exportJobToXLSX( List<dynamic> fSheet) async{
  var path = isEmulating ? 'sdcard/Documents' : 'storage/emulated/0/Documents';
  var excel = Excel.createExcel();
  var sheetObject = excel['Sheet1'];
  sheetObject.isRTL = false;
  // Add header row
  sheetObject.insertRowIterables(["Index", "Category", "Description", "UOM", 'QTY', "Cost Ex GST", "GST RATE"], 0);
  for(int i = 0; i < fSheet.length; i++){
    List<String> dataList = [];
    for(int j = 0; j < fSheet[i].length; j++){
      dataList.add(fSheet[i][j].toString());
    }
    dataList.add("10"); //GST is always 10
    sheetObject.insertRowIterables(dataList, i+1);
  }
  var fileBytes = excel.save();
  File("$path/stocktake_${job.id}.xlsx")
    ..createSync(recursive: true)
    ..writeAsBytesSync(fileBytes!);
}

writeJob(StockJob job) async {
  var filePath = isEmulating ? 'sdcard/Documents/' : 'storage/emulated/0/Documents/';
  //String dateString = job.date.replaceAll("/", "");
  filePath += 'job_${job.id}_${job.name}'; //_$dateString

  mPrint(filePath);

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
    "location" : job.location,
    "nof" : false,
  };
}

Map<String, dynamic> blankItem(bool nof){
  return {
    "index" : 0,
    "barcode" : 0,
    "category" : "MISC",
    "description" : "",
    "uom" : "EACH",
    "price" : 0.0,
    "count" : 0.0,
    "location" : job.location,
    "nof" : true,
  };
}

/* ZJunk
*/
