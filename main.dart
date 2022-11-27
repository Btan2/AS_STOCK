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
import 'package:shared_preferences/shared_preferences.dart';
import 'stock_job.dart';

final tableKey = GlobalKey<PaginatedDataTableState>();
List<StockItem> database = [];
List<StockJob> stockJob = [];
int itemIndex = -1;
int jobIndex = -1;


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
          appBar: AppBar(
            title: const Text('Home', textAlign: TextAlign.center),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.push( context, MaterialPageRoute(builder: (context) => const LoginPage())); // using animation for home -> login
                },
            ),
          ),
          body: SingleChildScrollView(
            child: Center(
              child: Column(
                  children: <Widget>[
                    mButton(
                        context,
                        Colors.blue,
                        TextButton(
                          child: const Text('Jobs', style: blueText),
                          onPressed: (){
                            goToPage(context, const JobsPage());
                            },
                        )
                    ),
                    mButton(
                        context,
                        Colors.blue,
                        TextButton(
                          child: const Text('LOGOUT', style: redText),
                          onPressed: (){
                            goToPage(context, const HomePage());
                          },
                        )
                    ),
                  ]
              ),
            ),
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
  List jobList = [];

  @override
  void initState() {
    super.initState();
    _listFiles();
  }

  void _listFiles() async {
    final directory = (await getApplicationDocumentsDirectory()).path;
    setState(() {
      jobList = Directory("$directory/").listSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Jobs'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              goToPage(context, const HomePage());
            },
          ),
        ),
        body: SingleChildScrollView(
            child: Center(
                child: Column(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Create New Job', style: blueText),
                        onTap: () {
                          goToPage(context, const NewJob());
                        },
                      )
                    ),
                    Column( // Load list of jobs as buttons, pressing button takes user to job
                        children: List.generate(jobList.length, (index) =>
                            Card(
                              child: ListTile(
                                title:Text(jobList[index].toString()),
                                trailing: Icon(Icons.inventory_2, color: Colors.white.withOpacity(0.8)),
                                onTap: () async{
                                  // jobIndex = index;
                                  // loadingDialog(context);
                                  // await loadDatabase(stockJob[index].dbPath).then((value) {
                                  //   goToPage(context, const OpenJob());
                                  // });
                                  //
                                  // setState(() {});
                                },
                              ),
                            ),
                        )
                    ),
                  ],
                )
            )
        )
    );
  }

  // NOT PROPER ASYNC, NEEDS TO BE FIXED
  Future<void> loadDatabase(String path) async{
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

      if (count > 1) {
        database.add(StockItem(
          index: database.length,
          barcode: (row[1] as Data).value.toString(),
          //barcodeInt ?? 0,
          category: (row[2] as Data).value.toString().trim().toUpperCase(),
          description: (row[3] as Data).value.toString().trim().toUpperCase(),
          uom: (row[4] as Data).value.toString().trim().toUpperCase(),
          price: (row[5] as Data).value,
          //priceInt ?? 0,
          nof: false,
        ));
      } else {
        count++;
      }
    }
    mPrint("MAIN BD: ${database.length}");
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
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "New Job",
            home: Scaffold(
                appBar: AppBar(
                  title: const Text("New Job", textAlign: TextAlign.center),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      goToPage(context, const JobsPage());
                    },
                  ),
                ),
                resizeToAvoidBottomInset: false,
                bottomSheet: SizedBox(
                    width: MediaQuery
                        .of(context)
                        .size
                        .width,
                    child: mButton(
                        context,
                        Colors.lightBlue,
                        TextButton(
                          onPressed: () async {
                            stockJob.add(newJob);
                            showAlert(context, "Created New Job!", "",
                                Colors.blue.withOpacity(0.8))
                                .then((value) {
                              goToPage(context, const JobsPage());
                            });
                          },
                          child: const Text('Create New Job', style: blueText),
                        )
                    )
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
                                      showAlert(context, "FilePicker",
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

                                    setState(() {}); // make sure text updates
                                  });
                                },
                              ),
                            ),
                          ),
                        ]
                    )
                )
            )
        ));
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
            title: Text("JobID: ${stockJob[jobIndex].id.toString()}", textAlign: TextAlign.center),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                database.clear();
                goToPage(context, const JobsPage());
                //Navigator.push( context, MaterialPageRoute(builder: (context) => const JobsPage())); // using animation for home -> login
              },
            ),
          ),

          body: SingleChildScrollView(
              child: Column(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info),
                        title: Text("Date: ${stockJob[jobIndex].date}"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info),
                        title: Text("JobID: ${stockJob[jobIndex].id.toString()}"),
                        ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info),
                        title: Text("Name: ${stockJob[jobIndex].name}"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info),
                        title: Text("Total Stock Count: ${stockJob[jobIndex].stock.length}"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info),
                        title: Text("Database: ${shortFilePath(stockJob[jobIndex].dbPath)}"),
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
                              child: const Text('Add Stock', style: blueText),
                              onPressed: () {
                                goToPage(context, const StocktakePage());
                                },
                            )
                        ),
                        mButton(context, Colors.blue,
                            TextButton(
                              child: const Text('View Job Spreadsheet', style: blueText),
                              onPressed: () {
                                goToPage(context, ViewSpreadSheet(mainList: stockJob[jobIndex].stock));
                                },
                            )
                        ),
                        mButton(context, Colors.blue,
                            TextButton(
                              child: const Text('View Database Spreadsheet', style: blueText),
                              onPressed: () {
                                goToPage(context, ViewSpreadSheet(mainList: database));
                                },
                            )
                        ),
                        mButton(context, Colors.green,
                            TextButton(
                              child: const Text('Save Job', style: blueText),
                              onPressed: () {
                                //saveJob(job);
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
==================
*/
class StocktakePage extends StatefulWidget {
  const StocktakePage({super.key});

  @override
  State<StocktakePage> createState() => _StocktakePageState();
}
class _StocktakePageState extends State<StocktakePage> {
  bool sort = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Add Item",
          home: Scaffold(
              appBar: AppBar(
                title:  Text("Stock List: ${stockJob[jobIndex].name}", textAlign: TextAlign.center),
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
                            leading: const Icon(Icons.info),
                            title: Text(stockJob[jobIndex].location),
                            onTap: () async {
                              goToPage(context, const Location());
                            },
                          ),
                        ),
                        mButton(
                            context,
                            Colors.blue,
                            TextButton(
                              onPressed: () {
                                //refresh();
                              },
                              child: const Text('SCAN ITEM', style: blueText),

                            )
                        ),
                        mButton(
                            context,
                            Colors.blue,
                            TextButton(
                              onPressed: () async {
                                if(stockJob[jobIndex].location.isNotEmpty && stockJob[jobIndex].dbPath.isNotEmpty) {
                                  goToPage(context, const AddItem());
                                }
                                else{
                                  String er = "\n${stockJob[jobIndex].location.isEmpty ? "Need location! \n" : ""}"
                                      "${stockJob[jobIndex].dbPath.isEmpty ? "Need database file!" : ""}";
                                  showAlert(context, "Alert", er, Colors.red.withOpacity(0.8));
                                }
                              },
                              child: const Text('SEARCH ITEM', style: blueText),
                            )
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
                                    columns: const <DataColumn>[
                                      DataColumn(label: Text("Barcode")),
                                      DataColumn(label: Text("Description")),
                                      DataColumn(label: Text("Count")),
                                      DataColumn(label: Text("Location")),
                                    ],
                                    source: RowLiterals(dataList: stockJob[jobIndex].literal)
                                )
                            )
                        ),
                      ]
                  )
              )
          )
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
  String location = stockJob[jobIndex].location;

  @override
  void initState() {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Locations",
          home: Scaffold(
              appBar: AppBar(
                title: const Text("Location", textAlign: TextAlign.center),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    await goToPage(context, const StocktakePage());
                    setState((){});
                    },
                ),
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
                          title: stockJob[jobIndex].location.isEmpty ? const Text("Select a location from the list below...", style: greyText) : Text(stockJob[jobIndex].location),
                          leading: stockJob[jobIndex].location.isEmpty ?  const Icon(Icons.warning_amber, color: Colors.red) : null,
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
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text("Add New Location", textAlign: TextAlign.justify),
                          onTap: (){
                            stockJob[jobIndex].addLocation("location${stockJob[jobIndex].allLocations.length + 1}");
                            setState((){});
                          },
                        ),
                      ),
                      Column(
                        children: List.generate(
                          stockJob[jobIndex].allLocations.length, (index) => Card(
                            child: ListTile(
                              title: Text(stockJob[jobIndex].allLocations[index], textAlign: TextAlign.justify),
                              onTap: () {
                                stockJob[jobIndex].setLocation(index);
                                setState(() {});
                                },
                            )
                        ),
                        ),
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
  bool sort = true;
  int addCount = 0;
  String btnText = "ADD NOF";

  TextEditingController searchCtrl = TextEditingController();
  TextEditingController addCtrl = TextEditingController();
  List<StockItem>? filterList;

  @override
  void initState() {
    super.initState();
    filterList = database;
    refresh(); // reset row selection so we don't accidentally add the previous item
  }

  void refresh(){
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Add Item",
            home: Scaffold(
                appBar: AppBar(
                  title: const Text("Add Item", textAlign: TextAlign.center),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      itemIndex = -1;
                      await goToPage(context, const StocktakePage());
                      setState((){});
                      }, // need to manually reset page or the table won't visually update
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
                                    setState(() {
                                      String search = value.toUpperCase();
                                      if (search == ""){
                                        tableKey.currentState?.pageTo(0); // Jump back to first page if search text is manually deleted by the user
                                      }
                                      filterList = database.where((item) => item.description.contains(search) || item.barcode.toString().contains(search)).toList();
                                    });
                                  }),
                              trailing: IconButton(
                                icon: const Icon(Icons.cancel),
                                onPressed: (){
                                  setState((){
                                    tableKey.currentState?.pageTo(0); // Jump back to first page on search text clear
                                    searchCtrl.clear();
                                    filterList = database;
                                  });
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
                                      columns: getColumns([1,3]),
                                      source: RowSource(dataList: filterList, showCells: [1,3], select: true)
                                  )
                              )
                          ),
                          mButton(
                              context,
                              itemIndex == -1 ? Colors.redAccent : Colors.blue,
                              TextButton(
                                child: Text( itemIndex == -1 ? "ADD NOF" : "ADD ITEM", style: blueText),
                                onPressed: () {
                                  if(itemIndex != -1) {
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.blue.withOpacity(0.8),
                                      builder: (context) => AlertDialog(
                                        title: const Text("Add Item"),
                                        content: Card(
                                            child: ListTile(
                                              title: TextField(
                                                  decoration: const InputDecoration(hintText: 'Count: ', border: InputBorder.none),
                                                  controller: addCtrl,
                                                  keyboardType: TextInputType.number,
                                                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      addCount = int.parse(value);
                                                    });
                                                  }),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.cancel),
                                                onPressed: (){
                                                  setState((){
                                                    addCtrl.clear();
                                                    addCount = 0;
                                                  });
                                                  },
                                              ),
                                            )
                                        ),
                                        actions: [
                                          ElevatedButton(
                                              child: const Text("Ok"),
                                              onPressed: () {
                                                setState(() {
                                                  /*
                                                    TODO: Remove stockItem from job list
                                                  */
                                                  if (addCount > 0) {
                                                    stockJob[jobIndex].addStock(database[itemIndex], addCount);
                                                  }

                                                  //showAlert( context, "Added Item", "${_db[itemIndex].description} x$addCount", Colors.blue.withOpacity(0.8));

                                                  itemIndex = -1; // reset select index
                                                });


                                                Navigator.pop(context);
                                                mPrint(stockJob[jobIndex].stock.length);

                                              }),
                                        ],
                                      ),
                                    );
                                    //showAlert( context, "Added Item", "${_db[itemIndex].description} x$addCount", Colors.blue.withOpacity(0.8));
                                    mPrint(stockJob[jobIndex].stock.length);
                                  }
                                  else {
                                    mPrint("nothing selected");
                                  }

                                  refresh(); // make sure table visually updates
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
  bool sort = true;
  TextEditingController searchController = TextEditingController();
  List<StockItem>? filterList;

  @override
  void initState() {
    super.initState();
    filterList = widget.mainList;
    //itemIndex = -1;
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
                  title: const Text("DATABASE List", textAlign: TextAlign.center),
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
                                    setState(() {
                                      String result = value.toUpperCase();
                                      if(result == ""){
                                        tableKey.currentState!.pageTo(0);
                                      }

                                      filterList = widget.mainList.where(
                                              (item) => item.description.contains(result) ||
                                                  item.barcode.toString().contains(result) ||
                                                  item.category.contains(result)).toList();
                                    });
                                  }),
                              trailing: IconButton(
                                icon: const Icon(Icons.cancel),
                                onPressed: () {
                                  setState(() {
                                    searchController.clear();
                                    filterList = widget.mainList;
                                    tableKey.currentState!.pageTo(0);
                                  });
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
                                      source: RowSource(dataList: filterList)
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

const blueText = TextStyle(color: Colors.white, fontSize: 18);
const redText = TextStyle(color: Colors.red, fontSize: 18);
const greyText = TextStyle(color: Colors.blueGrey, fontSize: 18);

// Jump to page with no animation
goToPage(BuildContext context, Widget page)
{
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
    context: context,
    barrierColor: c,
    builder: (context) => AlertDialog(
      title: Text(txtTitle),
      content: Text(txtContent),
      actions: [
        ElevatedButton(
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
// [showColumn] defines which columns should be built; an empty list will build every column
List<DataColumn> getColumns(List<int>? showColumn)
{
  List<DataColumn> dataColumns = <DataColumn>[
    const DataColumn(label: Text('Index')),
    const DataColumn(label: Text('Barcode')),
    const DataColumn(label: Text('Category')),
    const DataColumn(label: Text('Description')),
    const DataColumn(label: Text('UOM')),
    const DataColumn(label: Text('Price')),
  ];

  if (showColumn == null || showColumn.isEmpty) {
      return dataColumns;
  }

  List<DataColumn> dc = [];
  for(int i =0; i < dataColumns.length; i++) {
    if(showColumn.contains(i)) {
      dc.add(dataColumns[i]);
    }
  }
  return dc;
}

// Return Rows filled with StockLiteral(s)
class RowLiterals extends DataTableSource{
  List<StockLiteral>? dataList;
  int selectIndex = -1;

  RowLiterals({
    required this.dataList,
  });

  @override
  DataRow? getRow(int index) {
    assert(index >= 0);

    if(index >= rowCount){
      return null;
    }

    return DataRow.byIndex(
      index: index,
      selected: index == selectIndex,

      // Select rows and highlight
      onSelectChanged: (value) {
        selectIndex = selectIndex != dataList![index].index ? dataList![index].index : -1; // deselect if pressing same row
        itemIndex = selectIndex;// != -1 ? dataList![index].index : -1;
        if(selectIndex != -1) {
          mPrint(database[itemIndex].description);
        }
        notifyListeners(); // NEED THIS or select highlight won't visually update
      },

      cells: <DataCell>[
        DataCell(Text(dataList![index].barcode.toString())),
        DataCell(Text(dataList![index].description)),
        DataCell(Text(dataList![index].count.toString())),
        DataCell(Text(dataList![index].location)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => dataList!.length;
  @override
  int get selectedRowCount => selectIndex != -1 ? 1 : 0;
}

// Return Rows filled with StockItem(s)
// specific cells can be excluded using [showCells] list
class RowSource extends DataTableSource {
  List<StockItem>? dataList;
  List<int>? showCells;
  int selectIndex = -1;
  bool? select = false;

  RowSource({
    required this.dataList,
    this.showCells,
    this.select,
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

    if (showCells != null && showCells!.isNotEmpty) {
      List<DataCell> finalCells = [];
      for (int i = 0; i < 6; i++) {
        // Only add cells we want to show
        if (showCells!.contains(i)) {
          finalCells.add(dataCells[i]);
        }
      }
      dataCells = finalCells;
    }

    return DataRow.byIndex(
      index: index,
      selected: index == selectIndex,

      // Select stock item and highlight row
      onSelectChanged: (value) {
        if (select != null && select == true) {
          selectIndex = selectIndex != index ? index : -1;
          itemIndex = selectIndex;// != -1 ? index : -1; // make sure null on de-select

          if(itemIndex != -1){
            mPrint(database[itemIndex].description);
          }

          notifyListeners(); // NEED or table won't visually update
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
  int get selectedRowCount => selectIndex != -1 ? 1 : 0;
}

class DataStorage {
  final String filename;
  //File _filePath;

  DataStorage({
    required this.filename
  });

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  void _writeJson(String key, dynamic value,  Map<String, dynamic> jMap, String jString) async {
    // Initialize the local _filePath
    final filePath = await _localFile;

    //1. Create _newJson<Map> from input<TextField>
    Map<String, dynamic> newJson = {key: value};
    mPrint('1.(_writeJson) _newJson: $newJson');

    //2. Update _json by adding _newJson<Map> -> _json<Map>
    jMap.addAll(newJson);
    mPrint('2.(_writeJson) _json(updated): $jMap');

    //3. Convert _json ->_jsonString
    jString = jsonEncode(jMap);
    mPrint('3.(_writeJson) _jsonString: $jString\n - \n');

    //4. Write _jsonString to the _filePath
    filePath.writeAsString(jString);
  }
}

// Get .xlsx or .csv spreadsheet file path from phone
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

/*  Z_JUNK

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
  //     setState(() {
  //       //_value = i;
  //     });
  //   }
  // }
*/
