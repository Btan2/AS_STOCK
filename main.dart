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
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

Permission storageType = Permission.manageExternalStorage; //Permission.storage;
String jobStartStr = "ASJob_";
StockJob job = StockJob(id: "EMPTY", name: "EMPTY");
List<String> jobList = [];
List<String> masterCategory = [];
List<List<dynamic>> jobTable = List.empty();
Map<String, dynamic> sFile = {};
Directory? rootDir;
SpreadsheetTable? mainTable;
int scanType = 0;
int copyIndex = -1;
String copyCode = "";

enum ActionType {add, edit, assignBarcode, assignOrdercode}

// Table item indices
const int tIndex = 0;
const int tBarcode = 1;
const int tCategory = 2;
const int tDescription = 3;
const int tUom = 4;
const int tPrice = 5;
const int tDatetime = 6;
const int tOrdercode = 7;

// Stocktake item indices
const int iIndex = 0;
const int iCount = 1;
const int iLocation = 2;

// Shortened Month names
List<String> monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "July", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Colors
Color colorOk = Colors.blue.shade400;
Color colorAssign = Colors.teal;
Color colorEdit = Colors.blueGrey;
Color colorWarning = Colors.deepPurple.shade200;
Color colorDisable = Colors.blue.shade200;
Color colorBack = Colors.redAccent;

// Text style
TextStyle get warningText{ return TextStyle(color: Colors.red[900], fontSize: sFile["fontScale"]);}
TextStyle get whiteText{ return TextStyle(color: Colors.white, fontSize: sFile["fontScale"]);}
TextStyle get rText{ return TextStyle(color: Colors.red.shade400, fontSize: 16.0);}
TextStyle get greyText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}
TextStyle get blackText{ return TextStyle(color: Colors.black, fontSize: sFile["fontScale"]);}
TextStyle get titleText{ return const TextStyle(color: Colors.black87, fontSize: 20.0, fontWeight: FontWeight.bold);}
TextStyle get blueText{ return const TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold);}

void main() {
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
    setState(() {});
    //refresh(this);

    // Check for new version
    // Link to new version/download and install option?
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                  setState(() {});

                                  // load default spreadsheet
                                  await loadMasterSheet().then((value) async{
                                    if(mainTable != null || mainTable!.maxRows > 0){
                                      await showAlert(context, "", 'Master Spreadsheet was loaded successfully', colorOk).then((value) async{
                                        await getSession().then((value){
                                          setState(() {});
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const JobsPage()));
                                        });
                                      });
                                    }
                                  });
                                }
                                else{
                                  await getSession().then((value){
                                    setState(() {});
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
                                setState(() {});
                                await loadMasterSheet().then((value) async {
                                  await showAlert(context, "", 'Master Spreadsheet was loaded successfully', colorOk).then((value) {
                                    setState(() {});
                                    goToPage(context, const HomePage());
                                  });
                                });
                              },
                            )
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
                                setState(() {});
                                await loadMasterSheet().then((value) async {
                                  await showAlert(context, "", 'Master Spreadsheet was loaded successfully', colorOk).then((value) async{
                                    await getSession().then((value){
                                      goToPage(context, const AppSettings());
                                    });
                                  });
                                });
                              }
                              else{
                                await getSession().then((value){
                                  goToPage(context, const AppSettings());
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
      return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: (){
                goToPage(context, const HomePage());
              },
            ),
            centerTitle: true,
            title: const Text('App Settings'),
            automaticallyImplyLeading: false,
          ),
          body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  setState(() {});
                                },
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  sFile["fontScale"] += sFile["fontScale"] + 1 < 30 ? 1 : 0;
                                  setState(() {});
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
                                setState(() {});
                              }),
                            ),
                          ),
                        )
                    ),
                  ],
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

    setState(() {});
  }

  _readJob(String path) async {
    var jsn = File(path);
    String fileContent = await jsn.readAsString(); //await
    var dynamic = json.decode(fileContent);
    job = StockJob.fromJson(dynamic);
    job.calcTotal();
  }

  Future<String> _pickFile(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: (){
                job = StockJob(id: "EMPTY", name: "EMPTY");
                goToPage(context, const HomePage());
              },
            ),
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
                                title: Text(jobList[index].split("/").last),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_forever_sharp),
                                  color: Colors.redAccent,
                                  onPressed: () {
                                    jobList.removeAt(index);
                                    setState(() {});
                                  },
                                ),
                                onTap: () async {
                                  if(access) {
                                    await _readJob(jobList[index]).then((value) {
                                      jobTable = mainTable!.rows + job.nofList();
                                      copyIndex = -1;
                                      goToPage(context, const Stocktake());
                                    });
                                  }
                                  else{
                                    showAlert(context, "!! ALERT !!", "* Read/Write permissions were DENIED \n* Try changing storage permissions in App Settings", Colors.red[900]!);
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
                                      goToPage(context, NewJob());
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
                                        await _pickFile(context).then((String value){
                                          path = value;
                                        });

                                        // Check if path is valid
                                        if(path.isEmpty || path == "null" || !path.contains(jobStartStr)){
                                          return;
                                        }
                                        if(!jobList.contains(path)){
                                          jobList.add(path);
                                        }

                                        // Copy job file to documents folder if it is not there
                                        await _copyJobFile(path);
                                        await _readJob(path).then((value) async {
                                          jobTable = mainTable!.rows + job.nofList();
                                          copyIndex = -1;
                                          goToPage(context, const Stocktake());
                                        });
                                      }
                                      else {
                                        showAlert(context, "!! ALERT !!", "* Read/Write permissions were DENIED \n* Try changing storage permissions in App Settings", Colors.red[900]!);
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
        );
  }
}

class NewJob extends StatelessWidget{
  NewJob({super.key});

  final StockJob newJob = StockJob(id: "NULL", name: "EMPTY");
  final TextEditingController idCtrl = TextEditingController();
  final idFocus = FocusNode();
  final TextEditingController nameCtrl = TextEditingController();
  final nameFocus = FocusNode();


  String regexFormat(String s){
    String regex = r'[^\p{Alphabetic}\p{Mark}\p{Decimal_Number}\p{Connector_Punctuation}\p{Join_Control}\s]+';
    String fString = s.replaceAll(RegExp(regex, unicode: true),'');

    if (fString.contains("/")){
      fString = fString.replaceAll("/", '');
    }

    if (fString.contains("_")){
      fString = fString.replaceAll("_", '');
    }

    if (fString.contains(".")){
      fString = fString.replaceAll(".", '');
    }

    return fString;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: (){
                Navigator.pop(context, true);
              },
            ),
            centerTitle: true,
            title: const Text("New Job"),
            automaticallyImplyLeading: false,
          ),
          body: GestureDetector(
              onTap: () {
                FocusScopeNode currentFocus = FocusScope.of(context);
                if (!currentFocus.hasPrimaryFocus) {
                  currentFocus.unfocus();
                }
              },
              child: SingleChildScrollView(
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
                              // Job must need ID
                              if(idCtrl.text.isEmpty){
                                showAlert(context, "JOB ID IS EMTPY", "", Colors.orange);
                                return;
                              }

                              newJob.id = regexFormat(idCtrl.text);

                              // Using jobID for name if no name exists
                              if(nameCtrl.text.isEmpty){
                                nameCtrl.text = "Job${idCtrl.text}";
                              }

                              newJob.name = regexFormat(nameCtrl.text);

                              newJob.date = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

                              String path = "/storage/emulated/0/Documents/$jobStartStr${newJob.id}_0";

                              // Do not overwrite any other existing jobs
                              writeJob(newJob, false);

                              job = newJob;
                              job.calcTotal();
                              if(!jobList.contains(path)){
                                jobList.add(path);
                              }

                              jobTable = mainTable!.rows + job.nofList();

                              idCtrl.dispose();
                              nameCtrl.dispose();
                              copyIndex = -1;
                              goToPage(context, const Stocktake());
                            },
                          )
                      ),
                    ]
                    )
                )
            ),
          )
      )
    );
  }
}

class Stocktake extends StatelessWidget {
  const Stocktake({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: (){
            goToPage(context, const JobsPage());
            copyIndex = -1;
          },
        ),
        centerTitle: true,
        title: const Text("Stocktake", textAlign: TextAlign.center),
        automaticallyImplyLeading: false,
      ),

      body:SingleChildScrollView(
        child: Center(
            child: Column(
                children: [
                  Card(
                    child: ListTile(
                      title: Text("${job.id}\n${job.date.replaceAll("_", "/")}\n Total: ${job.total}"),
                      leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                    ),
                  ),
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
                        child: Text('SCAN & SEARCH', style: whiteText),
                        onPressed: () {
                          if (job.location.isNotEmpty) {
                            goToPage(context, const GridView(action: ActionType.add));
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
                        child: Text('EDIT STOCKTAKE', style: whiteText),
                        onPressed: () {
                          job.stocktake.isNotEmpty ? goToPage(context, const GridView(action: ActionType.edit)) :
                          showAlert(context, "Alert", "Stocktake is empty.", colorDisable);
                        },
                      )
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height / 30.0,
                  ),
                  rBox(
                      context,
                      Colors.orange.shade700,
                      TextButton(
                        child: Text('EXPORT STOCKTAKE', style: whiteText),
                        onPressed: () {
                          goToPage(context, const ExportPage());
                        },
                      )
                  ),
                ]
            )),
      ),
    );
  }
}

class ExportPage extends StatelessWidget{
  const ExportPage({super.key});

  _getDateString(String d){
    const gsDateBase = 2209161600 / 86400;
    const gsDateFactor = 86400000;

    final date = double.tryParse(d);
    if (date == null) return "NO DATE RECORDED";
    final millis = (date - gsDateBase) * gsDateFactor;

    var fd = (DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)).toString();
    fd = fd.substring(0, 10);
    fd = fd.replaceAll("-", "/");

    var fls = fd.split("/");
    if(fls[2].length < 2){
      fls[2] = "0${fls[2]}";
    }

    fd = "${fls[2]}/${fls[1]}/${fls[0]}";

    return fd;
    //(DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)).toString();
  }

  _exportXLSX() async {
    List<List<dynamic>> finalSheet = [];
    for(int i =0; i < job.stocktake.length; i++){
      bool skip = false;
      var tableIndex = job.stocktake[i]["index"];
      for(int j = 0; j < finalSheet.length; j++) {
        // Check if item already exists
        skip = finalSheet[j][0] == tableIndex;
        if(skip){
          // Add price and count to existing item
          finalSheet[j][4] += job.stocktake[i]["count"];
          finalSheet[j][5] += jobTable[tableIndex][tBarcode] * job.stocktake[i]["count"];
          break;
        }
      }

      // Item doesn't exist, so add new item to list
      if(!skip){

        bool nof = tableIndex >= mainTable!.rows.length;
        String date = jobTable[tableIndex][tDatetime].toString();
        if(!nof){
          date = _getDateString(date).toString();
        }

        finalSheet.add([
          jobTable[tableIndex][tIndex].toString(), //INDEX
          jobTable[tableIndex][tCategory].toString(), //CATEGORY
          jobTable[tableIndex][tDescription].toString(), // DESCRIPTION
          jobTable[tableIndex][tUom].toString(), // UOM
          job.stocktake[i]['count'].toString(), // COUNT
          (jobTable[tableIndex][tPrice] * job.stocktake[i]['count']).toString(), // TOTAL COST
          jobTable[tableIndex][tBarcode].toString(), // BARCODE
          nof.toString().toUpperCase(), // NOF
          date, // DATETIME
          (jobTable[tableIndex][tOrdercode] ?? 0).toString(), // ORDERCODE
        ]);
      }
    }

    var excel = Excel.createExcel();
    var sheetObject = excel['Sheet1'];
    sheetObject.isRTL = false;

    // Add header row
    sheetObject.insertRowIterables(["Master Index", "Category", "Description", "UOM", 'QTY', "Cost Ex GST", "Barcode", "NOF", "Datetime", "Ordercode"], 0,);
    for(int i = 0; i < finalSheet.length; i++){
      sheetObject.insertRowIterables(
          <String> [
            finalSheet[i][0],
            finalSheet[i][1],
            finalSheet[i][2],
            finalSheet[i][3],
            finalSheet[i][4],
            finalSheet[i][5],
            finalSheet[i][6],
            finalSheet[i][7],
            finalSheet[i][8],
            finalSheet[i][9],
          ],
          i+1
      );

      // if(finalSheet[i][7] == "FALSE"){
      //   debugPrint(finalSheet[i][8].toString());
      // }
      // else{
      //   debugPrint(finalSheet[i][8].toString());
      // }

      // Color code cell if date is older than 1 year
      if((DateTime.now().year - int.parse(finalSheet[i][8].split("/").first)) > 0){
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: i+1));
        cell.cellStyle = CellStyle(backgroundColorHex: '#FF8980', fontSize: 10, fontFamily: getFontFamily(FontFamily.Arial));
      }
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
    File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
  }

  _gunDataTXT(){
    String finalTxt = "";
    for(int i = 0; i < job.stocktake.length; i++){
      finalTxt += "S    ";

      var tableIndex = job.stocktake[i]["index"];

      // Barcodes (22 characters)
      // Using first barcode since barcodes can be multiline
      String bcode = jobTable[tableIndex][tBarcode].toString().split(",").toList()[0];

      for (int b = bcode.length; b < 22; b++){
        bcode += " ";
      }

      finalTxt += bcode;

      // Count (4 characters)
      String count = job.stocktake[i]["count"].toString();
      for (int c = count.length; c < 4; c++){
        count += " ";
      }

      finalTxt += count;

      // Location (25 characters)
      String loc = job.stocktake[i]["location"].toString();
      if(loc.length > 25){
        loc.substring(0,25);
      }

      for (int l = loc.length; l < 25; l++){
        loc += " ";
      }

      finalTxt += loc;
      finalTxt += "\n";
    }

    String date = job.date.toString().replaceAll("_", "-");
    var path = '/storage/emulated/0/Documents/$date-${job.id}-fdapp.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);
  }

  _exportHL(){
    String finalTxt = "";
    String dateTime = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}${DateTime.now().hour}/${DateTime.now().minute}/${DateTime.now().second}";
    for(int i = 0; i < job.stocktake.length; i++) {
      // Location (4 chars)
      String loc = job.stocktake[i]["location"];
      String locationNum = job.allLocations.indexOf(loc).toString();
      while(locationNum.length < 4){
        locationNum = "0$locationNum";
      }
      finalTxt += "$locationNum,";

      // Barcode (16 chars)
      var tableIndex = job.stocktake[i]["index"];
      String bcode = jobTable[tableIndex][tBarcode].toString().split(",").toList()[0];
      while(bcode.length < 16){
        bcode += " ";
      }
      finalTxt += "$bcode,";

      // Qty (5 chars + 1 whitespace)
      String sCount = job.stocktake[i]["count"].toString();
      if(sCount.contains(".")){
        sCount = double.parse(job.stocktake[i]["count"]).toStringAsFixed(1);
      }
      while(sCount.length < 5){
        sCount = "0$sCount";
      }
      finalTxt += "$sCount ,";

      finalTxt += dateTime;
      finalTxt += "\n";
    }

    String shortMonth = monthNames[DateTime.now().month - 1];
    String shortYear = DateTime.now().year.toString().substring(2);
    debugPrint(shortYear);

    String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
    var path = '/storage/emulated/0/Documents/IMPORT_${job.name}_$dateOutput.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);
  }

  _exportBarcodeQty(){
    String finalTxt = "";
    for(int i = 0; i < job.stocktake.length; i++) {
      // Barcodes (22 characters)
      // Using first barcode since barcodes can be multiline
      var tableIndex = job.stocktake[i]["index"];
      String bcode = jobTable[tableIndex][tBarcode].toString().split(",").toList()[0];

      while(bcode.length < 22){
        bcode += " ";
      }

      finalTxt += "$bcode, ";
      finalTxt += double.parse(job.stocktake[i]['count']).toStringAsFixed(1);
      finalTxt += "\n";
    }

    String shortMonth = monthNames[DateTime.now().month - 1];
    String shortYear = DateTime.now().year.toString().substring(2);
    String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
    var path = '/storage/emulated/0/Documents/BARCODEQTY_${job.id}_$dateOutput.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);

  }

  _exportOrdercodeQty(){
    String finalTxt = "";
    for(int i = 0; i < job.stocktake.length; i++) {
      // Barcodes (22 characters) Using first barcode since barcodes can be multiline
      var tableIndex = job.stocktake[i]["index"];
      String ocode = jobTable[tableIndex][tOrdercode].toString().split(",").toList()[0];

      while(ocode.length < 22){
        ocode += " ";
      }

      finalTxt += "$ocode, ";
      finalTxt += double.parse(job.stocktake[i]['count']).toStringAsFixed(1);
      finalTxt += "\n";
    }

    String shortMonth = monthNames[DateTime.now().month - 1];
    String shortYear = DateTime.now().year.toString().substring(2);
    String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
    var path = '/storage/emulated/0/Documents/ORDERCODEQTY_${job.id}_$dateOutput.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text("Export Stocktake"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: (){
              goToPage(context, const Stocktake());
            },
          ),
        ),
        body: SingleChildScrollView(
            child: Center(
                child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height / 20.0,
                      ),
                      rBox(
                          context,
                          colorOk,
                          TextButton(
                            child:
                            Text('XLSX', style: whiteText),
                            onPressed: () {
                              _exportXLSX();
                              showAlert(context, "Job Data Exported!", "/storage/emulated/0/Documents/stocktake_${job.id}_[num].xlsx\n", Colors.orange);
                            },
                          )
                      ),
                      rBox(
                          context,
                          colorOk,
                          TextButton(
                            child:
                            Text('SCANDATA (.TXT)', style: whiteText),
                            onPressed: () {
                              _gunDataTXT();
                              String date = job.date.toString().replaceAll("_", "-");
                              showAlert(context, "Job Data Exported!", "/storage/emulated/0/Documents/$date-${job.id}-fdapp.txt", Colors.orange);
                            },
                          )
                      ),
                      rBox(
                          context,
                          colorOk,
                          TextButton(
                            child:
                            Text('H&L (POS)', style: whiteText),
                            onPressed: () {
                              _exportHL();
                              String shortMonth = monthNames[DateTime.now().month - 1];
                              String shortYear = DateTime.now().year.toString().substring(2);
                              String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
                              showAlert(context, "Job Data Exported!", '/storage/emulated/0/Documents/IMPORT_${job.name}_$dateOutput.txt', Colors.orange);
                            },
                          )
                      ),
                      rBox(
                          context,
                          colorOk,
                          TextButton(
                            child:
                            Text('Barcode / Qty', style: whiteText),
                            onPressed: () {
                              _exportBarcodeQty();
                              String shortMonth = monthNames[DateTime.now().month - 1];
                              String shortYear = DateTime.now().year.toString().substring(2);
                              String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
                              showAlert(context, "Job Data Exported!", "/storage/emulated/0/Documents/BARCODEQTY_${job.id}_$dateOutput.txt", Colors.orange);
                            },
                          )
                      ),
                      rBox(
                          context,
                          colorOk,
                          TextButton(
                            child:
                            Text('Ordercode / Qty', style: whiteText),
                            onPressed: () {
                              _exportOrdercodeQty();

                              String shortMonth = monthNames[DateTime.now().month - 1];
                              String shortYear = DateTime.now().year.toString().substring(2);
                              String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
                              showAlert(context, "Job Data Exported!", "/storage/emulated/0/Documents/ORDERCODEQTY_${job.id}_$dateOutput.txt", Colors.orange);
                            },
                          )
                      ),
                    ]
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
    required this.action
  });

  @override
  State<GridView>  createState() => _GridView();
}
class _GridView extends State<GridView> {
  FocusNode searchFocus = FocusNode();

  TextEditingController barcodeCtrl = TextEditingController();
  TextEditingController descriptionCtrl = TextEditingController();
  TextEditingController ordercodeCtrl = TextEditingController();
  TextEditingController locationCtrl = TextEditingController();
  TextEditingController priceCtrl = TextEditingController();
  TextEditingController countCtrl = TextEditingController();
  TextEditingController searchCtrl = TextEditingController();

  List<List<dynamic>> filterList = List.empty();
  List<String> barcodeList = List.empty();
  List<String> ordercodeList = List.empty();

  Color colorMode = colorOk;
  String categoryValue = "MISC";
  double keyboardHeight = 20.0;
  int barcodeIndex = 0;
  int ordercodeIndex = 0;

  final int searchDescription = 0;
  final int scanBothCodes = 1;
  final int scanBarcode = 2;
  final int scanOrdercode = 3;

  @override
  void initState() {
    super.initState();
    colorMode = colorOk;

    if(widget.action == ActionType.edit){
      filterList = job.stockList();
    }
    else if(widget.action == ActionType.assignOrdercode || widget.action == ActionType.assignOrdercode){
      filterList = job.nofList();
      colorMode = colorAssign;
    }
  }

  @override
  void dispose() {
    barcodeCtrl.dispose();
    descriptionCtrl.dispose();
    ordercodeCtrl.dispose();
    locationCtrl.dispose();
    priceCtrl.dispose();
    countCtrl.dispose();

    searchCtrl.dispose();
    searchFocus.dispose();

    super.dispose();
  }

  String _setTitle(){
    switch(widget.action){
      case ActionType.assignBarcode:
        return "Assign Barcode";

      case ActionType.assignOrdercode:
        return "Assign Ordercode";

      case ActionType.add:
        if(scanType == searchDescription ){
          return "Search Description";
        }
        else if(scanType == scanBothCodes){
          return "Scan Barcode & Ordercode";
        }
        else if(scanType == scanBarcode ){
          return "Scan Barcode";
        }
        else{
          return  "Scan Ordercode";
        }

      case ActionType.edit:
        return "Edit Stock";

      default:
        break;
    }

    return "";
  }

  _setSearchList(){
    filterList =
      widget.action == ActionType.edit ? job.stockList() :
      widget.action == ActionType.assignBarcode ? job.nofList() :
      widget.action == ActionType.assignOrdercode ? job.nofList() :
      jobTable;
  }

  _setEmptyText(String barcode, String ordercode){
    categoryValue = "MISC";
    countCtrl.text = "0.0";
    descriptionCtrl.text = "";
    locationCtrl.text = job.location;
    priceCtrl.text = "0.0";
    barcodeIndex = 0;
    barcodeList = List.empty(growable: true);
    barcodeList.add("");
    barcodeCtrl.text = barcodeList[barcodeIndex];
    ordercodeIndex = 0;
    ordercodeList = List.empty(growable: true);
    ordercodeList.add("");
    ordercodeCtrl.text = barcodeList[ordercodeIndex];
  }

  _setTextCtrl(int index){
    barcodeIndex = 0;
    barcodeList = List.empty(growable: true);

    ordercodeIndex = 0;
    ordercodeList = List.empty(growable: true);

    if (widget.action == ActionType.edit){
      // EDIT ITEMS USE LIGHTER FORMAT
      // INDEX TO DATA TABLE MUST BE USED INSTEAD OF INDEX TO FILTERLIST
      final int tableIndex = filterList[index][iIndex];

      barcodeList += jobTable[tableIndex][tBarcode].toString().toUpperCase().split(",").toList();
      if(barcodeList.isNotEmpty){
        barcodeCtrl.text = barcodeList[barcodeIndex];
      }
      else {
        barcodeCtrl.text = "";
      }

      ordercodeList += jobTable[tableIndex][tOrdercode].toString().toUpperCase().split(",").toList();
      if(ordercodeList.isNotEmpty){
        ordercodeCtrl.text = ordercodeList[ordercodeIndex];
      }
      else {
        ordercodeCtrl.text = "";
      }

      categoryValue = jobTable[tableIndex][tCategory].toString().toUpperCase();
      descriptionCtrl.text = jobTable[tableIndex][tDescription];
      locationCtrl.text = filterList[index][iLocation].toString();
      priceCtrl.text = jobTable[tableIndex][tPrice].toString();
    }
    else if(widget.action == ActionType.add){
      categoryValue = "MISC";
      descriptionCtrl.text = "";
      priceCtrl.text = "0.0";
      locationCtrl.text = job.location;

      barcodeList.add("");
      barcodeCtrl.text = barcodeList[barcodeIndex];

      ordercodeList.add("");
      ordercodeCtrl.text = barcodeList[ordercodeIndex];
    }
    else{
      barcodeList += filterList[index][tBarcode].toString().toUpperCase().split(",").toList();
      if(barcodeList.isNotEmpty){
        barcodeCtrl.text = barcodeList[barcodeIndex];
      }
      else {
        barcodeCtrl.text = "";
      }

      ordercodeList += filterList[index][tOrdercode].toString().toUpperCase().split(",").toList();
      if(ordercodeList.isNotEmpty){
        ordercodeCtrl.text = ordercodeList[ordercodeIndex];
      }
      else {
        ordercodeCtrl.text = "";
      }

      categoryValue = filterList[index][tCategory].toString().toUpperCase();
      descriptionCtrl.text = filterList[index][tDescription];
      priceCtrl.text = filterList[index][tPrice].toString();
      locationCtrl.text = job.location;
    }
  }

  _searchWords() {
    return Card(
      shadowColor: Colors.black38,
      child: ListTile(
        trailing: IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: () {
            searchCtrl.text = "";
            if (widget.action != ActionType.edit){
              filterList = List.empty();
            }
            setState(() {});
          },
        ),

        title: TextField(
            controller: searchCtrl,
            focusNode: searchFocus,
            decoration: const InputDecoration(hintText: 'Enter search text', border: InputBorder.none),
            onChanged: (String value) { // onSubmitted:

              if (value.isEmpty || value == "") {
                filterList = List.empty();
                setState(() {});
                return;
              }

              _setSearchList();

              bool found = false;
              String search = value.toUpperCase();
              List<String> searchWords = search.split(' ').where((String s) => s.isNotEmpty).toList();

              for (int i = 0; i < searchWords.length; i++) {
                if (!found) {
                  List<List<dynamic>> first = List.empty();
                  first = filterList.where((List<dynamic> column) =>
                      column[tDescription].split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();

                  if (first.isNotEmpty) {
                    filterList = first;
                    found = true;
                  }
                }
                else {
                  // Check if any remaining search words are inside the filtered list
                  List<List<dynamic>> refined = filterList.where((List<dynamic> column) =>
                      column[tDescription].split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
                  // refine filter list to reduce search items
                  filterList = refined..sort((x, y) => (x[tDescription][tIndex] as dynamic).compareTo((y[tDescription][tIndex] as dynamic)));
                }
              }

              if (!found){
                if (widget.action != ActionType.edit){
                  filterList = List.empty();
                }
                else{
                  filterList = job.stockList();
                }
              }

              setState(() {});
            }
        ),
      ),
    );
  }

  _scanCodes(){
    return Card(
      shadowColor: Colors.black38,
      child: ListTile(
        title: TextField(
          decoration: const InputDecoration(hintText: 'Enter scancode', border: InputBorder.none),
          controller: searchCtrl,
          focusNode: searchFocus,
          keyboardType: TextInputType.name,
          onChanged: (String value){

            if(value.isEmpty){
              filterList = List.empty();
              setState(() {});
              return;
            }

            if(scanType == scanBarcode){
              filterList = jobTable.where((List<dynamic> column) =>
                  column[tBarcode].toString().split(',').where((s) => s.isNotEmpty).toList().contains(value.trim())).toList();
            }
            else if(scanType == scanOrdercode){
              filterList = jobTable.where((List<dynamic> column) =>
                  column[tOrdercode].toString().split(',').where((s) => s.isNotEmpty).toList().contains(value.trim())).toList();
            }
            else if (scanType == scanBothCodes){
              filterList = jobTable.where((List<dynamic> column) =>
                  column[tBarcode].toString().split(',').where((s) => s.isNotEmpty).toList().contains(value.trim())).toList();

              filterList += jobTable.where((List<dynamic> column) =>
                  column[tOrdercode].toString().split(',').where((s) => s.isNotEmpty).toList().contains(value.trim())).toList();
            }

            if(filterList.isNotEmpty){
              filterList = filterList..sort((x, y) => (x[tDescription][0] as dynamic).compareTo((y[tDescription][0] as dynamic)));
            }
            else{
              filterList = List.empty();
            }

            setState(() {});
          },
        ),

        trailing: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: (){
            filterList = List.empty();
            searchCtrl.text = "";
            setState(() {});
          },
        ),
      ),
    );
  }

  _assignCode(int pIndex) {
    int tableIndex = filterList[pIndex][tIndex];
    String descript = jobTable[tableIndex][tDescription];
    return Card(
        shadowColor: Colors.white.withOpacity(0.0),
        child: ListTile(
          trailing: tableIndex >= mainTable!.rows.length ? const Icon(Icons.fiber_new, color: Colors.black,) : null,
          title: Text(descript, style: blackText, textAlign: TextAlign.center, softWrap: true),
          subtitle: Text("\n${filterList[pIndex][tCategory]}", textAlign: TextAlign.center, softWrap: true),
          onTap: () async {

            String codeColumn = widget.action == ActionType.assignBarcode ? "barcode" : "ordercode";
            if (tableIndex >= mainTable!.rows.length) {
              String descript = jobTable[tableIndex][tDescription].toString();
              await confirmDialog(context, "Assign $copyCode to $descript?").then((value) async {
                if (value) {

                  int nofIndex = tableIndex - mainTable!.rows.length;

                  String s = job.nof[nofIndex][codeColumn].toString();

                  if(s.isEmpty || s == "NULL" || s == "null") {
                    job.nof[nofIndex][codeColumn] = copyCode;
                  }
                  else {
                    job.nof[nofIndex][codeColumn] += ",$copyCode";
                  }

                  jobTable = mainTable!.rows + job.nofList();

                  copyCode = "";
                  setState(() {});

                  s = job.nof[nofIndex][codeColumn].toString();

                  // debugPrint(s);

                  await writeJob(job, true).then((value){
                    goToPage(context, const GridView(action: ActionType.add));
                  });
                }
              });
            }
          }
        )
    );
  }

  // EDIT or ADD
  _editNOF(int index, String code) {
    _setTextCtrl(index);

    return StatefulBuilder(
      builder: (context, setState){
        return GestureDetector(
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          },
          child: Scaffold(
              backgroundColor: Colors.black,
              resizeToAvoidBottomInset: true,

              appBar: AppBar(
                automaticallyImplyLeading: false,
                centerTitle: true,
                title: widget.action == ActionType.add ? const Text("Add NOF") : const Text("Edit NOF"),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: (){
                    Navigator.pop(context);
                  },
                ),
                actions: [
                  PopupMenuButton(
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem<int>(
                            value: searchDescription,
                            child: ListTile(
                              title: Text("Paste Copied Item", style: copyIndex != -1 ? blackText : greyText),
                            ),
                          ),
                        ];
                      },

                      onSelected: (value) async {
                        if(copyIndex != -1){
                          descriptionCtrl.text = jobTable[copyIndex][tDescription].toString();
                          categoryValue = jobTable[copyIndex][tCategory].toString();
                          priceCtrl.text = jobTable[copyIndex][tPrice].toString();
                        }

                        setState((){});
                      }
                  ),
                ],
              ),

              body: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      titlePadding("Barcode:", TextAlign.left),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 10, bottom: 5),
                          child: Card(
                              child: ListTile(
                                trailing: IconButton(
                                  icon: Icon(Icons.arrow_forward_sharp, color: barcodeIndex >= (barcodeList.length - 1) ? Colors.white.withOpacity(0.3) : Colors.grey),
                                  onPressed: () {
                                    if(barcodeList.length > 1 ){
                                      barcodeIndex = min(barcodeIndex + 1, max(barcodeList.length-1 , 0));
                                      barcodeCtrl.text = barcodeList[barcodeIndex];
                                      setState(() {});
                                    }
                                  },
                                ),
                                title: TextField(
                                  scrollPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height/4.0),
                                  controller: barcodeCtrl,
                                  textAlign: TextAlign.center,
                                  onChanged: (value) {
                                    barcodeList[barcodeIndex] = barcodeCtrl.text;
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
                                        //barcodeFocus.requestFocus();
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),

                                leading: IconButton(
                                  icon: Icon(Icons.arrow_back_sharp, color: barcodeIndex < 1 ? Colors.white.withOpacity(0.3) : Colors.grey),
                                  onPressed: () {
                                    if(barcodeList.length > 1){
                                      barcodeIndex = max(barcodeIndex - 1, 0);
                                      barcodeCtrl.text = barcodeList[barcodeIndex];
                                      setState(() {});
                                    }
                                  },
                                ),
                              )
                          )
                      ),

                      titlePadding("Order Code:", TextAlign.left),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                              child: ListTile(
                                trailing: IconButton(
                                  icon: Icon(Icons.arrow_forward_sharp, color: ordercodeIndex >= (ordercodeList.length - 1) ? Colors.white.withOpacity(0.3) : Colors.grey),
                                  onPressed: () {
                                    if(ordercodeList.length > 1){
                                      ordercodeIndex = min(ordercodeIndex + 1, max(ordercodeList.length - 1 , 0));
                                      ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                      setState(() {});
                                    }
                                  },
                                ),
                                title: TextField(
                                  scrollPadding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height/4.0),
                                  controller: ordercodeCtrl,
                                  textAlign: TextAlign.center,
                                  onChanged: (value) {
                                    ordercodeList[ordercodeIndex] = ordercodeCtrl.text;
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
                                        //ordercodeFocus.requestFocus();
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),

                                leading: IconButton(
                                  icon: Icon(Icons.arrow_back_sharp, color: ordercodeIndex < 1 ? Colors.white.withOpacity(0.3) : Colors.grey),
                                  onPressed: () {
                                    if(ordercodeList.length > 1){
                                      ordercodeIndex = max(ordercodeIndex - 1, 0);
                                      ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                      setState(() {});
                                    }
                                  },
                                ),
                              )
                          )
                      ),

                      titlePadding("Category:", TextAlign.left),
                      Padding(
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
                                  child: Center(
                                      child: Text(value, textAlign: TextAlign.center,)
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ),

                      titlePadding("Description:", TextAlign.left),
                      Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                            child: ListTile(
                              title: TextField(
                                controller: descriptionCtrl,
                                scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight/2),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.name,
                              ),
                            ),
                          )
                      ),

                      titlePadding("Price:", TextAlign.left),
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                            child: ListTile(
                              title: TextField(
                                scrollPadding:  EdgeInsets.symmetric(vertical: keyboardHeight/2),
                                controller: priceCtrl,
                                //focusNode: priceFocus,
                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                              ),
                            )
                        ),
                      ),

                      index == -1 ? titlePadding("Add to Stocktake:", TextAlign.left) : Container(),
                      index == -1 ? Padding(
                          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                          child: Card(
                            child: ListTile(
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  // _clearFocus();
                                  double count = (double.tryParse(countCtrl.text) ?? 0.0)+ 1;
                                  countCtrl.text = count.toString();
                                  setState((){});
                                },
                              ),
                              title: TextField(
                                controller: countCtrl,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                              ),
                              leading: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  // _clearFocus();
                                  double count = (double.tryParse(countCtrl.text) ?? 0.0) - 1.0;
                                  countCtrl.text = max(count, 0.0).toString();
                                  setState((){});
                                },
                              ),
                            )
                        )
                      ) : Container(),
                    ],
                  )
              ),

              bottomNavigationBar: SingleChildScrollView(
                  child: Center(
                    child: Column(
                        children: [
                          rBox(context, colorOk,
                              TextButton(
                                child: Text('Confirm', style: whiteText),
                                onPressed: () async{
                                  String msg = "";

                                  if(widget.action == ActionType.edit){
                                    msg = "Confirm changes to NOF item?";
                                  }
                                  else if (widget.action == ActionType.add){
                                    msg = "Confirm Add NOF to stocktake?\n-> ${descriptionCtrl.text}";
                                  }

                                  await confirmDialog(context, msg).then((bool value) async {
                                    if (value) {
                                      int itemIndex;
                                      int nofIndex;

                                      // NEW NOF
                                      if (index == -1){
                                        itemIndex = -1;
                                        nofIndex = jobTable.length;
                                      }
                                      else{
                                        itemIndex = filterList[index][iIndex];
                                        nofIndex = itemIndex - mainTable!.rows.length;
                                      }

                                      int badIndex = -1;
                                      bool tooLong = false;
                                      bool noDescript = false;

                                      String finalBarcode = "";
                                      if(descriptionCtrl.text.isEmpty){
                                        noDescript = true;
                                        showAlert(context, "", "Description text must not be empty!", colorWarning);
                                      }
                                      else{
                                        for(int i = 0; i < barcodeList.length; i++){
                                          if(barcodeList[i].length > 22){
                                            tooLong = true;
                                            showAlert(context, "", "Barcode is too long: ${barcodeList[badIndex]}\n Barcode exceeds char limit (22).\n", colorWarning);
                                            break;
                                          }

                                          await barcodeExists(barcodeList[i], itemIndex).then((bool value){
                                            if(value){
                                              showAlert(context, "", "NOF contains duplicate barcodes${barcodeList[badIndex]}! \nRemove this barcode or get a new one (contact Andy).", colorWarning);
                                              badIndex = i;
                                            }
                                          });

                                          if(badIndex != -1){
                                            break;
                                          }

                                          if(i > 0){
                                            finalBarcode += ",${barcodeList[i]}";
                                          }
                                          else{
                                            // first barcode in barcodeList should not have a comma
                                            finalBarcode += barcodeList[i];
                                          }
                                        }
                                      }

                                      if(badIndex != -1 || tooLong || noDescript){
                                        //debugPrint(barcodeList[badIndex]);
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

                                        if(index == -1){
                                          // NEW NOF
                                          int nofIndex = jobTable.length;
                                          job.nof.add({
                                            "index" : nofIndex,
                                            "barcode" : finalBarcode,
                                            "category" : categoryValue,
                                            "description" : descriptionCtrl.text.toUpperCase(),
                                            "uom" : "EACH", //uomCtrl.text;
                                            "price" : double.tryParse(priceCtrl.text) ?? 0.0,
                                            "datetime" : "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                                            "ordercode" : finalOrdercode,
                                            "nof" : true,
                                          });

                                          // ADD NEW NOF TO STOCKTAKE IF COUNT IS GOOD
                                          double addCount = double.tryParse(countCtrl.text) ?? 0.0;
                                          if(addCount > 0){
                                            job.stocktake.add({
                                              "index": nofIndex,
                                              "count": addCount,
                                              "location": job.location,
                                            });

                                            job.calcTotal();
                                          }
                                        }
                                        else{
                                          // EDIT NOF
                                          job.nof[nofIndex]["barcode"] = finalBarcode;
                                          job.nof[nofIndex]["category"] = categoryValue;
                                          job.nof[nofIndex]["description"] = descriptionCtrl.text.toUpperCase();
                                          job.nof[nofIndex]["uom"] = "EACH";//uomCtrl.text;
                                          job.nof[nofIndex]["price"] = double.tryParse(priceCtrl.text) ?? 0.0;
                                          job.nof[nofIndex]["datetime"] = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
                                          job.nof[nofIndex]["ordercode"] = finalOrdercode;
                                          job.nof[nofIndex]["nof"] = true;
                                        }

                                        // Refresh jobTable
                                        jobTable = mainTable!.rows + job.nofList();

                                        if(widget.action != ActionType.edit){
                                          filterList = List.empty();
                                        }

                                        searchCtrl.text = "";

                                        await writeJob(job, true).then((value){
                                          Navigator.pop(context);
                                        });
                                      }
                                    }
                                  });

                                  setState(() {});
                                },
                              )
                          ),
                        ]
                    )
                )
            ),
          ),
        );
      },
    );
  }

  _addItem(int pIndex){
    int tableIndex = filterList[pIndex][iIndex];
    String descript = "";

    descript = jobTable[tableIndex][tDescription];

    return Card(
      shadowColor: Colors.white.withOpacity(0.0),
        child: ListTile(
          //trailing: filterList[pIndex][0] < mainTable!.rows.length ? null :
          // IconButton(
          //   onPressed: () async {
          //     setState(() {});
          //     // _clearFocus();
          //     await showGeneralDialog(
          //       context: context,
          //       barrierColor: Colors.black12, // Background color
          //       barrierDismissible: false,
          //       transitionDuration: const Duration(milliseconds: 100),
          //       pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
          //         return _editNOF(pIndex);
          //       },
          //     ).then((value){setState(() {});});
          //   },
          //   icon: const Icon(Icons.fiber_new, color: Colors.black,),
          // ),

          title: Text(descript, style: blackText, textAlign: TextAlign.center, softWrap: true),
          subtitle: Text("\n${filterList[pIndex][tCategory]}", textAlign: TextAlign.center, softWrap: true),

          onTap: () async {
            // _clearFocus();
            await counterConfirm(context, filterList[pIndex][tDescription], 0.0).then((double addCount) async{
              if(addCount != -1){
                job.stocktake.add({
                  "index": tableIndex,
                  "count": addCount,
                  "location": job.location,
                });
                job.calcTotal();

                writeJob(job, true);
                //debugPrint("JOB WRITTEN");
              }
              setState(() {});
            });
          },

          onLongPress: (){
            copyIndex = tableIndex;
            showNotification(context, colorWarning, whiteText, "", "Item copied @[$pIndex]");
          },
        ));
  }

  Widget _editStock(int pIndex){
    int tableIndex = filterList[pIndex][iIndex];
    bool nofItem = filterList[pIndex][0] >= mainTable!.rows.length;
    return Row(
        children: [
          Card(
              shadowColor: Colors.white.withOpacity(0.0),
              child: SizedBox(
                height: 150.0,
                width: MediaQuery.of(context).size.width * 0.75,

                child: ListTile(
                  title: Text(jobTable[tableIndex][tDescription], softWrap: true,),
                  subtitle: Text("Loc: ${filterList[pIndex][iLocation]}"),
                  trailing:  nofItem ? const Icon(Icons.fiber_new, color: Colors.black,) : null,
                  onTap: () async {
                    if(nofItem){
                      // _clearFocus();
                      await showGeneralDialog(
                        context: context,
                        barrierColor: Colors.black12, // Background color
                        barrierDismissible: false,
                        barrierLabel: 'Dialog',
                        transitionDuration: const Duration(milliseconds: 100),
                        pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
                          return _editNOF(pIndex, "");
                        },
                      );
                      setState(() {});
                    }
                  },

                  onLongPress: (){
                    copyIndex = tableIndex;
                    showNotification(context, colorWarning, whiteText, "", "Item copied @[$pIndex]");
                  },
                ),
              )
          ),
          Card(
            color: Colors.white60,
              child: SizedBox(
                  height: 150.0,
                  width: MediaQuery.of(context).size.width * 0.195,
                  child: ListTile(
                    title: Center(child: Text("${filterList[pIndex][iCount]}")),
                    onTap: () async {
                      // _clearFocus();
                      int tableIndex = filterList[pIndex][iIndex];
                      double c = filterList[pIndex][iCount];
                      await counterConfirm(context, jobTable[tableIndex][tDescription], c).then((double newCount) async {
                        if (newCount > -1 && newCount != c){
                          job.stocktake[pIndex]["count"] = newCount;
                          job.calcTotal();
                          writeJob(job, true);
                          //debugPrint("JOB WRITTEN");
                          filterList[pIndex][iCount] = newCount;
                          setState(() {});
                        }
                      });
                    },
                  ),
                )
            )
        ]
    );
  }

  @override
  Widget build(BuildContext context) {
    keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
    var size = MediaQuery.of(context).size; /*24 is for notification bar on Android*/
    final double itemHeight = (size.height - kToolbarHeight - 24) / 2;
    final double itemWidth = size.width / 2;
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },

      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: <Widget>[
            // Hide search bar if editing/viewing stocktake
            SliverAppBar(
              backgroundColor: colorMode,
              floating: true,
              pinned: true,
              collapsedHeight: widget.action != ActionType.edit ? kToolbarHeight * 2 : kToolbarHeight,
              centerTitle: true,
              title: Text(_setTitle()),

              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: (){
                  if (widget.action == ActionType.assignBarcode || widget.action == ActionType.assignOrdercode){
                    goToPage(context, const GridView(action: ActionType.add));
                  } else {
                    goToPage(context, const Stocktake());
                  }
                },
              ),

              actions: [
                PopupMenuButton(
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem<int>(
                          value: searchDescription,
                          child: ListTile(
                            title: const Text("Search description"),
                            trailing: scanType == searchDescription ? const Icon(Icons.check) : null,
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: scanBothCodes,
                          child: ListTile(
                            title: const Text("Scan barcode & ordercode"),
                            trailing: scanType == scanBothCodes ? const Icon(Icons.check) : null,
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: scanBarcode,
                          child: ListTile(
                            title: const Text("Scan barcode only"),
                            trailing: scanType == scanBarcode ? const Icon(Icons.check) : null,
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: scanOrdercode,
                          child: ListTile(
                            title: const Text("Scan ordercode only"),
                            trailing: scanType == scanOrdercode ? const Icon(Icons.check) : null,
                          ),
                        ),
                      ];
                    },

                    onSelected: (value) async {
                      scanType = value;
                      if(value != searchDescription){
                        searchFocus.requestFocus();
                      }
                      setState((){});
                    }
                ),
              ],

              flexibleSpace: widget.action == ActionType.add ? FlexibleSpaceBar(
                collapseMode: CollapseMode.none,
                centerTitle: true,
                titlePadding: const EdgeInsets.only(top: 90.0),
                title: scanType == 0 ? _searchWords() : _scanCodes(),
              ) : Container(),
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

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: colorMode,
                      style: BorderStyle.solid,
                      width: 3.0,
                    ),
                  ),

                  child: widget.action == ActionType.edit ? _editStock(pIndex) :
                  widget.action == ActionType.assignBarcode ? _assignCode(pIndex) :
                  widget.action == ActionType.assignOrdercode ? _assignCode(pIndex) :
                  _addItem(pIndex),
                );
                },
              ),
            ),

            SliverToBoxAdapter(
              child: filterList.isNotEmpty ? Container() : Padding(
                  padding: const EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0),
                  child: Center(
                      child: Text("EMPTY", style: greyText)
                  )
              ),
            ),

            // ADD NOF
            SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0, bottom: 10.0),
                  child: widget.action != ActionType.edit ? Container(
                    height: 50,
                    width: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(color: widget.action == ActionType.add ? colorEdit : colorBack, borderRadius: BorderRadius.circular(5)),
                    child: TextButton(
                      onPressed: () async {
                        if(widget.action != ActionType.add){
                          copyCode = "";
                          goToPage(context, const GridView(action: ActionType.add));
                        }
                        else{
                          // Copy search text if ordercode/barcode only
                          if(scanType < 2){
                            _setEmptyText("", "");
                          }
                          else if (scanType == scanBarcode){
                            _setEmptyText(searchCtrl.text, "");
                          }
                          else if (scanType == scanOrdercode){
                            _setEmptyText("", searchCtrl.text);
                          }
                          await showGeneralDialog(
                              context: context,
                              barrierColor: Colors.black12, // Background color
                              barrierDismissible: false,
                              transitionDuration: const Duration(milliseconds: 100),
                              pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
                                return _editNOF(-1, "");
                              }).then((value){
                                setState(() {});
                              });
                        }
                        },
                      child: Text(widget.action == ActionType.add ? '+ Add NOF' : "Cancel", style: whiteText),
                    ),
                  ) : Container(),
                )
            ),

            // ASSIGN ORDERCODE
            SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: widget.action == ActionType.add && scanType > 0 ? Container(
                    height: 50,
                    width: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(color: colorEdit, borderRadius: BorderRadius.circular(5)),
                    child: TextButton(
                        child: Text('Assign Ordercode to Item', style: whiteText),
                        onPressed: () {
                          // Do not check for duplicate ordercodes?
                          if(searchCtrl.text.isNotEmpty && scanType > 0){
                            copyCode = searchCtrl.text;
                            goToPage(context, const GridView(action: ActionType.assignOrdercode));
                          }
                       }
                    ),
                  ) : Container(),
                )
            ),

            // ASSIGN BARCODE
            SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: widget.action == ActionType.add && scanType > 0 ? Container(
                    height: 50,
                    width: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(color: colorEdit, borderRadius: BorderRadius.circular(5)),
                    child: TextButton(
                        child: Text('Assign Barcode to Item', style: whiteText),
                        onPressed: () async {
                          await barcodeExists(searchCtrl.text, -1).then((value){
                            if(!value){
                              copyCode = searchCtrl.text;
                              goToPage(context, const GridView(action: ActionType.assignBarcode));
                            }
                            else{
                              showAlert(context, "", "Barcode already exists within the stocktake! \n Try a new barcode.", colorWarning);
                            }
                          });
                        }
                    ),
                  ) : Container(),
                )
            ),
        ],
      ),
    ));
  }
}

Widget headerPadding(String title, TextAlign l){
  return Padding(
    padding: const EdgeInsets.all(15.0),
    child: Text(title, textAlign: l, style: const TextStyle(color: Colors.blue, fontSize: 20.0)),
  );
}

Widget titlePadding(String title, TextAlign l){
  return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: DefaultTextStyle(style: blueText, child: Text(title, textAlign: l),)
  );
}

Widget rBox(BuildContext context, Color c, Widget w) {
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

Future<double> counterConfirm(BuildContext context, String descript, double c) async {
  bool confirmed = false;
  double addCount = c;
  TextEditingController txtCtrl = TextEditingController();
  txtCtrl.text = (c).toString();

  await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) =>
          AlertDialog(
            alignment: Alignment.center,
            actionsAlignment: MainAxisAlignment.spaceAround,
            title: Text(descript),
            content: SingleChildScrollView(child: Column(
                children: <Widget>[
                  const Text("Count"),
                  GestureDetector(
                    onTap: () {
                      FocusScopeNode currentFocus = FocusScope.of(context);
                      if (!currentFocus.hasPrimaryFocus) {
                        currentFocus.unfocus();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 15.0),
                      child: Card(
                          child: ListTile(
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: (){
                                // focus.unfocus();
                                addCount = (double.tryParse(txtCtrl.text) ?? 0.0) + 1;
                                txtCtrl.text = addCount.toString();
                              },
                            ),

                            title: TextField(
                              controller: txtCtrl,
                              // focusNode: focus,
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                            ),

                            leading: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: (){
                                //focus.unfocus();
                                addCount = (double.tryParse(txtCtrl.text) ?? 0.0) - 1.0;
                                txtCtrl.text = max(addCount, 0).toString();
                              },
                            ),
                          )
                      ),
                    ),
                  )
                ]
            )),
            actions: <Widget>[
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                onPressed: () {
                  confirmed = false;
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                onPressed: () {
                  addCount = (double.tryParse(txtCtrl.text) ?? 0.0);
                  if(addCount > 0){
                    confirmed = true;
                    Navigator.pop(context);
                  }
                  else{
                    showAlert(context, "", "Cannot add zero (0) items", colorWarning);
                    txtCtrl.text = "0.0";
                  }
                },
                child: const Text("Confirm"),
              ),
            ],
          )
  );

  txtCtrl.dispose();

  return confirmed ? addCount : -1;
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

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<bool> barcodeExists(String barcode, int ignore) async{
  bool confirm = false;

  if (barcode.trim().isNotEmpty) {
    for (int i = 0; i < jobTable.length; i++) {
      if (jobTable[i][tBarcode].toString().isNotEmpty && i != ignore) {
        if(jobTable[i][tBarcode].toString().split(",").toList().contains(barcode)) {
            confirm = true;
            break;
        }
      }
    }
  }

  return confirm;
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

setLocation(BuildContext context1){
  TextEditingController txtCtrl = TextEditingController();
  // FocusNode textFocus = FocusNode();

  Future<String> textEditDialog(BuildContext context, String str) async{
    String originalText = str;
    String newText = originalText;

    await showDialog(
      context: context1,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) => GestureDetector(
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          },
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.spaceAround,
            title: const Text("Edit Text Field"),
            content: Card(
                child: ListTile(
                  title: TextField(
                    controller: txtCtrl,
                    //focusNode: textFocus,
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
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: (){
                      goToPage(context, const Stocktake());
                    },
                  ),
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
                                      txtCtrl.dispose();
                                      //textFocus.dispose();
                                      goToPage(context, const Stocktake());
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

goToPage(BuildContext context, Widget page) {
  Navigator.push(
    context,
    PageRouteBuilder(
      fullscreenDialog: true,
      pageBuilder: (context, animation1, animation2) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
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
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.4, right: 20, left: 20),
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
  return showDialog(
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

writeJob(StockJob job, bool overwrite) async {
  var filePath = '/storage/emulated/0/Documents/';

  // If "/Documents" folder does not exist, make it!
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

class StockJob {
  String date = '';
  String id;
  String name;
  double total = 0;
  List<Map<String, dynamic>> stocktake = List.empty(growable: true);
  List<Map<String, dynamic>> nof = List.empty(growable: true);
  List<String> allLocations = List.empty(growable: true);
  String location = "";

  @override
  bool operator == (Object other) => identical(this, other) || other is StockJob &&
      runtimeType == other.runtimeType &&
      date == other.date &&
      id == other.id &&
      name == other.name &&
      stocktake == other.stocktake &&
      nof == other.nof &&
      allLocations == other.allLocations &&
      location == other.location;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ date.hashCode ^ stocktake.hashCode ^ nof.hashCode ^ allLocations.hashCode ^ location.hashCode; // ^ dbPath.hashCode;

  StockJob({
    required this.id,
    required this.name,
    date,
    total,
    stocktake,
    nof,
    allLocations,
  });

  StockJob copy({
    String? date,
    String? id,
    String? name,
    double? total,
    List<Map<String, dynamic>>? stocktake,
    List<Map<String, dynamic>>? nof,
    List<String>? allLocations,
  }) =>
      StockJob(
          date: date ?? this.date,
          id: id ?? this.id,
          name: name ?? this.name,
          total: total ?? this.total,
          stocktake: stocktake ?? this.stocktake,
          nof: nof ?? this.nof,
          allLocations: allLocations ?? this.allLocations
      );

  factory StockJob.fromJson(dynamic json) {
    StockJob job = StockJob(id: json['id'] as String, name: json['name'] as String);

    job.date = json.containsKey("date") ? json['date'] as String : "";

    job.stocktake = !json.containsKey("stocktake") || json['stocktake'] == null ? List.empty(growable: true) : [
      for (final map in jsonDecode(json['stocktake'])){
        "index": int.parse(map['index'].toString()),
        "count": double.parse(map['count'].toString()),
        "location": map['location'].toString(),
      },
    ];

    job.nof = !json.containsKey("nof") || json['nof'] == null ? List.empty(growable: true) : [
      for (final map in jsonDecode(json['nof'])){
        "index": map['index'] as int,
        "barcode": map['barcode'] as String,
        "category": map['category'] as String,
        "description": map['description'] as String,
        "uom": map['uom'] as String,
        "price": map['price'] as double,
        "datetime": map['datetime'] as String,
        "ordercode": map['ordercode'] as String,
        "nof": map['nof'] as bool,
      }
    ];

    job.allLocations = !json.containsKey("allLocations") || json['allLocations'] == null ? List.empty(growable: true) : [
      for(final l in jsonDecode(json['allLocations']))
        l as String,
    ];

    job.location = '';
    return job;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.isEmpty ? "${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}" : date,
      'id': id,
      'name': name,
      'stocktake': jsonEncode(stocktake),
      'nof': jsonEncode(nof),
      'allLocations': jsonEncode(allLocations),
      'location': location,
    };
  }

  nofList() {
    List<List<dynamic>> n = List.empty(growable: true);
    for (var e in nof) {
      n.add(e.values.toList());
    }
    return n;
  }

  stockList() {
    List<List<dynamic>> l = List.empty(growable: true);
    for (var e in stocktake) {
      l.add(e.values.toList());
    }
    return l;
  }

  calcTotal() {
    total = 0.0;
    for (int i = 0; i < stocktake.length; i++) {
      total += stocktake[i]["count"];
    }
  }

}
