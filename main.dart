/*
LEGAL:
   This was programmed by Callum Jack Buchanan.
   Any derivatives of this work must include or mention my name in the final build as part of the copyright agreement below.
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
import 'package:flutter/services.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:excel/excel.dart';
import 'stock_job.dart';

// TABLE INDICES
const int tIndex = 0;
const int tBarcode = 1;
const int tCategory = 2;
const int tDescription = 3;
const int tUom = 4;
const int tPrice = 5;
const int tDatetime = 6;
const int tOrdercode = 7;

//const int tNof = 8;

// STOCK ITEM INDICES
const int iIndex = 0;
const int iCount = 1;
const int iLocation = 2;

Permission storageType = Permission.manageExternalStorage;
//Permission storageType = Permission.storage;
String jobStartStr = "ASJob_";
StockJob job = StockJob(id: "EMPTY", name: "EMPTY");
List<String> jobList = [];
List<List<dynamic>> jobTable = List.empty();
List<dynamic> itemCopy = List.empty();
bool saveable = false;

Directory? rootDir;
SpreadsheetTable? mainTable;
List<String> masterCategory = [];
Map<String, dynamic> sFile = {};
enum TableType {literal, linear, export, full, search}
enum ActionType {add, edit, editNOF, view}

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
TextStyle get blackText{ return TextStyle(color: Colors.black, fontSize: sFile["fontScale"]);}
TextStyle get titleText{ return const TextStyle(color: Colors.black87, fontSize: 20.0, fontWeight: FontWeight.bold);}
TextStyle get blueText{ return const TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold);}

void main() {
  Timer.periodic(const Duration(minutes:5), (Timer t) => saveable ? debugPrint("AUTOSAVED") : null);

  runApp(
     MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const HomePage(),
        theme: ThemeData(
          bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
          navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
        ),
    ),
  );
}

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
    _getVersion();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _getVersion() async{
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    versionNum = packageInfo.version;
    buildNum = packageInfo.buildNumber;
    refresh(this);

    // Check for new version
    // Link to new version/download and install option?
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

                        //
                        // TEST TABLE
                        //

                        rBox(
                          context,
                          Colors.black,
                          TextButton(
                              child: const Text("TEST TABLE"),
                              onPressed: (){
                                if(mainTable!.rows.isNotEmpty) {
                                    jobTable = mainTable!.rows;
                                    goToPage(context, const GridView(action: ActionType.view), false);
                                    //goToPage(context, const StaticTable(tableType: TableType.export), false);
                                  }
                                },
                          ),
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
  void dispose() {
    super.dispose();
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
          body: Center(
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

                    // headerPadding('Autosave Time', TextAlign.left),
                    // Padding(
                    //     padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                    //     child: Card(
                    //         child: ListTile(
                    //           title: Text(sFile["saveTimer"].toString(), textAlign: TextAlign.center),
                    //           leading: IconButton(
                    //             icon: const Icon(Icons.remove_circle_outline),
                    //             onPressed: () {
                    //               sFile["fontScale"] -= sFile["saveTimer"] - 1 > 5 ? 1 : 0;
                    //               refresh(this);
                    //             },
                    //           ),
                    //           trailing: IconButton(
                    //             icon: const Icon(Icons.add_circle_outline),
                    //             onPressed: () {
                    //               sFile["fontScale"] += sFile["saveTimer"] + 1 < 20 ? 1 : 0;
                    //               refresh(this);
                    //             },
                    //           ),
                    //         )
                    //     )
                    // ),

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
          ),

          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(8.0),
            child: rBox(
                context,
                colorBack,
                TextButton(
                  child: Text('Back', style: whiteText),
                  onPressed: () {
                    goToPage(context, const HomePage(), false);
                  },
                )
            ),
          )
      ),
    );
  }
}

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

  @override
  void dispose() {
    super.dispose();
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
                                    await _readJob(jobList[index]).then((value) {
                                      saveable = true;
                                      jobTable = mainTable!.rows + job.nofList();
                                      goToPage(context, const OpenJob(), true);
                                    });
                                  }
                                  else{
                                    //showNotification(context, Colors.redAccent, whiteText, "!! ALERT !!", "* Read/Write permissions were DENIED\n * Try changing permissions via -> 'App Settings'",);
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

                                        if(!jobList.contains(path)){
                                          jobList.add(path);
                                        }

                                        // copy job file to documents folder if it is not there
                                        await _copyJobFile(path);
                                        await _readJob(path).then((value) {
                                          saveable = true; // set autosave flag
                                          jobTable = mainTable!.rows + job.nofList();
                                          goToPage(context, const OpenJob(), true);
                                        });
                                      }
                                      else {
                                        //showNotification(context, Colors.red[900]!, whiteText, "!! ALERT !!", "* Read/Write permissions were DENIED\n * Try changing permissions via -> 'App Settings'");
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

          bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(8.0),
              child: rBox(
                  context,
                  colorBack,
                  TextButton(
                    child: Text('Back', style: whiteText),
                    onPressed: () {
                      job = StockJob(id: "EMPTY", name: "EMPTY");
                      goToPage(context, const HomePage(), false);
                    },
                  )
              ),
          )
        )
    );
  }
}

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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
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
                      ]
                  )
              )
          ),

            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(8.0),
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
                                  //showNotification(context, Colors.orange, whiteText, "!! ALERT", "\n* Job ID is empty: ${idCtrl.text.isEmpty}");
                                  return;
                                }

                                var s = idCtrl.text;
                                String regex = r'[^\p{Alphabetic}\p{Mark}\p{Decimal_Number}\p{Connector_Punctuation}\p{Join_Control}\s]+';
                                s = s.replaceAll(RegExp(regex, unicode: true),'');

                                if (s.contains("_")){
                                  s = s.replaceAll("_", '');
                                }

                                newJob.id = s;
                                newJob.name = nameCtrl.text;
                                newJob.date = "${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}";

                                String path = "/storage/emulated/0/Documents/$jobStartStr${newJob.id}_0";

                                // Do not overwrite any other existing jobs
                                writeJob(newJob, false);

                                job = newJob;
                                job.calcTotal();
                                if(!jobList.contains(path)){
                                  jobList.add(path);
                                }

                                jobTable = mainTable!.rows + job.nofList();
                                saveable = true;
                                goToPage(context, const OpenJob(), false);
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
              ),
            )
        )
    );
  }
}

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
                                    showAlert(context, "Alert", "No spreadsheet data!\n* Press 'Sync with Server' to get latest MASTER SHEET.\n*You can also load a spreadsheet file from storage via the Settings page", colorOk);
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
                                  //goToPage(context, const StaticTable(tableType: TableType.export), false);
                                  exportJobToXLSX();
                                  showAlert(context, "Job Export", "Stocktake exported: "'/storage/emulated/0/Documents/stocktake_${job.id}_[num].xlsx', Colors.orange);
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

        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(8.0),
          child: rBox(
              context,
              colorBack,
              TextButton(
                child: Text('Back', style: whiteText),
                onPressed: () {
                  saveable = false; // Cancel auto-save
                  goToPage(context, const JobsPage(), false);
                },
              )
          ),
        )
      ),
    );
  }
}

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
                            setLocation(context);
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
                            child: Text('SCAN', style: whiteText),
                            onPressed: () {
                              if (job.location.isNotEmpty) {
                                goToPage(context, const ScanItem(), false);
                              } else {
                                showAlert(context, "Alert", 'Create and set location before scanning.', Colors.red.withOpacity(0.8));
                              }
                            },
                          )
                      ),
                      rBox(
                          context,
                          Colors.blue,
                          TextButton(
                            child: Text('SEARCH', style: whiteText),
                            onPressed: () {
                              if (job.location.isNotEmpty) {
                                goToPage(context, const GridView(action: ActionType.add), false);
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
                            child: Text('EDIT STOCKTAKE', style: whiteText),
                            onPressed: () {
                              job.literals.isNotEmpty ? goToPage(context, const GridView(action: ActionType.edit), false)
                                  : showAlert(context, "Alert", "Stocktake is empty.", colorDisable);
                              // goToPage(context, DynamicTable(tableType: TableType.literal, action: ActionType.edit), true)
                            },
                          )
                      ),
                    ]
                )),
            ),

            bottomNavigationBar: Padding(
                padding: const EdgeInsets.all(8.0),
                child: rBox(
                    context,
                    colorBack,
                    TextButton(
                      child: Text('Back', style: whiteText),
                      onPressed: () {
                        goToPage(context, const OpenJob(), false);
                      },
                    )
                ),
            )
        )
    );
  }
}

class ScanItem extends StatefulWidget {
  const ScanItem({super.key});
  @override
  State<ScanItem> createState() => _ScanItem();
}
class _ScanItem extends State<ScanItem> {
  TextEditingController searchCtrl= TextEditingController();
  FocusNode searchFocus = FocusNode();
  TextEditingController countCtrl = TextEditingController();
  FocusNode countFocus = FocusNode();
  List<dynamic> searchItem = List.empty();
  bool found = false;
  bool wholeBarcode = true;
  bool autofocusSearch = false;

  @override
  void initState() {
    super.initState();
    searchFocus.unfocus();
    autofocusSearch = true;
    countCtrl.text = "0.0";
    found = false;
    searchFocus.requestFocus();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    searchFocus.dispose();
    countCtrl.dispose();
    countFocus.dispose();
    //searchItem.clear();
    super.dispose();
  }

  _clearFocus(){
    searchFocus.unfocus();
    countFocus.unfocus();
  }

  _scanString(String value){
    if(value.isNotEmpty){
      // Go through table and split barcode string by comma
      for(int i = 0; i < jobTable.length; i++){
        var split = (jobTable[i][1].toString()).split(",").toList();
        for (int j = 0; j < split.length; j++){
          // Trim whitespace and check against scan value
          if (value == split[j].trim()){
            found = true;
            searchItem = jobTable[i];
            return;
          }
        }
      }
    }

    found = false;
    searchItem = List.empty();
  }

  @override
  Widget build(BuildContext context) {
    double keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: const Text("Barcode Scanning", textAlign: TextAlign.center),
          ),

          body: GestureDetector(
              onTapDown: (_) => _clearFocus(),
              child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 20.0, bottom: 5),
                      ),

                      headerPadding("Barcode:", TextAlign.left),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 15.0),
                          child: Card(
                            child: ListTile(
                              // trailing: SizedBox(
                              //   height: double.infinity,
                              //   child: IconButton(
                              //     icon: const Icon(Icons.clear),
                              //     onPressed: (){
                              //       searchCtrl.text = "";
                              //     },
                              //   ),
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
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 15.0),
                          child: Card(
                            child: ListTile(
                              title: Text("${found ? searchItem[tDescription] : "EMPTY"}", style: found ? blackText : greyText, textAlign: TextAlign.center,),
                            ),
                          ),
                      ),
                      GestureDetector(
                        //onTapDown: (_) => _clearFocus(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0),
                          child: Card(
                              child: ListTile(
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    //_clearFocus();
                                    if(found){
                                      double count = (double.tryParse(countCtrl.text) ?? 0.0) + 1;
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
                                    //_clearFocus();
                                    if(found){
                                      double count = (double.tryParse(countCtrl.text) ?? 0.0) - 1.0;
                                      countCtrl.text = max(count, 0).toString();
                                    }
                                    refresh(this);
                                  },
                                ),
                              )
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                        child: rBox(
                          context,
                          found ? colorOk : colorDisable,
                          TextButton(
                              child: Text(found ? 'ADD ITEM' : 'ADD NOF', style: whiteText),
                              onPressed: () {
                                if(!found){
                                  addNOF(context, searchCtrl.text, double.tryParse(countCtrl.text) ?? 0.0);

                                  // Refresh search string
                                  searchCtrl.text = "";
                                  found = false;
                                  searchItem = List.empty();

                                  refresh(this);
                                }
                                else if(found)
                                {
                                  double count = (double.tryParse(countCtrl.text) ?? 0.0);
                                  if(count <= 0){
                                    //showNotification(context, colorWarning, whiteText, "Count is zero (0), can't add zero items", "");
                                    return;
                                  }

                                  countCtrl.text = "0.0";
                                  job.literals.add({"index" : searchItem[tIndex], "count" : count, "location" : job.location,});
                                  job.calcTotal();
                                  String shortDescript = searchItem[tDescription];
                                  if(shortDescript.length > 18)
                                  {
                                    shortDescript = shortDescript.substring(0, 15);
                                    shortDescript += "...";
                                  }

                                  //showNotification(context, colorWarning, whiteText, "Added [$count] $shortDescript", "");
                                  refresh(this);
                                }
                              }
                          ),
                        ),
                      ),
                    ],
                  )
              )
          ),

          bottomSheet: GestureDetector(
              onTapDown: (_) => _clearFocus(),
              child: SingleChildScrollView(
                  child: Center(
                    child: Column(
                        children: [
                          rBox(context, colorBack, TextButton(
                            child: Text("Back", style: whiteText),
                            onPressed: () async {
                              job.calcTotal();
                              //Navigator.pop(context);
                              goToPage(context, const Stocktake(), false);
                            },
                          )
                          ),
                        ]
                    ),
                  )
              )
          )
        )
    );
  }
}

class GridView extends StatefulWidget {
  final ActionType action;

  const GridView({
    super.key,
    required this.action,
  });

  @override
  State<GridView>  createState() => _GridView();
}
class _GridView extends State<GridView> {
  FocusNode barcodeFocus = FocusNode();
  FocusNode ordercodeFocus = FocusNode();
  FocusNode priceFocus = FocusNode();
  FocusNode descriptionFocus = FocusNode();
  FocusNode countFocus = FocusNode();
  FocusNode locationFocus = FocusNode();
  FocusNode searchFocus = FocusNode();
  // FocusNode uomFocus = FocusNode();
  // TextEditingController uomCtrl = TextEditingController();
  TextEditingController barcodeCtrl = TextEditingController();
  TextEditingController ordercodeCtrl = TextEditingController();
  TextEditingController priceCtrl = TextEditingController();
  TextEditingController descriptionCtrl = TextEditingController();
  TextEditingController countCtrl = TextEditingController();
  TextEditingController locationCtrl = TextEditingController();
  TextEditingController categoryCtrl = TextEditingController();
  TextEditingController searchCtrl = TextEditingController();
  List<List<dynamic>> filterList = List.empty();
  List<String> barcodeList = List.empty();
  List<String> ordercodeList = List.empty();

  String categoryValue = "MISC";
  double keyboardHeight = 20.0;
  int barcodeIndex = 0;
  int ordercodeIndex = 0;
  int sortType = 0;

  @override
  void initState() {
    super.initState();
    filterList = widget.action == ActionType.edit ? job.literalList() : jobTable; //;_getMainList();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    descriptionCtrl.dispose();
    countCtrl.dispose();
    locationCtrl.dispose();
    categoryCtrl.dispose();

    barcodeFocus.dispose();
    ordercodeFocus.dispose();
    priceFocus.dispose();
    descriptionFocus.dispose();
    countFocus.dispose();
    locationFocus.dispose();
    searchFocus.dispose();

    super.dispose();
  }

  _setTextFields(int index){
    if (widget.action == ActionType.edit){
      // Get index of item inside the job table (or mainTable)
      final int tableIndex = filterList[index][iIndex];

      barcodeIndex = 0;
      barcodeList = jobTable[tableIndex][tBarcode].toString().toUpperCase().split(",").toList();
      if(barcodeList.isNotEmpty){
        barcodeCtrl.text = barcodeList[barcodeIndex];
      }
      else {
        barcodeCtrl.text = "";
      }

      ordercodeIndex = 0;
      ordercodeList = jobTable[tableIndex][tOrdercode].toString().toUpperCase().split(",").toList();
      if(ordercodeList.isNotEmpty){
        ordercodeCtrl.text = ordercodeList[ordercodeIndex];
      }
      else {
        ordercodeCtrl.text = "";
      }

      descriptionCtrl.text = jobTable[tableIndex][tDescription];
      categoryValue = jobTable[tableIndex][tCategory].toString().toUpperCase();
      // ordercodeCtrl.text = jobTable[tableIndex][tOrdercode].toString();
      countCtrl.text = filterList[index][iCount].toString();
      locationCtrl.text = filterList[index][iLocation].toString();
      priceCtrl.text = jobTable[tableIndex][tPrice].toString();
    }
    else{
      barcodeIndex = 0;

      var spl = filterList[index][tBarcode].toString().toUpperCase().split(",").toList();
      if(spl.isNotEmpty){
        // debugPrint("BARCODE LENGTH: ${spl.length}");
        barcodeCtrl.text = spl[barcodeIndex];
      }
      else
      {
        barcodeCtrl.text = "";
      }

      //barcodeCtrl.text = filterList[index][tBarcode].toString().toUpperCase();
      categoryValue = filterList[index][tCategory].toString().toUpperCase();
      descriptionCtrl.text = filterList[index][tDescription];
      ordercodeCtrl.text = filterList[index][tOrdercode].toString();
      //String uomCheck = filterList[index][tUom].toString().toUpperCase();
      //uomCtrl.text = uomCheck != "NULL" ? uomCheck : "EACH";
      priceCtrl.text = filterList[index][tPrice].toString();
      countCtrl.text = "0.0";
      locationCtrl.text = widget.action == ActionType.view ? "DEF_LOCATION" : job.location;
    }
  }

  _clearFocus(){
    // uomFocus.focus();
    barcodeFocus.unfocus();
    ordercodeFocus.unfocus();
    descriptionFocus.unfocus();
    priceFocus.unfocus();
    countFocus.unfocus();
    locationFocus.unfocus();
    ordercodeFocus.unfocus();
  }

  _searchList() {
    return Card(
      shadowColor: Colors.black38,
      child: ListTile(
        leading: const Icon(Icons.search),
        title: TextField(
            controller: searchCtrl,
            focusNode: searchFocus,
            decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none),
            onSubmitted: (String value) { // onChanged: -> if faster work flow
              if(widget.action == ActionType.edit){
                filterList = job.literalList();
              }
              else{
                filterList = jobTable;
              }

              if (value.isEmpty || value == "") {
                refresh(this);
                return;
              }

              bool found = false;
              String search = value.toUpperCase();
              List<String> searchWords = search.split(' ').where((String s) => s.isNotEmpty).toList();

              for (int i = 0; i < searchWords.length; i++) {
                if (!found) {
                  List<List<dynamic>> first = List.empty();
                  if (widget.action == ActionType.edit){
                    first = job.literalList().where((List<dynamic> column) =>
                        column[tDescription].split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
                  }
                  else{
                    first = jobTable.where((List<dynamic> column) =>
                        column[tDescription].split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
                  }

                  if (first.isNotEmpty) {
                    filterList = first;
                    found = true;
                  }
                }
                else {
                  // Check if any remaining search words are inside the filtered list
                  var refined = filterList.where((List<dynamic> column) =>
                      column[tDescription].split(' ').where((s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
                  if (refined.isNotEmpty) {
                    filterList = refined; // refine filter list to reduce search items
                  }
                }
              }

              if (!found){
                filterList = List.empty();
              }
              else{
                _sortFilterList();
              }

              refresh(this);
            }
        ),
      ),
    );
  }

  _sortFilterList(){
    if(sortType == 0){
      debugPrint("SORTED LIST BY DESCRIPTION A-Z");
      filterList = filterList..sort((x, y) => (x[tDescription][0] as dynamic).compareTo((y[tDescription][0] as dynamic)));
    }
    // else if(sortType == 1){
    //   debugPrint("SORTED LIST BY DESCRIPTION Z-A");
    //   filterList = filterList..sort((y, x) => (x[tDescription][0] as dynamic).compareTo((y[tDescription][0] as dynamic)));
    // }
    // else if (sortType == 2){
    //   debugPrint("SORTED LIST BY CATEGORY");
    //   filterList = filterList..sort((x, y) => (y[tCategory][0] as dynamic).compareTo((x[tCategory][0] as dynamic)));
    // }
  }

  _editCount() {
    return GestureDetector(
        onTapDown: (_) => _clearFocus(),
        child: Padding(
          padding: const EdgeInsets.only(
              left: 15.0, right: 15.0, top: 0, bottom: 5),
          child: Card(
              child: ListTile(
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    _clearFocus();
                    double count = (double.tryParse(countCtrl.text) ?? 0.0) + 1;
                    countCtrl.text = count.toString();
                    // refresh(this);
                  },
                ),
                title: TextField(
                  scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight),
                  controller: countCtrl,
                  focusNode: countFocus,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    _clearFocus();
                    double count = (double.tryParse(countCtrl.text) ?? 0.0) - 1.0;
                    countCtrl.text = max(count, 0.0).toString();
                    // refresh(this);
                  },
                ),
              )
          )
      )
    );
  }

  _deleteItem(int index) {
    job.literals.removeAt(index);
    job.calcTotal();
    filterList = job.literalList();
    Navigator.pop(context);

    //goToPage(context, const TableView2(action: ActionType.edit), false);

    // job.literals.removeAt(index);
    // job.calcTotal();
    // refresh(this);
    // goToPage(context, const TableView2(action: ActionType.edit), false);
    // Navigator.pop(context);
  }

  _checkFields(){
    if(barcodeCtrl.text.isEmpty){
      barcodeCtrl.text = '0';
    }
    if(ordercodeCtrl.text.isEmpty){
      ordercodeCtrl.text = '';
    }
    // if(uomCtrl.text.isEmpty){
    //   uomCtrl.text = "EACH";
    // }
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

  _editStock(int index) {
    return StatefulBuilder(builder: (context, setState){
      return Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
            onTapDown: (_) => _clearFocus(),
            child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height/20.0,
                    ),
                    Padding(
                        padding: const EdgeInsets.only(left:15, right: 15, bottom: 5, top: 15),
                        child: Card(
                            color: Colors.red.withOpacity(0.9),
                            child: ListTile(
                                title: Text("DELETE ITEM", textAlign: TextAlign.center, style: whiteText),
                                trailing: IconButton(
                                    icon: const Icon(Icons.delete_forever_sharp, color: Colors.white),
                                    onPressed: () async {
                                      _clearFocus();
                                      await confirmDialog(context, "Remove Item from stock count?").then((bool value2) async{
                                        if(value2){
                                          _deleteItem(index);
                                        }
                                      });
                                    }
                                )
                            )
                        )
                    ),
                    titlePadding("Location:", TextAlign.left),
                    GestureDetector(
                        onTapDown: (_) => _clearFocus(),
                        child: editTextCard(locationCtrl, locationFocus, '', keyboardHeight)
                    ),
                    titlePadding("Count:", TextAlign.left),
                    _editCount(),
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
                          colorOk,
                          TextButton(
                            child: Text('Confirm', style: whiteText),
                            onPressed: () async{
                              double countNum = double.tryParse(countCtrl.text) ?? 0.0;
                              if (countNum <= 0) {
                                await confirmDialog(context, "Item count is 0\nRemove item from stocktake?").then((bool value) async {
                                  if(value){
                                    _deleteItem(index);
                                  }
                                });
                              }
                              else {
                                await confirmDialog(context, "Confirm changes to stock item?").then((bool value) async {
                                  if (value) {
                                    job.literals[index]["count"] = countNum;
                                    job.literals[index]["location"] = locationCtrl.text.toUpperCase();
                                    job.calcTotal();

                                    // Add location to list if it doesn't exist
                                    if (!job.allLocations.contains(locationCtrl.text.toUpperCase())) {
                                      job.allLocations.add(locationCtrl.text.toUpperCase());
                                    }
                                    filterList = job.literalList();
                                    //goToPage(context, const Stocktake(), false);
                                    Navigator.pop(context);
                                  }
                                });
                              }
                              refresh(this);
                            },
                          )
                      ),
                      rBox(
                          context,
                          colorBack,
                          TextButton(
                            child: Text('Cancel', style: whiteText),
                            onPressed: (){
                              //goToPage(context, const Stocktake(), false);
                              Navigator.pop(context);
                            },
                          )
                      ),
                    ]
                )
            )
        ),
      );
    });
  }

  _editNOF(int index) {
    return StatefulBuilder(
      builder: (context, setState){
        return Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,

          body: GestureDetector(
              onTapDown: (_) => _clearFocus(),
              child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height/20.0,
                      ),

                      titlePadding("Barcode:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => _clearFocus(),
                          child: Padding(
                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                              child: Card(
                                  child: ListTile(
                                    trailing: IconButton(
                                      icon: Icon(Icons.arrow_forward_sharp, color: barcodeIndex >= (barcodeList.length - 1) ? Colors.white.withOpacity(0.3) : Colors.grey),
                                      onPressed: () {
                                        barcodeIndex = min(barcodeIndex + 1, max(barcodeList.length-1 , 0));
                                        barcodeCtrl.text = barcodeList[barcodeIndex];
                                        setState(() {});
                                      },
                                    ),
                                    title: TextField(
                                      scrollPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height/4.0),
                                      controller: barcodeCtrl,
                                      textAlign: TextAlign.center,
                                      onSubmitted: (value) {
                                        if(barcodeCtrl.text != "###" && barcodeCtrl.text != ""){
                                          barcodeList[barcodeIndex] = barcodeCtrl.text;
                                        }
                                        else{
                                          showAlert(context, "", "Barcode format is not correct", colorWarning);
                                          barcodeCtrl.text = barcodeList[barcodeIndex];
                                        }
                                        setState((){});
                                      },
                                    ),
                                    subtitle: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_forever_sharp, color: Colors.red),
                                          onPressed: () {
                                            if(barcodeList.length > 1){
                                              barcodeList.removeAt(barcodeIndex);
                                              if(barcodeIndex >= barcodeList.length){
                                                barcodeIndex = barcodeList.length-1;
                                              }
                                            }
                                            setState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.fiber_new_rounded, color: Colors.blue),
                                          onPressed: () {
                                            barcodeList.add("");
                                            barcodeIndex = barcodeList.length - 1;
                                            barcodeCtrl.text = barcodeList[barcodeIndex];
                                            barcodeFocus.requestFocus();
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),

                                    leading: IconButton(
                                      icon: Icon(Icons.arrow_back_sharp, color: barcodeIndex < 1 ? Colors.white.withOpacity(0.3) : Colors.grey),
                                      onPressed: () {
                                        barcodeIndex = max(barcodeIndex - 1, 0);
                                        barcodeCtrl.text = barcodeList[barcodeIndex];
                                        setState(() {});
                                      },
                                    ),
                                  )
                              )
                          )
                      ),

                      titlePadding("Order Code:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => _clearFocus(),
                          child: Padding(
                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                              child: Card(
                                  child: ListTile(
                                    trailing: IconButton(
                                      icon: Icon(Icons.arrow_forward_sharp, color: ordercodeIndex >= (ordercodeList.length - 1) ? Colors.white.withOpacity(0.3) : Colors.grey),
                                      onPressed: () {
                                        ordercodeIndex = min(ordercodeIndex + 1, max(ordercodeList.length-1 , 0));
                                        ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                        setState(() {});
                                      },
                                    ),
                                    title: TextField(
                                      scrollPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height/4.0),
                                      controller: ordercodeCtrl,
                                      textAlign: TextAlign.center,
                                      onSubmitted: (value) {
                                        if(ordercodeCtrl.text != ""){
                                          ordercodeList[ordercodeIndex] = ordercodeCtrl.text;
                                        }
                                        else{
                                          showAlert(context, "", "Ordercode format is not correct", colorWarning);
                                          ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                        }
                                        setState((){});
                                      },
                                    ),
                                    subtitle: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_forever_sharp, color: Colors.red),
                                          onPressed: () {
                                            if(ordercodeList.length > 1){
                                              ordercodeList.removeAt(ordercodeIndex);
                                              if(ordercodeIndex >= ordercodeList.length){
                                                ordercodeIndex = ordercodeList.length-1;
                                              }
                                            }
                                            setState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.fiber_new_rounded, color: Colors.blue),
                                          onPressed: () {
                                            ordercodeList.add("");
                                            ordercodeIndex = ordercodeList.length - 1;
                                            ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                            ordercodeFocus.requestFocus();
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),

                                    leading: IconButton(
                                      icon: Icon(Icons.arrow_back_sharp, color: ordercodeIndex < 1 ? Colors.white.withOpacity(0.3) : Colors.grey),
                                      onPressed: () {
                                        ordercodeIndex = max(ordercodeIndex - 1, 0);
                                        ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                        setState(() {});
                                      },
                                    ),
                                  )
                              )
                          )
                      ),

                      titlePadding("Category:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => _clearFocus(),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                            child: Card(
                              child: DropdownButton<String>(
                                value: categoryValue,
                                isExpanded: true,
                                menuMaxHeight: MediaQuery.of(context).size.height / 2.0,
                                icon: const Icon(Icons.keyboard_arrow_down),
                                onChanged:((value) {
                                  setState(() {
                                    categoryValue = value!;
                                  });
                                }),
                                items: masterCategory.map((String value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Center(child:Text(value, textAlign: TextAlign.center,),),
                                  );
                                }).toList(),
                              ),
                            ),
                          )
                      ),

                      titlePadding("Description:", TextAlign.left),
                      GestureDetector(
                          onTapDown: (_) => _clearFocus(),
                          child: editTextCard(descriptionCtrl, descriptionFocus, 'E.G. PETERS I/CREAM VAN 1L',  keyboardHeight + 15.0)
                      ),

                      titlePadding("Price:", TextAlign.left),
                      GestureDetector(
                        onTapDown: (_) => _clearFocus(),
                        child: editDecimalCard(priceCtrl, priceFocus, '', keyboardHeight)
                      ),

                      // titlePadding("UOM:", TextAlign.left),
                      // GestureDetector(
                      //     onTapDown: (_) => _clearFocus(),
                      //     child: editTextField(uomCtrl, uomFocus, 'EACH', keyboardHeight)
                      // ),
                    ],
                  )),
          ),

          bottomNavigationBar: SingleChildScrollView(
              child: Center(
                  child: Column(
                      children: [
                        rBox(context, colorOk,
                            TextButton(
                              child: Text('Confirm', style: whiteText),
                              onPressed: () async{
                                await confirmDialog(context, "Confirm changes to NOF item?").then((bool value) async {
                                  _checkFields();
                                  if (value) {
                                    final itemIndex = filterList[index][iIndex];
                                    final nofIndex = itemIndex - mainTable!.rows.length;

                                    //debugPrint(nofIndex.toString());

                                    int badIndex = -1;
                                    String finalBarcode = "";

                                    for(int i = 0; i < barcodeList.length; i++){
                                      if(barcodeExists(barcodeList[i], itemIndex)){
                                        badIndex = i;
                                        break;
                                      }

                                      if(i > 0){
                                        finalBarcode += ",${barcodeList[i]}";
                                      }
                                      else{
                                        finalBarcode += barcodeList[i];
                                      }
                                    }

                                    if(badIndex != -1){
                                      debugPrint(barcodeList[badIndex]);
                                      showAlert(context, "", "NOF contains duplicate barcode: ${barcodeList[badIndex]}\nRemove this barcode or get a new one (contact Andy).", colorWarning);
                                    }
                                    else{

                                      String finalOrdercode = "";
                                      for(int i = 0; i < ordercodeList.length; i++){
                                        if(i > 0){
                                          finalOrdercode += ",${ordercodeList[i]}";
                                        }
                                        else{
                                          finalOrdercode += ordercodeList[i];
                                        }
                                      }

                                      job.nof[nofIndex]["barcode"] = finalBarcode;
                                      job.nof[nofIndex]["category"] = categoryValue;
                                      job.nof[nofIndex]["description"] = descriptionCtrl.text.toUpperCase();
                                      job.nof[nofIndex]["uom"] = "EACH";//uomCtrl.text;
                                      job.nof[nofIndex]["price"] = double.tryParse(priceCtrl.text) ?? 0.0;
                                      job.nof[nofIndex]["datetime"] = "${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}";
                                      job.nof[nofIndex]["ordercode"] = finalOrdercode;
                                      job.nof[nofIndex]["nof"] = true;

                                      // Refresh jobTable
                                      jobTable = mainTable!.rows + job.nofList();
                                      filterList = widget.action == ActionType.edit ? job.literalList() : jobTable;
                                      Navigator.pop(context);
                                    }
                                  }
                                });

                                refresh(this);
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
          ),

        );
      },
    );
  }

  _addStock(int index){
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
          onTapDown: (_) => _clearFocus(),
          child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height/20.0,
                  ),

                  titlePadding("Description:", TextAlign.left),
                  Card(
                      child: ListTile(
                        title: Text(filterList[index][tDescription], style: greyText),
                      )
                  ),

                  titlePadding("Category:", TextAlign.left),
                  Card(
                      child: ListTile(
                        title: Text(filterList[index][tCategory] ?? 'MISC', style: greyText),
                      )
                  ),

                  // titlePadding("Current Location:", TextAlign.left),
                  // Card(
                  //     child: ListTile(
                  //       title: Text(job.location, style: greyText),
                  //     )
                  // ),

                  titlePadding("Add Count:", TextAlign.left),
                  _editCount(),
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
                        colorOk,
                        TextButton(
                          child: Text('Confirm', style: whiteText),
                          onPressed: (){
                            double count = double.tryParse(countCtrl.text) ?? 0.0;
                            if(count <= 0){
                              showAlert(context, "", "Cannot add zero (0) items", colorWarning);
                              countCtrl.text = "0";
                              return;
                            }
                            job.literals.add({"index" : filterList[index][tIndex], "count" : count, "location" : job.location,});
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
                  ]
              )
          )
      ),
    );
  }

  _viewFields(int index){
    return StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height/20.0,
                  ),

                  titlePadding("Description:", TextAlign.left),
                  Card(
                      child: ListTile(
                        title: Text(filterList[index][tDescription], style: greyText),
                      )
                  ),

                  titlePadding("Barcode(s):", TextAlign.left),
                  Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                      child: Card(
                          child: ListTile(
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                setState(() {
                                  var spl = (filterList[index][tBarcode].toString().toUpperCase()).split(",").toList();
                                  barcodeIndex = min(barcodeIndex + 1, spl.length-1);
                                  barcodeCtrl.text = spl[barcodeIndex];
                                });
                              },
                            ),
                            title: Text(barcodeCtrl.text, textAlign: TextAlign.center),
                            leading: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                setState(() {
                                  var spl = filterList[index][tBarcode].toString().toUpperCase().split(",").toList();
                                  barcodeIndex = max(barcodeIndex - 1, 0);
                                  barcodeCtrl.text = spl[barcodeIndex];
                                });
                              },
                            ),
                          )
                      )
                  ),

                  titlePadding("Order Code: ", TextAlign.left),
                  Card(
                    child: ListTile(
                      title: Text(filterList[index][tOrdercode] ?? "", style: greyText),
                    )
                  ),

                  titlePadding("Category:", TextAlign.left),
                  Card(
                      child: ListTile(
                        title: Text(filterList[index][tCategory] ?? 'MISC', style: greyText),
                      )
                  ),

                  titlePadding("UOM:", TextAlign.left),
                  Card(
                      child: ListTile(
                        title: Text(filterList[index][tUom], style: greyText),
                      )
                  ),

                  titlePadding("Price:", TextAlign.left),
                  Card(
                      child: ListTile(
                        title: Text(filterList[index][tPrice].toString(), style: greyText),
                      )
                  ),
                ],
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
                              onPressed: (){
                                Navigator.pop(context);
                              },
                            )
                        ),
                      ]
                  )
              )
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
    var size = MediaQuery.of(context).size; /*24 is for notification bar on Android*/
    final double itemHeight = (size.height - kToolbarHeight - 24) / 2;
    final double itemWidth = size.width / 2;
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: <Widget>[
                SliverAppBar(
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
                  ),
                    actions: [
                      PopupMenuButton(
                          itemBuilder: (context) {
                            return [
                              PopupMenuItem<int>(
                                value: 0,
                                child: Card(
                                  child: ListTile(
                                    title: const Text("Sort by Description A-Z"),
                                    trailing: sortType == 0 ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                                  ),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 1,
                                child: Card(
                                  child: ListTile(
                                    title: const Text("Sort by Description Z-A"),
                                    trailing: sortType == 1 ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                                  ),
                                ),
                              ),
                              PopupMenuItem<int>(
                                value: 2,
                                child: Card(
                                  child: ListTile(
                                    title: const Text("Sort by Category"),
                                    trailing: sortType == 2 ? const Icon(Icons.check_box) : const Icon(Icons.check_box_outline_blank),
                                  ),
                                ),
                              ),

                              // const PopupMenuItem<int>(
                              //   value: 2,
                              //   child: Text("Default sort"),
                              // ),
                            ];
                          },
                          onSelected: (value) {
                            sortType = value;
                            _sortFilterList();
                            refresh(this);
                          }
                      ),
                    ]
                ),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: (itemWidth / itemHeight) * 8.0,
                  ),
                  delegate: SliverChildBuilderDelegate( (BuildContext context, int pIndex) {
                    if (pIndex >= filterList.length){
                      return null;
                    }
                    return GestureDetector(
                      onTapDown: (_) => _clearFocus(),
                      child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black38.withOpacity(0.8),
                              style: BorderStyle.solid,
                              width: 2.0,
                            ),
                            color: Colors.black,
                          ),
                          child: Card(
                              child: ListTile(
                                trailing: filterList[pIndex][0] < mainTable!.rows.length ? null : IconButton(
                                  onPressed: () async {
                                    refresh(this);
                                    _clearFocus();
                                    _setTextFields(pIndex);
                                    await showGeneralDialog(
                                      context: context,
                                      barrierColor: Colors.black12, // Background color
                                      barrierDismissible: false,
                                      barrierLabel: 'Dialog',
                                      transitionDuration: const Duration(milliseconds: 100),
                                      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
                                        return _editNOF(pIndex);
                                        },
                                    ).then((value){refresh(this);});
                                    },
                                  icon: const Icon(Icons.edit_note, color: Colors.black,),
                                ),
                                title: Text(jobTable[(filterList[pIndex][iIndex])][tDescription], style: blackText, textAlign: TextAlign.center, softWrap: true),
                                subtitle: widget.action == ActionType.edit ?
                                    Text("\nCount: ${filterList[pIndex][iCount]}       Loc: ${filterList[pIndex][iLocation]}", textAlign: TextAlign.center, softWrap: true,) :
                                    Text("\n${filterList[pIndex][tCategory]}", textAlign: TextAlign.center),
                                onTap: () async {
                                    _clearFocus();
                                    _setTextFields(pIndex);
                                    await showGeneralDialog(
                                      context: context,
                                      barrierColor: Colors.black12, // Background color
                                      barrierDismissible: false,
                                      barrierLabel: 'Dialog',
                                      transitionDuration: const Duration(milliseconds: 100),
                                      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
                                        return widget.action == ActionType.add ? _addStock(pIndex) :
                                        widget.action == ActionType.edit ? _editStock(pIndex) :
                                        _viewFields(pIndex);
                                      },
                                    ).then((value){refresh(this);});
                                },
                                onLongPress: (){
                                  itemCopy = filterList[pIndex];
                                  showNotification(context, colorWarning, whiteText, "", "Item copied @[$pIndex]");
                                  //debugPrint(filterList[pIndex].toString());
                                },
                              )
                          )
                      )
                    );
                    },
                  ),
                )
              ],
            ),

            bottomSheet: SingleChildScrollView(
                 child: Center(
                     child: Column(
                         children: [
                           _searchList(),
                         ]
                     )
                 )
             ),

            bottomNavigationBar: Padding(
                padding: const EdgeInsets.all(8.0),
                child: rBox(
                  context,
                  colorBack,
                  TextButton(
                    child: Text('Back', style: whiteText),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                )
            )
        )
    );
  }
}

setLocation(BuildContext context1){
  Future<String> textEditDialog(BuildContext context, String str) async{
    String originalText = str;
    String newText = originalText;
    var textFocus = FocusNode();
    TextEditingController txtCtrl = TextEditingController();
    txtCtrl.text = originalText;

    await showDialog(
      context: context1,
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

    txtCtrl.dispose();
    textFocus.dispose();

    return newText;
  }

  showGeneralDialog(
      context: context1,
      barrierColor: Colors.black12, // Background color
      barrierDismissible: false,
      barrierLabel: 'Dialog',
      transitionDuration: const Duration(milliseconds: 100),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
        return StatefulBuilder(
            builder: (context, setState) {
             return Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  centerTitle: true,
                  title: const Text("Select Location", textAlign: TextAlign.center),
                ),
                body: SingleChildScrollView(
                    child: Column(
                        children: [
                          const Padding(padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 30, bottom: 5),),
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
                                      await textEditDialog(context, job.allLocations[index]).then((value){
                                        if(value.isNotEmpty){
                                          job.allLocations[index] = value;
                                          job.allLocations = job.allLocations.toSet().toList();
                                        }
                                        else {
                                          showNotification(context, colorDisable, blackText, "Location text cannot be empty", "");
                                        }
                                      });
                                      setState((){});
                                    },
                                  ),
                                  onLongPress: () async {
                                    bool b = await confirmDialog(context, "Delete location '${job.allLocations[index]}'?");
                                    if(b){
                                      if(job.location == job.allLocations[index]) {
                                        job.location = "";
                                      }
                                      job.allLocations.removeAt(index);
                                      setState((){});
                                    }
                                  },
                                  onTap: () {
                                    job.location = job.allLocations[index];
                                    setState((){});
                                    //Navigator.pop(context);
                                    goToPage(context, const Stocktake(), true);
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
                        child: Column(
                            children: [
                              rBox(
                                  context,
                                  Colors.lightBlue,
                                  TextButton(
                                    child: Text('NEW LOCATION', style: whiteText),
                                    onPressed: () async {
                                      await textEditDialog(context, "").then((value) {
                                        if(value.isNotEmpty && !job.allLocations.contains(value)){
                                          job.allLocations.add(value);
                                        }
                                      });

                                      setState((){});
                                    },
                                  )
                              ),
                              rBox(
                                  context,
                                  colorBack,
                                  TextButton(
                                    child: Text('BACK', style: whiteText),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      //goToPage(context, const Stocktake(), false);
                                    },
                                  )
                              )
                            ]
                        )
                    )
                ),
              );
            });
        }
  );
}

addNOF(BuildContext context1, String barcode, double nCount){
  List<String> barcodeList = List.empty();
  int barcodeIndex = 0;
  List<String> ordercodeList = List.empty();
  int ordercodeIndex = 0;

  TextEditingController barcodeCtrl = TextEditingController();
  var barcodeFocus = FocusNode();
  TextEditingController ordercodeCtrl = TextEditingController();
  var ordercodeFocus = FocusNode();

  TextEditingController priceCtrl = TextEditingController();
  var priceFocus = FocusNode();
  TextEditingController descriptionCtrl = TextEditingController();
  var descriptionFocus = FocusNode();
  TextEditingController countCtrl = TextEditingController();
  var countFocus = FocusNode();
  String categoryValue = "MISC";

  barcodeList = barcode.split(",").toList();
  if(barcodeList.isNotEmpty){
    barcodeCtrl.text = barcodeList[barcodeIndex];
  }
  else {
    barcodeCtrl.text = "###";
  }

  categoryValue = "MISC";
  descriptionCtrl.text = "";

  ordercodeCtrl.text = "";

  priceCtrl.text = "0.0";
  countCtrl.text = nCount.toString();

  //uomCtrl.text = "EACH";
  //locationCtrl.text = job.location;
  //locationFocus.unfocus();

  void clearFocus(){
    barcodeFocus.unfocus();
    countFocus.unfocus();
    descriptionFocus.unfocus();
    ordercodeFocus.unfocus();

    priceFocus.unfocus();
  }

  void disposeControllers(){
    barcodeCtrl.dispose();
    countCtrl.dispose();
    descriptionCtrl.dispose();
    ordercodeCtrl.dispose();
    priceCtrl.dispose();
    barcodeFocus.dispose();
    countFocus.dispose();
    descriptionFocus.dispose();
    ordercodeFocus.dispose();
    priceFocus.dispose();
  }

  showGeneralDialog(
    context: context1,
    barrierColor: Colors.black12, // Background color
    barrierDismissible: false,
    barrierLabel: 'Dialog',
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
      return StatefulBuilder(
        builder: (context, setState) {
          return Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: Colors.black,

              body: GestureDetector(
                  onTapDown: (_) => clearFocus,
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
                                child: Padding(
                                    padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                                    child: Card(
                                        child: ListTile(
                                          trailing: IconButton(
                                            icon: Icon(Icons.arrow_forward_sharp, color: barcodeIndex >= (barcodeList.length - 1) ? Colors.white.withOpacity(0.3) : Colors.grey),
                                            onPressed: () {
                                              barcodeIndex = min(barcodeIndex + 1, max(barcodeList.length-1 , 0));
                                              barcodeCtrl.text = barcodeList[barcodeIndex];
                                              //setState(() {});
                                            },
                                          ),
                                          title: TextField(
                                            scrollPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height/4.0),
                                            controller: barcodeCtrl,
                                            textAlign: TextAlign.center,
                                            onSubmitted: (value) {
                                              if(barcodeCtrl.text != "###" && barcodeCtrl.text != ""){
                                                // MUST REMOVE COMMAS OR LIST WILL BE MESSED UP
                                                barcodeList[barcodeIndex] =  barcodeCtrl.text.replaceAll(",", "");
                                              }
                                              else{
                                                showAlert(context, "", "Barcode format is not correct", colorWarning);
                                                barcodeCtrl.text = barcodeList[barcodeIndex];
                                              }
                                              //setState((){});
                                            },
                                          ),
                                          subtitle: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_forever_sharp, color: Colors.red),
                                                    onPressed: () {
                                                      if(barcodeList.length > 1){
                                                        barcodeList.removeAt(barcodeIndex);
                                                        if(barcodeIndex >= barcodeList.length){
                                                          barcodeIndex = barcodeList.length-1;
                                                        }
                                                      }
                                                      //setState(() {});
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.fiber_new_rounded, color: Colors.blue),
                                                    onPressed: () {
                                                      barcodeList.add("");
                                                      barcodeIndex = barcodeList.length - 1;
                                                      barcodeCtrl.text = barcodeList[barcodeIndex];
                                                      //setState(() {});
                                                    },
                                                  ),
                                                ],
                                              )
                                          ),

                                          leading: IconButton(
                                            icon: Icon(Icons.arrow_back_sharp, color: barcodeIndex < 1 ? Colors.white.withOpacity(0.3) : Colors.grey),
                                            onPressed: () {
                                              barcodeIndex = max(barcodeIndex - 1, 0);
                                                barcodeCtrl.text = barcodeList[barcodeIndex];
                                                //setState(() {});
                                              },
                                          ),
                                        )
                                    )
                                )
                            ),

                            titlePadding("Order Code:", TextAlign.left),
                            GestureDetector(
                                onTapDown: (_) => clearFocus(),
                                child: Padding(
                                    padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                                    child: Card(
                                        child: ListTile(
                                          trailing: IconButton(
                                            icon: Icon(Icons.arrow_forward_sharp, color: ordercodeIndex >= (ordercodeList.length - 1) ? Colors.white.withOpacity(0.3) : Colors.grey),
                                            onPressed: () {
                                              ordercodeIndex = min(ordercodeIndex + 1, max(ordercodeList.length-1 , 0));
                                              ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                              //setState(() {});
                                            },
                                          ),
                                          title: TextField(
                                            scrollPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height/4.0),
                                            controller: ordercodeCtrl,
                                            textAlign: TextAlign.center,
                                            onSubmitted: (value) {
                                              if(ordercodeCtrl.text.isNotEmpty && ordercodeCtrl.text != ""){
                                                // MUST REMOVE COMMAS OR LIST WILL BE MESSED UP
                                                ordercodeList[ordercodeIndex] =  ordercodeCtrl.text.replaceAll(",", "");
                                              }
                                              else{
                                                showAlert(context, "", "Barcode format is not correct", colorWarning);
                                                ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                              }
                                              //setState((){});
                                            },
                                          ),
                                          subtitle: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_forever_sharp, color: Colors.red),
                                                    onPressed: () {
                                                      if(ordercodeList.length > 1){
                                                        ordercodeList.removeAt(ordercodeIndex);
                                                        if(ordercodeIndex >= ordercodeList.length){
                                                          ordercodeIndex = ordercodeList.length-1;
                                                        }
                                                      }
                                                      //setState(() {});
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.fiber_new_rounded, color: Colors.blue),
                                                    onPressed: () {
                                                      ordercodeList.add("");
                                                      ordercodeIndex = ordercodeList.length - 1;
                                                      ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                                      //setState(() {});
                                                    },
                                                  ),
                                                ],
                                              )
                                          ),

                                          leading: IconButton(
                                            icon: Icon(Icons.arrow_back_sharp, color: ordercodeIndex < 1 ? Colors.white.withOpacity(0.3) : Colors.grey),
                                            onPressed: () {
                                              ordercodeIndex = max(ordercodeIndex - 1, 0);
                                              ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                              //setState(() {});
                                            },
                                          ),
                                        )
                                    )
                                )
                            ),

                            titlePadding("Description:", TextAlign.left),
                            GestureDetector(
                                onTapDown: (_) => clearFocus(),
                                child: editTextCard(descriptionCtrl, descriptionFocus, 'Description', 0.0)
                            ),

                            titlePadding("Category:", TextAlign.left),
                            GestureDetector(
                                onTapDown: (_) => clearFocus(),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
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
                                        setState(() {
                                          categoryValue = newValue!;
                                        });
                                      },
                                    ),
                                  ),
                                )
                            ),

                            // titlePadding("UOM:", TextAlign.left),
                            // GestureDetector(
                            //     onTapDown: (_) => clearFocus(),
                            //     child: editTextField(uomCtrl, uomFocus, 'EACH', keyboardHeight)
                            // ),

                            // GestureDetector(
                            //     onTapDown: (_) => clearFocus(),
                            //     child: editTextCard(ordercodeCtrl, ordercodeFocus, '',  0.0)
                            // ),

                            titlePadding("Price:", TextAlign.left),
                            Padding(
                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                              child: Card(
                                  child: ListTile(
                                    title: TextField(
                                      //scrollPadding:  EdgeInsets.symmetric(vertical: 0.0),
                                      controller: priceCtrl,
                                      focusNode: priceFocus,
                                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                    ),
                                  )
                              ),
                            ),

                            // titlePadding("Location:", TextAlign.left),
                            // GestureDetector(
                            //     onTapDown: (_) => clearFocus(),
                            //     child: editTextCard(locationCtrl, locationFocus, '', 0.0)
                            // ),

                            titlePadding("Add to Stocktake:", TextAlign.left),
                            Padding(
                                padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                                child: Card(
                                    child: ListTile(
                                      trailing: IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () {
                                          clearFocus();
                                          double count = (double.tryParse(countCtrl.text) ?? 0.0)+ 1;
                                          countCtrl.text = count.toString();
                                          // refresh(this);
                                        },
                                      ),
                                      title: TextField(
                                        //scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight),
                                        controller: countCtrl,
                                        focusNode: countFocus,
                                        textAlign: TextAlign.center,
                                        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                      ),
                                      leading: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () {
                                          clearFocus();
                                          double count = (double.tryParse(countCtrl.text) ?? 0.0) - 1.0;
                                          countCtrl.text = max(count, 0.0).toString();
                                          // refresh(this);
                                        },
                                      ),
                                    )
                                )
                            ),
                            itemCopy.isNotEmpty ? Padding(
                                padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                                child: Card(
                                    child: ListTile(
                                      tileColor: colorWarning,
                                      title: TextButton(
                                        child: Text("Paste copied item", style: whiteText),
                                        onPressed:() {
                                          barcodeIndex = 0;
                                          barcodeCtrl.text = "###"; // Need new barcode number otherwise duplicate will be detected
                                          categoryValue = itemCopy[tCategory];
                                          descriptionCtrl.text = itemCopy[tDescription].toString();
                                          ordercodeCtrl.text = itemCopy[tOrdercode].toString() == "null" ? "" : itemCopy[tOrdercode].toString();
                                          priceCtrl.text = itemCopy[tPrice].toString();
                                          countCtrl.text = "0";
                                          //locationCtrl.text = job.location;
                                          setState((){});
                                        }
                                      )
                                    )
                                )
                            ) : Container(),
                          ]
                      )
                  )
              ),
            bottomNavigationBar: SingleChildScrollView(
                child: Center(
                    child: Column(
                        children: [
                          rBox(
                              context,
                              colorOk,
                              TextButton(
                                child: Text('Confirm', style: whiteText),
                                onPressed: () {
                                  int badIndex = -1;

                                  String finalBarcode = "";
                                  for(int i = 0; i < barcodeList.length; i++){
                                    if(barcodeExists(barcodeList[i], -1)){
                                      badIndex = i;
                                      break;
                                    }

                                    if(i > 0){
                                      finalBarcode += ",${barcodeList[i]}";
                                    }
                                    else{
                                      finalBarcode += barcodeList[i];
                                    }
                                  }

                                  if(badIndex != -1){
                                    debugPrint(barcodeList[badIndex]);
                                    showAlert(context, "", "NOF contains duplicate barcode: ${barcodeList[badIndex]}\nRemove this barcode or get a new one (contact Andy).", colorWarning);
                                  }
                                  else if (descriptionCtrl.text.isEmpty){
                                    showAlert(context, "", "Description text must not be empty!", colorWarning);
                                  }
                                  else{
                                    if(ordercodeCtrl.text.isEmpty){
                                      ordercodeCtrl.text = '0';
                                    }
                                    if(priceCtrl.text.isEmpty){
                                      priceCtrl.text = '0.0';
                                    }
                                    if(countCtrl.text.isEmpty){
                                      countCtrl.text = '0.0';
                                    }
                                    // if(locationCtrl.text.isEmpty){
                                    //   locationCtrl.text = job.location;
                                    // }

                                    int newIndex = jobTable.length;

                                    // Add to NOF list
                                    job.nof.add({
                                      "index": newIndex,
                                      "barcode": finalBarcode,
                                      "category": categoryValue,
                                      "description": descriptionCtrl.text.toUpperCase(),
                                      "uom": "EACH",//uomCtrl.text,
                                      "price": double.tryParse(priceCtrl.text) ?? 0.0,
                                      "datetime" : "${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}",
                                      "ordercode" : ordercodeCtrl.text,
                                      "nof": true,
                                    });

                                    jobTable = mainTable!.rows + job.nofList();

                                    double countNum = double.tryParse(countCtrl.text) ?? 0.0;

                                    // Add NOF to stocktake if applicable
                                    if (countNum > 0) {
                                      job.literals.add({
                                        "index": newIndex,
                                        "count": countNum,
                                        "location": job.location,
                                      });

                                      job.calcTotal();
                                    }

                                    disposeControllers();
                                    Navigator.pop(context);
                                  }
                                },
                              )
                          ),
                          rBox(
                              context,
                              colorBack,
                              TextButton(
                                child: Text('Cancel', style: whiteText),
                                onPressed: (){
                                  disposeControllers();
                                  Navigator.pop(context);
                                },
                              )
                          ),
                        ]
                    )
                )
            ),
          );
        },
      );
    },
  );
}

refresh(var widget) {
  widget.setState(() {});
}

shortFilePath(String s) {
  var sp = s.split("/");
  return sp[sp.length - 1];
}

getDateString(String d){
  const gsDateBase = 2209161600 / 86400;
  const gsDateFactor = 86400000;

  final date = double.tryParse(d);
  if (date == null) return "NO DATE RECORDED";
  final millis = (date - gsDateBase) * gsDateFactor;

  var fd = (DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)).toString();
  fd = fd.substring(0, 10);
  fd = fd.replaceAll("/", "_");
  return fd;

  //(DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)).toString();
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
    // animate ? MaterialPageRoute(builder: (BuildContext context) {return page;})
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
        duration: const Duration(milliseconds: 1200),
        padding: const EdgeInsets.all(15.0),  // Inner padding for SnackBar content.
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.7,
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

Widget editTextCard(TextEditingController txtCtrl, FocusNode focus, String hint, double keyHeight){
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
          ),
        ),
      )
  );
}

Widget editDecimalCard(TextEditingController txtCtrl, FocusNode focus, String hint, double keyHeight){
  return Padding(
    padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
    child: Card(
        child: ListTile(
          title: TextField(
            scrollPadding:  EdgeInsets.symmetric(vertical: keyHeight),
            controller: txtCtrl,
            focusNode: focus,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
          ),
        )
    ),
  );
}

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

Future<void> loadMasterSheet() async {
  Uint8List bytes;
  final path = await _localPath;
  String filePath = "$path/MASTERFILE_19032023.xlsx";
  await Future.delayed(const Duration(microseconds: 0));
  if(!File(filePath).existsSync()){
    ByteData data = await rootBundle.load("assets/MASTERFILE_19032023.xlsx");
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(filePath).writeAsBytes(bytes);
  }
  else{
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
    masterCategory = <String>["CATERING", "CHEMICALS", "CONSUMABLES", "INVOICE", "MISC"];
  }

  // Remove header row
  mainTable!.rows.removeRange(0, 1);
}

exportJobToXLSX() async {

  CellStyle oldDate = CellStyle(backgroundColorHex: '#FF8980');

  List<List<dynamic>> finalSheet = [];

  for(int i =0; i < job.literals.length; i++){
    bool skip = false;
    var tableIndex = job.literals[i]["index"];
    for(int j = 0; j < finalSheet.length; j++) {
      // Check if item already exists
      skip = finalSheet[j][0] == tableIndex;
      if(skip){
        // Add price and count to existing item
        finalSheet[j][4] += job.literals[i]["count"];
        finalSheet[j][5] += jobTable[tableIndex][5] * job.literals[i]["count"];
        break;
      }
    }

    // Item doesn't exist, so add new item to list
    if(!skip){
      finalSheet.add([
        jobTable[tableIndex][tIndex], //INDEX
        jobTable[tableIndex][tCategory], //CATEGORY
        jobTable[tableIndex][tDescription], // DESCRIPTION
        jobTable[tableIndex][tUom], // UOM
        job.literals[i]['count'], // COUNT
        jobTable[tableIndex][tPrice] * job.literals[i]['count'], // TOTAL COST
        jobTable[tableIndex][tBarcode], // BARCODE
        (tableIndex >= mainTable!.rows.length).toString().toUpperCase(), // NOF
        jobTable[tableIndex][tDatetime].toString(), // DATETIME
        jobTable[tableIndex][tOrdercode].toString(), // ORDERCODE
      ]);
    }
  }

  var excel = Excel.createExcel();
  var sheetObject = excel['Sheet1'];
  sheetObject.isRTL = false;

  // Add header row
  sheetObject.insertRowIterables(["Master Index", "Category", "Description", "UOM", 'QTY', "Cost Ex GST", "Barcode", "NOF", "Datetime", "Ordercode"], 0);

  for(int i = 0; i < finalSheet.length; i++){
    List<String> row = [];

    for(int j = 0; j < finalSheet[i].length; j++){
      // Check date and color cell...somehow...
      row.add(finalSheet[i][j].toString());
    }

    sheetObject.insertRowIterables(row, i+1);
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
        // huh?
      });
    }
  });

  filePath = '/storage/emulated/0/Documents/$jobStartStr${job.id}_0';

  // Check if file exists
  if(!overwrite){
    String num = '0';
    bool readyWrite = false;

    while(!readyWrite){
      await File(filePath).exists().then((value){
        if(value){
          // Add iterable value at end of file
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
}

writeSession() async {
  Map<String, dynamic> jMap = {
    "uid" : "",
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
      "uid" : "",
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
      "uid" : jsn['uid'] == null || jsn["uid"].isEmpty ? "USER" :  jsn['uid'] as String,
      "fontScale" : jsn['fontScale'] == null ? 20.0 : jsn['fontScale'] as double,
      "dropScale" : jsn['dropScale'] == null ? 50.0 : jsn['dropScale'] as double
    };
    return false;
  }
}

bool barcodeExists(String barcode, int ignore){
  if (barcode.trim().isEmpty){
    return false;
  }

  for(int n = 0; n < jobTable.length; n++) {
    if (n != ignore){
      if(jobTable[n][tBarcode].split(",").toList().contains(barcode)){
        return true;
      }
    }
  }

  return false;
}

void gunDataTXT(){
  var startString = "S     ";
  var locString = "";
}
