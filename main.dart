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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart';

import 'stock_job.dart';

List<StockItem> spreadsheet = [];
StockJob currentJob = StockJob(id: "EMPTY", name: "EMPTY");
SessionFile sFile = SessionFile();

Permission storageType = Permission.storage;
Directory? rootDir;
String jobDir = '';
bool isEmulating = true;


/*
===================
  main
===================
*/
void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage()),
  );
}

/*
===================
  Login Page
===================
*/
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
                    hintText:
                    'Enter valid email id as user_name@email_client.com'),
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
                    hintText: 'Enter secure password'),
              ),
            ),
            TextButton(
              child: const Text('Forgot Password',
                  style: TextStyle(color: Colors.blue, fontSize: 15)),
              onPressed: () {
                mPrint('FORGOT PASSWORD LINK');
              },
            ),
            Container(
              height: 50,
              width: 250,
              decoration: BoxDecoration(
                  color: Colors.blue, borderRadius: BorderRadius.circular(20)),
              child: TextButton(
                child: const Text('Login',
                    style: TextStyle(color: Colors.white, fontSize: 25)),
                onPressed: () async {
                  await readSession().then((value){
                    // use animation for login -> home
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));

                    if(value == true){
                      ScaffoldMessenger.of(context).showSnackBar(
                          showNotification(Text('NEW SESSION FILE WRITTEN TO APP DIR', style: textStyle(Colors.black, fontTitle), textAlign: TextAlign.center), Colors.orange)
                      );
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 130),
            const Text('Serving Australian businesses for over 30 years!',
                style: TextStyle(color: Colors.blueGrey))
          ],
        ),
      ),
    );
  }
}

/*
==================
  Home Page
==================
*/
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Home'),
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            child: Center(
              child: Column(children: <Widget>[
                mButton(
                    context,
                    Colors.blue,
                    TextButton(
                      child: Text('Jobs', style: textStyle(Colors.white, fontButton)),
                      onPressed: () {
                        goToPage(context, const JobsPage());
                      },
                    )),
                mButton(
                    context,
                    colorBack,
                    TextButton(
                      child: Text('App Settings', style: textStyle(Colors.white, fontButton)),
                      onPressed: () async {
                        goToPage(context, const AppSettings());
                      },
                    )),
              ]),
            ),
          ),
          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(children: [
                    mButton(context,
                        colorWarning,
                        TextButton(
                          child: Text('Logout', style: textStyle(Colors.white, fontButton)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
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

/*
==================
  Settings Page
==================
*/
class AppSettings extends StatefulWidget{
  const AppSettings({ super.key, });
  @override
  State<AppSettings> createState() => _AppSettingsState();
}
class _AppSettingsState extends State<AppSettings> {
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

                      const Padding(
                        padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                        child: Text(
                            "Storage Permission Type",
                            textAlign: TextAlign.left,
                            style: TextStyle(color: Colors.blue, fontSize: 16)),
                      ),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                            child: ListTile(
                              title: DropdownButton(
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

                      const Padding(
                        padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                        child: Text(
                            'Rows per Page',
                            textAlign: TextAlign.left,
                            style: TextStyle(color: Colors.blue, fontSize: 16)),
                      ),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                              child: ListTile(
                                title: Text(sFile.pageCount.toString(), textAlign: TextAlign.center,),
                                leading: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    sFile.pageCount = (sFile.pageCount - 1) % 30;
                                    refresh(this);
                                  },
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    sFile.pageCount = (sFile.pageCount + 1) % 30;
                                    refresh(this);
                                  },
                                ),
                              )
                          )
                      ),

                      const Padding(
                        padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                        child: Text(
                            'Emulator Mode',
                            textAlign: TextAlign.left,
                            style: TextStyle(color: Colors.blue, fontSize: 16)),
                      ),
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
              child: mButton(
                  context,
                  colorWarning,
                  TextButton(
                    child: Text('Back', style: textStyle(Colors.white, fontBody)),
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

/*
==================
  Jobs Page
==================
*/
class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
  });

  @override
  State<JobsPage> createState() => _JobsState();
}
class _JobsState extends State<JobsPage> {
  List jobList = [];

  @override
  void initState() {
    super.initState();
    _prepareStorage();
    _listFiles();
    jobDir = '';
  }

  // Add single job file to session dirs
  _singleAdd(String dir) {
    var spt = dir.split("/");
    String str = spt[spt.length - 1];

    if (str.startsWith("job_")) {
      if(!sFile.dirs.contains(dir)){
        sFile.dirs.add(dir);
      }
    }

    refresh(this);
  }

  // Add job file directory to session dirs
  _dirAdd(String dir) {
    var list = Directory(dir).listSync();
    for (int i = 0; i < list.length; i++) {

      // get filename at the end
      var spt = list[i].toString().split("/");
      String str = spt[spt.length - 1];

      // check if directory contains job files
      if (str.startsWith("job_")) {
        if(!sFile.dirs.contains(dir)){
          sFile.dirs.add(dir);
          break;
        }
      }
    }

    refresh(this);
  }

  // doesn't delete file
  _removeJob(int i){
    jobList.removeAt(i);
  }

  // Get list of job files
  _listFiles() async {
    jobList.clear();

    var fileSplit = [];
    String fileString = "";

    // Go through job file directory(s) stored in session_file
    for(String s in sFile.dirs){
      // get string at the end of path
      fileSplit = s.split("/");
      fileString = fileSplit[fileSplit.length - 1];

      // get name at the end of the file path
      if (fileString.startsWith("job_")) {
        if(await File(s).exists()){
          if(!_duplicateFile(fileString)){
            var jobFile = File(s);
            jobList.add(jobFile);
          }
        }
      }
      else{
        // string points to a directory containing job files, so scan for job files
        var list = Directory(s).listSync();
        for (int i = 0; i < list.length; i++) {

          // get name at the end of the file path
          fileSplit = list[i].toString().split("/");
          fileString = fileSplit[fileSplit.length - 1];

          if (fileString.startsWith("job_")) {
            if(!_duplicateFile(fileString)){
              jobList.add(list[i]);
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

  _readJob(dynamic jsn) async {
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
          resizeToAvoidBottomInset: false, // Don't resize bottom elements if screen changes

          appBar: AppBar(
            centerTitle: true,
            title: const Text('Jobs'),
            automaticallyImplyLeading: false,
          ),

          body: SingleChildScrollView(
              child: Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: 10.0,
                      ),
                      Column(
                          children: List.generate(jobList.length, (index) => Card(
                            child: ListTile(
                              title: Text(_shorten(jobList[index].toString())),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_forever_sharp), // doesn't delete forever
                                color: Colors.red[300],
                                onPressed: () {
                                  _removeJob(index);
                                  refresh(this);
                                },
                              ),
                              onTap: () async {

                                writeSession();
                                String n = _shorten(jobList[index].toString());

                                if("job_${currentJob.id}" == n){
                                  goToPage(context, const OpenJob());
                                }
                                else{ // Prepare job files for Job Page
                                  await _readJob(jobList[index]).then((value) {
                                    jobDir = jobList.elementAt(index).path;
                                    loadingDialog(context);
                                    goToPage(context, const LoadJobPage());
                                  });
                                }
                              },
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
                  child: Column(children: [
                    mButton(
                        context,
                        Colors.lightBlue,
                        TextButton(
                          child: Text('New Job', style: textStyle(Colors.white, fontBody)),
                          onPressed: () {
                            writeSession();
                            goToPage(context, const NewJob());
                          },
                        )
                    ),
                    mButton(
                        context,
                        Colors.blue[800]!,
                        TextButton(
                          child: Text('Scan Directory', style: textStyle(Colors.white, fontBody)),
                          onPressed: () async{
                            String path = await pickDir(context);
                            _dirAdd(path);
                            _listFiles();
                          },
                        )
                    ),
                    mButton(
                        context,
                        Colors.blue[800]!,
                        TextButton(
                          child: Text('Load from Storage', style: textStyle(Colors.white, fontBody)),
                          onPressed: () async{
                            String path = await pickFile(context);
                            _singleAdd(path);
                            _listFiles();
                          },
                        )
                    ),
                    mButton(
                        context,
                        colorWarning,
                        TextButton(
                          child: Text('Back', style: textStyle(Colors.white, fontBody)),
                          onPressed: () {
                            // save session and clear vars
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

/*
==================
  New Job Page
==================
*/
class NewJob extends StatefulWidget {
  const NewJob({
    super.key,
  });

  @override
  State<NewJob> createState() => _NewJobState();
}
class _NewJobState extends State<NewJob> {
  StockJob newJob = StockJob(id: "NULL", name: "EMPTY");
  String savePath = "";
  bool overwriteJob = false;

  @override
  void initState() {
    super.initState();
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                goToPage(context, const JobsPage());
              },
            ),
          ),
          body: SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(
                          left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Job Id: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(
                            left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: TextFormField(
                              textAlign: TextAlign.left,
                              onChanged: (value) {
                                newJob.id = value;
                              },
                            )
                        )
                    ),
                    const Padding(
                      padding: EdgeInsets.only(
                          left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Job Name: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(
                            left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: TextFormField(
                              textAlign: TextAlign.left,
                              onChanged: (value) {
                                newJob.name = value;
                              },
                            )
                        )
                    ),
                    const Padding(
                      padding: EdgeInsets.only(
                          left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Database File Path: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 15.0, right: 15.0, top: 15.0, bottom: 5),
                      child: Card(
                        child: ListTile(
                          leading: newJob.dbPath == "" ? const Icon(Icons.question_mark) : null,
                          title: Text(
                            shortFilePath(newJob.dbPath),
                            textAlign: TextAlign.left,
                          ),
                          onTap: () async {
                            newJob.dbPath = await pickSpredsheet(context);
                            refresh(this);
                          }
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(
                          left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Job File Save Location: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: ListTile(
                                leading: newJob.dbPath == "" ? const Icon(Icons.question_mark) : null,
                                title: Text(savePath, textAlign: TextAlign.left),
                                onTap: () async {
                                  savePath = await pickDir(context);
                                  refresh(this);
                                }
                                )
                        )
                    ),
                  ]
              )
          ),
          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(children: [
                    mButton(
                        context,
                        colorOk,
                        TextButton(
                          child: Text('Create Job', style: textStyle(Colors.white, fontBody)),
                          onPressed: () async {
                            if(savePath.isEmpty){
                              ScaffoldMessenger.of(context).showSnackBar(
                                  showNotification(const Text('!! JOB NOT CREATED -> SAVE PATH NULL !!'), Colors.orange)
                              );
                            }
                            else if(savePath.isNotEmpty) {
                              bool confirmWrite = false;

                              // Check if job already exists
                              var checkFile = File('$savePath/job_${newJob.id}');
                              await checkFile.exists().then((value){
                                if(value == true){
                                  showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      barrierColor: Colors.blue.withOpacity(0.8),
                                      builder: (context) => AlertDialog(
                                          title: const Text("Warning!"),
                                          content: SingleChildScrollView(
                                              child: Column(
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                                                      child: Text('* Job file [${newJob.id}] already exists!\n\n* Confirm overwrite?', textAlign: TextAlign.left, style: TextStyle(color: colorWarning, fontSize: 20)),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 5, bottom: 5),
                                                      child: Text('** WARNING: DETECTED JOB FILE WILL BE DELETED IF "YES" **', textAlign: TextAlign.left, style: TextStyle(color: colorWarning, fontSize: 20)),
                                                    ),
                                                    mButton(
                                                        context,
                                                        colorOk,
                                                        TextButton(
                                                          child:
                                                          Text('Yes', style: textStyle(Colors.white, fontBody)),
                                                          onPressed: () {
                                                            confirmWrite = true;
                                                            Navigator.pop(context);
                                                            refresh(this);
                                                          },
                                                        )
                                                    ),
                                                    mButton(
                                                        context,
                                                        colorBack,
                                                        TextButton(
                                                          child:
                                                          Text('No', style: textStyle(Colors.white, fontBody)),
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
                                }
                                else {
                                  confirmWrite = true;
                                }

                                if(confirmWrite) {
                                  writeJob(newJob, '$savePath/job_${newJob.id}');
                                  // if(!sFile.dirs.contains(savePath)){
                                  //   sFile.dirs.add(savePath);
                                  // }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                      showNotification(Text('!! JOB CREATED -> ${newJob.id}'), colorOk)
                                  );
                                  goToPage(context, const JobsPage());
                                }
                              });
                            }
                          },
                        )
                    ),
                    mButton(
                        context,
                        colorBack,
                        TextButton(
                          child:
                          Text('Cancel', style: textStyle(Colors.white, fontBody)),
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                                showNotification(const Text('!! JOB NOT CREATED -> USER CANCEL'), Colors.orange)
                            );
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

/*
==================
  Load Job Page
==================
*/
class LoadJobPage extends StatefulWidget {
  const LoadJobPage({super.key});

  @override
  State<LoadJobPage> createState() => _LoadJobState();
}
class _LoadJobState extends State<LoadJobPage> {
  var sheets = [];

  @override
  void initState() {
    super.initState();
    getSheets();
  }

  getSheets() async {
    if (currentJob.dbPath.isEmpty) {
      await showAlert(
          context,
          "Alert",
          "Invalid File Path:"
              "\n* The database for this job cannot be found.\n"
              "\n* No Database can be loaded for the job.",
          colorWarning.withOpacity(0.8));
      return;
    }

    File file = File(currentJob.dbPath);
    var bytes = file.readAsBytesSync();
    var decoder = SpreadsheetDecoder.decodeBytes(bytes);

    sheets = decoder.tables.keys.toList();

    // var status = await Permission.storage.status;
    // if (!status.isGranted) {
    //   await Permission.storage.request();
    //   File file = File(currentJob.dbPath);
    //   var bytes = file.readAsBytesSync();
    //   var decoder = SpreadsheetDecoder.decodeBytes(bytes);
    //
    //   sheets = decoder.tables.keys.toList();
    // }

    refresh(this);
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
        barcode: cell[1].toString(),
        category: cell[2].toString().trim().toUpperCase(),
        description: trimDescripString(cell[3].toString().trim().toUpperCase()),
        uom: cell[4].toString().trim().toUpperCase(),
        price: double.parse(cell[5].toString()),
        nof: false,
      ));
    }

    //mPrint("MAIN BD: ${spreadsheet.length}");
  }

  trimDescripString(String s){
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
              title: const Text("Load Spreasheet Data for Job", textAlign: TextAlign.center)
          ),

          body: SingleChildScrollView(
            child: Column(
              children:[
                const Center(
                    child: ListTile(
                      title: Text("Available Sheets:")
                    )
                  ),
                Column(
                    children: List.generate(sheets.length, (index) => Card(
                      child: ListTile(
                        title: Text(sheets.elementAt(index).toString()),
                        onTap: () async {
                          loadingDialog(context);
                          await loadDatabase(sheets.elementAt(index).toString()).then((value){
                            goToPage(context, const OpenJob());
                          });
                          },
                      ),
                    ),)
                ),
              ]
            ),
          ),
            bottomSheet: SingleChildScrollView(
                child: Center(
                  child: Column(
                    children: [
                      mButton(
                        context,
                        colorDisable,
                        TextButton(
                          child: Text('START WITH NO DATA', style: textStyle(Colors.white, fontBody)),
                          onPressed: () async{
                            await (showAlert(
                                context,
                                'Warning!',
                                'No Spreasheet Data:'
                                    '\n* The job will load without spreadsheet data.',
                                colorWarning)).then((value){
                              goToPage(context, const OpenJob());
                            });
                            },
                        )
                    ),
                      mButton(
                          context,
                          colorBack,
                          TextButton(
                            child: Text('Back', style: textStyle(Colors.white, fontBody)),
                            onPressed: () {
                              goToPage(context, const JobsPage());
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

/*
==================
  Open Job
==================
*/
class OpenJob extends StatelessWidget {
  const OpenJob({
    super.key,
  });

  _exportJobToXLSX( List<dynamic> fSheet, String outDir) async{
    var path = outDir;//.replaceAll('storage/emulated/0', 'sdcard');
    if(path.isEmpty){
      return false;
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

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Job ID: ${currentJob.id.toString()}",
              textAlign: TextAlign.center),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: Column(
              children: [
            Card(
              child: ListTile(
                title: Text("Date: ${currentJob.date}"),
                trailing: const Icon(Icons.date_range, color: Colors.blueGrey),
              ),
            ),
            Card(
              child: ListTile(
                title: Text("Name: ${currentJob.name}"),
              ),
            ),
            Card(
              child: ListTile(
                title: Text("Total Stock Count: ${currentJob.getTotal()}"),
              ),
            ),
            Card(
              child: ListTile(
                title: Text("Database: ${shortFilePath(currentJob.dbPath)}"),
                trailing:
                const Icon(Icons.edit_rounded, color: Colors.amberAccent),
              ),
            ),
            Center(
                child: Column(children: [
                  mButton(
                      context,
                      Colors.blue,
                      TextButton(
                        child:
                        Text('Stocktake', style: textStyle(Colors.white, fontBody)),
                        onPressed: () {
                          goToPage(context, const StocktakePage());
                        },
                      )
                  ),
                  mButton(
                      context,
                      Colors.blue,
                      TextButton(
                        child: Text('View Stocktake Spreadsheet',
                            style: textStyle(Colors.white, fontBody)),
                        onPressed: () {
                          goToPage(context, ViewSpreadSheet(mainList: currentJob.getList()));
                        },
                      )
                  ),
                  mButton(
                      context,
                      Colors.blue,
                      TextButton(
                        child: Text('Export Spreadsheet',
                            style: textStyle(Colors.white, fontBody)),
                        onPressed: () async {
                          String outDir = await pickDir(context);
                          await _exportJobToXLSX(currentJob.getFinalSheet(), outDir).then((value) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                showNotification(Text(value ? 'STOCKTAKE EXPORT -> stocktake_${currentJob.id}' : 'STOCKTAKE EXPORT -> EXPORT CANCEL'), value ? colorOk : Colors.orange)
                            );
                          });
                          },
                      )
                  ),
                  mButton(
                      context,
                      Colors.green,
                      TextButton(
                        child: Text('Save Job', style: textStyle(Colors.white, fontBody)),
                        onPressed: () {
                          writeJob(currentJob, jobDir);
                          ScaffoldMessenger.of(context).showSnackBar(
                              showNotification(Text('JOB SAVED -> job_${currentJob.id}'), colorOk)
                          );
                        },
                      )
                  ),
                  mButton(
                      context,
                      Colors.red,
                      TextButton(
                        child:
                        Text('Close Job', style: textStyle(Colors.white, fontBody)),
                        onPressed: () {
                          // Save job on close?
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              barrierColor: Colors.blue.withOpacity(0.8),
                              builder: (context) => AlertDialog(
                                  title: const Text("Save Job?"),
                                  content: SingleChildScrollView(
                                      child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                                              child: Text('Save changes to job file?', textAlign: TextAlign.left, style: TextStyle(color: colorWarning, fontSize: 20)),
                                            ),
                                            mButton(
                                                context,
                                                colorOk,
                                                TextButton(
                                                  child:
                                                  Text('Save', style: textStyle(Colors.white, fontBody)),
                                                  onPressed: () {
                                                    writeJob(currentJob, jobDir);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                        showNotification(Text('JOB SAVED -> job_${currentJob.id}'), colorOk)
                                                    );
                                                    Navigator.pop(context);
                                                  },
                                                )
                                            ),
                                            mButton(
                                                context,
                                                colorBack,
                                                TextButton(
                                                  child:
                                                  Text('No', style: textStyle(Colors.white, fontBody)),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                )
                                            ),
                                          ]
                                      )
                                  )
                              )
                          );

                          goToPage(context, const JobsPage());
                        },
                      )
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 30,
                  )
                ]
                )
            )]),
        ),
      ),
    );
  }
}

/*
==================
  Stocktake Page
==================
*/
class StocktakePage extends StatefulWidget {
  const StocktakePage({super.key});

  @override
  State<StocktakePage> createState() => _StocktakePageState();
}
class _StocktakePageState extends State<StocktakePage> {
  int stockIndex = -1;
  int selectIndex = -1;
  TextEditingController removeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  getIndex() {
    return selectIndex;
  }

  setIndex(int stockIndex, int selectIndex) {
    this.stockIndex = stockIndex;
    this.selectIndex = selectIndex;

    mPrint("SELECT INDEX: $selectIndex");
    if (selectIndex != -1) {
      mPrint("ITEM INDEX: $stockIndex");
      mPrint(currentJob.literal[selectIndex].description);
    }

    refresh(this);
  }

  errorStart() {
    return showAlert(
        context,
        "Alert",
        'User Action Error:'
            '${currentJob.location.isEmpty ? '\n* Create and set location before scanning.' : ''}'
            '${currentJob.dbPath.isEmpty ? '\n* Database is empty; need spreadsheet for item lookup.' : ''}'
            "\n* Possible other reaons.",
        Colors.red.withOpacity(0.8));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text("Stocktake - Total: ${currentJob.getTotal()}", textAlign: TextAlign.center),
              automaticallyImplyLeading: false,
              // leading: IconButton(
              //   icon: const Icon(Icons.arrow_back),
              //   onPressed: () {
              //     goToPage(context, const OpenJob());
              //     },
            ),
            body: Center(
                child: Column(children: [
                  const Padding(
                    padding: EdgeInsets.only(
                        left: 15.0, right: 15.0, top: 15, bottom: 5),
                    child: Text('Current Location: ',
                        textAlign: TextAlign.left,
                        style: TextStyle(color: Colors.blue, fontSize: 20)),
                  ),
                  Card(
                    child: ListTile(
                      title:
                      currentJob.location.isEmpty ?
                      Text("Tap to select a location...", style: textStyle(Colors.grey, fontBody)) : Text(currentJob.location, textAlign: TextAlign.center),
                      leading: currentJob.location.isEmpty ? const Icon(Icons.warning_amber, color: Colors.red) : null,
                      onTap: () async {
                        goToPage(context, const Location());
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(
                        left: 15.0, right: 15.0, top: 35, bottom: 5),
                  ),
                  mButton(
                      context,
                      Colors.blue,
                      TextButton(
                        child: Text('Scan Item',
                            style: textStyle(Colors.white, fontBody)),
                        onPressed: () async {
                          if (currentJob.location.isNotEmpty &&
                              currentJob.dbPath.isNotEmpty) {
                            //selectIndex = -1;
                            //goToPage(context, const ScanItem());
                          } else {
                            errorStart();
                          }
                        },
                      )
                  ),
                  mButton(
                      context,
                      Colors.blue,
                      TextButton(
                        child: Text('Search Item',
                            style: textStyle(Colors.white, fontBody)),
                        onPressed: () async {
                          if (currentJob.location.isNotEmpty &&
                              currentJob.dbPath.isNotEmpty) {
                            selectIndex = -1;
                            goToPage(context, const SearchItem());
                          } else {
                            errorStart();
                          }
                        },
                      )
                  ),
                  mButton(
                      context,
                      Colors.blue,
                      TextButton(
                        child: Text('Add NOF', style: textStyle(Colors.white, fontBody)),
                        onPressed: () async {
                          if (currentJob.location.isNotEmpty && currentJob.dbPath.isNotEmpty) {
                            selectIndex = -1;
                            goToPage(context, const AddNOF());
                          }
                        },
                      )
                  ),
                  mButton(
                      context,
                      Colors.blue,
                      TextButton(
                        child: Text('Edit Stocktake', style: textStyle(Colors.white, fontBody)),
                        onPressed: () async {
                          selectIndex = -1;
                          goToPage(context, const EditStock());
                        },
                      )
                  ),
                ]
                )
            ),
            bottomSheet: SingleChildScrollView(
                child: Center(
                    child: Column(children: [
                      mButton(
                          context,
                          colorBack,
                          TextButton(
                            child:
                            Text('Back', style: textStyle(Colors.white, fontBody)),
                            onPressed: () {
                              goToPage(context, const OpenJob());
                            },
                          )
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: 30,
                      )
                    ]
                    )
                )
            )
        )
    );
  }
}

/*
==================
  EditStock Page
==================
*/
class EditStock extends StatefulWidget {
  const EditStock({super.key});

  @override
  State<EditStock> createState() => _EditStockState();
}
class _EditStockState extends State<EditStock> {
  int stockIndex = -1;
  int selectIndex = -1;
  TextEditingController removeCtrl = TextEditingController();

  final tableKey = GlobalKey<PaginatedDataTableState>();

  List<StockItem> stockList = spreadsheet + currentJob.nof;

  @override
  void initState() {
    super.initState();
    selectIndex = -1;
    stockIndex = -1;
  }

  getIndex() {
    return selectIndex;
  }

  setIndex(int stockIndex, int selectIndex) {
    this.stockIndex = stockIndex; // position of stock item in database + nof
    this.selectIndex = selectIndex; // position of selection on screen

    mPrint("SELECT INDEX: $selectIndex");
    if (selectIndex != -1) {
      mPrint("ITEM INDEX: $stockIndex");
      mPrint(currentJob.literal[selectIndex].description);
    }

    refresh(this);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Stocktake - Total: ${currentJob.getTotal()}",
              textAlign: TextAlign.center),
          //automaticallyImplyLeading: false,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                goToPage(context, const StocktakePage());
              }),
        ),
        body: Center(
            child: Column(children: [
              mButton(
                  context,
                  selectIndex > -1 ? colorOk : colorDisable,
                  TextButton(
                    child: Text('EDIT ITEM', style: textStyle(Colors.white, fontBody)),
                    onPressed: () {
                      if (selectIndex > -1) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          barrierColor: Colors.blue.withOpacity(0.8),
                          builder: (context) => AlertDialog(
                            title: const Text("Edit Item"),
                            content: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Card(
                                      child: ListTile(
                                          title: Text("Table Index: $stockIndex")
                                      ),
                                    ),
                                    Card(
                                      child: ListTile(
                                          title: Text(
                                              "Barcode: ${stockList[stockIndex].barcode}")),
                                    ),
                                    Card(
                                      child: ListTile(
                                          title: Text(
                                              "Description: ${stockList[stockIndex].description}")),
                                    ),
                                    Card(
                                      child: ListTile(
                                          title: Text(
                                              "UOM: ${stockList[stockIndex].uom}")),
                                    ),
                                    Card(
                                      child: ListTile(
                                          title: Text(selectIndex >= 0 ? "Count: ${currentJob.literal[selectIndex].count}" : "Count: null_something_gone_wrong")
                                      ),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.8,
                                      height: 20.0,
                                    ),
                                    Card(
                                        child: ListTile(
                                          title: TextField(
                                            decoration: const InputDecoration(
                                                hintText: 'Remove: ',
                                                border: InputBorder.none),
                                            controller: removeCtrl,
                                            keyboardType:
                                            const TextInputType.numberWithOptions(signed: false, decimal: true),
                                            onSubmitted: (value) async {
                                              currentJob.removeStock(selectIndex, stockList[stockIndex], double.parse(value));
                                              removeCtrl.clear();
                                              selectIndex = 0;
                                              stockIndex = 0;
                                              // refresh(this);
                                              Navigator.pop(context);
                                            },
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.cancel),
                                            onPressed: () {
                                              removeCtrl.clear();
                                              //refresh(this);
                                            },
                                          ),
                                        )
                                    ),
                                  ],
                                )
                            ),
                            actions: [
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                                  child: const Text("Cancel"),
                                  onPressed: () {
                                    removeCtrl.clear();
                                    selectIndex = 0;
                                    stockIndex = 0;
                                    Navigator.pop(context);
                                    refresh(this);
                                  }
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  )
              ),
              Expanded(
                  child: SingleChildScrollView(
                      child: PaginatedDataTable(
                          sortColumnIndex: 0,
                          sortAscending: true,
                          showCheckboxColumn: false,
                          showFirstLastButtons: true,
                          rowsPerPage: sFile.pageCount,
                          key: tableKey,
                          controller: ScrollController(),
                          columns: const <DataColumn>[
                            DataColumn(label: Text("Description")),
                            DataColumn(label: Text("Count")),
                            DataColumn(label: Text("UOM")),
                            DataColumn(label: Text("Location")),
                            DataColumn(label: Text("Barcode")),
                          ],
                          source: RowLiterals(
                              dataList: currentJob.literal,
                              parent: this
                          )
                      )
                  )
              ),
            ])
        ),
      ),
    );
  }
}

/*
==================
  Location Page
==================
*/
class Location extends StatefulWidget {
  const Location({super.key});

  @override
  State<Location> createState() => _LocationState();
}
class _LocationState extends State<Location> {
  String location = currentJob.location;
  TextEditingController loctnCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void newLocation() {
    showDialog(
      context: context,
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
                controller: loctnCtrl,
                keyboardType: TextInputType.name,
                onSubmitted: (value) {
                  // Add string to currentJob location list
                  if (value.isNotEmpty) {
                    currentJob.addLocation(value.toUpperCase());
                  }
                  loctnCtrl.clear();
                  refresh(this);
                  Navigator.pop(context);
                },
              ),
            )
        ),
        actions: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorBack),
            onPressed: () {
              loctnCtrl.clear();
              refresh(this);
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorOk),
            onPressed: () async {
              if (loctnCtrl.text.isNotEmpty) {
                currentJob.addLocation(loctnCtrl.text.toUpperCase());
              }

              loctnCtrl.clear();
              refresh(this);
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );

    refresh(this);
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
                  children: currentJob.allLocations.isNotEmpty ? List.generate(
                      currentJob.allLocations.length,
                          (index) => Card(
                          child: ListTile(
                            trailing: currentJob.allLocations[index] == currentJob.location ? const Icon(Icons.arrow_back, color: Colors.green) : null,
                            title: Text(currentJob.allLocations[index], textAlign: TextAlign.justify),
                            onTap: () {
                              currentJob.setLocation(index);
                              refresh(this);
                              // goToPage(context, const StocktakePage());
                            },
                          )
                      )
                  ) : [
                    Card(
                        child: ListTile(
                          title: Text("No locations, create a new location...",
                              style: textStyle(Colors.grey, fontBody),
                              textAlign: TextAlign.justify),
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
                    mButton(
                        context,
                        Colors.lightBlue,
                        TextButton(
                          child: Text('Add Location', style: textStyle(Colors.white, fontTitle)),
                          onPressed: () {
                            newLocation();
                          },
                        )
                    ),
                    mButton(
                        context,
                        colorBack,
                        TextButton(
                          child: Text('Back', style: textStyle(Colors.white, fontTitle)),
                          onPressed: () async {
                            await goToPage(context, const StocktakePage());
                            refresh(this);
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

/*
==================
  Add NOF Page
==================
*/
class AddNOF extends StatefulWidget {
  const AddNOF({super.key});

  @override
  State<AddNOF> createState() => _AddNOFState();
}
class _AddNOFState extends State<AddNOF> {
  TextEditingController barcodeCtrl = TextEditingController();
  TextEditingController categoryCtrl = TextEditingController();
  TextEditingController descriptCtrl = TextEditingController();
  TextEditingController uomCtrl = TextEditingController();
  TextEditingController addCtrl = TextEditingController();

  bool goodNOF() {
    return barcodeCtrl.text.isNotEmpty &&
        categoryCtrl.text.isNotEmpty &&
        descriptCtrl.text.isNotEmpty &&
        uomCtrl.text.isNotEmpty;
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
                    const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Barcode: ', textAlign: TextAlign.left, style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Card(
                        child: ListTile(
                          title: TextField(
                            scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight + 15),
                            decoration: const InputDecoration(hintText: 'NON_DUPLICATES', border: InputBorder.none),
                            controller: barcodeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              refresh(this);
                              barcodeCtrl.clear();
                            },
                          ),
                        )
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text(
                          'Category: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)
                      ),
                    ),
                    Card(
                        child: ListTile(
                          title: TextField(
                            scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight + 15),
                            decoration: const InputDecoration(hintText: 'E.g. meat, ice-cream', border: InputBorder.none),
                            controller: categoryCtrl,
                            keyboardType: TextInputType.name,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              refresh(this);
                              categoryCtrl.clear();
                            },
                          ),
                        )
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text(
                          'Description:',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)
                      ),
                    ),
                    Card(
                        child: ListTile(
                          title: TextField(
                            scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight + 15),
                            decoration: const InputDecoration(hintText: 'E.g. PETERS I/CREAM VAN 1L', border: InputBorder.none),
                            controller: descriptCtrl,
                            keyboardType: TextInputType.name,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              refresh(this);
                              descriptCtrl.clear();
                            },
                          ),
                        )),
                    const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text(
                          'UOM: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)
                      ),
                    ),
                    Card(
                        child: ListTile(
                          title: TextField(
                            scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight + 15),
                            decoration: const InputDecoration(hintText: 'E.g. EACH,CARTON', border: InputBorder.none),
                            controller: uomCtrl,
                            keyboardType: TextInputType.name,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              refresh(this);
                              uomCtrl.clear();
                            },
                          ),
                        )
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text(
                          'Add Count: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)
                      ),
                    ),
                    Card(
                        child: ListTile(
                          title: TextField(
                            scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight + 15),
                            decoration: const InputDecoration(hintText: '0', border: InputBorder.none),
                            controller: addCtrl,
                            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              refresh(this);
                              addCtrl.clear();
                            },
                          ),
                        )
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: 20.0,
                    ),
                    Center(
                      child: mButton(
                          context,
                          colorOk,
                          TextButton(
                            child: Text('Add NOF', style: textStyle(Colors.white, fontBody)),
                            onPressed: () async {
                              if (goodNOF()) {
                                StockItem nof = StockItem(
                                    index: spreadsheet.length + currentJob.nof.length,
                                    barcode: barcodeCtrl.text.toUpperCase(),
                                    category: categoryCtrl.text.toUpperCase(),
                                    description: descriptCtrl.text.toUpperCase(),
                                    uom: uomCtrl.text.toUpperCase(),
                                    price: 0.00,
                                    nof: true
                                );
                                if (currentJob.addNOF(nof)) {
                                  if (addCtrl.text != "0" && addCtrl.text.isNotEmpty) {
                                    currentJob.addStock(nof, double.parse(addCtrl.text));
                                  }
                                  showAlert(context, "NOF added!", '', Colors.blue.withOpacity(0.8)).then((value) {
                                    goToPage(context, const StocktakePage());
                                  }
                                  );
                                } else {
                                  showAlert(
                                      context,
                                      "Error!",
                                      'DUPLICATE BARCODE: '
                                          '\n* Item already exists.'
                                          '\n* Go to "Search Item" page and find the NOF'
                                          '\n* Barcode scanning should automatically find the NOF',
                                      Colors.red.withOpacity(0.8)).then((value) {
                                    goToPage(context, const StocktakePage());
                                  }
                                  );
                                }
                              } else {
                                showAlert(
                                    context,
                                    'Error!',
                                    'NOF IS INCOMPLETE: '
                                        '\n* Make sure all text fields contain info',
                                    Colors.blue.withOpacity(0.8));
                              }

                              //mPrint("NOF ITEMS ${currentJob.nof.length}");
                            },
                          )
                      ),
                    ),
                    Center(
                        child: mButton(
                          context,
                          colorBack,
                          TextButton(
                            child: Text('Cancel', style: textStyle(Colors.white, fontBody)),
                            onPressed: () async {
                              goToPage(context, const StocktakePage());
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

/*
=============================
  Search Item Page
=============================
*/
class SearchItem extends StatefulWidget {
  const SearchItem({super.key});

  @override
  State<SearchItem> createState() => _SearchItemState();
}
class _SearchItemState extends State<SearchItem> {
  int selectIndex = -1;
  final tableKey = GlobalKey<PaginatedDataTableState>(); // reset page on search text deletion

  TextEditingController searchCtrl = TextEditingController();
  TextEditingController addCtrl = TextEditingController();
  List<StockItem>? filterList; // contains list of items we are searching for
  List<StockItem>? searchList; // full list of stock items + NOFs

  @override
  void initState() {
    super.initState();
    searchList = spreadsheet + currentJob.nof;
    filterList = searchList;
  }

  getIndex() {
    return selectIndex;
  }

  setIndex(int stockIndex, int selectIndex) {
    this.selectIndex = selectIndex;

    mPrint("SELECT INDEX: $selectIndex");
    if (selectIndex != -1) {
      mPrint("ITEM INDEX: $stockIndex");
      mPrint(filterList![selectIndex].description);
    }

    refresh(this);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(

          appBar: AppBar(
            centerTitle: true,
            title: const Text("Search Item"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                goToPage(context, const StocktakePage());
              },
            ),
          ),

          body: Center(
              child: Column(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.search),
                        title: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(
                                hintText: 'Search', border: InputBorder.none),
                            onChanged: (value) {
                              String search = value.toUpperCase();
                              // Jump back to first page if search input text is manually deleted by the user
                              if (search.isEmpty) {
                                tableKey.currentState?.pageTo(0);
                              }
                              filterList = searchList!.where((item) => item.description.contains(search) || item.barcode.toString().contains(search)).toList();
                              refresh(this);
                            }
                            ),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: () {
                            tableKey.currentState?.pageTo(0); // Jump back to first page on search text clear
                            searchCtrl.clear();
                            filterList = searchList;
                            refresh(this);
                            },
                        ),
                      ),
                    ),
                    Expanded(
                        child: SingleChildScrollView(
                            child: PaginatedDataTable(
                              key: tableKey,
                              sortColumnIndex: 0,
                              sortAscending: true,
                              showCheckboxColumn: false,
                              showFirstLastButtons: true,
                              rowsPerPage: sFile.pageCount,
                              controller: ScrollController(),
                              // Only show description and UOM
                              columns: getColumns([3, 4]),
                              source: RowSource(
                                  parent: this,
                                  dataList: filterList,
                                  showCells: [3, 4],
                                  select: true
                              ),
                            )
                        )
                    ),
                    Center(
                        child: Column(children: [
                          mButton(
                              context,
                              selectIndex > -1 ? Colors.blue : Colors.grey,
                              TextButton(
                                //itemIndex == -1 ? "ADD NOF" :
                                child: Text("ADD ITEM", style: textStyle(Colors.white, fontTitle)),
                                onPressed: () {
                                  if (selectIndex > -1) {
                                    showDialog(
                                      barrierDismissible: false,
                                      context: context,
                                      barrierColor: Colors.blue.withOpacity(0.8),
                                      builder: (context) => AlertDialog(
                                        actionsAlignment: MainAxisAlignment.spaceAround,
                                        content: Card(
                                            child: ListTile(
                                              title: Text("Add Count:", style: textStyle(Colors.black, fontBody)),
                                              subtitle: TextField(
                                                decoration: const InputDecoration(border: InputBorder.none),
                                                controller: addCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                                onSubmitted: (value) {
                                                  currentJob.addStock(filterList![selectIndex], double.parse(value));
                                                  String s = filterList![selectIndex].description;
                                                  if (s.length > 12) {
                                                    s = s.substring(0, 12);
                                                  }
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                      showNotification(Text('Stock Added: $s -> ${addCtrl.text}', style: textStyle(Colors.black, fontTitle), textAlign: TextAlign.center), colorOk)
                                                  );
                                                  addCtrl.clear();
                                                  selectIndex = -1;
                                                  refresh(this);
                                                  Navigator.pop(context);
                                                },
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.cancel),
                                                onPressed: () {
                                                  addCtrl.clear();
                                                },
                                              ),
                                            )
                                        ),
                                        actions: [
                                          ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                                              child: const Text("Cancel"),
                                              onPressed: () {
                                                addCtrl.clear();
                                                selectIndex = -1;
                                                refresh(this);
                                                Navigator.pop(context);
                                              }
                                          ),
                                          ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                                              child: const Text("Ok"),
                                              onPressed: () {
                                                currentJob.addStock(filterList![selectIndex], double.parse(addCtrl.text));
                                                String s = filterList![selectIndex].description;
                                                if (s.length > 12) {
                                                  s = s.substring(0, 12);
                                                }
                                                ScaffoldMessenger.of(context).showSnackBar(showNotification(
                                                    Text('Stock Added: $s -> ${addCtrl.text}', style: textStyle(Colors.black, fontTitle), textAlign: TextAlign.center), colorOk)
                                                );
                                                addCtrl.clear();
                                                selectIndex = -1;
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
                          )
                        ])
                    )
                  ]
              )
          ),
        )
    );
  }
}

/*
============================
  View Spreadsheet Page
============================
*/
class ViewSpreadSheet extends StatefulWidget {
  final List<StockItem> mainList;

  const ViewSpreadSheet({
    super.key,
    required this.mainList,
  });

  @override
  State<ViewSpreadSheet> createState() => _SpreadSheetState();
}
class _SpreadSheetState extends State<ViewSpreadSheet> {
  TextEditingController searchController = TextEditingController();
  List<StockItem>? filterList;
  final tableKey = GlobalKey<PaginatedDataTableState>();

  @override
  void initState() {
    super.initState();
    filterList = widget.mainList;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Sheet",
            home: Scaffold(
                appBar: AppBar(
                  centerTitle: true,
                  title: Text("Spreadsheet View: ${currentJob.id}",
                      textAlign: TextAlign.center),
                  leading: IconButton(
                      onPressed: () {
                        goToPage(context, const OpenJob());
                      },
                      icon: const Icon(Icons.arrow_back)),
                ),
                body: Center(
                    child: Column(children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.search),
                          title: TextField(
                              controller: searchController,
                              decoration: const InputDecoration(
                                  hintText: 'Search', border: InputBorder.none), onChanged: (value) {
                            String result = value.toUpperCase();
                            if (result == "") {
                              tableKey.currentState!.pageTo(0);
                            }
                            filterList = widget.mainList.where((item) => item.description.contains(result) || item.barcode.toString().contains(result) || item.category.contains(result)).toList();
                            refresh(this);
                          }
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              searchController.clear();
                              filterList = widget.mainList;
                              tableKey.currentState!.pageTo(0);
                              refresh(this);
                            },
                          ),
                        ),
                      ),
                      Expanded(
                          child: SingleChildScrollView(
                              child: PaginatedDataTable(
                                  sortColumnIndex: 0,
                                  sortAscending: true,
                                  showCheckboxColumn: false,
                                  showFirstLastButtons: true,
                                  rowsPerPage: sFile.pageCount,
                                  key: tableKey,
                                  controller: ScrollController(),
                                  columns: getColumns([]),
                                  source: RowSource(
                                      parent: this,
                                      dataList: filterList,
                                      select: false)
                              )
                          )
                      ),
                    ])
                )
            )
        )
    );
  }
}

/*
=====================================
  TABLE/SPREADSHEET FUNCTIONS
==================================
*/

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

class RowLiterals extends DataTableSource {
  List<StockLiteral>? dataList;
  dynamic parent;

  RowLiterals({
    required this.dataList,
    required this.parent,
  });

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if (index >= rowCount) {
      return null;
    }

    return DataRow.byIndex(
      index: index,
      selected: index == parent.getIndex(),

      // Select and return item index
      onSelectChanged: (value) {
        int selectIndex = parent.getIndex() != index ? index : -1;
        int stockIndex = selectIndex > -1 ? dataList![selectIndex].index : -1;

        notifyListeners();
        parent.setIndex(stockIndex, selectIndex);
      },

      cells: <DataCell>[
        DataCell(Text(dataList![index].description)),
        DataCell(Text(dataList![index].count.toString())),
        DataCell(Text(dataList![index].uom)),
        DataCell(Text(dataList![index].location)),
        DataCell(Text(dataList![index].barcode.toString())),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList!.length;
  @override
  int get selectedRowCount => parent.getIndex() != -1 ? 1 : 0;
}

class RowSource extends DataTableSource {
  List<StockItem>? dataList;
  List<int>? showCells; // hide/show specific cells
  bool select = false;

  dynamic parent;

  RowSource(
      {required this.parent,
        required this.dataList,
        this.showCells,
        required this.select});

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if (index >= rowCount) {
      return null;
    }

    List<DataCell> dataCells = <DataCell>[
      DataCell(Text(dataList![index].index.toString())),
      DataCell(Text(dataList![index].barcode.toString())),
      DataCell(Text(dataList![index].category)),
      DataCell(Text(dataList![index].description)),
      DataCell(Text(dataList![index].uom)),
      DataCell(Text(dataList![index].price.toString())),
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

      // Select and return item index
      onSelectChanged: (value) {
        if (select == true) {
          int selectIndex = parent.getIndex() != index ? index : -1;
          int stockIndex =
          selectIndex != -1 ? dataList![selectIndex].index : -1;

          notifyListeners();
          parent.setIndex(stockIndex, selectIndex);
        }
      },
      cells: dataCells,
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList!.length;
  @override
  int get selectedRowCount =>
      (select == true && parent.getIndex() > -1) ? 1 : 0;
}

/*
======================================================
      COLORS & STYLES
======================================================
*/

Color colorOk = Colors.blue.shade400;
Color colorWarning = Colors.deepPurple.shade200;
Color colorDisable = Colors.blue.shade200;
Color colorBack = Colors.grey.shade600;

const fontTitle = 18.0;
const fontBody = 18.0;
const fontSmall = 12.0;
const fontBig = 24.0;
const fontButton = 18.0;

textStyle(Color c, var s) {
  return TextStyle(color: c, fontSize: s);
}

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

/*
======================================================
      POP-UPs & RE-USABLE WIDGETS
======================================================
*/

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

mButton(BuildContext context, Color c, TextButton t) {
  return Padding(
    padding:
    const EdgeInsets.only(left: 0.0, right: 0.0, top: 10.0, bottom: 10.0),
    child: Container(
      height: 50,
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(color: c), //, borderRadius: BorderRadius.),
      child: t,
    ),
  );
}

showNotification(Text message, Color bkgColor) {
  return SnackBar(
    content: message,
    backgroundColor: bkgColor,
    duration: const Duration(milliseconds: 1500),
    //width: 280.0, // Width of the SnackBar.
    padding: const EdgeInsets.symmetric(horizontal: 10.0),  // Inner padding for SnackBar content.
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 65.0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0),
    ),
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
            child: const Text("Ok"),
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

/*
======================================================
  READ/WRITE OPERATIONS
======================================================
*/

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

  // var storageExternal = await Permission.manageExternalStorage.status;
  //
  // if (storageExternal != PermissionStatus.granted) {
  //   await Permission.manageExternalStorage.request();
  // }
  //
  // b = storageExternal == PermissionStatus.granted;
  // mPrint("STORAGE ACCESS IS : $b");
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

Future<String> pickSpredsheet(BuildContext context) async {
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
    //mPrint(value.toString());
    val = value.toString();
  });

  return val;
}

writeJob(StockJob job, String path) async {
  //path.replaceAll('storage/emulated/0', 'sdcard');

  var filePath = path;
  var jobFile = File(filePath);
  Map<String, dynamic> jMap = job.toJson();
  var jString = jsonEncode(jMap);
  jobFile.writeAsString(jString);
}

writeSession() async {
  final path = await _localPath;
  final filePath = File('$path/session_file');
  Map<String, dynamic> jMap = sFile.toJson();
  var jString = jsonEncode(jMap);
  filePath.writeAsString(jString);
}

readSession() async {
  final path = await _localPath;
  var filePath = File('$path/session_file');

  // create session file if it doesn't exist
  if(!await filePath.exists()) {
    mPrint("Session Folder does not exist");
    sFile = SessionFile();
    writeSession();
    return true;
  }
  else{
    mPrint("Session Folder exists");
    String fileContent = await filePath.readAsString();
    var dynamic = json.decode(fileContent);
    sFile = SessionFile.fromJson(dynamic);
    return false;
  }
}
