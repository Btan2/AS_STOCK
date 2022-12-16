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
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'stock_job.dart';

final tableKey = GlobalKey<PaginatedDataTableState>();
List<StockItem> database = [];
StockJob currentJob = StockJob(id:"EMPTY", name:"EMPTY");

bool deleteConfirm = false; // Make sure user definitely wants to delete a job file

/*
===================
  main
===================
*/
void main() {
  runApp(
    const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoginPage()
    ),
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
                    hintText: 'Enter valid email id as user_name@email_client.com'
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 0),
              child: TextField(
                obscureText: true,
                decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Password',
                    hintText: 'Enter secure password'
                ),
              ),
            ),
            TextButton(
              child: const Text('Forgot Password', style: TextStyle(color: Colors.blue, fontSize: 15)),
              onPressed: (){ mPrint('FORGOT PASSWORD LINK'); },
            ),
            Container(
              height: 50,
              width: 250,
              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
              child: TextButton(
                child: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 25)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage())); // use animation for login -> home
                },
              ),
            ),
            const SizedBox(height: 130),
            const Text('Serving Australian businesses for over 30 years!', style: TextStyle(color: Colors.blueGrey))
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
              child: Column(
                  children: <Widget>[
                    mButton(
                        context,
                        Colors.blue,
                        TextButton(
                          child: Text('Jobs', style: textStyle(Colors.white, fontButton)),
                          onPressed: (){
                            goToPage(context, const JobsPage());
                            },
                        )
                    ),
                  ]
              ),
            ),
          ),

          bottomSheet: SingleChildScrollView(
              child: Center(
                  child:Column(
                      children:[
                        mButton(context, Colors.redAccent,
                            TextButton(
                              child: Text('Logout', style: textStyle(Colors.white, fontButton)),
                              onPressed: (){
                                Navigator.push( context, MaterialPageRoute(builder: (context) => const LoginPage()));
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
  Jobs Page
==================
*/
class JobsPage extends StatefulWidget {
  const JobsPage({super.key,});

  @override
  State<JobsPage> createState() => _JobsState();
}
class _JobsState extends State<JobsPage> {
  List jobList = []; // List of JSON job files inside application directory
  bool confirm = false;
  //Color confirmColor = Colors.grey.shade200;

  @override
  void initState() {
    super.initState();
    _listFiles();

    mPrint("Current Job: ${currentJob.name.toString()}");
  }

  // Get list of JSON job files
  void _listFiles() async {
    final directory = (await getApplicationDocumentsDirectory()).path;
    jobList.clear();
    var list = Directory("$directory/").listSync();
    for (int i =0; i < list.length; i++) {
      var spt = list[i].toString().split("/");
      String str = spt[spt.length-1];
      if (str.startsWith("job_")) {
        jobList.add(list[i]);
      }
    }

    refresh(this);
  }

  // Show alert dialog if db path doesn't exist
  Future<void> checkDB() async{
    if(currentJob.dbPath.isEmpty){
      await showAlert(context, "", "NO DATABASE FILE", warning.withOpacity(0.8));
      return;
    }
  }

  // NOT PROPER ASYNC, NEEDS TO BE FIXED
  Future<void> loadDatabase(String path) async{
    if(path.isEmpty){
      await showAlert(context, "", "NO DATABASE FILE", warning.withOpacity(0.8));
      return;
    }

    File file = File(path);
    var bytes = file.readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    var sheet = "Sheet1";

    // Popup to select specific sheet?
    for (var table in excel.tables.keys) {
      sheet = table;
      break;
    }

    database.clear();

    // Need counter to ignore first two rows since they do not contain stock item data
    int count = 0;
    for(var row in excel[sheet].rows){
      await Future.delayed(const Duration(microseconds: 0));
      setState(() {});
      refresh(this);

      if (count > 1) {
        database.add(StockItem(
          index: database.length,
          barcode: (row[1] as Data).value.toString(),
          category: (row[2] as Data).value.toString().trim().toUpperCase(),
          description: (row[3] as Data).value.toString().trim().toUpperCase(),
          uom: (row[4] as Data).value.toString().trim().toUpperCase(),
          price: (row[5] as Data).value,
          nof: false,
        ));
      } else {
        count++;
      }

      //setState(() {});
    }

    mPrint("MAIN BD: ${database.length}");
  }

  Future<void> loadStockJob(int index) async{
    bool loadDB = false;
    await _readJsonFile(jobList[index]).then((value){
      if(currentJob.name != value.name) {
        loadDB = true;
        currentJob = value;
        loadingDialog(context);
      }
    });

    if(loadDB){
      await loadDatabase(currentJob.dbPath);
    }
    else{
      await checkDB();
    }
  }

  String shortPath(String s){
    var sp = s.split("/");
    String str = sp[sp.length-1];
    return str.substring(0, str.length-1);
  }

  deleteJob(){
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.red.shade300.withOpacity(0.8),
      builder: (context) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceAround,

        title: Text("Delete StockJob file?", style: textStyle(Colors.black, fontTitle),),
        content: Card(
            child: ListTile(
              title: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Type "YES" to confirm...', disabledBorder: InputBorder.none),
                controller: TextEditingController(),
                keyboardType: TextInputType.name,
                onChanged: (value) {
                  var str = value.toUpperCase().trimLeft();
                  confirm = str == "Y" || str.startsWith("YES");
                },
              ),
            )
        ),

        actions: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: back),
            onPressed: () {
              mPrint("JOB NOT DELETED");
              Navigator.pop(context);
              },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ok),
            onPressed: () {
              if(confirm)
              {
                mPrint("JOB SHOULD BE DELETED");
              }
              else{
                mPrint("JOB NOT DELETED");
              }
              Navigator.pop(context);
              },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
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
                    Column( // Load list of jobs as buttons, pressing button takes user to job
                      children: List.generate(jobList.length, (index) => Card(
                        child: ListTile(
                          title:Text(shortPath(jobList[index].toString())),
                          trailing: IconButton(
                              icon: const Icon(Icons.inventory_2),
                              color: Colors.grey[400],
                              highlightColor: Colors.red[300],

                              onPressed: () {
                                deleteJob();
                                refresh(this);
                              },
                          ),

                          onTap: () async {
                            await loadStockJob(index).then((value){ goToPage(context, const OpenJob()); });
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
                child:Column(
                    children:[
                      mButton(context, Colors.lightBlue,
                          TextButton(
                            child: Text('New Job', style: textStyle(Colors.white, fontBody)),
                            onPressed: (){
                              goToPage(context, const NewJob());
                            },
                          )
                      ),
                      mButton(context, Colors.blue[800]!,
                          TextButton(
                            child: Text('Load from Storage', style: textStyle(Colors.white, fontBody)),
                            onPressed: (){
                            },
                          )
                      ),
                      mButton(context, Colors.redAccent,
                          TextButton(
                            child: Text('Back', style: textStyle(Colors.white, fontBody)),
                            onPressed: (){
                              database.clear();
                              currentJob = StockJob(id:"EMPTY", name:"EMPTY");
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
  const NewJob({super.key,});

  @override
  State<NewJob> createState() => _NewJobState();
}
class _NewJobState extends State<NewJob> {
  StockJob newJob = StockJob(id: "NULL", name: "EMPTY");

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
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Job Id: ', textAlign: TextAlign.left, style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
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
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Job Name: ', textAlign: TextAlign.left, style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 5),
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
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Database File Path: ', textAlign: TextAlign.left, style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 15.0, bottom: 5),
                      child: Card(
                        child: ListTile(
                          leading: newJob.dbPath == "" ? const Icon(Icons.question_mark) : null,
                          title: Text(shortFilePath(newJob.dbPath),textAlign: TextAlign.left,),
                          onTap: () {
                            pickFile().then((val) {
                              if (val!.isEmpty) {
                                newJob.dbPath = "";
                                showAlert(
                                    context,
                                    "FilePicker",
                                    "Invalid File Path:"
                                        "\n- Only '.XLSX' and '.CSV' files are accepted. Make sure you have the correct file extension type."
                                        "\n- Check the integrity of the file if you cannot load it, the pathing could be corrupted.",
                                    Colors.red.withOpacity(0.8));
                              }
                              else {
                                newJob.dbPath = val;
                                // showAlert(context, "FilePicker",
                                //     "File Path is Valid!",
                                //     Colors.blue.withOpacity(0.8));
                                mPrint(newJob.dbPath);
                              }

                              refresh(this);
                            });
                            },
                        ),
                      ),
                    ),
                  ]
              )
          ),

          bottomSheet: SingleChildScrollView(
              child: Center(
                  child:Column(
                      children:[
                        mButton(context, ok,
                            TextButton(
                              child: Text('Create Job', style: textStyle(Colors.white, fontBody)),
                              onPressed: () async {
                                _writeJson(newJob);
                                showAlert(context, "New Job Created", newJob.id, Colors.blue.withOpacity(0.8)).then((value) {
                                  goToPage(context, const JobsPage());
                                });
                                },
                            )
                        ),
                        mButton(context, back,
                            TextButton(
                              child: Text('Cancel', style: textStyle(Colors.white, fontBody)),
                              onPressed: () async {
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
  Open Job
  View details, go to add item page, view current stock etc.
==================
*/
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
            title: Text("Job ID: ${currentJob.id.toString()}", textAlign: TextAlign.center),
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
                        title: Text("Total Stock Count: ${currentJob.stock.length}"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text("Database: ${shortFilePath(currentJob.dbPath)}"),
                        trailing: const Icon(Icons.edit_rounded, color: Colors.amberAccent),
                      ),
                    ),
                ]
              ) ,
            ),

          bottomSheet: SingleChildScrollView(
              child: Center(
                  child:Column(
                      children:[
                        mButton(context, Colors.blue,
                            TextButton(
                              child: Text('Stocktake', style: textStyle(Colors.white, fontBody)),
                              onPressed: () {
                                goToPage(context, const StocktakePage());
                                },
                            )
                        ),
                        mButton(context, Colors.blue,
                            TextButton(
                              child: Text('View Job Spreadsheet', style: textStyle(Colors.white, fontBody)),
                              onPressed: () {
                                goToPage(context, ViewSpreadSheet(mainList: currentJob.stock));
                                },
                            )
                        ),
                        mButton(context, Colors.blue,
                            TextButton(
                              child: Text('View Database Spreadsheet', style: textStyle(Colors.white, fontBody)),
                              onPressed: () {
                                goToPage(context, ViewSpreadSheet(mainList: database));
                                },
                            )
                        ),
                        mButton(context, Colors.green,
                            TextButton(
                              child: Text('Save Job', style: textStyle(Colors.white, fontBody)),
                              onPressed: () {
                                _writeJson(currentJob);
                              },
                            )
                        ),
                        mButton(context, Colors.redAccent,
                            TextButton(
                              child: Text('Close Job', style: textStyle(Colors.white, fontBody)),
                              onPressed: () {
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
              )
          ),
        ),
    );
  }
}

/*
==================
  Stocktake Page
  TO DO: * Change total stock count position, the title isn't so obvious
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

  getIndex(){
    return selectIndex;
  }

  setIndex(int stockIndex, int selectIndex) {
    this.stockIndex = stockIndex;
    this.selectIndex = selectIndex;

    mPrint("SELECT INDEX: $selectIndex");
    if(selectIndex != -1) {
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
          title:  Text("Stocktake - Total: ${currentJob.stock.length}", textAlign: TextAlign.center),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              goToPage(context, const OpenJob());
              },
          ),
        ),

        body: Center(
            child: Column(
                children: [
                  Card(
                    child: ListTile(
                      leading: currentJob.location.isEmpty ? const Icon(Icons.warning_amber, color: Colors.red) : null,
                      title: currentJob.location.isEmpty ? const Text("NO LOCATION") : Text(currentJob.location),
                      trailing: currentJob.location.isEmpty? null : const Icon(Icons.edit_rounded, color: Colors.blueGrey),
                      onTap: () async {
                        goToPage(context, const Location());
                        },
                    ),
                  ),
                  mButton(context, Colors.blue,
                      TextButton(
                        child: Text('ADD ITEM', style: textStyle(Colors.white, fontBody)),
                        onPressed: () async {
                          if(currentJob.location.isNotEmpty && currentJob.dbPath.isNotEmpty) {
                            selectIndex = -1;
                            goToPage(context, const AddItem());
                          }
                          else{
                            String er = "\n${currentJob.location.isEmpty ? "Need location! \n" : ""}"
                                "${currentJob.dbPath.isEmpty ? "Need database file!" : ""}";
                            showAlert(context, "Alert", er, Colors.red.withOpacity(0.8));
                          }
                          },
                      )
                  ),
                  mButton(context, selectIndex > -1 ? ok : disable,
                      TextButton (
                          child: Text('EDIT ITEM', style: textStyle(Colors.white, fontBody)),
                          onPressed: () async {
                            if (selectIndex >= 0){
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
                                            child: ListTile(title: Text("Database Index: $stockIndex")),
                                          ),
                                          Card(
                                            child: ListTile(title: Text("Barcode: ${database[stockIndex].barcode}")),
                                          ),
                                          Card(
                                            child: ListTile(title: Text("Description: ${database[stockIndex].description}")),
                                          ),
                                          Card(
                                            child: ListTile(title: Text("UOM: ${database[stockIndex].uom}")),
                                          ),
                                          Card(
                                            child: ListTile(title: Text("Count: ${currentJob.literal[selectIndex].count}")),
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.8,
                                            height: 20.0,
                                          ),
                                          Card(
                                              child: ListTile(
                                                title: TextField(
                                                    autofocus: true,
                                                    decoration: const InputDecoration(hintText: 'Remove: ', border: InputBorder.none),
                                                    controller: removeCtrl,
                                                    keyboardType: TextInputType.number,
                                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                    // keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    // inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
                                                    onChanged: (value){
                                                      removeCtrl.text = value;

                                                      refresh(this);
                                                    },
                                                    onSubmitted: (value) {
                                                      int count = int.parse(value);
                                                      currentJob.removeStock(selectIndex, database[stockIndex], count);
                                                      selectIndex = -1;
                                                      Navigator.pop(context);
                                                      refresh(this);
                                                    },
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(Icons.cancel),
                                                  onPressed: (){
                                                    refresh(this);
                                                    removeCtrl.text = '0';
                                                  },
                                                ),
                                              )
                                          ),
                                        ],
                                      )
                                  ),
                                  actions: [
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: back),
                                        child: const Text("Cancel"),
                                        onPressed: () {
                                          removeCtrl.text = '0';
                                          selectIndex = -1;
                                          Navigator.pop(context);
                                          refresh(this);
                                        }),
                                  ],
                                ),
                              );
                            }
                          },
                        )),

                  Expanded(
                        child: SingleChildScrollView(
                            child: PaginatedDataTable(
                                sortColumnIndex: 0,
                                sortAscending: true,
                                showCheckboxColumn: false,
                                showFirstLastButtons: true,
                                rowsPerPage: 20,
                                key: tableKey,
                                controller: ScrollController(),
                                columns: const <DataColumn>[
                                  DataColumn(label: Text("Description")),
                                  DataColumn(label: Text("Count")),
                                  DataColumn(label: Text("UOM")),
                                  DataColumn(label: Text("Location")),
                                  DataColumn(label: Text("Barcode")),
                                ],
                                source: RowLiterals(dataList: currentJob.literal, parent: this)
                            )
                        )
                    ),
                ]
            )
        ),
      )
    );
}}


/*
==================
  Select and Add Locations
==================
*/
class Location extends StatefulWidget {
  const Location({super.key});

  @override
  State<Location> createState() => _LocationState();
}
class _LocationState extends State<Location>{
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
      barrierColor: ok.withOpacity(0.8),
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
                    if (value.isNotEmpty){
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
            style: ElevatedButton.styleFrom(backgroundColor: back),
            onPressed: () {
              loctnCtrl.clear();
              refresh(this);
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ok),
            onPressed: () {
              loctnCtrl.clear();
            },
            child: const Text("Clear"),
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
            title: const Text("Location", textAlign: TextAlign.center),
          ),

          body: SingleChildScrollView(
              child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text('Current Location: ', textAlign: TextAlign.left, style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ),
                    Card(
                      child: ListTile(
                        title: currentJob.location.isEmpty ? Text("Select a location from the list below...", style: textStyle(Colors.grey, fontBody)) : Text(currentJob.location, textAlign: TextAlign.center),
                        leading: currentJob.location.isEmpty ?  const Icon(Icons.warning_amber, color: Colors.red) : null,

                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15, bottom: 5),
                      child: Text(
                          'Locations: ',
                          textAlign: TextAlign.left,
                          style: TextStyle(color: Colors.blue, fontSize: 20)
                      ),
                    ),

                    Column(
                      children: List.generate(
                        currentJob.allLocations.length, (index) =>
                          Card(
                              child: ListTile(
                                title: Text(currentJob.allLocations[index], textAlign: TextAlign.justify),
                                onTap: () {
                                  currentJob.setLocation(index);
                                  refresh(this);
                                  },
                              )
                          ),
                      ),
                    ),
                  ]
              )
          ),

          bottomSheet: SingleChildScrollView(
              child: Center(
                  child:Column(
                      children:[
                        mButton( context,
                            Colors.lightBlue,
                            TextButton(
                              child: Text('Add Location', style: textStyle(Colors.white, fontTitle)),
                              onPressed: (){
                                newLocation();
                              },
                            )
                        ),
                        mButton( context,
                            Colors.grey[900]!,
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
  Add Item Page
==================
*/
class AddItem extends StatefulWidget {
  const AddItem({super.key});

  @override
  State<AddItem> createState() => _AddItemState();
}
class _AddItemState extends State<AddItem> {
  int selectIndex = -1;
  TextEditingController searchCtrl = TextEditingController();
  TextEditingController addCtrl = TextEditingController();
  List<StockItem>? filterList;

  @override
  void initState() {
    super.initState();
    filterList = database;

    //addCtrl.selection = TextSelection.fromPosition(TextPosition(offset: addCtrl.text.length));
    mPrint("LUDED");
  }

  getIndex() {
    return selectIndex;
  }

  setIndex(int stockIndex, int selectIndex) {
      this.selectIndex = selectIndex;

      mPrint("SELECT INDEX: $selectIndex");
      if(selectIndex != -1) {
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
          resizeToAvoidBottomInset: false,

          appBar: AppBar(
            centerTitle: true,
            title: const Text("Add Item"),
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
                            decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none),
                            onChanged: (value) {
                              String search = value.toUpperCase();

                              // Jump back to first page if search input text is manually deleted by the user
                              if (search.isEmpty){
                                tableKey.currentState?.pageTo(0);
                              }
                              filterList = database.where((item) => item.description.contains(search) || item.barcode.toString().contains(search)).toList();

                              refresh(this);
                            }),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: (){
                            tableKey.currentState?.pageTo(0); // Jump back to first page on search text clear
                            searchCtrl.clear();
                            filterList = database;

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
                                rowsPerPage: 20,
                                controller: ScrollController(),

                                // Only show description and UOM
                                columns: getColumns([3,4]),
                                source: RowSource(parent: this, dataList: filterList, showCells: [3,4], select: true),
                            )
                        )
                    ),
                  ]
              )
          ),

          bottomSheet: SingleChildScrollView(
            child: Center(
                child:Column(
                    children:[
                      mButton(context, selectIndex > -1 ? Colors.blue : Colors.grey,
                          TextButton(
                            child: Text( "ADD ITEM", style: textStyle(Colors.white, fontTitle)), //itemIndex == -1 ? "ADD NOF" :
                            onPressed: () {
                              if(selectIndex > -1) {
                                showDialog(
                                  barrierDismissible: false,
                                  context: context,
                                  barrierColor: Colors.blue.withOpacity(0.8),
                                  builder: (context) => AlertDialog(
                                    actionsAlignment: MainAxisAlignment.spaceAround,
                                    content: Card(
                                        child: ListTile(
                                          title: Text("Add:", style: textStyle(Colors.black, fontBody)),
                                          subtitle: TextField(
                                            // autofocus: true,
                                            decoration: const InputDecoration(border: InputBorder.none),
                                            controller: addCtrl,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                                            onSubmitted: (value) {
                                              int count = int.parse(value); // ?? '0'
                                              if (count > 0) {
                                                currentJob.addStock(filterList![selectIndex], count);
                                                //showAlert( context, "Added Item", "${_db[itemIndex].description} x$addCount", Colors.blue.withOpacity(0.8));
                                              }

                                              addCtrl.clear();
                                              selectIndex = -1;
                                              refresh(this);
                                              Navigator.pop(context);
                                            },
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.cancel),
                                            onPressed: (){
                                              addCtrl.clear();
                                            },
                                          ),
                                        )
                                    ),
                                    actions: [
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: back),
                                          child: const Text("Cancel"),
                                          onPressed: () {
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
                    ]
                )
            )
        ),
      )
    );
  }
}

/*
=========================
  View Spread Sheet
=========================
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
                  title: Text("Spreadsheet View: ${currentJob.id}", textAlign: TextAlign.center),
                  leading: IconButton(
                      onPressed: () {
                        goToPage(context, const OpenJob());
                      },
                      icon: const Icon(Icons.arrow_back)),
                ),
                body: Center(
                    child: Column(
                        children: [
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.search),
                              title: TextField(
                                  controller: searchController,
                                  decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none),
                                  onChanged: (value) {
                                    String result = value.toUpperCase();
                                    if(result == ""){
                                      tableKey.currentState!.pageTo(0);
                                    }
                                    filterList = widget.mainList.where(
                                            (item) => item.description.contains(result) ||
                                            item.barcode.toString().contains(result) ||
                                            item.category.contains(result)).toList();

                                    refresh(this);
                                  }),
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
                                      rowsPerPage: 20,
                                      key: tableKey,
                                      controller: ScrollController(),
                                      columns: getColumns([]),
                                      source: RowSource(parent: this, dataList: filterList, select: false)
                                  )
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

/*
======================================================
      FUNCTIONS, REUSABLE WIDGETS AND STYLES
======================================================
*/

Color ok = Colors.blue.shade400;
Color warning = Colors.deepPurple.shade200;
Color disable = Colors.blue.shade200;
Color back = Colors.grey.shade400;

const fontTitle = 18.0;
const fontBody = 18.0;
const fontSmall = 12.0;
const fontBig = 24.0;
const fontButton = 18.0;

refresh(var widget){
  widget.setState(() {});
}

textStyle(Color c, var s){
    return TextStyle(color: c, fontSize: s);
}

// Jump to page with no animation
goToPage(BuildContext context, Widget page) {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}



// Basic button widget
Widget mButton(BuildContext context, Color c, TextButton t) {
  return Padding(
    padding:
    const EdgeInsets.only(left: 0.0, right: 0.0, top: 10.0, bottom: 10.0),
    child: Container(
      height: 50,
      width: MediaQuery.of(context).size.width * 0.8,
      decoration:
      BoxDecoration(color: c),//, borderRadius: BorderRadius.),
      child: t,
    ),
  );
}

// Alert pop-up with confirmation window
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
            style: ElevatedButton.styleFrom(backgroundColor: ok),
            child: const Text("Ok"),
            onPressed: (){
              Navigator.pop(context);
            }),
      ],
    ),
  );
}

// Show loading window
loadingDialog(BuildContext context) {
  AlertDialog alert = AlertDialog(
    content: Row(children: [
      const CircularProgressIndicator(
        backgroundColor: Colors.white,
      ),
      Container(margin: const EdgeInsets.only(left: 10), child: const Text("Loading...")),
    ]),
  );
  showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return alert;
      });
}

// Get DataColumns for table
// [showColumn] defines which columns should be returned; an empty list will show every column of the table.
// Returns columns in order of the [showColumn] e.g. [3, 1, 2] will show 3rd column first, 1st column second and so on.
List<DataColumn> getColumns(List<int>? showColumn) {
  List<DataColumn> dataColumns = <DataColumn>[
    const DataColumn(label: Text('Index')),
    const DataColumn(label: Text('Barcode')),
    const DataColumn(label: Text('Category')),
    const DataColumn(label: Text('Description')),
    const DataColumn(label: Text('UOM')),
    const DataColumn(label: Text('Price')),
  ];

  // Not hiding anything, return all columns
  if (showColumn == null || showColumn.isEmpty) {
    return dataColumns;
  }

  // Create list of columns in order of [showColumn]
  List<DataColumn> dc = [];
  for (int i = 0; i < showColumn.length; i++) {
    int col = showColumn[i];
    if (col < dataColumns.length){
      dc.add(dataColumns[col]);
    }
  }

  return dc;
}

// Return Rows filled with StockLiteral(s)
class RowLiterals extends DataTableSource{
  List<StockLiteral>? dataList;
  dynamic parent;

  RowLiterals({
    required this.dataList,
    required this.parent,
  });

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if(index >= rowCount){
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

// Return Rows filled with StockItem(s)
// specific cells can be excluded using [showCells] list
class RowSource extends DataTableSource {
  List<StockItem>? dataList;
  List<int>? showCells;
  bool select = false;

  dynamic parent;

  RowSource({
    required this.parent,
    required this.dataList,
    this.showCells,
    required this.select
  });

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if(index >= rowCount){
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
        if (cell < dataCells.length){
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
          int stockIndex = selectIndex != -1 ? dataList![selectIndex].index : -1;

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
  int get selectedRowCount => (select == true && parent.getIndex() > -1) ? 1 : 0;
}

// Get app directory path
Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

// Read StockJob from JSON file
Future<StockJob> _readJsonFile(dynamic jsn) async {
  String fileContent = await jsn.readAsString(); //await
  var dynamic = json.decode(fileContent);
  return StockJob.fromJson(dynamic);
}

// Write StockJob to JSON file
void _writeJson(StockJob job) async {
  final path = await _localPath;
  final filePath = File('$path/job_${job.id}');
  Map<String, dynamic> jMap = job.toJson();
  var jString = jsonEncode(jMap);
  mPrint('_jsonString: $jString\n - \n');
  filePath.writeAsString(jString);
}


// Get .xlsx or .csv spreadsheet file path from phone
// DOESN'T RETURN PROPER PATHING ONLY RETURNS THE INSTANCE; IS A PROPER PATH REQUIRED?
pickFile() async {
  FilePickerResult? result = await FilePicker.platform
      .pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv']);

  if (result != null) {
    return (result.files.single.path).toString();
  }
  return "";
}

// "Safely" print something to terminal, otherwise IDE notifications chuck a sissy fit
mPrint(var s) {
  if (s == null){
    return;
  }
  if (!kReleaseMode) {
    if (kDebugMode) {
      print(s.toString());
    }
  }
}

// Return string containing only name and extension of the file path string
shortFilePath(String s){
  var sp = s.split("/");
  return sp[sp.length-1];
}



// zJUNK
/*

  PaginatedDataTable(
      sortColumnIndex: 1,
      sortAscending: sort,
      controller: ScrollController(),
      rowsPerPage: 9,
      showCheckboxColumn: false,
      showFirstLastButtons: true,
      columns: getColumns([1, 3]),
      source: RowSource(
          dataList: filterList,
          showCells: [1, 3],// Ignoring index, category, uom and price
          select: true,
      )
  )

  // getJobList() async {
  //   await SharedPreferences.getInstance()
  //       .then((prefs) {
  //         jobKeys.clear();
  //         jobKeys = prefs.getKeys().toList();
  //         // for (var k in prefs.getKeys()) {
  //         //
  //         //   jobKeys.add(k);
  //         // }
  //         mPrint(jobKeys);
  //       }
  //   );
  // }
  // saveJob(StockJob job) async{
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String jString = jsonEncode(job.toJson());
  //
  //   prefs.setString('job_${job.id}', jString); //'Job${stockJob[jobIndex].id}'
  //   mPrint(jString);
  // }

  //int _value = -1;
  //bool isLoading = false;

  // Future<void> loop() async{
  //   for(int i = 0; i < 10000; i++)
  //   {
  //     await Future.delayed(const Duration(milliseconds: 0));
  //     satState(() {
  //       //_value = i;
  //     });
  //   }
  // }
*/
