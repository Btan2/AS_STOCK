import 'package:universal_html/html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

enum Action{blank, edit, view, compare, upload}
enum CellFormat{words, datetime, decimals, integers, multiline}

String versionStr = "0.23.06+1";

List<List<String>> jobTable = [];
List<List<String>> bkpTable = [];
List<List<String>> masterTable = [];
List<String> jobCategory = [];
List<String> masterCategory = [];
List<Map<String, dynamic>> jobHeader = [{}];
List<Map<String, dynamic>> masterHeader = [{}];

TextStyle get whiteText{ return const TextStyle(color: Colors.white, fontSize: 20.0);}
TextStyle get blackText{ return const TextStyle(color: Colors.black, fontSize: 20.0);}
TextStyle get greyText{ return const TextStyle(color: Colors.black12, fontSize: 20.0);}
TextStyle get cellText{ return const TextStyle(color: Colors.black, fontSize: 12.0);}

final Color colorOk = Colors.blue.shade400;
const Color colorError = Colors.redAccent;
final Color colorWarning = Colors.deepPurple.shade200;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /*
    RUN FUNCTIONS THAT NEED TO BE LOADED FIRST HERE
  */

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
      theme: ThemeData(
        bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
        navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget{
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPage();
}
class _LoginPage extends State<LoginPage>{
  String pass = "";
  String username = "";
  Color splashColor = colorOk;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 10.0,),
        child: Text("version $versionStr", style: cellText, textAlign: TextAlign.center),
      ),
      body: SingleChildScrollView(
          child: Center(
              child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 35.0),
                      child: Center(
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height/10.0,
                          child: SvgPicture.asset("AS_logo_light.svg"),
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
                      width: MediaQuery.of(context).size.width/4.0,
                      child: TextField(
                        decoration: const InputDecoration(hintText: 'Enter username', border: OutlineInputBorder()),
                        textAlign: TextAlign.center,
                        onChanged: (String value) {
                          username = value;
                          setState(() {});
                        }
                        ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height/40.0,
                    ),
                    rBox(
                      width: MediaQuery.of(context).size.width/4.0,
                      child: TextField(
                          obscureText: true,
                          decoration: const InputDecoration(hintText: 'Enter password', border: OutlineInputBorder()),
                          textAlign: TextAlign.center,
                          onChanged: (String value) {
                            pass = value;
                            setState(() {});
                          }
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height/40.0,
                    ),
                    TapRegion(
                      onTapInside: (value) async{
                        if(pass == "pass" && username == "andy"){
                          setState(() {
                            splashColor = Colors.green;
                          });
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MainPage()));
                          return;
                        }

                        setState((){
                          splashColor = colorError;
                        });
                        await Future.delayed(const Duration(milliseconds: 500));
                        setState(() {
                          splashColor = colorOk;
                        });
                      },
                      child: rBox(
                          width: MediaQuery.of(context).size.width/4.0,
                          child: Material(
                            color: splashColor,
                            borderRadius: BorderRadius.circular(20.0),
                            child: const Center(child: Text("Login", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20.0))),
                          )
                      )
                    ),
                  ]
              )
            )
      ),
    );
  }
}

class MainPage extends StatefulWidget{
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPage();
}
class _MainPage extends State<MainPage>{
  Action action = Action.blank;
  TextEditingController masterSearchCtrl = TextEditingController();
  TextEditingController jobSearchCtrl = TextEditingController();

  List<List<String>> jobFilterList = [[]];
  List<List<String>> masterFilterList = [[]];

  List<String> masterEdit = [];
  List<String> jobEdit = [];

  String loadingMsg = "Loading...";
  int masterRow = -1;
  int masterCell = -1;

  int jobRow = -1;
  int jobCell = -1;

  int searchColumn = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose(){
    masterSearchCtrl.dispose();
    jobSearchCtrl.dispose();
    super.dispose();
  }

  void _filePicker({bool? job}) {
    // Load xlsx from file browser
    FileUploadInputElement uploadInput = FileUploadInputElement();
    uploadInput.click();

    uploadInput.onAbort.listen((e){
      setState(() {
        isLoading = false;
      });
      return;
    });

    uploadInput.onChange.listen((e) {
      // read file content as dataURL
      List<File> files = List.empty();
      files = uploadInput.files as List<File>;

      FileReader reader = FileReader();

      final file = files[0];
      reader.readAsArrayBuffer(file);

      reader.onAbort.listen((e) {
        setState(() {
          isLoading = false;
        });
        return;
      });

      reader.onError.listen((fileEvent) {
        return;
      });

      reader.onLoadEnd.listen((e) async {
        bool master = (job ?? false) == false;
        // Pull masterfile from server
        await loadSpreadSheet(bytes: reader.result as List<int>, master: master).then((value){
          setState(() {
            masterFilterList = List.of(masterTable);
            jobFilterList = List.of(jobTable);
            isLoading = false;
          });
        });
      });
    });
  }

  Future<void> loadSpreadSheet({required List<int> bytes, required bool master}) async{
    if(bytes.isEmpty){
      loadingMsg = "...";
      return;
    }

    if(!master){
      jobTable = List.empty();
    }
    else{
      masterTable = List.empty();
    }

    setState((){
      loadingMsg = "Decoding spreadsheet...";
    });
    await Future.delayed(const Duration(seconds: 1));

    try{
      var decoder = SpreadsheetDecoder.decodeBytes(bytes);
      var sheets = decoder.tables.keys.toList();
      if(sheets.isEmpty){
        return;
      }

      SpreadsheetTable? table = decoder.tables[sheets.first];
      if(table!.rows.isEmpty || table.rows[0].length != 8){
        return;
      }

      setState((){
        loadingMsg = "Creating header row...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      if(!master){
        jobHeader = List.generate(
            table.rows[0].length, (index) => <String, dynamic>{"text" : table.rows[0][index].toString().toUpperCase(), "format" : CellFormat.words}
        );
      }
      else{
        masterHeader = List.generate(
            table.rows[0].length, (index) => <String, dynamic>{"text" : table.rows[0][index].toString().toUpperCase(), "format" : CellFormat.words}
        );
        jobHeader = List.of(masterHeader);
      }

      setState((){
        loadingMsg = "Creating categories...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      if(!master){
        jobCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][2].toString().toUpperCase()).toSet().toList();
      }
      else{
        masterCategory = List<String>.generate(table.rows.length, (index) => table.rows[index][2].toString().toUpperCase()).toSet().toList();
        jobCategory = List.of(masterCategory);
      }

      setState((){
        loadingMsg = "Creating table...";
      });
      await Future.delayed(const Duration(milliseconds:500));

      if(!master){
        jobTable = List.generate(table.rows.length, (index) => List<String>.generate(jobHeader.length, (index2) => table.rows[index][index2].toString().toUpperCase()));
        jobTable.removeAt(0); // Remove header from main
      }
      else{
        masterTable = List.generate(table.rows.length, (index) => List<String>.generate(masterHeader.length, (index2) => table.rows[index][index2].toString().toUpperCase()));
        masterTable.removeAt(0); // Remove header from main

        setState((){
          loadingMsg = "Creating backup table...";
        });
        await Future.delayed(const Duration(milliseconds:500));
        bkpTable = List.of(masterTable); // Copy loaded masterTable for later use
        jobTable = List.of(masterTable);
      }

      setState((){
        loadingMsg = "The spreadsheet was imported.";
      });

      //return;
    }
    catch (e){
      debugPrint("The Spreadsheet has errors:\n ---> $e");
      isLoading = false;
      loadingMsg = "The Spreadsheet has errors:\n ---> $e";
      //return;
    }
  }

  Widget _blank(){
    double height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height,
      child: SvgPicture.asset("AS_logo_symbol.svg", width: height/2)
    );
  }

  Widget _uploadPage(){
    return Column(
        children: [
          SizedBox(
              height: MediaQuery.of(context).size.height/3
          ),
          ElevatedButton(
              onPressed: (){},
              child: const Text("Edit")
          ),
          const SizedBox(height: 20.0),
          ElevatedButton(
              onPressed: (){},
              child: const Text("Commit")
          ),
          const SizedBox(height: 20.0),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
          )
        ]
    );
  }

  Widget _comparePage(){
    return Column(
      children: [
        Row(
          children:[
            Expanded(
                child: _tableView(
                    header: jobHeader,
                    table: jobTable,
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height/1.8,
                    padding: 10.0,
                    filterList: List.of(jobFilterList),
                    searchCtrl: jobSearchCtrl,
                    activeCell: jobCell,
                    activeRow: jobRow,
                    editItem: jobEdit,
                    job: true
              )
            ),
            Expanded(
                child: _tableView(
                    header: masterHeader,
                    table: masterTable,
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height/1.8,
                    padding: 10.0,
                    filterList: List.of(masterFilterList),
                    searchCtrl: masterSearchCtrl,
                    activeRow: masterRow,
                    activeCell: masterCell,
                    editItem: masterEdit
                )
            ),
          ]
        )
      ],
    );
  }

  Widget _tableView({
    bool? job,
    required List<Map<String, dynamic>> header,
    required List<List<String>> table,
    required List<List<String>> filterList,
    required double width,
    required double height,
    required double padding,
    required TextEditingController searchCtrl,
    required List<String> editItem,
    required activeRow,
    required activeCell,
  }){

    bool isJob = job ?? false;

    double cellHeight = height/8;

    setTableState(){
      setState((){
        if(isJob){
          jobSearchCtrl = searchCtrl;
          jobFilterList = filterList;
          jobRow = activeRow;
          jobCell = activeCell;
          jobEdit = editItem;
        }
        else{
          masterSearchCtrl = searchCtrl;
          masterFilterList = filterList;
          masterRow = activeRow;
          masterCell = activeCell;
          masterEdit = editItem;
        }
      });
    }

    confirmEdit(int index){
      setState((){
        if(isJob){
          jobTable[index] = List.of(editItem);
        }
        else{
          masterTable[index] = List.of(editItem);
        }
      });
    }

    Widget searchBar(double width){
      searchWords(String searchText){
        bool found = false;
        List<String> searchWords = searchText.split(" ").where((String s) => s.isNotEmpty).toList();
        List<List<String>> refined = [[]];

        for (int i = 0; i < searchWords.length; i++) {
          if (!found) {
              filterList = table.where((row) => row[searchColumn].contains(searchWords[i])).toList();
              found = filterList.isNotEmpty;
          }
          else {
              refined = filterList.where((row) => row[searchColumn].contains(searchWords[i])).toList();
              if(refined.isNotEmpty){
                filterList = List.of(refined);
              }
          }
        }

        if(!found){
            filterList = List.empty();
        }
      }

      return Container(
          width: width,
          decoration: BoxDecoration(
            color: colorOk,
            border: Border.all(
              color: colorOk,
              style: BorderStyle.solid,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(20.0),
          ),

          child: ListTile(
            leading: PopupMenuButton(
                icon: const Icon(Icons.manage_search, color: Colors.white),
                itemBuilder: (context) {
                  return List.generate(header.length, (index) =>
                      PopupMenuItem<int> (
                        value: index,
                        child: ListTile(
                          title: Text("Search ${header[index]["text"]}"),
                          trailing: index == searchColumn ? const Icon(Icons.check) : null,
                        ),
                      )
                  );
                },
                onSelected: (value) async {
                  setState((){
                    searchColumn = value;
                  });
                }
            ),

            title: TextFormField(
              controller: searchCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: "Search ${header[searchColumn]["text"].toLowerCase()}...",
                border: InputBorder.none,
              ),

              onChanged: (String value){
                activeRow = -1;

                if(value.isNotEmpty){
                  searchWords(value.toUpperCase());
                }
                else{
                    filterList = List.of(table);
                }

                setTableState();
              },
            ),

            trailing: IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                  searchCtrl.clear();
                  filterList = table;
                  setTableState();
              },
            ),
          )
      );
    }

    Widget tableHeader(){
      return Row(
        children: List.generate(header.length, (index) => Expanded(
          child: Container(
              height: cellHeight,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.0),
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: Colors.black,
                  style: BorderStyle.solid,
                  width: 1.0,
                ),
              ),
              child: TapRegion(
                child: Center(
                    child: Text(
                      header[index]["text"],
                      softWrap: true,
                      maxLines: 3,
                      overflow: TextOverflow.fade,
                      style: cellText
                  )
              ),
              onTapInside: (value){
                showAlert(
                    context: context,
                    text: Text("Cell Text: ${header[index]["text"]}\n\nCell Format: ${header[index]["format"]}")
                );
              },
            )
          )
        ))
      );
    }

    Widget editRow(){
      return Row(
          children: List.generate(header.length, (index) => Expanded(
              child: Container(
                height: cellHeight,
                width: index == 3 ? 150 : 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.0),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: colorOk, //Colors.black,
                    style: BorderStyle.solid,
                    width: 2.0,
                  ),
                ),
                child: TapRegion(
                  onTapInside:(value) {
                    activeCell = index;
                    setTableState();
                  },

                  child: activeCell == index ? TextFormField(
                    autofocus: true,
                    initialValue: activeRow < 0 ? "" :  table[activeRow][index],
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    onTapOutside: (value){
                      activeCell = -1; // Disable text edit on tap outside
                      //editItem[index] = value as String;
                      setTableState();
                      // setState((){
                      //   activeCell = -1;
                      // });q
                    },
                    onChanged: (String value){
                      editItem[index] = value;
                      setTableState();
                    },
                  ) : Text(
                    activeRow < 0 ? "" : editItem[index],
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    softWrap: true,
                  ),
                )
              )
          )
          )
      );
    }

    Widget getRow(int tableIndex){
      int tableLength = table[tableIndex].length;//isJob ? jobTable[tableIndex].length : masterTable[tableIndex].length;
      return TapRegion(
          onTapInside: (value) {
            activeRow = tableIndex;
            editItem = List.of(table[tableIndex]);
            setTableState();
          },
          child: Row(
              children: List.generate(tableLength, (index) => Expanded(
                  child: Container(
                    height: cellHeight,
                    decoration: BoxDecoration(
                      color: activeRow == tableIndex ? Colors.white24 : Colors.white.withOpacity(0.0),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: Colors.black,
                        style: BorderStyle.solid,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      table[tableIndex][index],
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      softWrap: true,
                    ),
                  )
              )
          )
      ),
      );
    }

    return Padding(
        padding: EdgeInsets.all(padding),
        child: TapRegion(
            onTapOutside: (value){
              setState(() {
                // if(activeCell < 0){
                //   activeRow = -1;
                // }
              });
            },

            child: Column(
                children:[
                  SizedBox(
                    width: width,
                    child: tableHeader(),
                  ),
                  Container(  // Main Scrollable list
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black.withOpacity(0.5),
                        style: BorderStyle.solid,
                        width: 1.0,
                      ),
                    ),
                    child: filterList.isNotEmpty ? ListView.builder(
                      itemCount: filterList.length,
                      prototypeItem: getRow(int.parse(filterList.first[0])),
                      itemBuilder: (context, index) {
                        final int tableIndex = int.parse(filterList[index][0]);
                        return getRow(tableIndex);
                      },
                    ) :
                    Row(
                        children: [
                          Expanded(child: Text("EMPTY", style: greyText, textAlign: TextAlign.center,))
                        ]
                    ),
                  ),
                  const SizedBox(
                    height: 5.0,
                  ),
                  searchBar(width),
                  const SizedBox(
                    height: 5.0,
                  ),
                  Container(
                      width: width,
                      color: colorOk,
                      child: Text("Edit Row", textAlign: TextAlign.center, style: whiteText)
                  ),
                  SizedBox(
                    width: width,
                    child: editRow(),
                  ),
                  const SizedBox(
                    height: 5.0,
                  ),
                  Row(
                    children:[
                      Center(
                          child: ElevatedButton(
                              onPressed: () {
                                  activeRow = -1;
                                  activeCell = -1;
                                  setTableState();
                              },
                              child: const Text("CLEAR")
                          )
                      ),
                      Center(
                          child: ElevatedButton(
                              onPressed: () {
                                int i = int.tryParse(editItem[0]) ?? -1;
                                if(i>- 0){
                                  confirmEdit(i);
                                }
                              },
                              child: const Text("SAVE EDIT")
                          )
                      ),
                    ]
                  )
                ]
            )
        )
    );

  }

  ListView _drawerMenu(){
    return ListView(
      children: <Widget>[
        const SizedBox(height: 5),
        ListTile(
          leading: const Icon( Icons.arrow_back_outlined, color: Colors.white),
          hoverColor: Colors.white70,
          onTap: (){
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon( Icons.cloud_download, color: Colors.white),
          title: const Text("Get Master File", style: TextStyle(color: Colors.white, fontSize: 20.0)),
          hoverColor: Colors.white70,
          onTap: () async {
            setState(() {
              loadingMsg = "Waiting for file...";
              isLoading = true;
              action = Action.view;
            });

            _filePicker();

            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: Icon( Icons.open_in_browser, color: masterTable.isNotEmpty ? Colors.white : Colors.grey),
          title: const Text("Upload Job File & Edit", style: TextStyle(color: Colors.white, fontSize: 20.0)),
          hoverColor: Colors.white70,
          onTap: () async {
            if(masterTable.isNotEmpty){
              setState(() {
                loadingMsg = "Waiting for file...";
                //isLoading = true;
                action = Action.compare;
              });

              //_filePicker(job: true);
              Navigator.pop(context);
            }
            else{
              showAlert(context: context, text: const Text("MASTER table is empty.", textAlign: TextAlign.center,));
              //Show pop up
            }
          }
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: Icon( Icons.cloud_upload, color: Colors.red.shade50),
          title: const Text("Upload changes to Masterfile", style: TextStyle(color: Colors.white, fontSize: 20.0)),
          hoverColor: Colors.white70,
          onTap: () {
            action = Action.upload;
            setState(() {});
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.logout_outlined, color: Colors.white),
          title: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontSize: 20.0)),
          hoverColor: Colors.white70,
          onTap: () async {
            await confirmDialog(context, "End session and logout?").then((value){
              if(value){
                masterTable = List.empty();
                jobTable = List.empty();
                jobHeader = List.empty();
                masterHeader = List.empty();
                masterCategory = List.empty();
                jobCategory = List.empty();
                bkpTable = List.empty();
                
                Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => const LoginPage()));
              }
            });
          },
        ),
      ],
    );
  }

  Widget _getMainBody(){
    double mediaHeight = MediaQuery.of(context).size.height;

    if(action == Action.blank){
      masterTable = List.empty();
      return _blank();
    }
    else if(action == Action.upload){
      return _uploadPage();
    }
    else if(action == Action.compare){
      if(isLoading){
        return Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height/3),
              Text(loadingMsg, textAlign: TextAlign.center, style: blackText),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
              )
            ]
        );
      }
      else if(masterTable.isNotEmpty){
        return _comparePage();
      }
    }
    else if(action == Action.view){
      if(isLoading){
        return Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height/3),
              Text(loadingMsg, textAlign: TextAlign.center, style: blackText),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
              )
            ]
        );
      }
      else if(masterTable.isNotEmpty){
        return _tableView(
          header: masterHeader,
            table: masterTable,
            width: MediaQuery.of(context).size.width/1.5,
            height: mediaHeight /2,
            padding: 8.0,
            filterList: masterFilterList,
            searchCtrl: masterSearchCtrl,
            activeRow: masterRow,
            activeCell: masterCell,
            editItem: masterEdit
        );
      }
    }

    return _blank();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: SvgPicture.asset("AS_logo_light.svg", height: 50),
          leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
          ),
        ),

        drawer: Drawer(
            child: Material(
                color: Colors.blue,
                child: _drawerMenu()
            )
        ),

        body: SingleChildScrollView(
            child: Center(
                child: _getMainBody()
            )
        )
    );
  }
}

rBox({required double width, required Widget child}){
  return Padding(
    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
    child: SizedBox(
        height: 50,
        width: width,
        child: child
    ),
  );
}

showAlert({required BuildContext context, required Text text, Color? color}) {
  return showDialog(
      barrierDismissible: false,
      context: context,
      barrierColor: color ?? colorOk,
      builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: SingleChildScrollView(
              child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Center(
                    child: AlertDialog(
                      actionsPadding: const EdgeInsets.all(20.0),
                      content: text,
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
              )
          )
      )
  );
}

String getDateString(String d){
  String newDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
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
        newDate = "${dateSplit[2]}/${dateSplit[1]}/${dateSplit[0]}";
      }
    }
    catch (e){
      return newDate;
    }
  }

  return newDate;
}

Future<bool> confirmDialog(BuildContext context, String str) async {
  bool confirmation = false;
  await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: colorOk.withOpacity(0.8),
      builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: SingleChildScrollView(
              child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Center(
                      child: AlertDialog(
                        actionsAlignment: MainAxisAlignment.spaceAround,
                        actionsPadding: const EdgeInsets.all(20.0),
                        titlePadding: const EdgeInsets.all(20.0),
                        title: Text(str, textAlign: TextAlign.center,),
                        actions: <Widget>[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: colorError),
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
              )
          )
      )
  );

  return confirmation;
}
