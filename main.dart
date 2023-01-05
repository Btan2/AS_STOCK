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

Permission storageType = Permission.manageExternalStorage;
StockJob currentJob = StockJob(id: "EMPTY", name: "EMPTY");
Directory? rootDir;
Map<String, dynamic> sFile = {};
List<StockItem> spreadsheet = [];
String jobDir = '';
bool isEmulating = true;
enum TableType { literal, linear, export, full, addItem, editItem}

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
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          // appBar: AppBar(
          //   centerTitle: true,
          //   title: const Text('Home'),
          //   automaticallyImplyLeading: false,
          // ),
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
                            await getSession().then((value)
                            {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const JobsPage()));
                            });
                              // use animation for login -> home

                              //if(value == true){
                                //showNotification(context, Colors.orange, const TextStyle(color: Colors.black, fontSize: 18.0), "NEW SESSION FILE CREATED AND SAVED TO LOCAL APP DIR", "");
                              //}
                            //});
                            },
                        )
                    ),
                    rBox(
                        context,
                        colorEdit,
                        TextButton(
                          child: const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 20.0)),
                          onPressed: ()  {
                            getSession();
                            goToPage(context, const AppSettings());
                            //showNotification(context, Colors.orange, const TextStyle(color: Colors.black, fontSize: 18.0), "NEW SESSION FILE CREATED AND SAVED TO LOCAL APP DIR", "");
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
                        await writeSession().then((value){SystemNavigator.pop();});
                        },
                    ),
                ),
              ),
            )
          // bottomNavigationBar: BottomNavigationBarItem(
          //   color: Colors.transparent,
          //   elevation: 0,
          //   child: Platform.isIOS ? SizedBox(width: MediaQuery.sizeOf(context).width, height: 5.0) :
          //       Padding(
          //         padding: const EdgeInsets.all(10.0),
          //         child: Container(
          //           height: 50,
          //           width: MediaQuery.sizeOf(context).width * 0.4,
          //           decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
          //           child: TextButton(
          //             child: const Text('Close App', style: TextStyle(color: Colors.white, fontSize: 20.0)),
          //             onPressed: () async {
          //               await writeSession().then((value){SystemNavigator.pop();});
          //               },
          //           ),
          //         ),
          //       )
          // ),
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
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            resizeToAvoidBottomInset: false, // Don't resize bottom elements if screen changes

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
                      headerPadding("Device is Emulator", TextAlign.left),
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: ListTile(
                                title: Checkbox(
                                  value: isEmulating,
                                  onChanged: ((value){
                                    isEmulating = value as bool;
                                    refresh(this);
                                  }
                                  ),
                                )
                            )
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
                    onPressed: () {
                      writeSession();
                      goToPage(context, const HomePage());
                    },
                  )
              ),
            ),
          )
        )
    );
  }
}

/*=============
  Jobs Page
=============*/
class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
  });
  @override
  State<JobsPage> createState() => _JobsPage();
}
class _JobsPage extends State<JobsPage> {
  List<String> jobList = [];
  bool access = false;

  @override
  void initState() {
    super.initState();
    _prepareStorage();
    _access();
    _listFiles();
    jobDir = '';
  }

  _access() async{
   access = await storageType.isGranted;
  }

  _fileAdd(String dir) {
    var spt = dir.split("/");
    String str = spt[spt.length - 1];
    if (str.startsWith("job_")) {
      if(!sFile["dirs"].contains(dir)){
        sFile["dirs"].add(dir);
      }
    }
    refresh(this);
  }

  _dirAdd(String dir) async{
    if(await Directory(dir).exists()){
      var list = Directory(dir).listSync();
      for (int i = 0; i < list.length; i++) {
        // get filename at the end
        var spt = list[i].toString().split("/");
        String str = spt[spt.length - 1];
        // check if directory contains job files
        if (str.startsWith("job_")) {
          if(!sFile["dirs"].contains(dir)){
            sFile["dirs"].add(dir);
            break;
          }
        }
      }
    }
    refresh(this);
  }

  // doesn't delete file
  _removeJob(int i){
    jobList.removeAt(i);
  }

  _listFiles() async {
    // if(sFile["dirs"] is String){
    //   return;
    // }

    jobList.clear();
    var fileSplit = [];
    String fileString = "";

    // Go through job file directory(s) stored in session_file
    for(String s in sFile["dirs"]){
      // get string at the end of path
      fileSplit = s.split("/");
      fileString = fileSplit[fileSplit.length - 1];
      if (fileString.startsWith("job_")) {
        if(await File(s).exists()){
          if(!_duplicateFile(fileString)){
            //var jobFile = File(s);
            jobList.add(s);
          }
        }
      }
      else{
        // string points to a directory containing job files, so scan for job files
        if(await Directory(s).exists()){
          var list = Directory(s).listSync();
          for (int i = 0; i < list.length; i++) {
            fileSplit = list[i].toString().split("/");
            fileString = fileSplit[fileSplit.length - 1];
            if (fileString.startsWith("job_")) {
              if(!_duplicateFile(fileString)){
                jobList.add(list[i].toString());
              }
            }
          }
        }
      }
    }

    refresh(this);
  }

  bool _duplicateFile(String fileString) {
    var pathSplit = [];
    String checkString = "";

    for(int j = 0; j < jobList.length; j++) {
      pathSplit = (jobList[j].toString()).split("/");
      checkString = pathSplit[pathSplit.length - 1];
      if (checkString == fileString){
        return true;
      }
    }
    return false;
  }

  String _shorten(String s) {
    var sp = s.split("/");
    String str = sp[sp.length - 1];
    return str.substring(0, str.length - 1);
  }

  _readJob(String path) async {
    var jsn = File(path);
    String fileContent = await jsn.readAsString(); //await
    var dynamic = json.decode(fileContent);
    currentJob = StockJob.fromJson(dynamic);
    currentJob.calcTotal();
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
          ),
          body: SingleChildScrollView(
              child: Center(
                  child: Column(
                    children: [
                      headerPadding("Available Jobs:", TextAlign.left),
                      Column(
                          children: List.generate(jobList.length, (index) => Card(
                            child: ListTile(
                              title: Text(_shorten(jobList[index].toString())),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_forever_sharp), // doesn't delete forever
                                color: Colors.redAccent,
                                onPressed: () {
                                  _removeJob(index);
                                  refresh(this);
                                },
                              ),
                              onTap: () async {
                                if(access) {
                                  writeSession();
                                  String n = _shorten(jobList[index]);
                                  if("job_${currentJob.id}" == n){
                                    goToPage(context, const OpenJob());
                                  }
                                  else{
                                    await _readJob(jobList[index]).then((value) {
                                      jobDir = jobList[index];
                                      goToPage(context, const OpenJob());
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
                                        goToPage(context, const NewJob());
                                      },
                                    )
                                ),
                                mBox(
                                    context,
                                    Colors.blue[800]!,
                                    TextButton(
                                      child: Text('Scan Directory', style: whiteText),
                                      onPressed: () async{
                                        if(access) {
                                          String path = await pickDir(context);
                                          _dirAdd(path);
                                          _listFiles();
                                        }
                                        else{
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
                                ),
                                mBox(
                                    context,
                                    Colors.blue[800]!,
                                    TextButton(
                                      child: Text('Load from Storage', style: whiteText),
                                      onPressed: () async{
                                        if(access){
                                          String path = await pickFile(context);
                                          _fileAdd(path);
                                          _listFiles();
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
                                spreadsheet.clear();
                                currentJob = StockJob(id: "EMPTY", name: "EMPTY");
                                goToPage(context, const HomePage());
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

/*================
  New Job
================*/
class NewJob extends StatefulWidget {
  const NewJob({
    super.key,
  });

  @override
  State<NewJob> createState() => _NewJob();
}
class _NewJob extends State<NewJob> {
  StockJob newJob = StockJob(id: "NULL", name: "EMPTY");
  String savePath = "";
  bool overwriteJob = false;

  @override
  void initState() {
    super.initState();
    _prepareStorage();
  }

  Future<bool> _checkFile(File checkFile) async {
    bool confirmWrite = false;
    await checkFile.exists().then((value) {
      showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.blue.withOpacity(0.8),
          builder: (context) => AlertDialog(
              title: const Text("Warning!"),
              content: SingleChildScrollView(
                  child: Column(
                      children: [
                        headerPadding('* Job file [${newJob.id}] already exists!\n\n* Confirm overwrite?', TextAlign.left),
                        Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 5, bottom: 5),
                          child: Text('** WARNING: DETECTED JOB FILE WILL BE DELETED IF "YES" **', textAlign: TextAlign.left, style: TextStyle(color: colorWarning, fontSize: 20)),
                        ),
                        mBox(
                            context,
                            colorOk,
                            TextButton(
                              child: Text('Yes', style: whiteText),
                              onPressed: () {
                                confirmWrite = true;
                                Navigator.pop(context);
                                refresh(this);
                              },
                            )
                        ),
                        mBox(
                            context,
                            colorBack,
                            TextButton(
                              child: Text('No', style: whiteText),
                              onPressed: () {
                                confirmWrite = false;
                                Navigator.pop(context);
                                refresh(this);
                              },
                            )
                        ),
                      ]
                  )
              )
          )
      );
    });
    return confirmWrite;
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
            // leading: IconButton(
            //   icon: const Icon(Icons.arrow_back),
            //   onPressed: () {
            //     goToPage(context, const JobsPage());
            //   },
            // ),
          ),
          body: SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerPadding("Job Id:", TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: TextFormField(
                              textAlign: TextAlign.left,
                              onChanged: (value) {
                                newJob.id = value;
                                refresh(this);
                              },
                            )
                        )
                    ),
                    headerPadding("Job Name:", TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: TextFormField(
                              textAlign: TextAlign.left,
                              onChanged: (value) {
                                newJob.name = value;
                                refresh(this);
                              },
                            )
                        )
                    ),
                    headerPadding("Save Location:", TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: ListTile(
                                leading: newJob.dbPath == "" ? const Icon(Icons.question_mark) : null,
                                title: Text(savePath, textAlign: TextAlign.left),
                                onTap: () async {
                                  savePath = await pickDir(context);
                                  refresh(this);
                                },
                            )
                        )
                    ),
                  ]
              )
          ),
          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(children: [
                    mBox(
                        context,
                        colorOk,
                        TextButton(
                          child: Text('Create Job', style: whiteText),
                          onPressed: () async {
                            if(savePath.isEmpty){
                              showNotification(context, Colors.orange, whiteText, "!! ALERT", "* Job was not created \n* Save path is empty");
                              return;
                            }
                            // Check if job already exists
                            var f = File('$savePath/job_${newJob.id}');
                            await _checkFile(f).then((value){
                              if(value == true){
                                writeJob(newJob, '$savePath/job_${newJob.id}');
                                // Add new job to session file
                                if(!sFile["dirs"].contains(savePath)){
                                  sFile["dirs"].add(savePath);
                                }
                                showNotification(context, colorOk, whiteText, "Job Create", "* File name: job_${newJob.id} \n* Save path: $savePath/job_${newJob.id}");
                                goToPage(context, const JobsPage());
                              }
                            });
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
                            goToPage(context, const JobsPage());
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

/*===========
  Open Job
============*/
class OpenJob extends StatelessWidget {
  const OpenJob({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Job -> ${currentJob.id.toString()}", textAlign: TextAlign.center),
          automaticallyImplyLeading: false,
          actions: [
            PopupMenuButton(
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem<TableType>(
                      value: TableType.literal,
                      child: Text("Literal Spreadsheet"),
                    ),
                    const PopupMenuItem<TableType>(
                      value: TableType.linear,
                      child: Text("Linear Spreadsheet"),
                    ),
                    const PopupMenuItem<TableType>(
                      value: TableType.export,
                      child: Text("Export Spreadsheet"),
                    ),
                    const PopupMenuItem<TableType>(
                      value: TableType.full,
                      child: Text("Full Spreadsheet"),
                    ),
                  ];
                },
                onSelected: (value) async {
                  goToPage(context, StaticTable(tableType: value));
                }
            ),
          ],
        ),

        body: SingleChildScrollView(
          child: Column(
              children: [
                Card(
                  child: ListTile(
                    title: Text(currentJob.date),
                    leading: const Icon(Icons.date_range, color: Colors.blueGrey),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  height: MediaQuery.of(context).size.height/40.0,
                ),
                Card(
                  child: ListTile(
                    title: currentJob.dbPath.isEmpty?
                      Text( "NO SPREADSHEET DATA", style: warningText) : Text(shortFilePath(currentJob.dbPath)),
                    subtitle: currentJob.dbPath.isEmpty || spreadsheet.isEmpty ?
                      Text("Tap here to load a sheet...", style: warningText) : Text("Count: ${spreadsheet.length}"),
                    leading: currentJob.dbPath.isEmpty || spreadsheet.isEmpty?
                      const Icon(Icons.warning_amber, color: Colors.red) : const Icon(Icons.list_alt, color: Colors.green),
                    onTap: (){
                      goToPage(context, const LoadSpreadsheet());
                    },
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height/20.0,
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
                                  if(currentJob.dbPath.isEmpty || spreadsheet.isEmpty){
                                    showNotification(context, Colors.red, whiteText, "!! ALERT !!", "* No spreadsheet data! \n* Tap 'Spreadsheet:' to load file.");
                                    return;
                                  }
                                  goToPage(context, const Stocktake());
                                },
                              )
                          ),
                          mBox(
                              context,
                              Colors.blue,
                              TextButton(
                                child: Text('Export Spreadsheet', style: whiteText),
                                onPressed: () {
                                  goToPage(context, const StaticTable(tableType: TableType.export));
                                  },
                              )
                          ),
                          mBox(
                              context,
                              Colors.green,
                              TextButton(
                                child: Text('Save Job', style: whiteText),
                                onPressed: () {
                                  writeJob(currentJob, jobDir);
                                  showNotification(context, colorOk, whiteText, "Job Saved", "* File name: job_${currentJob.id} \n* Save path: $jobDir");
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
                        writeJob(currentJob, jobDir);
                        goToPage(context, const JobsPage());
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

/*============
  Scan Item
============*/
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

/*====================
  Load Spreadsheet
====================*/
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
    _getSheets(currentJob.dbPath);
  }

  _getSheets(String path) {
    if (path.isNotEmpty && File(path).existsSync()) {
      File file = File(path);
      var bytes = file.readAsBytesSync();
      var decoder = SpreadsheetDecoder.decodeBytes(bytes);
      sheets = decoder.tables.keys.toList();
      refresh(this);
    }
  }

  Future<void> loadDatabase(String sheetName) async {
    File file = File(currentJob.dbPath);
    var bytes = file.readAsBytesSync();
    var decoder = SpreadsheetDecoder.decodeBytes(bytes);

    var sheet = decoder.tables[sheetName];

    spreadsheet.clear();

    // N.B. Ignore first two rows as they contain header info
    for(int i = 2; i < sheet!.rows.length; i++){
      await Future.delayed(const Duration(microseconds: 0));
      refresh(this);

      var cell = sheet.rows[i];

      spreadsheet.add(StockItem(
        index: spreadsheet.length,
        barcode: cell[1].toString().trim().toUpperCase(),
        category: cell[2].toString().trim().toUpperCase(),
        description: trimDescription(cell[3].toString().trim().toUpperCase()),
        uom: cell[4].toString().trim().toUpperCase(),
        price: double.parse(cell[5].toString()),
        nof: false,
      ));
    }
    //mPrint("MAIN BD: ${spreadsheet.length}");
  }

  trimDescription(String s){
    s = s.replaceAll("    ", " ");
    s = s.replaceAll("   ", " ");
    s = s.replaceAll("  ", " ");
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(

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
                          leading: currentJob.dbPath == "" ? const Icon(Icons.question_mark) : null,
                          title: Text(shortFilePath(currentJob.dbPath), textAlign: TextAlign.left),
                          onTap: () async {
                            await pickSpreadsheet(context).then((value){
                              currentJob.dbPath = value;
                              _getSheets(currentJob.dbPath);
                            });
                          }
                          ),
                    ),
                    headerPadding("Available Sheets:", TextAlign.left),
                    Column(
                        children: List.generate(sheets.length, (index) => Card(
                              child: ListTile(
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
                                loadingDialog(context);
                                await loadDatabase(loadSheet).then((value){
                                  goToPage(context, const OpenJob());
                                });
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
                              goToPage(context, const OpenJob());
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

/*==================
  Stocktake
==================*/
class Stocktake extends StatelessWidget{
  const Stocktake({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text("Stocktake - Total: ${currentJob.getTotal()}", textAlign: TextAlign.center),
              automaticallyImplyLeading: false,
            ),
            body: Center(
                child: Column(
                    children: [
                      headerPadding("Current Location:", TextAlign.left),
                      Card(
                        child: ListTile(
                          title: currentJob.location.isEmpty ?
                            Text("Tap to select a location...", style: greyText) :
                            Text(currentJob.location, textAlign: TextAlign.center),
                          leading: currentJob.location.isEmpty ? const Icon(Icons.warning_amber, color: Colors.red) : null,
                          onTap: () {
                            goToPage(context, const Location());
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
                              if (currentJob.location.isNotEmpty && currentJob.dbPath.isNotEmpty) {
                                //selectIndex = -1;
                                // goToPage(context, const ScanItem());
                              } else {
                                showAlert(context,
                                    "Alert",
                                    'User Action Error:'
                                        '${currentJob.location.isEmpty ? '\n* Create and set location before scanning.' : ''}'
                                        '${currentJob.dbPath.isEmpty ? '\n* Spreadsheet file path is empty; need spreadsheet for item lookup.' : ''}'
                                        '${spreadsheet.isEmpty ? '\n* Sheet has not been selected; select sheet when loading Spreadsheet.' : ''}'
                                        "\n* Possible other reasons.",
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
                              if (currentJob.location.isNotEmpty && currentJob.dbPath.isNotEmpty) {
                                // selectIndex = -1;
                                goToPage(context, DynamicTable(dataList: spreadsheet + currentJob.nof, tableType: TableType.addItem, searchBar: true));
                              } else {
                                showAlert(context,
                                    "Alert",
                                    'User Action Error:'
                                        '${currentJob.location.isEmpty ? '\n* Create and set location before scanning.' : ''}'
                                        '${currentJob.dbPath.isEmpty ? '\n* Database is empty; need spreadsheet for item lookup.' : ''}'
                                        "\n* Possible other reasons.",
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
                              if (currentJob.location.isNotEmpty && currentJob.dbPath.isNotEmpty) {
                                goToPage(context, const AddNOF());
                              }
                              },
                          )
                      ),
                      mBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('Edit Stocktake', style: whiteText),
                            onPressed: () {
                              goToPage(context, DynamicTable(dataList: currentJob.literal, tableType: TableType.editItem, searchBar: false,));
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
                                  goToPage(context, const OpenJob());
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

/*=================
  Location
==================*/
class Location extends StatelessWidget {
  const Location({super.key});

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
                  children: currentJob.allLocations.isNotEmpty ? List.generate(
                      currentJob.allLocations.length,
                          (index) => Card(
                          child: ListTile(
                            trailing: currentJob.allLocations[index] == currentJob.location ? const Icon(Icons.arrow_back, color: Colors.green) : null,
                            title: Text(currentJob.allLocations[index], textAlign: TextAlign.justify),
                            onTap: () {
                              currentJob.setLocation(index);
                              goToPage(context, const Stocktake());
                            },
                          )
                      )
                  ) : [
                    Card(
                        child: ListTile(
                          title: Text("No locations, create a new location...", style: greyText, textAlign: TextAlign.justify),
                        )
                    )
                  ],
                ),
              ]
              )
          ),
          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(children: [
                    mBox(
                        context,
                        Colors.lightBlue,
                        TextButton(
                          child: Text('Add Location', style: whiteText),
                          onPressed: () {
                            TextEditingController textCtrl = TextEditingController();
                            showDialog(context: context,
                              barrierDismissible: false,
                              barrierColor: colorOk.withOpacity(0.8),
                              builder: (context) => AlertDialog(
                                actionsAlignment: MainAxisAlignment.spaceAround,
                                title: const Text("Add Location"),
                                content: Card(
                                    child: ListTile(
                                      title: TextField(
                                        autofocus: true,
                                        decoration: const InputDecoration(hintText: 'Enter location name ', border: InputBorder.none),
                                        controller: textCtrl,
                                        keyboardType: TextInputType.name,
                                        onSubmitted: (value) {
                                          // Add string to currentJob location list
                                          if (value.isNotEmpty) {
                                            currentJob.addLocation(value.toUpperCase());
                                          }
                                          textCtrl.clear();
                                          //refresh(this);
                                          Navigator.pop(context);
                                        },
                                      ),
                                    )
                                ),
                                actions: <Widget>[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                                    onPressed: () {
                                      textCtrl.clear();
                                      refresh(this);
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                                    onPressed: () {
                                      if (textCtrl.text.isNotEmpty) {
                                        currentJob.addLocation(textCtrl.text.toUpperCase());
                                      }
                                      textCtrl.clear();
                                      //refresh(this);
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Add"),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                    ),
                    mBox(
                        context,
                        colorBack,
                        TextButton(
                          child: Text('Back', style: whiteText),
                          onPressed: () {
                            goToPage(context, const Stocktake());
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
  Add NOF
================*/
class AddNOF extends StatefulWidget {
  const AddNOF({super.key});

  @override
  State<AddNOF> createState() => _AddNOF();
}
class _AddNOF extends State<AddNOF> {
  List<String> uomList = ["EACH", "6 PACK", "12 PACK", "PER CARTON", "PER LITRE", "PER GALLON", "PER KG", "PER TONNE"];
  TextEditingController barcodeCtrl = TextEditingController();
  TextEditingController descriptionCtrl = TextEditingController();
  TextEditingController priceCtrl = TextEditingController();
  TextEditingController addCtrl = TextEditingController();
  String uomValue = "EACH";
  String categoryValue = "MISC";

  @override
  void initState() {
    super.initState();
    uomValue = uomList[0];
    categoryValue = masterCategory[0];
    addCtrl.text = "0.0";
    priceCtrl.text = "0.0";
  }

  @override
  Widget build(BuildContext context) {
    var keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            centerTitle: true,
            title: const Text("Add NOF"),
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerPadding("Barcode:", TextAlign.left),
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                      child: Card(
                        child: ListTile(
                          title: TextField(
                            scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight + 15),
                            decoration: const InputDecoration(hintText: 'NON_DUPLICATES', border: InputBorder.none),
                            controller: barcodeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        )
                      ),
                    ),
                    headerPadding("Category:", TextAlign.left),
                    Padding(
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
                                  child: Text(
                                    items,
                                    textAlign: TextAlign.center,
                                  )
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              categoryValue = newValue!;
                            });
                          },
                        ),
                      ),
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
                            keyboardType: TextInputType.name,
                          ),
                        )
                      ),
                    ),
                    headerPadding("UOM:", TextAlign.left),
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
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
                    ),
                    headerPadding("Price:", TextAlign.left),
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                      child: Card(
                          child: ListTile(
                            title: TextField(
                              scrollPadding: const EdgeInsets.symmetric(vertical: 0), // EdgeInsets.symmetric(vertical: keyboardHeight),
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                            ),
                          )
                      ),
                    ),
                    headerPadding("Add Count:", TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: ListTile(
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  double count = double.parse(addCtrl.text) + 1;
                                  addCtrl.text = count.toString();
                                  refresh(this);
                                },
                              ),
                              title: TextField(
                                controller: addCtrl,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                              ),
                              leading: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  double count = double.parse(addCtrl.text) - 1.0;
                                  addCtrl.text = max(count, 0).toString();
                                  refresh(this);
                                },
                              ),
                            )
                        )
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height / 10.0,
                    ),
                    Center(
                      child: mBox(
                          context,
                          colorOk,
                          TextButton(
                            child: Text('Add NOF', style: whiteText),
                            onPressed: () async {
                              if (barcodeCtrl.text.isNotEmpty && descriptionCtrl.text.isNotEmpty) {
                                StockItem nof = StockItem(
                                    index: spreadsheet.length + currentJob.nof.length,
                                    barcode: barcodeCtrl.text,
                                    category: categoryValue,
                                    description: descriptionCtrl.text,
                                    uom: uomValue,
                                    price: double.parse(priceCtrl.text),
                                    nof: true
                                );
                                if (currentJob.addNOF(nof)) {
                                  double count = double.parse(addCtrl.text);
                                  if (count > 0) {
                                    currentJob.addLiteral(nof, count);
                                  }
                                  await showAlert(
                                      context,
                                      "NOF Added",
                                      "\n* Barcode: ${nof.barcode}\n* Description: ${nof.description}\n* Added to stock: $count",
                                      Colors.blue.withOpacity(0.8)
                                  ).then((value) {
                                    goToPage(context, const Stocktake());
                                  });
                                }
                                else {
                                  await showAlert(
                                      context,
                                      "Error!",
                                      "DUPLICATE BARCODE: \n* Item already exists.\n* Go to 'Search Item' page and find the NOF.\n* Barcode scanning should automatically find the NOF",
                                      Colors.red.withOpacity(0.8)
                                  ).then((value) {
                                    goToPage(context, const Stocktake());
                                  }
                                  );
                                }
                              }
                              else {
                                await showAlert(
                                    context,
                                    'Error!',
                                    'NOF IS INCOMPLETE:\n* Make sure all text fields contain info.',
                                    Colors.blue.withOpacity(0.8)
                                );
                              }
                            },
                          )
                      ),
                    ),
                    Center(
                        child: mBox(
                          context,
                          colorBack,
                          TextButton(
                            child: Text('Cancel', style: whiteText),
                            onPressed: () async {
                              goToPage(context, const Stocktake());
                            },
                          ),
                        )
                    )
                  ]
              )
          ),
        )
    );
  }
}

/*======================
  Spreadsheet Static
======================*/
class StaticTable extends StatelessWidget {
  final TableType tableType;

  const StaticTable({
    super.key,
    required this.tableType,
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
      columns: tableType == TableType.literal ? const [
        DataColumn(label: Text("Description")),
        DataColumn(label: Text("Count")),
        DataColumn(label: Text("UOM")),
        DataColumn(label: Text("Location")),
        DataColumn(label: Text("Barcode")),
      ] : tableType == TableType.export ? const [
        DataColumn(label: Text('Index')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('UOM')),
        DataColumn(label: Text('QTY')),
        DataColumn(label: Text('Cost Ex GST')),
        DataColumn(label: Text('GST RATE')),
      ] : getColumns([]),
      source: tableType == TableType.linear ? RowSource(parent: this, dataList: currentJob.getList()) :
      tableType == TableType.literal ? RowLiterals(parent: this, dataList: currentJob.literal) :
      tableType == TableType.export ?  RowExport(parent: this, dataList: currentJob.getFinalSheet()) :
      RowSource(parent: this, dataList: spreadsheet + currentJob.nof),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text("Spreadsheet View: ${currentJob.id}", textAlign: TextAlign.center),
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
                                tableType != TableType.export ? Container() :
                                mBox(
                                    context,
                                    Colors.blue,
                                    TextButton(
                                      child: Text('Export Spreadsheet', style: whiteText),
                                      onPressed: () async {
                                        await pickDir(context).then((value){
                                          exportJobToXLSX(currentJob.getFinalSheet(), value);
                                          showNotification(context, Colors.orange, whiteText, 'Exported Spreadsheet', '* Save Path: stocktake_${currentJob.id}');
                                        });
                                      },
                                    )
                                ),
                                mBox(
                                    context,
                                    colorBack,
                                    TextButton(
                                      child: Text("Back", style: whiteText),
                                      onPressed: () {
                                        if(tableType == TableType.editItem || tableType == TableType.addItem){
                                          goToPage(context, const Stocktake());
                                        }
                                        else{
                                          goToPage(context, const OpenJob());
                                        }
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
  final bool searchBar;
  final List dataList;
  const DynamicTable({
    super.key,
    required this.tableType,
    required this.searchBar,
    required this.dataList,
  });

  @override
  State<DynamicTable> createState() => _DynamicTable();
}
class _DynamicTable extends State<DynamicTable>{
  TextEditingController searchCtrl = TextEditingController();
  TextEditingController addCtrl = TextEditingController();
  final tableKey = GlobalKey<PaginatedDataTableState>();
  late int listIndex;
  late int selectIndex;
  List filterList = [];

  @override
  void initState() {
    super.initState();
    _clearInput();

    if(widget.searchBar){
      filterList = widget.dataList;
    }
  }

  getIndex() {
    return selectIndex;
  }

  setIndex(int listIndex, int selectIndex) {
    this.listIndex = listIndex; // position of item in the table list
    this.selectIndex = selectIndex; // position of selection on screen

    mPrint("SELECT INDEX: $selectIndex");
    mPrint("LIST INDEX: $listIndex");

    // if (selectIndex != -1) {
    //   if(widget.tableType == TableType.literal){
    //     mPrint(currentJob.literal[selectIndex].description);
    //   }
    //   if (widget.tableType == TableType.search){
    //     mPrint(fullList[selectIndex].description);
    //   }
    // }

    refresh(this);
  }

  _clearInput(){
    addCtrl.text = "0";
    searchCtrl.clear();
    selectIndex = -1;
    selectIndex = -1;
    listIndex = -1;
  }

  actionEdit() {
    return mBox(
        context,
        selectIndex > -1 ? colorOk : colorDisable,
        TextButton(
          child: Text('EDIT ITEM', style: whiteText),
          onPressed: () {
            if (selectIndex > -1) {
              showDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.blue.withOpacity(0.8),
                builder: (context) => AlertDialog(
                  actionsAlignment: MainAxisAlignment.spaceAround,
                  title: const Text("Edit Item"),
                  content: SingleChildScrollView(
                      child: Column(
                        children: [
                          Card(child: ListTile(title: Text("Table Index: $selectIndex")),),
                          Card(child: ListTile(title: Text("Barcode: ${widget.dataList[selectIndex].barcode}")),),
                          Card(child: ListTile(title: Text("Description: ${widget.dataList[selectIndex].description}")),),
                          Card(child: ListTile(title: Text("UOM: ${widget.dataList[selectIndex].uom}")),),
                          Card(child: ListTile(title: Text(selectIndex >= 0 ? "Count: ${currentJob.literal[selectIndex].count}" : "Count: null_something_gone_wrong")),),
                          Card(child: ListTile(title: Text("NOF: ${currentJob.literal[selectIndex].nof}")),),
                          SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height / 10.0,
                          ),
                          headerPadding("Remove Count", TextAlign.left),
                          Padding(
                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                              child: Card(
                                  child: ListTile(
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () {
                                        double count = double.parse(addCtrl.text) + 1;
                                        addCtrl.text = count.toString();
                                      },
                                    ),
                                    title: TextField(
                                      controller: addCtrl,
                                      textAlign: TextAlign.center,
                                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                    ),
                                    leading: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () {
                                        double count = double.parse(addCtrl.text) - 1;
                                        addCtrl.text = max(count, 0).toString();

                                      },
                                    ),
                                  )
                              )
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height / 10.0,
                          ),
                        ],
                      )
                  ),
                  actions: [
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                        child: const Text("Cancel"),
                        onPressed: () {
                          _clearInput();
                          refresh(this);
                          Navigator.pop(context);
                        }
                    ),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                        child: const Text("Confirm"),
                        onPressed: () async{
                          double remove = double.parse(addCtrl.text);
                          currentJob.removeLiteral(selectIndex, remove);
                          _clearInput();
                          refresh(this);
                          Navigator.pop(context);
                        }
                    ),
                  ],
                ),
              );
            }
          },
        )
    );
  }

  actionAdd(){
    return mBox(
        context,
        selectIndex > -1 ? Colors.blue : Colors.grey,
        TextButton(
          child: Text("ADD ITEM", style: whiteText),
          onPressed: () {
            if (selectIndex > -1) {
              showDialog(
                barrierDismissible: false,
                context: context,
                barrierColor: Colors.blue.withOpacity(0.8),
                builder: (context) => AlertDialog(
                  actionsAlignment: MainAxisAlignment.spaceAround,
                  content: SingleChildScrollView(
                    child: Column(
                      children: [
                        Card(child: Text("Barcode: ${widget.dataList[selectIndex].barcode}")),
                        Card(child: Text(widget.dataList[selectIndex].description)),
                        headerPadding("Add Count", TextAlign.left),
                        Padding(
                            padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                            child: Card(
                               child: ListTile(
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () {
                                      double count = double.parse(addCtrl.text) + 1;
                                      addCtrl.text = count.toString();
                                      refresh(this);
                                    },
                                  ),
                                  title: TextField(
                                    controller: addCtrl,
                                    textAlign: TextAlign.center,
                                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                  ),
                                  leading: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () {
                                      double count = double.parse(addCtrl.text) - 1;
                                      addCtrl.text = max(count, 0).toString();
                                      refresh(this);
                                    },
                                  ),
                                )
                            )
                        ),
                      ]
                    )
                  ),
                  actions: [
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                        child: const Text("Cancel"),
                        onPressed: () {
                          _clearInput();
                          refresh(this);
                          Navigator.pop(context);
                        }
                    ),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                        child: const Text("Confirm"),
                        onPressed: () {
                          double count = double.parse(addCtrl.text);
                          currentJob.addLiteral(filterList[selectIndex], count);
                          String s = filterList[selectIndex].description;
                          if (s.length > 12) {
                            s = s.substring(0, 12);
                          }
                          showNotification(context, colorOk, whiteText, "Stock Added", "* $s \n* Count: $count");
                          _clearInput();
                          refresh(this);
                          Navigator.pop(context);
                        }
                    ),
                  ],
                ),
              );
            }
            refresh(this);
          },
        )
    );
  }

  searchBar(){
    return Card(
      child: ListTile(
        leading: const Icon(Icons.search),
        title: TextField(
            controller: searchCtrl,
            decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none),
            onChanged: (value) {
              String search = value.toUpperCase();
              tableKey.currentState?.pageTo(0);
              filterList = widget.dataList.where((item) => item.description.contains(search) || item.barcode.toString().contains(search)).toList();
              refresh(this);
            }
        ),
      ),
    );
  }

  PaginatedDataTable get _table {
    return PaginatedDataTable(
        sortColumnIndex: 0,
        sortAscending: true,
        showCheckboxColumn: false,
        showFirstLastButtons: true,
        rowsPerPage: sFile["pageCount"],
        controller: ScrollController(),
        columns:
          widget.tableType == TableType.addItem ? getColumns([3, 4]) :
          widget.tableType == TableType.editItem ? const [
            DataColumn(label: Text("Description")),
            DataColumn(label: Text("Count")),
            DataColumn(label: Text("UOM")),
            DataColumn(label: Text("Location")),
            DataColumn(label: Text("Barcode"))] : getColumns([]),
        source:
          widget.tableType == TableType.addItem ? RowSource(parent: this, dataList: filterList, showCells: [3, 4], select: true) :
          widget.tableType == TableType.editItem ? RowLiterals(parent: this, dataList: currentJob.literal, select: true) :
          RowSource(parent: this, dataList: widget.dataList),

      //   widget.tableType == TableType.search ? getColumns([3, 4]) :
      //   widget.tableType == TableType.export ? const[
      //   DataColumn(label: Text('Index')),
      //   DataColumn(label: Text('Category')),
      //   DataColumn(label: Text('Description')),
      //   DataColumn(label: Text('UOM')),
      //   DataColumn(label: Text('QTY')),
      //   DataColumn(label: Text('Cost Ex GST')),
      //   DataColumn(label: Text('GST RATE'))] :
      //   getColumns([]),

      //widget.tableType == TableType.literal ? RowLiterals(parent: this, dataList: currentJob.literal, select: true) :
      //widget.tableType == TableType.linear ? RowSource(parent: this, dataList: currentJob.getList()) :
      //widget.tableType == TableType.export ? RowExport(parent: this, dataList: currentJob.getFinalSheet()) :

      //widget.tableType == TableType.search ? RowSource(parent: this, dataList: filterList, showCells: [3, 4], select: true) :
      //RowSource(parent: this, dataList: itemList),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text("Spreadsheet View: ${currentJob.id}", textAlign: TextAlign.center),
              automaticallyImplyLeading: false,
            ),
            body: Center(
                child: Column(
                    children: [
                      widget.searchBar ? searchBar() : Container(),
                      Expanded(
                          child: SingleChildScrollView(
                            child: _table,
                          )
                      ),
                      Center(
                          child: Column(
                              children: [
                                widget.tableType == TableType.editItem ? actionEdit() :
                                widget.tableType == TableType.addItem ? actionAdd() :
                                Container(),
                                mBox(context, colorBack, TextButton(
                                  child: Text("Back", style: whiteText),
                                  onPressed: () {
                                    if(widget.tableType == TableType.editItem || widget.tableType == TableType.addItem){
                                      goToPage(context, const Stocktake());
                                    }
                                    else{
                                      goToPage(context, const OpenJob());
                                    }
                                    },
                                )),
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

/*=========================
  SPREADSHEET FUNCTIONS
===========================*/
List<DataColumn> getColumns(List<int>? showColumn) {
  // [showColumn] defines which columns should be returned; an empty list will show every column of the table.
  // Returns columns in order of the [showColumn] e.g. [3, 1, 2] will show 3rd column first, 1st column second and so on.

  List<DataColumn> dataColumns = <DataColumn>[
    const DataColumn(label: Text('Index')),
    const DataColumn(label: Text('Barcode')),
    const DataColumn(label: Text('Category')),
    const DataColumn(label: Text('Description')),
    const DataColumn(label: Text('UOM')),
    const DataColumn(label: Text('Price')),
  ];

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

class RowExport extends DataTableSource{
  List? dataList = [];
  dynamic parent;
  bool? select = false;

  RowExport({
    required this.dataList,
    required this.parent,
    this.select
  });

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if (index >= rowCount) {
      return null;
    }

    mPrint(dataList![index].toString());
    List sub = dataList![index] as List;

    return DataRow.byIndex(
        index: index,
        selected: (select == true) ? index == parent.getIndex() : false,
        onSelectChanged: (value) {
          if(select == true){
            int selectIndex = parent.getIndex() != index ? index : -1;
            int listIndex = selectIndex > -1 ? dataList![selectIndex].index : -1;
            notifyListeners();
            parent.setIndex(listIndex, selectIndex);
          }
        },

        cells: <DataCell>[
          DataCell(Text(sub[0].toString())),
          DataCell(Text(sub[1].toString())),
          DataCell(Text(sub[2].toString())),
          DataCell(Text(sub[3].toString())),
          DataCell(Text(sub[4].toString())),
          DataCell(Text(sub[5].toString())),
          const DataCell(Text("10.0")),
        ]
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList!.length;
  @override
  int get selectedRowCount => (select == true && parent.getIndex() > -1) ? 1 : 0;
}
class RowLiterals extends DataTableSource {
  List dataList;
  dynamic parent;
  bool? select = false;

  RowLiterals({
    required this.dataList,
    required this.parent,
    this.select
  });

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if (index >= rowCount) {
      return null;
    }

    return DataRow.byIndex(
      index: index,
      selected: (select == true) ? index == parent.getIndex() : false,

      onSelectChanged: (value) {
        if(select == true){
          int selectIndex = parent.getIndex() != index ? index : -1;
          int listIndex = selectIndex > -1 ? dataList[selectIndex].index : -1;
          notifyListeners();
          parent.setIndex(listIndex, selectIndex);
        }
      },

      cells: <DataCell>[
        DataCell(Text(dataList[index].description)),
        DataCell(Text(dataList[index].count.toString())),
        DataCell(Text(dataList[index].uom)),
        DataCell(Text(dataList[index].location)),
        DataCell(Text(dataList[index].barcode.toString())),
      ],

    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList.length;
  @override
  int get selectedRowCount => (select == true && parent.getIndex() > -1) ? 1 : 0;
}
class RowSource extends DataTableSource {
  List dataList;
  List<int>? showCells; // hide/show specific cells
  bool? select = false;
  dynamic parent;

  RowSource({
    required this.parent,
    required this.dataList,
    this.showCells,
    this.select
  });

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if (index >= rowCount) {
      return null;
    }

    List<DataCell> dataCells = <DataCell>[
      DataCell(Text(dataList[index].index.toString())),
      DataCell(Text(dataList[index].barcode.toString())),
      DataCell(Text(dataList[index].category)),
      DataCell(Text(dataList[index].description)),
      DataCell(Text(dataList[index].uom)),
      DataCell(Text(dataList[index].price.toString())),
    ];

    // Create list of cells in order of [showCells]
    if (showCells != null && showCells!.isNotEmpty) {
      List<DataCell> dc = [];
      for (int i = 0; i < showCells!.length; i++) {
        int cell = showCells![i];
        if (cell < dataCells.length) {
          dc.add(dataCells[cell]);
        }
      }

      dataCells = dc;
    }

    return DataRow.byIndex(
      index: index,
      selected: (select == true) ? index == parent.getIndex() : false,
      onSelectChanged: (value) {
        if (select == true) {
          int selectIndex = parent.getIndex() != index ? index : -1;
          int listIndex = selectIndex != -1 ? dataList[selectIndex].index : -1;
          notifyListeners();
          parent.setIndex(listIndex, selectIndex);
        }
      },
      cells: dataCells,
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList.length;
  @override
  int get selectedRowCount => (select == true && parent.getIndex() > -1) ? 1 : 0;
}

/*===================
  COLORS & STYLES
===================*/
Color colorOk = Colors.blue.shade400;
Color colorEdit = Colors.blueGrey;
Color colorWarning = Colors.deepPurple.shade200;
Color colorDisable = Colors.blue.shade200;
Color colorBack = Colors.redAccent;
// Color colorBack = Colors.grey.shade600;
// const double fontHeader = 20.0;

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

goToPage(BuildContext context, Widget page) {
  // Jump to page with no animation
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
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
      //width: MediaQuery.sizeOf(context).width, // Width of the SnackBar.
      padding: const EdgeInsets.all(15.0),  // Inner padding for SnackBar content.
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      margin: const EdgeInsets.all(15.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    )
  );
}

showAlert(BuildContext context, String txtTitle, String txtContent, Color c) {
  return showDialog(
    //barrierDismissible: false,
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

loadingDialog(BuildContext context) {
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
      });
}

/*=========================
  READ/WRITE OPERATIONS
=========================*/
Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<void> _prepareStorage() async {
  rootDir = Directory('/storage/emulated/0/');
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

Future<String> pickDir(BuildContext context) async {
  String val = "";
  await FilesystemPicker.open(
    title: rootDir.toString(),
    context: context,
    rootDirectory: rootDir!,
    fsType: FilesystemType.folder,
    fileTileSelectMode: FileTileSelectMode.wholeTile,
    pickText: 'Use this folder',
    folderIconColor: Colors.teal,
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

exportJobToXLSX( List<dynamic> fSheet, String outDir) async{
  if(outDir.isEmpty){
    return false;
  }
  var path = outDir;
  if(isEmulating){
    path = path.replaceAll('storage/emulated/0', 'sdcard');
  }
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
  File("$path/stocktake_${currentJob.id}.xlsx")
    ..createSync(recursive: true)
    ..writeAsBytesSync(fileBytes!);
}

writeJob(StockJob job, String path) async {
  var filePath = path;
  if(isEmulating){
    filePath = filePath.replaceAll('storage/emulated/0', 'sdcard');
  }
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
      "uid" : jsn['uid'] as String,
      "pageCount" : jsn['pageCount'] as int,
      "fontScale" : jsn['fontScale'] as double,
      "dropScale" : jsn['dropScale'] as double
    };
    return false;
  }
}

//region ++ zJUNK ++
/*


//==============
//  Login Page
//==============
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Login', textAlign: TextAlign.center),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 60.0),
              child: Center(
                child: SizedBox(
                  width: 470,
                  height: 200,
                  child: Image(image: AssetImage('assets/AS_Logo2.png')),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: TextField(
                decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Email',
                    hintText: 'Enter valid email id as user_name@email_client.com'
                ),
              ),
            ),
            const Padding(
              padding:
              EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
              child: TextField(
                obscureText: true,
                decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Password',
                    hintText: 'Enter secure password'
                ),
              ),
            ),
            // TextButton(
            //   child: const Text('Forgot Password', style: TextStyle(color: Colors.blue, fontSize: 15)),
            //   onPressed: () {
            //     mPrint('FORGOT PASSWORD LINK');
            //   },
            // ),
            Container(
              height: 50,
              width: 250,
              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
              child: TextButton(
                child: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 25)),
                onPressed: () async {
                  await getSession().then((value){
                    // use animation for login -> home
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
                    if(value == true){
                      showNotification(context, Colors.orange, const TextStyle(color: Colors.black, fontSize: 18.0), "NEW SESSION FILE CREATED AND SAVED TO LOCAL APP DIR", "");
                    }
                  });
                },
              ),
            ),
            // const SizedBox(height: 130),
            // const Text('Serving Australian businesses for over 30 years!', style: TextStyle(color: Colors.blueGrey))
          ],
        ),
      ),
    );
  }
}
onPressed: () {
  TextEditingController textCtrl = TextEditingController();
  showDialog(context: context,
    barrierDismissible: false,
    barrierColor: colorOk.withOpacity(0.8),
    builder: (context) => AlertDialog(
      actionsAlignment: MainAxisAlignment.spaceAround,
      title: const Text("Add Location"),
      content: Card(
          child: ListTile(
            title: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Enter location name ', border: InputBorder.none),
              controller: textCtrl,
              keyboardType: TextInputType.name,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  currentJob.addLocation(value.toUpperCase());
                }
                textCtrl.clear();
                Navigator.pop(context);
              },
            ),
          )
      ),
      actions: <Widget>[
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: colorBack),
          onPressed: () {
            textCtrl.clear();
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: colorOk),
          onPressed: () {
            if (textCtrl.text.isNotEmpty) {
              currentJob.addLocation(textCtrl.text.toUpperCase());
            }
            textCtrl.clear();
            Navigator.pop(context);
          },
          child: const Text("Add"),
        ),
      ],
    ),
  );
},
 */
//endregion
