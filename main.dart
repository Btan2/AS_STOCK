/*
LEGAL:
   This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
   To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.

   This program is distributed WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

BUILD NAMING CONVENTIONS:
   version.year.month+build

BUILD CMD:
    flutter build apk --no-pub --target-platform android-arm64,android-arm --split-per-abi --build-name=0.23.08 --build-number=2 --obfuscate --split-debug-info build/app/outputs/symbols
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:decimal/decimal.dart';

const String versionStr = "0.23.08+2";
Permission storageType = Permission.manageExternalStorage; //Permission.storage;
List<String> jobPageList = [];
List<String> masterCategory = [];
Map<String, dynamic> sFile = {};
Directory? rootDir;
enum Action {add, edit, addBarcode, addOrdercode}
int searchColumn = 3; // Start search column on description
int copyIndex = -1;
String copyCode = "";
String errorString = "";
String sheetPath = "";
String appDir = "";
String lastCategory = "MISC";
StockJob job = StockJob(id: "EMPTY");

// Colors & Text Style
final Color colorOk = Colors.blue.shade400;
final Color colorWarning = Colors.deepPurple.shade200;
const Color colorEdit = Colors.blueGrey;
const Color colorBack = Colors.redAccent;
TextStyle get whiteText{ return TextStyle(color: Colors.white, fontSize: sFile["fontScale"]);}
TextStyle get greyText{ return TextStyle(color: Colors.grey, fontSize: sFile["fontScale"]);}
TextStyle get blackText{ return TextStyle(color: Colors.black, fontSize: sFile["fontScale"]);}

class Index{
  static const int index = 0;
  static const int barcode = 1;
  static const int category = 2;
  static const int description = 3;
  static const int uom = 4;
  static const int price = 5;
  static const int datetime = 6;
  static const int ordercode = 7;
  static const int nof = 8;
  static const int stockCount = 1;
  static const int stockLocation = 2;
  static const int stockBarcodes = 3;
  static const int stockOrdercodes = 4;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await getApplicationDocumentsDirectory().then((Directory value){
    appDir = value.path;
  });
  //await getAppDir();

  await loadDefMastersheet();
  await loadSessionFile();
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

class HomePage extends StatelessWidget{
  const HomePage({super.key});

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
                                // DateTime cDate = DateTime.now().isUtc ? DateTime.now() : DateTime.now().toUtc();
                                // if(cDate.month > 6 || cDate.month < 5 || cDate.year < 2023 || cDate.year > 2023){
                                //   showAlert(context, "", "ERROR: \n\nLicense has EXPIRED!\n\nYou are not authorized to use this software!", Colors.red);
                                //   return;
                                // }

                                if(rootDir == null){
                                  prepareStorage();
                                }

                                //await grantAccess().then((value){
                                await storageType.isGranted.then((value){
                                  if(value){
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const JobsPage()));
                                  }
                                  else{
                                    showAlert(context, "ERROR", "Storage permissions were denied!\n\nTry changing 'Storage Permission Type' in App Settings.", Colors.red);
                                  }
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
                              goToPage(context, const AppSettings());
                            },
                          ),
                        ),
                      ]
                  )
              )
          ),
          bottomSheet: SingleChildScrollView(
              child: Center(
                  child: Column(
                      children: [
                        SizedBox(
                          height: 32,
                          width: MediaQuery.of(context).size.width,
                          child: const Text('Version: $versionStr', style: TextStyle(color: Colors.blueGrey), textAlign: TextAlign.center,),
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
        onWillPop: () async => goToPage(context, const HomePage()),
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await writeSession().then((value){
                    goToPage(context, const HomePage());
                  });
                },
              ),
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
                        headerPadding('Error Reports', TextAlign.left),
                        Center(
                          child: Padding(
                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                              child: Card(
                                  color: Colors.blueGrey[400],
                                  child: ListTile(
                                    title: Text('Copy Error Log', textAlign: TextAlign.center, style: whiteText),
                                    onTap: () async {
                                      copyErrLog();
                                      showAlert(context, "ALERT", "'fd_error_log.txt' has been copied to Internal Storage -> Documents\n", colorOk);
                                    },
                                  )
                              )
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
                                    // change storage then check if valid, if not valid tell user
                                    storageType = pValue as Permission;
                                    if(storageType == Permission.manageExternalStorage){
                                      sFile["permission"] = "${Permission.manageExternalStorage}";
                                    }
                                    else if(storageType == Permission.storage){
                                      sFile["permission"] = "${Permission.storage}";
                                    }

                                    // Inform the user storage can be accessed
                                    prepareStorage();

                                    // await grantAccess().then((value){
                                    await storageType.isGranted.then((value){
                                      if(value){
                                        showAlert(context, "ALERT", "Storage permissions were granted!", Colors.green);
                                      }
                                      else {
                                        showAlert(context, "ERROR", "Storage permissions were denied!\n\nTry changing 'Storage Permission Type' in App Settings.", Colors.red);
                                      }
                                    });

                                    await writeSession().then((value){
                                      if(errorString.isNotEmpty){
                                        showNotification(context, Colors.red, whiteText, "Write session file error: $errorString\n");
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
                )
            )
        )
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
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _copyJobFile(String path) async {
    bool copyJob = false;
    // if(path.contains('sdcard')){
    //   if(!path.contains("sdcard/Documents")){
    //     copyJob = true;
    //   }
    // }

    if(!path.contains("/storage/emulated/0/Documents")){
      copyJob = true;
    }

    // Copy and move job to default documents directory (if it isn't there already)
    if(copyJob){
      try{
        var jsn = File(path);
        String fileContent = await jsn.readAsString();
        var dynamic = json.decode(fileContent);
        var j = StockJob.fromJson(dynamic);

        String checkPath = "/storage/emulated/0/Documents/${j.id}";
        await File(checkPath).exists().then((value) async {
          if(value){
            confirmDialog(
                context,
                "ALERT!\n\nJob file already exists inside Documents directory!\n\nDO YOU WISH TO REPLACE THE EXISTING JOB FILE?"
            ).then((value){
              if(!value){
                return;
              }
            });
          }
        });

        writeJob(j);
      }
      catch (e){
        writeErrLog(e.toString(), "JobsPage() -> _copyJobFile() -> ${path.split("/").last}");
        showAlert(context, "ERROR", "Failed to copy job file => $e", Colors.red);
      }
    }

    setState(() {});
  }

  _readJob(String path) async {
    try{
      var jsn = File(path);
      String fileContent = await jsn.readAsString(); //await
      var dynamic = json.decode(fileContent);
      job = StockJob.fromJson(dynamic);
      job.calcTotal();

      masterCategory = List<String>.generate(job.table.length, (index) => job.table[index][2].toString().toUpperCase());
      masterCategory.removeAt(0); // Remove header row
      masterCategory = masterCategory.toSet().toList(); // Remove duplicates
    }
    catch (e){
      writeErrLog(e.toString(), "JobsPage() -> _readJob() -> $path");
      showAlert(context, "ERROR", "Failed to read job file => $e", Colors.red);
    }

    if(!jobPageList.contains(path)){
      jobPageList.add(path);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => goToPage(context, const HomePage()),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: (){
                job = StockJob(id: "EMPTY");
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
                          children: List.generate(jobPageList.length, (index) => Card(
                            child: ListTile(
                                title: Text(jobPageList[index].split("/").last),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_forever_sharp),
                                  color: Colors.redAccent,
                                  onPressed: () {
                                    jobPageList.removeAt(index);
                                    setState(() {});
                                  },
                                ),
                                onTap: () async {
                                  await _readJob(jobPageList[index]).then((value){
                                    setState(() {
                                      copyIndex = -1;
                                    });
                                    goToPage(context, const Stocktake());
                                  });
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
                                      goToPage(context, const NewJob());
                                    },
                                  )
                              ),
                              rBox(
                                  context,
                                  Colors.blue[800]!,
                                  TextButton(
                                    child: Text('Load from Storage', style: whiteText),
                                    onPressed: () async{
                                      String path = "";
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
                                        path = value.toString();
                                      });

                                      // Check if path is valid
                                      if(path.isEmpty || path == "null" || !path.split("/").last.startsWith("ASJob")){
                                        return;
                                      }

                                      await _copyJobFile(path);
                                      await _readJob(path).then((value){
                                        setState(() {
                                          copyIndex = -1;
                                        });
                                        goToPage(context, const Stocktake());
                                      });
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
        )
    );
  }
}

class NewJob extends StatefulWidget{
  const NewJob({super.key,});

  @override
  State<NewJob> createState() => _NewJob();
}
class _NewJob extends State<NewJob>{
  String masterfileStr = "";
  String idStr = "";

  @override
  void initState() {
    super.initState();
    _getDefaultMastersheet();
  }

  @override
  void dispose(){
    super.dispose();
  }

  _getDefaultMastersheet() {
    masterfileStr = "$appDir/MASTERFILE.xlsx";
    setState(() {});
  }

  _masterfileSelector() async {
    await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: colorOk.withOpacity(0.8),
        builder: (context2) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
                actionsAlignment: MainAxisAlignment.spaceAround,
                title: const Text("Select Spreadsheet:", textAlign: TextAlign.center,),
                content: SingleChildScrollView(
                    child: Center(
                        child: Column(
                            children:[
                              rBox(
                                context2,
                                colorOk,
                                TextButton(
                                  child: Text('Load default MASTERFILE.xlsx', style: whiteText),
                                  onPressed: () async {
                                    await _getDefaultMastersheet().then((value){
                                      setState(() {});
                                      Navigator.pop(context2);
                                    });
                                  },
                                ),
                              ),
                              rBox(
                                context2,
                                Colors.green,
                                TextButton(
                                  child: Text('Load from storage', style: whiteText),
                                  onPressed: () async {
                                    await FilesystemPicker.open(
                                      title: rootDir.toString(),
                                      context: context2,
                                      rootDirectory: rootDir!,
                                      fsType: FilesystemType.file,
                                      allowedExtensions: ['.xlsx'],
                                      pickText: 'Select XLSX document.',
                                      folderIconColor: Colors.blue,
                                      fileTileSelectMode: FileTileSelectMode.wholeTile,
                                      requestPermission: () async => await storageType.request().isGranted,).then((value){
                                        masterfileStr = value.toString();
                                        setState(() {});
                                        Navigator.pop(context2);
                                      });
                                  },
                                ),
                              ),
                            ]
                        )
                    )
                )
            )
        )
    );
  }

  String _regexFormat(String s){
    String regex = r'[^\p{Alphabetic}\p{Mark}\p{Decimal_Number}\p{Connector_Punctuation}\p{Join_Control}\s]+';
    String fString = s.replaceAll(RegExp(regex, unicode: true),'');

    // if (fString.contains("\\")){
    //   fString = fString.replaceAll("/", '');
    // }

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
    return WillPopScope(
        onWillPop: () async => false,
        child: GestureDetector(
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
                                      onChanged: (String value){
                                        idStr = value;
                                        setState(() {});
                                      },
                                    )
                                )
                            ),
                            headerPadding('Masterfile:', TextAlign.left),
                            Padding(
                                padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 10, bottom: 10),
                                child: Center(
                                  child: Card(
                                    child: ListTile(
                                        title: Text(masterfileStr.split("/").last, textAlign: TextAlign.center, style: blackText),
                                        onTap: () async {
                                          _masterfileSelector();
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
                              child: rBox(
                                  context,
                                  colorOk,
                                  TextButton(
                                    child: Text('Create Job', style: whiteText),
                                    onPressed: () async {
                                      String jobFilePath = "/storage/emulated/0/Documents/$idStr/ASJob_$idStr";
                                      if(File(jobFilePath).existsSync()){
                                        showAlert(context, "ALERT", "Job file already exists!\n\nPlease rename the job ID or delete the job file which already exists.", colorWarning);
                                        return;
                                      }

                                      // Job must need ID
                                      if(idStr.isEmpty){
                                        showAlert(context, "WARNING", "Job ID is empty!", Colors.orange);
                                        return;
                                      }

                                      idStr = _regexFormat(idStr);

                                      // // Using jobID for name if no name exists
                                      // if(nameStr.isEmpty){
                                      //   nameStr = "Job$nameStr";
                                      // }
                                      //
                                      // nameStr = _regexFormat(nameStr);

                                      StockJob newJob = StockJob(id: idStr);
                                      newJob.date = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
                                      sheetPath = masterfileStr;

                                      // User must rename jobID if it already exists
                                      await writeJob(newJob).then((value){
                                        job = newJob;
                                        job.calcTotal();
                                        if (!jobPageList.contains(jobFilePath)) {
                                          jobPageList.add(jobFilePath);
                                        }
                                        copyIndex = -1;
                                        goToPage(context, const Stocktake());
                                      });
                                    },
                                  )
                              ),
                            )
                          ]
                      )
                  ),
                ),
        )
    );
  }
}

class Stocktake extends StatefulWidget {
  const Stocktake({super.key,});
  @override
  State<Stocktake> createState() => _Stocktake();
}
class _Stocktake extends State<Stocktake> {
  bool isLoading = false;
  String loadingMsg = "Loading...";

  @override
  void initState() {
    super.initState();
    _getTable();
  }

  Future<void> loadSpreadSheet(String filePath) async {
    Uint8List bytes;
    if(!File(filePath).existsSync()){
      errorString = "FAILED TO LOAD SPREADSHEET!\nThe filepath does not exist: -> $filePath";
      return;
    }

    setState((){
      loadingMsg = "Decoding spreadsheet...";
    });

    await Future.delayed(const Duration(seconds: 1));

    try{
      File file = File(filePath);
      bytes = file.readAsBytesSync();
      var decoder = SpreadsheetDecoder.decodeBytes(bytes);
      var sheets = decoder.tables.keys.toList();
      if(sheets.isEmpty){
        errorString = "FAILED TO LOAD SHEETS!\nThe spreadsheet does not contain data? -> $filePath";
        return;
      }

      setState((){
        loadingMsg = "Loading table...";
      });
      await Future.delayed(const Duration(milliseconds: 500));

      SpreadsheetTable? table = decoder.tables[sheets.first]!;
      if(table.rows.isEmpty) {
        errorString = "Spreadsheet was not loaded!\nThe spreadsheet is empty!";
        return;
      }

      setState((){
        loadingMsg = "Creating header row...";
      });
      await Future.delayed(const Duration(milliseconds: 500));

      job.headerRow = List<String>.generate(table.rows[0].length, (index) => table.rows[0][index].toString().toUpperCase());

      setState((){
        loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(milliseconds: 500));

      setState((){
        loadingMsg = "Creating main table...";
      });
      await Future.delayed(const Duration(milliseconds: 500));

      // Add nof column to list (always false because it's from the MASTERFILE)
      job.table = List.generate(
        table.rows.length, (index) => List<String>.generate(
          table.rows[0].length, (index2) => table.rows[index][index2].toString().toUpperCase()
        ) + ["false"],
        growable: true
      );

      job.table.removeAt(0); // Remove header row

      masterCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][2].toString().toUpperCase());
      masterCategory.removeAt(0); // Remove header row
      masterCategory = masterCategory.toSet().toList(); // Remove duplicates
    }
    catch (e){
      errorString = "$e";
    }
  }

  _getTable() async {
    if(job.table.isNotEmpty){
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        isLoading = false;
      });

      return;
    }

    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if(sheetPath.toLowerCase().endsWith("xlsx")){
      await loadSpreadSheet(sheetPath).then((value) async {
        if (job.table.isEmpty) {
          writeErrLog(errorString, "NewJob() -> loadMasterSheet() -> ${job.id}");
          showAlert(context, "ERROR", "$errorString\nSheet Path: $sheetPath", Colors.red);
        }

        // Make sure table is saved
        writeJob(job);

        setState(() {
          isLoading = false;
        });
      });
    }
    else{
      setState(() {
        isLoading = false;
      });
    }
  }

  _popBack(){
    if(!isLoading){
      //headerRow = List.empty();
      job = StockJob(id: "EMPTY");//, name: "EMPTY");
      masterCategory = List.empty();
      copyIndex = -1;

      lastCategory = "MISC";
      goToPage(context, const JobsPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => _popBack(),//goToPage(context, const JobsPage()),
        child: Scaffold(
          appBar: AppBar(
            leading: isLoading ? const Icon(Icons.lock_clock) : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _popBack(),
            ),
            centerTitle: true,
            title: const Text("Stocktake", textAlign: TextAlign.center),
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            child: Center(
              child: Column(
                children: isLoading ? [
                  SizedBox(height: MediaQuery.of(context).size.height/3),
                  Text(loadingMsg, style: const TextStyle(fontSize: 24.0)),
                  const CircularProgressIndicator(),
                ] :  [
                  const SizedBox(height: 10.0,),
                  Card(
                    child: ListTile(
                      title: Text(job.id, textScaleFactor: 1.25, textAlign: TextAlign.center),
                      subtitle: Text("\n${job.date}\n\nTOTAL COUNT: ${job.total}", style: blackText),
                    ),
                  ),

                  headerPadding("Current Location:", TextAlign.left),
                  Card(
                    child: ListTile(
                      title: job.location.isEmpty ? Text("Tap to select a location...", style: greyText) : Text(job.location, textAlign: TextAlign.center, softWrap: true, maxLines: 1, overflow: TextOverflow.ellipsis),
                      leading: job.location.isEmpty ? const Icon(Icons.warning_amber, color: Colors.red) : null,
                      trailing: job.location.isNotEmpty ?  const Icon(Icons.playlist_add, color: colorEdit) : null,
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
                            goToPage(context, const GridView(action: Action.add));
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
                          job.stocktake.isNotEmpty ? goToPage(context, const GridView(action: Action.edit)) :
                          showAlert(context, "ERROR:", "Stocktake is empty.", Colors.blue.shade200);
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
                          goToPage(context, ExportPage());
                        },
                      )
                  ),
                ],
              )
            )
          ),
        )
    );
  }
}

class GridView extends StatefulWidget {
  final Action action;
  const GridView({
    super.key,
    required this.action
  });

  @override
  State<GridView>  createState() => _GridView();
}
class _GridView extends State<GridView> {
  TextEditingController descriptCtrl = TextEditingController();
  TextEditingController priceCtrl = TextEditingController();
  TextEditingController barcodeCtrl = TextEditingController();
  TextEditingController ordercodeCtrl = TextEditingController();
  TextEditingController countCtrl = TextEditingController();
  TextEditingController searchCtrl = TextEditingController();
  TextEditingController totalCost = TextEditingController();
  FocusNode scanDeviceFocus = FocusNode();
  List<List<dynamic>> filterList = List.empty();
  List<String> barcodeList = List.empty();
  List<String> ordercodeList = List.empty();
  Color colorMode = colorOk;
  String categoryValue = "MISC";
  String scanText = '';
  int barcodeIndex = 0;
  int ordercodeIndex = 0;
  int addBarcodeIndex = 0;
  int addOrdercodeIndex = 0;
  int assignSearchColumn = Index.description;
  double keyboardHeight = 20.0;

  @override
  void initState() {
    super.initState();

    // Set filter list and GridView color
    if(widget.action == Action.add){
      //assignSearchColumn = searchColumn;

      filterList = List.empty();
      colorMode = colorOk;
    }
    else if(widget.action == Action.edit){
      filterList = List.of(job.stocktake);
      colorMode = colorOk;
    }
    else{ //if(widget.action == Action.addBarcode || widget.action == Action.addOrdercode){
      filterList = List.of(job.table);
      colorMode = Colors.teal;
    }
  }

  @override
  void dispose() {
    // Make sure Focus is removed before disposing controller
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    descriptCtrl.dispose();
    priceCtrl.dispose();
    barcodeCtrl.dispose();
    ordercodeCtrl.dispose();
    countCtrl.dispose();
    searchCtrl.dispose();
    scanDeviceFocus.dispose();
    totalCost.dispose();

    super.dispose();
  }

  _popBack(){
    if(widget.action == Action.addBarcode || widget.action == Action.addOrdercode){
      goToPage(context, const GridView(action: Action.add));
    }
    else{
      goToPage(context, const Stocktake());
    }
  }

  Future<double> _counterConfirm(BuildContext context, String descript, double price, double c, bool edit) async {
    bool confirmed = false;
    bool delete = false;
    double addCount = c;

    await showDialog(
        useSafeArea: true,
        context: context,
        barrierDismissible: false,
        barrierColor: colorOk.withOpacity(0.8),
        builder: (context){
          TextEditingController txtCtrl = TextEditingController();
          txtCtrl.text = addCount.toString();
          totalCost.text = "Total Cost: ${price * addCount}";

          return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                alignment: Alignment.center,
                actionsAlignment: MainAxisAlignment.spaceAround,
                title: Center(
                    child:
                    Text(descript, overflow: TextOverflow.fade, softWrap: true, maxLines: 4, textAlign: TextAlign.center,)),
                content: GestureDetector(
                  onTap: () {
                    FocusScopeNode currentFocus = FocusScope.of(context);
                    if (!currentFocus.hasPrimaryFocus) {
                      currentFocus.unfocus();
                    }
                  },
                  child: SingleChildScrollView(
                      child: Column(
                          children: <Widget>[
                            TextField(
                                decoration: InputDecoration(
                                    hintText: 'Unit Price: $price',
                                    border: InputBorder.none,
                                    hintStyle: const TextStyle(color: Colors.black)
                                ),
                                enabled: false
                            ),
                            TextField(
                                controller: totalCost,
                                style: const TextStyle(color: Colors.black),
                                decoration: const InputDecoration(border: InputBorder.none),
                                enabled: false
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 10.0),
                              child: Card(
                                  shadowColor: Colors.white.withOpacity(0.0),
                                  child: ListTile(
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () {
                                        addCount += 1;
                                        txtCtrl.text = addCount.toString();
                                        totalCost.text = "Total Cost:  ${(addCount * price).toString()}";
                                      },
                                    ),
                                    title: TextFormField(
                                      controller: txtCtrl,
                                      textAlign: TextAlign.center,
                                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                                       onChanged: (String value) async {
                                         addCount = double.tryParse(value) ?? 0;
                                         totalCost.text = "Total Cost:  ${(addCount * price).toString()}";
                                      },
                                    ),
                                    leading: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: (){
                                        addCount = max(addCount - 1, 0);
                                        txtCtrl.text = addCount.toString();
                                        totalCost.text = "Total Cost:  ${(addCount * price).toString()}";
                                      },
                                    ),
                                  )
                              ),
                            ),
                            edit ? Padding(
                              padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 0.0),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                                onPressed: () async {
                                  await confirmDialog(context, "CONFIRM ITEM DELETION?").then((value){
                                    if(value){
                                      delete = true;
                                      // Unfocus then dispose
                                      FocusScopeNode currentFocus = FocusScope.of(context);
                                      if (!currentFocus.hasPrimaryFocus) {
                                        currentFocus.unfocus();
                                      }
                                      txtCtrl.dispose();
                                      Navigator.pop(context);
                                    }
                                  });
                                },
                                child: const Text("DELETE"),
                              ),
                            ) : Container(),
                          ]
                      )
                  ),
                ),
                actions: <Widget>[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                    onPressed: () {
                      //Unfocus then dispose
                      FocusScopeNode currentFocus = FocusScope.of(context);
                      if (!currentFocus.hasPrimaryFocus) {
                        currentFocus.unfocus();
                      }

                      txtCtrl.dispose();
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                    onPressed: () async {
                      if(addCount > 0){
                        confirmed = true;

                        //Unfocus then dispose
                        FocusScopeNode currentFocus = FocusScope.of(context);
                        if (!currentFocus.hasPrimaryFocus) {
                          currentFocus.unfocus();
                        }

                        txtCtrl.dispose();
                        Navigator.pop(context);
                      }
                      else{
                        String er = "Count is zero (0).";
                        if(edit){
                          er += "\n\nPress 'DELETE' if you wish to remove this item.";
                        }
                        showAlert(context, "ERROR:", er, colorWarning);
                        txtCtrl.text = "0.0";
                      }
                    },

                    child: const Text("Confirm"),
                  ),
                ],
              )
          );
        }
    );

    return confirmed ? addCount : (delete ? -2 : -1);
  }

  Future<bool> _longPressSelect(BuildContext context, int index) async {
    bool edit = false;
    await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: colorOk.withOpacity(0.8),
        builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              actionsAlignment: MainAxisAlignment.spaceAround,
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                      onPressed: () async {
                        await showGeneralDialog(
                          context: context,
                          barrierColor: Colors.black12,
                          barrierDismissible: false,
                          barrierLabel: '',
                          transitionDuration: const Duration(milliseconds: 100),
                          pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
                            _setEditText(index);
                            return _itemEdit(index);
                          },
                        ).then((value){
                          setState(() {});
                          Navigator.pop(context);
                        });
                      },
                      child: const Text("Edit Item"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () {
                        copyIndex = index;
                        showNotification(context, colorWarning, whiteText, "Item copied @[$index]");
                        Navigator.pop(context);
                      },
                      child: const Text("Copy Item"),
                    ),
                  ]
                )
              ),
              actions: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
              ],
            )
        )
    );

    return edit;
  }

  void _setEmptyText(String barcode, String ordercode){
    // locationText = job.location;
    // descriptionText = "";
    // priceText = "0.0";

    categoryValue = "MISC";
    countCtrl.text = "0.0";
    descriptCtrl.text = "";
    priceCtrl.text = "0.0";
    barcodeIndex = 0;
    barcodeList = List.empty(growable: true);
    barcodeList.add(barcode);
    barcodeCtrl.text = barcodeList[barcodeIndex];
    ordercodeIndex = 0;
    ordercodeList = List.empty(growable: true);
    ordercodeList.add(ordercode);
    ordercodeCtrl.text = ordercodeList[ordercodeIndex];
  }

  void _setEditText(int index){
      barcodeIndex = 0;
      barcodeList = List.empty(growable: true);
      ordercodeIndex = 0;
      ordercodeList = List.empty(growable: true);

      final int tableIndex = int.parse(filterList[index][Index.index]);
      barcodeList += job.table[tableIndex][Index.barcode].toString().toUpperCase().split(",").toList();
      if(barcodeList.isNotEmpty){
        barcodeCtrl.text = barcodeList[0];
      }
      else {
        barcodeCtrl.text = "";
      }
      ordercodeList += job.table[tableIndex][Index.ordercode].toUpperCase().split(",").toList();
      if(ordercodeList.isNotEmpty){
        ordercodeCtrl.text = ordercodeList[0];
      }
      else {
        ordercodeCtrl.text = "";
      }

      categoryValue = job.table[tableIndex][Index.category];
      descriptCtrl.text = job.table[tableIndex][Index.description];
      priceCtrl.text = double.parse(job.table[tableIndex][Index.price]).toStringAsFixed(2);
      //descriptionText =
      // locationText = filterList[index][iLocation].toString();
      // priceText =
  }

  Widget _searchBar(){
    bool assignMode = widget.action == Action.addBarcode || widget.action == Action.addOrdercode;

    void defaultSearchList(){
      // List to return if search query is not found
      filterList = widget.action == Action.add ? List.empty() :
          assignMode ? List.of(job.table) :
          widget.action == Action.edit ? List.of(job.stocktake) :
      List.empty();
    }

    void searchString(String searchText){
      int column = searchColumn;
      if(assignMode){
        column = assignSearchColumn;
      }

      // Set list to search through
      filterList = widget.action == Action.add ? List.of(job.table) :
        assignMode ? List.of(job.table) :
        widget.action == Action.edit ? List.of(job.stocktake) :
        List.empty();

      bool found = false;
      List<String> searchWords = searchText.split(' ').where((String s) => s.isNotEmpty).toList();
      for (int i = 0; i < searchWords.length; i++) {
        if (!found) {
          List<List<dynamic>> first = widget.action == Action.edit ?
          filterList.where((row) =>
              job.table[int.parse(row[Index.index])][column].toString().split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList() :
          filterList.where((row) =>
              row[column].toString().split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
          //filterList.where((row) => jobTable[int.parse(row[Index.index])][searchColumn].contains(searchWords[i])).toList() :
          //filterList.where((row) => row[searchColumn].contains(searchWords[i])).toList();
          if(first.isNotEmpty){
            filterList = List.of(first);//..sort((x, y) => (x[tDescription] as dynamic).compareTo((y[tDescription] as dynamic)));
            found = true;
          }
        }
        else {
          List<List<dynamic>> refined = widget.action == Action.edit ?
          filterList.where((row) =>
              job.table[int.parse(row[Index.index])][column].toString().split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList() :
          filterList.where((row) =>
              row[column].toString().split(' ').where((String s) => s.isNotEmpty).toList().contains(searchWords[i])).toList();
          // filterList.where((row) => jobTable[int.parse(row[Index.index])][searchColumn].contains(searchWords[i])).toList() :
          // filterList.where((row) => row[searchColumn].contains(searchWords[i])).toList();
          if(refined.isNotEmpty){
            filterList = List.of(refined);//..sort((x, y) => (x[tDescription] as dynamic).compareTo((y[tDescription] as dynamic)));
          }
        }
      }

      if(!found){
        filterList = List.empty();
      }
    }

    return RawKeyboardListener(
      autofocus: true,
      focusNode: scanDeviceFocus,
      onKey: (RawKeyEvent event) async {
        if (event is RawKeyDownEvent) {
          if (event.physicalKey == PhysicalKeyboardKey.enter) {
            searchCtrl.text = scanText;
            scanText = '';
            if(searchCtrl.text.isEmpty){
              defaultSearchList();
              setState(() {});
              return;
            }
            searchString(searchCtrl.text.toUpperCase());

            // Automatically show item add popup if one item is found
            // Duplicate barcodes are not allowed so it should always only return one item for barcode scanning
            if(filterList.length == 1){
              double price = double.parse(filterList[0][Index.price]);
              await _counterConfirm(context, filterList[0][Index.description], price, 1, false).then((double count) async{
                if(count != -1){
                  Decimal addCount = Decimal.parse(count.toStringAsFixed(3));
                  job.stocktake.add(<String>[
                    filterList.first[Index.index],
                    addCount.toString(),
                    job.location,
                    addBarcodeIndex.toString(),
                    addOrdercodeIndex.toString(),
                  ]);

                  String shortDescript = filterList.first[Index.description];
                  shortDescript.substring(0, min(shortDescript.length, 14));
                  showNotification(context, colorWarning, whiteText, "Added $shortDescript --> $addCount");
                  job.calcTotal();

                  writeJob(job);
                }
              });
            }
            setState(() {});
          } else {
            scanText += event.data.keyLabel;
          }
        }
      },

      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: Icon(Icons.search, color: Colors.white.withOpacity(0.0)),
          ),
          Expanded(
              child: Center(
                  child: TextField(
                    textAlign: TextAlign.center,
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (String value) async {
                      if(value.isEmpty) {
                        defaultSearchList();
                        setState(() {});
                        return;
                      }
                      searchString(value.toUpperCase());
                      setState(() {});
                    },
                  )
              )
          ),
          IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                searchCtrl.clear();
                defaultSearchList();
                setState(() {});
              },
            )
        ]
      ),
    );
  }

  Widget _getHeader(){
    if(widget.action == Action.edit){
      return FlexibleSpaceBar(
          collapseMode: CollapseMode.none,
          centerTitle: true,
          titlePadding: const EdgeInsets.only(top: kTextTabBarHeight),
          title: ListView(
              children: [
                _searchBar(),
                const SizedBox(height:10.0),
                Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 25.0, // 25.0
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                              child: Center(
                                  child: Text("Description", textAlign: TextAlign.center, style: blackText)
                              )
                          )
                      ),
                      Container(
                          width: 100.0,
                          height: 25.0,
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                          child: Center(
                              child: Text("Location", textAlign: TextAlign.center, style: blackText)
                          )
                      ),
                      Container(
                          width: 75.0,
                          height: 25.0,
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                          child:  Center(
                              child: Text("Count", textAlign: TextAlign.center, style: blackText)
                          )
                      )
                    ]
                ),
              ]
          )
      );
    }
    else{
      return FlexibleSpaceBar(
          collapseMode: CollapseMode.none,
          centerTitle: true,
          titlePadding: const EdgeInsets.only(top: kTextTabBarHeight),
          title: ListView(
              children: [
                _searchBar(),
                const SizedBox(height:10.0),
                Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 25.0,
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                              child: Center(
                                  child: Text(job.headerRow[Index.description], textAlign: TextAlign.center, style: blackText)
                              )
                          )
                      ),
                      // (searchColumn == Index.barcode || searchColumn == Index.ordercode) ? Container(
                      //     width: 100.0,
                      //     height:25.0,
                      //     decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                      //     child: Center(
                      //         child: Text(job.headerRow[searchColumn], textAlign: TextAlign.center, style: blackText)
                      //     )
                      // ) : Container()
                    ]
                )
              ]
          )
      );
    }
  }

  Widget _rowAssign(int pIndex) {
    int tableIndex = int.parse(filterList[pIndex][Index.index].toString());
    String descript = job.table[tableIndex][Index.description].toString();
    return GestureDetector(
        onTap: () async {
          await confirmDialog(context, "Assign $copyCode to $descript?").then((value) async {
            if (value) {
              // Make sure we add barcode/ordercode to the correct column
              int codeColumn = widget.action == Action.addBarcode ? Index.barcode : Index.ordercode;

              String s = job.table[tableIndex][codeColumn].toString();
              if(s.isEmpty || s == "NULL" || s == "null") {
                job.table[tableIndex][codeColumn] = copyCode;
              }
              else {
                job.table[tableIndex][codeColumn] += ",$copyCode";
              }
              copyCode = "";
              setState(() {});
              await writeJob(job).then((value){
                goToPage(context, const GridView(action: Action.add));
              });
            }
          });
        },
        child: Row(
          children: [
            Expanded(
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                  child: Text(descript, textAlign: TextAlign.center, softWrap: true, overflow: TextOverflow.fade),
                )
            ),
            // Expanded(
            //   child: Container(
            //     height: 150,
            //     decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
            //     child: Text(job.table[tableIndex][searchColumn], textAlign: TextAlign.center, softWrap: true, maxLines: 2, overflow: TextOverflow.fade,)
            //   )
            // ),
          ],
        )
    );
  }

  Widget _rowEdit(int pIndex, double cellHeight){
    int tableIndex = int.parse(filterList[pIndex][Index.index].toString());
    return Row(
        children: [
        Expanded(
          child:GestureDetector(
            onLongPress: (){
              copyIndex = tableIndex;
              showNotification(context, colorWarning, whiteText, "Item copied @[$pIndex]");
            },
            onTap: () async {
              await showGeneralDialog(
                context: context,
                barrierColor: Colors.black12,
                barrierDismissible: false,
                barrierLabel: '',
                transitionDuration: const Duration(milliseconds: 100),
                pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
                  _setEditText(pIndex);
                  return _itemEdit(pIndex);
                },
              );
              setState(() {});
            },

              child: Container(
                height: cellHeight,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                child: Center(
                    child: Text(
                      job.table[tableIndex][Index.description],
                      textAlign: TextAlign.center,
                    )
                ),
              ),
            ),
          ),

          TapRegion(
            onTapInside: (value) async {
              await textEditDialog(context, "Edit Location", job.stocktake[pIndex][Index.stockLocation]).then((value){
                String editStr = value.toUpperCase();
                if(!job.allLocations.contains(editStr)){
                  job.allLocations.add(editStr);
                }
                job.stocktake[pIndex][Index.stockLocation] = editStr;
                filterList[pIndex][Index.stockLocation] = editStr;
                writeJob(job);
              });
            },
            child:  Container(
              width: 100.0,
              height: cellHeight,
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
              child: Center(
                  child: Text(filterList[pIndex][Index.stockLocation], textAlign: TextAlign.center,)
              ),
            ),
          ),

          GestureDetector(
              onTap: () async {
                double c = double.parse(filterList[pIndex][Index.stockCount]);
                double price = double.parse(job.table[tableIndex][Index.price]);
                await _counterConfirm(context, job.table[tableIndex][Index.description], price, c, true).then((double newCount) async {
                  if (newCount == -2){
                    job.stocktake.removeAt(pIndex);
                    if(copyIndex == pIndex){
                      copyIndex = -1;
                    }
                    job.calcTotal();
                    writeJob(job);
                    filterList.removeAt(pIndex);
                    setState(() {});
                  }
                  else if (newCount > -1 && newCount != c){
                    String decimalCount = Decimal.parse(newCount.toStringAsFixed(3)).toString();
                    job.stocktake[pIndex][Index.stockCount] = decimalCount;
                    job.calcTotal();
                    writeJob(job);

                    // Manually update the filter list item instead of updating the entire list
                    filterList[pIndex][Index.stockCount] = decimalCount;
                    setState(() {});
                  }
                });
              },
              child: Container(
                width: 75.0,
                height: cellHeight,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                child: Center(
                    child: Text(filterList[pIndex][Index.stockCount])
                ),
              )
          )
        ]
      );
  }

  Widget _rowAdd(int pIndex, double cellHeight){
    int tableIndex = int.parse(filterList[pIndex][Index.index].toString());
    String descript = job.table[tableIndex][Index.description];
    String lastCell = "";

    if(searchColumn != Index.index && searchColumn != Index.description){
      lastCell = job.table[tableIndex][searchColumn];
    }

    return GestureDetector(
      onLongPress: () async {
        await _longPressSelect(context, tableIndex);
      },

      onTap: () async {
        addBarcodeIndex = 0;
        addOrdercodeIndex = 0;

        // Try to find specific barcode/ordercode
        if(searchColumn == Index.barcode){
          List<String> codeList = filterList[pIndex][searchColumn].split(",").toList();
          for(int i = 0; i < codeList.length; i++){
            if(codeList[i].contains(searchCtrl.text)){
              addBarcodeIndex = i;
              break;
            }
          }
        }

        double price = double.parse(filterList[pIndex][Index.price]);
        await _counterConfirm(context, filterList[pIndex][Index.description], price, 1, false).then((double addCount) async{
          if(addCount != -1){
            job.stocktake.add(<String>[
              int.parse(filterList[pIndex][Index.index].toString()).toString(),
              Decimal.parse(addCount.toStringAsFixed(3)).toString(),
              job.location,
              addBarcodeIndex.toString(),
              addOrdercodeIndex.toString(),
            ]);

            String shortDescript = filterList[pIndex][Index.description].toString();
            shortDescript.substring(0, min(shortDescript.length, 14));
            showNotification(context, colorWarning, whiteText, "Added '$shortDescript' --> $addCount");
            job.calcTotal();
            writeJob(job);
          }
          setState(() {});
        });
      },
      child: Row(
          children: [
            Expanded(
              child: Container(
                height: cellHeight,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
                child: Center(
                    child: Text(descript, textAlign: TextAlign.center, softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis)
                ),
              ),
            ),
            lastCell.isNotEmpty ? Container(
              width: 100.0,
              height: cellHeight,
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.0)),
              child: Center(
                child: Text(lastCell, textAlign: TextAlign.center, softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis)
              )
            ) : Container()
          ]
      ),
    );
  }

  Widget _itemEdit(int index) {
    bool newItem = index == -1;

    confirmEdit() async {
      String msg = "";
      if(newItem){
        msg = "Add NOF to stocktake?\n-> ${descriptCtrl.text}";
      }
      else {
        msg = "Confirm changes?";
      }

      await confirmDialog(context, msg).then((bool value) async {
        if (value) {
          bool editError = false;
          bool barcodeIsEmpty = false;
          String finalBarcode = "";
          if(descriptCtrl.text.isEmpty){
            editError = true;
            showAlert(context, "ERROR:", "Description text must not be empty!", colorWarning);
          }

          barcodeIsEmpty = barcodeList.isEmpty || (barcodeList.length == 1 && barcodeList[0].isEmpty);
          if(!barcodeIsEmpty) {
            for(int i = 0; i < barcodeList.length; i++){
              if(i > 0){
                // Do not add empty barcodes
                if(barcodeList[i].isNotEmpty){
                  finalBarcode += ",${barcodeList[i]}";
                }
              }
              else{
                // first barcode in barcodeList should not have a comma
                finalBarcode += barcodeList[i];
              }
            }
          }

          if(!editError){
            String finalOrdercode = "";
            for(int i = 0; i < ordercodeList.length; i++){
              if(i > 0){
                // Do not add empty ordercodes
                if(ordercodeList[i].isNotEmpty){
                  finalOrdercode += ",${ordercodeList[i]}";
                }
              }
              else{
                finalOrdercode += ordercodeList[i];
              }
            }

            if(newItem){
              // ADD NEW ITEM TO STOCKTAKE IF COUNT IS GOOD
              double addCount = double.tryParse(countCtrl.text) ?? 0.0;
              if(addCount > 0){
                int newIndex = job.table.length;
                job.table.add(<String>[
                  newIndex.toString(),
                  finalBarcode,
                  categoryValue,
                  descriptCtrl.text.toUpperCase(),
                  "EACH",
                  Decimal.parse(double.parse(priceCtrl.text).toStringAsFixed(2)).toString(),
                  "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                  finalOrdercode,
                  true.toString()
                ]);

                job.stocktake.add(<String>[
                  newIndex.toString(),
                  Decimal.parse(double.parse(addCount.toString()).toStringAsFixed(3)).toString(), // Decimal.parse(addCount.toString()),
                  job.location,
                  '0', // Use first barcode in barcode list by default
                  '0', // Use first ordercode in ordercode list by default
                ]);

                job.calcTotal();
              }
            }
            else{
              // Save Edits
              int tableIndex = int.parse(filterList[index][Index.index]);
              job.table[tableIndex][Index.barcode] = finalBarcode;
              job.table[tableIndex][Index.category] = categoryValue;
              job.table[tableIndex][Index.description] = descriptCtrl.text.toUpperCase();
              //job.table[tableIndex][Index.uom] = "EACH";
              job.table[tableIndex][Index.price] = Decimal.parse(double.parse(priceCtrl.text).toStringAsFixed(2)).toString();
              job.table[tableIndex][Index.datetime] = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
              job.table[tableIndex][Index.ordercode] = finalOrdercode;
            }

            setState(() {});

            if(widget.action != Action.edit){
              filterList = List.empty();
            }
            searchCtrl.text = "";
            await writeJob(job).then((value){
              Navigator.pop(context);
            });
          }
        }
      });

      setState(() {});
    }

    // Add or edit NOF item
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
              title: widget.action == Action.add ? const Text("Add NOF") : const Text("Edit NOF"),
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
                          value: searchColumn,
                          child: ListTile(
                            title: Text("Paste Copied Item", style: copyIndex != -1 ? blackText : greyText),
                          ),
                        ),
                      ];
                    },
                    onSelected: (value) async {
                      if(copyIndex != -1){
                        descriptCtrl.text = job.table[copyIndex][Index.description];
                        // descriptionText =
                        categoryValue = job.table[copyIndex][Index.category];
                        priceCtrl.text = double.parse(job.table[copyIndex][Index.price]).toStringAsFixed(2);
                      }
                      setState((){});
                    }
                ),
              ],
            ),

            body: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    titlePadding("Description:", TextAlign.left),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                        child: Card(
                          child: ListTile(
                            title: TextFormField(
                              controller: descriptCtrl,
                              scrollPadding: EdgeInsets.symmetric(vertical: keyboardHeight/2),
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.name,
                              //initialValue: descriptionText,
                              // onChanged: (String s) {
                              //   descriptionText = s;
                              //   setState((){});
                              // },
                            ),
                          ),
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

                    titlePadding("Price:", TextAlign.left),
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
                      child: Card(
                          child: ListTile(
                            title: TextFormField(
                              controller: priceCtrl,
                              textAlign: TextAlign.center,
                              scrollPadding:  EdgeInsets.symmetric(vertical: keyboardHeight/2),
                              keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                              //initialValue: priceText,
                              // onChanged: (String s) {
                              //   priceText = s;
                              //   setState((){});
                              // }
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
                                  double count = (double.tryParse(countCtrl.text) ?? 0.0) - 1.0;
                                  countCtrl.text = max(count, 0.0).toString();
                                  setState((){});
                                },
                              ),
                            )
                        )
                    ) : Container(),
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
                                  Flexible(
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_forever_sharp, color: Colors.red,),
                                        onPressed: () {
                                          if(barcodeList.length > 1){
                                            barcodeList.removeAt(barcodeIndex);
                                            barcodeIndex = min(barcodeIndex - 1, 0);
                                            barcodeCtrl.text = barcodeList[barcodeIndex];
                                          }
                                          setState(() {});
                                        },
                                      )
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.fiber_new_rounded, color: Colors.blue),
                                    onPressed: () {
                                      barcodeList.add("");
                                      barcodeIndex = barcodeList.length - 1;
                                      barcodeCtrl.text = barcodeList[barcodeIndex];
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
                                  Flexible(
                                      child:IconButton(
                                        icon: const Icon(Icons.delete_forever_sharp, color: Colors.red),
                                        onPressed: () {
                                          if(ordercodeList.length > 1){
                                            ordercodeList.removeAt(ordercodeIndex);
                                            ordercodeIndex = min(ordercodeIndex - 1, 0);
                                            ordercodeCtrl.text = ordercodeList[ordercodeIndex];
                                          }
                                          setState(() {});
                                          },
                                      )
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.fiber_new_rounded, color: Colors.blue),
                                    onPressed: () {
                                      ordercodeList.add("");
                                      ordercodeIndex = ordercodeList.length - 1;
                                      ordercodeCtrl.text = ordercodeList[ordercodeIndex];
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
                                onPressed: () async {
                                  setState((){
                                    lastCategory = categoryValue;
                                  });

                                  confirmEdit();
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

  Text _setAppBarTitle(){
    switch(widget.action){
      case Action.addBarcode:
        return const Text("Assign Barcode");
      case Action.addOrdercode:
        return const Text("Assign Ordercode");
      case Action.add:
        String title = job.headerRow[searchColumn][0];
        title += job.headerRow[searchColumn].substring(min(1, job.headerRow[searchColumn].length)).toLowerCase();
        return Text("Search $title");
      case Action.edit:
        return const Text("Edit Stock");
      default:
        return const Text("");
    }
  }

  @override
  Widget build(BuildContext context) {
    keyboardHeight = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).size.height/4.0;
    // aspectRatio = (w / h) * 8.0 --> NOTE: 24 is standard for notification bar on Android
    double itemAspectRatio = MediaQuery.of(context).size.width / 2;
    itemAspectRatio /= (MediaQuery.of(context).size.height - kToolbarHeight - 24) / 2;
    itemAspectRatio *= 8;

    bool assignMode = widget.action == Action.addOrdercode || widget.action == Action.addBarcode;

    return WillPopScope(
        onWillPop: () async => _popBack(),
        child: GestureDetector(
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
                      SliverAppBar(
                          floating: true,
                          pinned: true,
                          collapsedHeight: kToolbarHeight * 2.5,
                          backgroundColor: colorMode,
                          centerTitle: true,
                          title: _setAppBarTitle(),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: (){
                              _popBack();
                            },
                          ),
                          actions: [
                            PopupMenuButton(
                                icon: const Icon(Icons.manage_search, color: Colors.white),
                                itemBuilder: (context) {
                                  return List.generate(job.headerRow.length, (index) =>
                                      PopupMenuItem<int> (
                                        value: index,
                                        child: ListTile(
                                          title: Text("Search ${job.headerRow[index]}"),
                                          trailing: assignMode && index == assignSearchColumn ? const Icon(Icons.check) :
                                            !assignMode && index == searchColumn ? const Icon(Icons.check) :
                                            null,
                                        ),
                                      )
                                  );
                                },
                                onSelected: (value) async {
                                  setState((){
                                    if(assignMode){
                                      assignSearchColumn = value;
                                    } else {
                                      searchColumn = value;
                                    }
                                  });
                                }
                            ),
                          ],
                          flexibleSpace: _getHeader(),
                      ),
                      filterList.isNotEmpty ? SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          childAspectRatio: itemAspectRatio,
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
                            child: widget.action == Action.edit ? _rowEdit(pIndex, 150.0) :
                              widget.action == Action.add ? _rowAdd(pIndex, 150.0) :
                              _rowAssign(pIndex),
                          );
                        },
                      ),
                      ) : SliverToBoxAdapter(
                        child: Center(
                            child: Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: Text("EMPTY", style: greyText, textAlign: TextAlign.center)
                            )
                        ),
                      ),

                      // ADD NOF/CANCEL ASSIGN CODE
                      SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20.0, left: 10.0, right: 10.0, bottom: 10.0),
                            child: widget.action != Action.edit ? Container(
                              height: 50,
                              width: MediaQuery.of(context).size.width * 0.7,
                              decoration: BoxDecoration(color: widget.action == Action.add ? colorEdit : colorBack, borderRadius: BorderRadius.circular(5)),
                              child: TextButton(
                                child: Text(widget.action == Action.add ? '+ Add NOF' : "Cancel", style: whiteText),
                                onPressed: () async {
                                  if(widget.action != Action.add){
                                    copyCode = "";
                                    goToPage(context, const GridView(action: Action.add));
                                  }
                                  else{
                                    if (searchColumn == Index.barcode){
                                      _setEmptyText(searchCtrl.text, "");
                                    }
                                    else if (searchColumn == Index.ordercode){
                                      _setEmptyText("", searchCtrl.text);
                                    }
                                    else{
                                      _setEmptyText("", "");
                                    }
                                    await showGeneralDialog(
                                        context: context,
                                        barrierColor: Colors.black12,
                                        barrierDismissible: false,
                                        transitionDuration: const Duration(milliseconds: 100),
                                        pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
                                          categoryValue = lastCategory;
                                          return _itemEdit(-1);
                                        }
                                    ).then((value){
                                      setState(() {});
                                    });
                                  }
                                },
                              ),
                            ) : Container(),
                          )
                      ),

                      // ASSIGN BARCODE
                      SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: widget.action == Action.add && searchColumn == Index.barcode ? Container(
                              height: 50,
                              width: MediaQuery.of(context).size.width * 0.7,
                              decoration: BoxDecoration(color: colorEdit, borderRadius: BorderRadius.circular(5)),
                              child: TextButton(
                                  child: Text('Assign Barcode to Item', style: whiteText),
                                  onPressed: () async {
                                    copyCode = searchCtrl.text;
                                    goToPage(context, const GridView(action: Action.addBarcode));
                                  }
                              ),
                            ) : Container(),
                          )
                      ),

                      // ASSIGN ORDERCODE
                      SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: widget.action == Action.add && searchColumn == Index.ordercode ? Container(
                              height: 50,
                              width: MediaQuery.of(context).size.width * 0.7,
                              decoration: BoxDecoration(color: colorEdit, borderRadius: BorderRadius.circular(5)),
                              child: TextButton(
                                  child: Text('Assign Ordercode to Item', style: whiteText),
                                  onPressed: () {
                                    // Do not check for duplicate ordercodes?
                                    if(searchCtrl.text.isNotEmpty){
                                      copyCode = searchCtrl.text;
                                      goToPage(context, const GridView(action: Action.addOrdercode));
                                    }
                                  }
                              ),
                            ) : Container(),
                          )
                      ),
                    ],
                  ),
            ),
        )
    );
  }
}

class ExportPage extends StatelessWidget{
  ExportPage({super.key});
  // Shortened Month names
  final List<String> monthNames = ["what", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "July", "Aug", "Sep", "Oct", "Nov", "Dec"];

  String _getDateString(String d){
    // // If date contains '/' , '-' or 'T' it is asssumed correct
    // if(d.contains("T")){
    //   return d.substring(0, d.indexOf("T")).toString();
    // }
    // else if(d.contains("/") || d.contains("-")){
    //   return d;
    // }
    String todayDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
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
          todayDate = "${dateSplit[2]}/${dateSplit[1]}/${dateSplit[0]}";
        }
      }
      catch (e){
        errorString = "$e";
        writeErrLog(errorString, "_getDateString()");
        return todayDate;
      }
    }
    return todayDate;
  }

  _exportXLSX() async {
    List<List<dynamic>> finalSheet = [];

    for(int i = 0; i < job.stocktake.length; i++){
      bool skip = false;
      int tableIndex = int.parse(job.stocktake[i][Index.index]);

      for(int j = 0; j < finalSheet.length; j++) {
        // Check if item already exists
        skip = int.parse(finalSheet[j][Index.index].toString()) == tableIndex;

        // Add QTY and TOTAL COST to existing item
        if(skip){
          Decimal quantity = Decimal.parse(finalSheet[j][4].toString()) + Decimal.parse(job.stocktake[i][Index.stockCount]);
          finalSheet[j][4] = quantity.toString();
          //Decimal cost = quantity * Decimal.parse(jobTable[tableIndex][Index.price]);
          //finalSheet[j][5] = (cost).toStringAsFixed(2);
          break;
        }
      }

      // Item doesn't exist, so add new item to the sheet
      if(!skip){
        Decimal quantity = Decimal.parse(job.stocktake[i][Index.stockCount].toString());
        Decimal price = Decimal.parse(job.table[tableIndex][Index.price]);
        //Decimal cost = quantity * Decimal.parse(jobTable[tableIndex][Index.price]);

        String barcode = job.table[tableIndex][Index.barcode].toString();
        if(barcode == "null") {
          barcode = "";
        }

        String ordercode = job.table[tableIndex][Index.ordercode].toString();
        if(ordercode == "null"){
          ordercode = "";
        }

        finalSheet.add([
          job.table[tableIndex][Index.index].toString(),                             // INDEX
          job.table[tableIndex][Index.category].toString().toUpperCase(),            // CATEGORY
          job.table[tableIndex][Index.description].toString().toUpperCase(),         // DESCRIPTION
          job.table[tableIndex][Index.uom].toString().toUpperCase(),                 // UOM
          quantity.toString(),                                                      // QTY
          (price).toStringAsFixed(2),                                               // UNIT PRICE
          barcode,                                                                  // BARCODES
          job.table[tableIndex][Index.nof].toUpperCase() == "TRUE",                  // NOF
          _getDateString(job.table[tableIndex][Index.datetime].toString()),           // DATETIME
          ordercode,                                                                // ORDERCODE
        ]);
      }
    }

    var excel = Excel.createExcel();
    var sheetObject = excel['Sheet1'];
    sheetObject.isRTL = false;

    // Add header row
    sheetObject.insertRowIterables(["Master Index", "Category", "Description", "UOM", 'QTY', "Unit Price", "Barcode", "NOF", "Datetime", "Ordercode"], 0,);
    for(int i = 0; i < finalSheet.length; i++){
      sheetObject.insertRowIterables(
          <String> [
            finalSheet[i][0], // INDEX
            finalSheet[i][1], // CATEGORY
            finalSheet[i][2], // DESCRIPTION
            finalSheet[i][3], // UOM
            finalSheet[i][4], // QTY
            finalSheet[i][5], // UNIT PRICE
            finalSheet[i][6], // BARCODES
            finalSheet[i][7].toString(), // NOF
            finalSheet[i][8], // DATETIME
            finalSheet[i][9], // ORDERCODE
          ],
          i+1
      );

      int yearThen = int.parse(finalSheet[i][8].split("/").last);
      // Get last two year digits using mod
      int diff = (DateTime.now().year % 100) - (yearThen % 100);
      // Color code cell if date is older than 1 year
      if(diff > 0){
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: i+1));
        cell.cellStyle = CellStyle(backgroundColorHex: '#FF8980', fontSize: 10, fontFamily: getFontFamily(FontFamily.Arial));
      }
    }

    // Set column widths
    sheetObject.setColWidth(0, 15.0); // INDEX
    sheetObject.setColWidth(1, 25.0); // CATEGORY
    sheetObject.setColWidth(2, 75.0); // DESCRIPTION
    sheetObject.setColWidth(3, 25.0); // UOM
    sheetObject.setColWidth(4, 15.0); // QTY
    sheetObject.setColWidth(5, 25.0); // COST EX GST
    sheetObject.setColWidth(6, 25.0); // BARCODES
    sheetObject.setColWidth(7, 15.0); // NOF

    String filePath = "/storage/emulated/0/Documents/${job.id}/stocktake_${job.id}.xlsx";

    var fileBytes = excel.save();
    File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
  }

  _gunDataTXT(){
    String finalTxt = "";
    for(int i = 0; i < job.stocktake.length; i++){
      finalTxt += "S    ";
      int tableIndex = int.parse(job.stocktake[i][Index.index]);

      int barcodeIndex = int.parse(job.stocktake[i][Index.stockBarcodes]);
      String bcode = job.table[tableIndex][Index.barcode].toString().split(",").toList()[barcodeIndex];
      while(bcode.length < 22){
        bcode += " ";
      }

      finalTxt += bcode;

      // Count (4 characters)
      double dblCount = double.tryParse(job.stocktake[i][Index.stockCount]) ?? 0;
      String count = Decimal.parse(dblCount.toStringAsFixed(3)).toString();

      while(count.length < 4) {
        count += " ";
      }

      finalTxt += count;

      // Location (25 characters)
      String stockLocation = job.stocktake[i][Index.stockLocation].toString();
      if(stockLocation.length > 25){
        stockLocation.substring(0,25);
      }

      while(stockLocation.length < 25){
        stockLocation += " ";
      }

      finalTxt += stockLocation;
      finalTxt += "\n";
    }

    String date = job.date.toString().replaceAll("/", "-");
    var path = '/storage/emulated/0/Documents/${job.id}/$date-${job.id}-fdapp.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);
  }

  _exportHL(){
    String finalTxt = "";
    String shortYear = DateTime.now().year.toString().substring(2);
    String shortMonth = monthNames[DateTime.now().month];

    String dateTime = "${DateTime.now().day}/${DateTime.now().month}/$shortYear${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}";
    for(int i = 0; i < job.stocktake.length; i++) {
      // Location (4 chars)
      String locationIndex = job.stocktake[i][Index.stockLocation];
      String locationNum = (job.allLocations.indexOf(locationIndex) + 1).toString();

      while(locationNum.length < 4){
        locationNum = "0$locationNum";
      }
      finalTxt += "$locationNum,";

      // Barcode (16 chars)
      int tableIndex = int.parse(job.stocktake[i][Index.index]);
      int barcodeIndex = int.parse(job.stocktake[i][Index.stockBarcodes]);
      String bcode = job.table[tableIndex][Index.barcode].toString().split(",").toList()[barcodeIndex];
      // String bcode = jt[tableIndex][Index.barcode].toString().split(",").toList()[barcodeIndex];

      while(bcode.length < 16){
        bcode += " ";
      }
      finalTxt += "$bcode,";

      // Qty (5 chars + 1 whitespace)
      double dblCount = double.tryParse(job.stocktake[i][Index.stockCount]) ?? 0;
      String count = Decimal.parse(dblCount.toStringAsFixed(3)).toString();

      while(count.length < 5){
        count = "0$count";
      }

      finalTxt += "$count ,";
      finalTxt += dateTime;
      finalTxt += "\n";
    }

    String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
    var path = '/storage/emulated/0/Documents/${job.id}/IMPORT_${job.id}_$dateOutput.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);
  }

  _exportbarcodeQty(){
    String finalTxt = "";
    for(int i = 0; i < job.stocktake.length; i++) {
      // Barcodes (22 characters)
      // Using first barcode since barcodes can be multiline
      int tableIndex = int.parse(job.stocktake[i][Index.index]);
      int barcodeIndex = int.parse(job.stocktake[i][Index.stockBarcodes]);
      List<String> bcodeList = job.table[tableIndex][Index.barcode].toString().split(",").toList();
      String barcode = "";

      if(bcodeList.isEmpty){
        barcode = "NULL";
      }
      else{
        barcode = bcodeList[barcodeIndex];
      }

      while(barcode.length < 22){
        barcode += " ";
      }

      finalTxt += "$barcode,";

      double dblCount = double.tryParse(job.stocktake[i][Index.stockCount]) ?? 0;
      finalTxt += Decimal.parse(dblCount.toStringAsFixed(3)).toString();
      finalTxt += "\n";
    }

    String shortMonth = monthNames[DateTime.now().month];
    String shortYear = DateTime.now().year.toString().substring(2);
    String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
    var path = '/storage/emulated/0/Documents/${job.id}/BARCODEQTY_${job.id}_$dateOutput.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);
  }

  _exportOrdercodeQty(){
    String finalTxt = "";
    for(int i = 0; i < job.stocktake.length; i++) {

      // Barcodes (22 characters) Using first barcode since barcodes can be multiline
      int tableIndex = int.parse(job.stocktake[i][Index.index]);
      int ordercodeIndex = int.parse(job.stocktake[i][Index.stockOrdercodes]); // Prints specific barcode
      List<String> ocodeList = job.table[tableIndex][Index.ordercode].toString().split(",").toList();

      String ordercode = "";

      if(ocodeList.isEmpty){
        ordercode = "NULL";
      }
      else{
        ordercode = ocodeList[ordercodeIndex];
      }

      if(ordercode.isEmpty){
        ordercode = "NULL";
      }

      while(ordercode.length < 22){
        ordercode += " ";
      }

      finalTxt += "$ordercode,";

      double dblCount = double.tryParse(job.stocktake[i][Index.stockCount].toString()) ?? 0;
      finalTxt += Decimal.parse(dblCount.toStringAsFixed(3)).toString();
      finalTxt += "\n";
    }

    String shortMonth = monthNames[DateTime.now().month];
    String shortYear = DateTime.now().year.toString().substring(2);
    String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
    var path = '/storage/emulated/0/Documents/${job.id}/ORDERCODEQTY_${job.id}_$dateOutput.txt';
    var jobFile = File(path);
    jobFile.writeAsString(finalTxt);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => goToPage(context, const Stocktake()),
        child: Scaffold(
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
                            height: MediaQuery.of(context).size.height / 20.0,
                          ),
                          rBox(
                              context,
                              colorOk,
                              TextButton(
                                child: Text('XLSX', style: whiteText),
                                onPressed: () {
                                  _exportXLSX();
                                  showAlert(context, "Job Data Exported!", "../Documents/${job.id}/stocktake_${job.id}.xlsx", Colors.orange);
                                },
                              )
                          ),
                          rBox(
                              context,
                              colorOk,
                              TextButton(
                                child: Text('SCANDATA (.TXT)', style: whiteText),
                                onPressed: () {
                                  _gunDataTXT();
                                  String date = job.date.toString().replaceAll("_", "-");
                                  showAlert(context, "Job Data Exported!", "../Documents/${job.id}/$date-${job.id}-fdapp.txt", Colors.orange);
                                },
                              )
                          ),
                          rBox(
                              context,
                              colorOk,
                              TextButton(
                                child: Text('H&L (POS)', style: whiteText),
                                onPressed: () {
                                  _exportHL();
                                  String shortMonth = monthNames[DateTime.now().month];
                                  String shortYear = DateTime.now().year.toString().substring(2);
                                  String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
                                  showAlert(context, "Job Data Exported!", '../Documents/${job.id}/IMPORT_${job.id}_$dateOutput.txt', Colors.orange);
                                },
                              )
                          ),
                          rBox(
                              context,
                              colorOk,
                              TextButton(
                                child: Text('Barcode / Qty', style: whiteText),
                                onPressed: () {
                                  _exportbarcodeQty();
                                  String shortMonth = monthNames[DateTime.now().month - 1];
                                  String shortYear = DateTime.now().year.toString().substring(2);
                                  String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
                                  showAlert(context, "Job Data Exported!", "../Documents/${job.id}/BARCODEQTY_${job.id}_$dateOutput.txt", Colors.orange);
                                },
                              )
                          ),
                          rBox(
                              context,
                              colorOk,
                              TextButton(
                                child: Text('Ordercode / Qty', style: whiteText),
                                onPressed: () {
                                  _exportOrdercodeQty();
                                  String shortMonth = monthNames[DateTime.now().month];
                                  String shortYear = DateTime.now().year.toString().substring(2);
                                  String dateOutput = "${DateTime.now().day}$shortMonth$shortYear";
                                  showAlert(context, "Job Data Exported!", "../Documents/${job.id}/ORDERCODEQTY_${job.id}_$dateOutput.txt\n", Colors.orange);
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

Widget headerPadding(String title, TextAlign l){
  return Padding(
    padding: const EdgeInsets.all(15.0),
    child: Text(title, textAlign: l, style: const TextStyle(color: Colors.blue, fontSize: 20.0)),
  );
}

Widget titlePadding(String title, TextAlign l){
  return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.lightBlue, fontSize: 20.0, fontWeight: FontWeight.bold),
        child: Text(title, textAlign: l),
      )
  );
}

Widget rBox(BuildContext context, Color color, Widget widget) {
  return Padding(
    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
    child: Container(
      height: 50,
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: widget,
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String str) async {
  bool confirmation = false;
  await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) =>
          WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
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
          )
  );
  return confirmation;
}

Future<void> prepareStorage() async {
  var path = '/storage/emulated/0';//!isEmulating ? '/storage/emulated/0' : 'sdcard';
  rootDir = Directory(path);
  var storage = await storageType.status;
  if (storage != PermissionStatus.granted) {
    await storageType.request();
  }
}

Future<String> textEditDialog(BuildContext context, String title, String str) async{
  String originalText = str;
  String newText = originalText;

  await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context){
        return StatefulBuilder(
            builder: (builder, setState){
              return WillPopScope(
                onWillPop: () async => false,
                child: GestureDetector(
                    onTap: () {
                      FocusScopeNode currentFocus = FocusScope.of(context);
                      if (!currentFocus.hasPrimaryFocus) {
                        currentFocus.unfocus();
                      }
                    },
                    child: AlertDialog(
                      actionsAlignment: MainAxisAlignment.spaceAround,
                      title: Text(title),
                      content: Card(
                          child: ListTile(
                            title: TextFormField(
                              initialValue: originalText,
                              autofocus: true,
                              decoration: const InputDecoration(hintText: '', border: InputBorder.none),
                              keyboardType: TextInputType.name,
                              onChanged: (value) {
                                newText = value.toUpperCase();
                                setState((){});
                              },
                            ),
                          )
                      ),
                      actions: <Widget>[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: colorBack),
                          onPressed: () {
                            newText = originalText;
                            setState((){});
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("Confirm"),
                        ),
                      ],
                    )
                ),
              );
            }
        );
      }
  );
  return newText;
}

setLocation(BuildContext context1){
  showGeneralDialog(
      context: context1,
      barrierColor: Colors.black12, // Background color
      barrierDismissible: false,
      barrierLabel: 'Dialog',
      transitionDuration: const Duration(milliseconds: 100),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation){
        return StatefulBuilder(
            builder: (context, setState) {
              return WillPopScope(
                  onWillPop: () async => goToPage(context, const Stocktake()),
                  child: Scaffold(
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
                                children: job.allLocations.isEmpty ? List.empty() : List.generate(job.allLocations.length, (index) => Card(
                                    child: ListTile(
                                      title: Text(job.allLocations[index], textAlign: TextAlign.justify, softWrap: true, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      selected: job.allLocations[index] == job.location,
                                      selectedColor: Colors.black,
                                      selectedTileColor: Colors.greenAccent.withOpacity(0.4),
                                      trailing: IconButton(
                                        icon: Icon(Icons.edit_note, color: Colors.yellow.shade800),
                                        // EDIT LOCATION TEXT
                                        onPressed: () async {
                                          await textEditDialog(context, "Edit Location", job.allLocations[index]).then((value){
                                            if(value.isNotEmpty){
                                              job.allLocations[index] = value;
                                              job.allLocations = job.allLocations.toSet().toList();
                                            }
                                            else {
                                              showAlert(context, "ERROR: ", "Location text cannot be empty.", Colors.red);
                                            }
                                          });

                                          await writeJob(job).then((value){
                                            setState((){});
                                          });
                                        },
                                      ),

                                      // DELETE LOCATION
                                      onLongPress: () async {
                                        bool b = await confirmDialog(context, "Delete location '${job.allLocations[index]}'?");
                                        if(b){
                                          if(job.location == job.allLocations[index]) {
                                            if(job.allLocations.isNotEmpty){
                                              job.location = job.allLocations[0];
                                            }
                                            else{
                                              job.location = "";
                                            }
                                          }

                                          // Clear deleted location from stocktake items
                                          for(int i = 0; i < job.stocktake.length; i++){
                                            if(job.stocktake[i][Index.stockLocation] == job.allLocations[index]){
                                              job.stocktake[i][Index.stockLocation] = "NULL";
                                            }
                                          }

                                          job.allLocations.removeAt(index);

                                          await writeJob(job).then((value){
                                            setState((){});
                                          });
                                        }
                                      },
                                      onTap: () {
                                        job.location = job.allLocations[index];
                                        goToPage(context, const Stocktake());
                                        setState((){});
                                      },
                                    )
                                )
                                ),
                              ),
                              Card(
                                  child: ListTile(
                                    title: Text("+ Add New Location..", style: greyText, textAlign: TextAlign.justify),
                                    onTap: () async {
                                      await textEditDialog(context, "New Location", "").then((value) async {
                                        if(value.isNotEmpty && !job.allLocations.contains(value)){
                                          job.allLocations.add(value);
                                          await writeJob(job).then((value){
                                            setState((){});
                                          });
                                        }
                                      });
                                    },
                                  )
                              )
                            ]
                        )
                    ),
                  )
              );
            }
        );
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

showNotification(BuildContext context,  Color bkgColor, TextStyle textStyle, String message,) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: textStyle, maxLines: 2, softWrap: true, overflow: TextOverflow.fade),
        backgroundColor: bkgColor,
        duration: const Duration(milliseconds: 1200),
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

showAlert(BuildContext context, String txtTitle, String txtContent, Color c) {
  return showDialog(
      barrierDismissible: false,
      context: context,
      barrierColor: c,
      builder: (context) =>
          WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
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
          )
  );
}

writeJob(StockJob job) async {
  String filePath = '/storage/emulated/0/Documents/${job.id}/';

  // If job folder does not exist, make it!
  await Directory(filePath).exists().then((value){
    if(!value){
      Directory(filePath).create().then((Directory directory) {
        // huh?
      });
    }
  });

  filePath += 'ASJob_${job.id}';
  var jobFile = File(filePath);
  Map<String, dynamic> jMap = job.toJson();
  var jString = jsonEncode(jMap);
  jobFile.writeAsString(jString, mode: FileMode.writeOnly);
}

loadSessionFile() async {
  errorString = "";
  var filePath = File('$appDir/session_file');
  if(!await filePath.exists()) {
    // Create new session file
    sFile = {
      "uid" : "",
      "fontScale" : 16.0,
      "permission" : "${Permission.manageExternalStorage}",
    };

    storageType = Permission.manageExternalStorage;
    await writeSession();
  }
  else{
    try{
      // Load existing session file
      String fileContent = await filePath.readAsString();
      var jsn = json.decode(fileContent);
      sFile = {
        "uid" : "", //(jsn['uid'] == null || jsn["uid"].isEmpty || jsn) ? "USER1" : jsn['uid'].toString(),
        "fontScale" : jsn["fontScale"] == null ? 16.0 : jsn['fontScale'] as double,
        "permission" : jsn["permission"] == null ? "Permission.manageExternalStorage" : jsn['permission'].toString(), // == null ? 0 : jsn['permission'] as int,
      };

      // Set storage permissions
      if(sFile["permission"] == "Permission.manageExternalStorage"){
        storageType = Permission.manageExternalStorage;
      }
      else if(sFile["permission"] == "Permission.storage"){
        storageType = Permission.storage;
      }
      else{
        storageType = Permission.manageExternalStorage;
      }
    }
    catch(e){
      errorString = "$e";
      writeErrLog("$e", "getSession()");
    }
  }
}

loadDefMastersheet() async {
  // Copy MASTERFILE into App Directory
  if(!File("$appDir/MASTERFILE.xlsx").existsSync()){
    ByteData data = await rootBundle.load("assets/MASTERFILE.xlsx"); // Copy MASTERFILE from assets folder
    var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File("$appDir/MASTERFILE.xlsx").writeAsBytes(bytes); // Write MASTERFILE to App Directory
  }
}

writeSession() async {
  errorString = "";
  Map<String, dynamic> jMap = {
    "uid" : sFile["uid"],
    'fontScale' : sFile["fontScale"],
    'permission' : sFile["permission"],
  };

  try{
    final jString = jsonEncode(jMap);
    final filePath = File('$appDir/session_file');
    filePath.writeAsString(jString, mode: FileMode.writeOnly);
  }
  catch (e){
   errorString = "$e";
   writeErrLog("$e", "writeSession()");
  }
}

writeErrLog(String err, String id) async {
  // Construct new error line entry
  String errLine = "[ ERROR @ ${DateTime.now()} ]\n";
  errLine += "ID: $id\n";
  errLine += "ERROR: $err\n";
  errLine += "[ END ]\n\n";

  // Create new error log if it does not exist
  if(!File("$appDir/fd_err_log.txt").existsSync()){
    String newLog = "++ FD APP ERROR LOG ++\n\n";
    newLog = "[ ERROR @ START_OF_ERROR_LOG";
    newLog += "ID: Test Error\n";
    newLog += "ERROR: THIS IS A TEST ERROR AND CAN BE IGNORED\n";
    newLog += "[ END ]\n\n";

    // Add error line to new file lines
    errLine = newLog + errLine;
    final errFile = File('$appDir/fd_err_log.txt');
    errFile.writeAsString(errLine, mode: FileMode.writeOnlyAppend);
  }
  else {
    final errFile = File('$appDir/fd_err_log.txt');
    var s = await errFile.readAsLines();

    if(s.length < 10000) {
      errFile.writeAsString(errLine, mode: FileMode.writeOnlyAppend);
    }
    else {
      // Create new file if current file lines exceed 10000
      String newLog = "++ FD APP ERROR LOG ++\n\n";
      newLog = "[ ERROR @ START_OF_ERROR_LOG";
      newLog += "ID: Test Error\n";
      newLog += "ERROR: THIS IS A TEST ERROR AND CAN BE IGNORED\n";
      newLog += "[ END ]\n\n";
      errLine = newLog + errLine;

      // Overwrite file and add error line
      errFile.writeAsString(errLine, mode: FileMode.writeOnly);
    }
  }
}

copyErrLog() async {
  var filePath = File('$appDir/fd_err_log.txt');
  String fileContent = await filePath.readAsString();
  String copyPath = '/storage/emulated/0/Documents/fd_err_log.txt';
  var errFile = File(copyPath);
  errFile.writeAsString(fileContent, mode: FileMode.writeOnly);
}

class StockJob {
  String date = '';
  String id;
  List<String> headerRow = List.empty(growable: true);
  Decimal total = Decimal.parse('0.0');
  List<List<String>> stocktake = List.empty(growable: true);
  List<List<String>> table = List.empty();
  List<String> allLocations = List.empty(growable: true);
  String location = "";

  StockJob({
    required this.id,
    date,
    total,
    stocktake,
    table,
    allLocations,
    location,
  });

  factory StockJob.fromJson(dynamic json) {
    StockJob sj = StockJob(
        id: json['id'] as String
    );

    sj.date = json.containsKey("date") ? json['date'] as String : "";

    sj.stocktake = List.empty(growable: true);
    if(json.containsKey("stocktake") && json['stocktake'] != null){
      for(final map in jsonDecode(json['stocktake'])){
        sj.stocktake.add(<String>[
          map[Index.index].toString(),
          map[Index.stockCount].toString(),
          map[Index.stockLocation].toString(),
          map[Index.stockBarcodes] == null ? "0" : map[Index.stockBarcodes].toString(),
          map[Index.stockOrdercodes] == null ? "0" : map[Index.stockOrdercodes].toString(),
        ]);
      }
    }

    if(json.containsKey('headerRow') && json['headerRow'] != null) {
      var h = jsonDecode(json['headerRow']);
      sj.headerRow = List.generate(h.length, (index) => h[index].toString());
    }

    if(json.containsKey('table') && json['table'] != null){
      var m = jsonDecode(json['table']);
      sj.table = List.generate(
          m.length, (index) => List<String>.generate(
          m[0].length, (index2) => m[index][index2].toString().toUpperCase()
      ));
    }

    sj.allLocations = !json.containsKey("allLocations") || json['allLocations'] == null ? List.empty(growable: true) : [
      for(final l in jsonDecode(json['allLocations']))
        l as String,
    ];

    sj.location = '';
    return sj;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.isEmpty ? "${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}" : date,
      'id': id,
      'headerRow': jsonEncode(headerRow),
      'table' : jsonEncode(table),
      'stocktake': jsonEncode(stocktake),
      'allLocations': jsonEncode(allLocations),
      'location': location,
    };
  }

  calcTotal() {
    total = Decimal.parse('0.0');
    for (int i = 0; i < stocktake.length; i++) {
      total += Decimal.parse(stocktake[i][Index.stockCount].toString());
    }
  }
}
