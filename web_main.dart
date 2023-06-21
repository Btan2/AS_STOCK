import 'package:universal_html/html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

enum Action{blank, edit, view, upload}
enum CellFormat{words, datetime, decimals, integers, multiline}

String versionStr = "0.23.06+1";

List<List<String>> oldTable = [];
List<List<String>> mainTable = [];
List<String> masterCategory = [];
List<Map<String, dynamic>> headerRow = [{}];

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
                    GestureDetector(
                      onTap: () async{
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
  bool isLoading = false;
  int activeRow = -1;
  int activeCell = -1;
  TextEditingController searchCtrl = TextEditingController();
  List<List<String>> filterList = [[]];

  int searchColumn = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose(){
    searchCtrl.dispose();
    super.dispose();
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
          title: const Text("View Master File", style: TextStyle(color: Colors.white, fontSize: 20.0)),
          hoverColor: Colors.white70,
          onTap: (){
            setState(() {
              isLoading = true;
            });

            // Pull masterfile from server
            _startFilePicker();
            action = Action.view;
            setState(() {});
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon( Icons.open_in_browser, color: Colors.white),
          title: const Text("Open XLSX File", style: TextStyle(color: Colors.white, fontSize: 20.0)),
          hoverColor: Colors.white70,
          onTap: () {
            setState(() {
              isLoading = true;
            });

            _startFilePicker();
            action = Action.view;
            setState(() {});
            Navigator.pop(context);
          },
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
                Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => const LoginPage()));
              }
            });
          },
        ),
      ],
    );
  }

  void _startFilePicker() {
    FileUploadInputElement uploadInput = FileUploadInputElement();
    uploadInput.click();

    uploadInput.onAbort.listen((e){
        mainTable = List.empty();
        setState(() {
          isLoading = false;
        });
        return;
      }
    );

    uploadInput.onChange.listen((e) {
      // read file content as dataURL
      List<File> files = List.empty();
      files = uploadInput.files as List<File>;

      FileReader reader = FileReader();

      final file = files[0];
      reader.readAsArrayBuffer(file);

      reader.onAbort.listen((e) {
        mainTable = List.empty();
        setState(() {
          isLoading = false;
        });
        return;
      });

      reader.onError.listen((fileEvent) {
        return;
      });

      reader.onLoadEnd.listen((e) async{
        await loadSpreadSheet(reader.result as List<int>).then((value){
          setState(() {
            filterList = List.of(mainTable);
            isLoading = false;
          });
        });
      });
    });
  }

  Widget _blank(double height){
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

  Widget _searchBar(double width){
    searchWords(String searchText){
      bool found = false;
      List<String> searchWords = searchText.split(" ").where((String s) => s.isNotEmpty).toList();
      List<List<String>> refined = [[]];

      for (int i = 0; i < searchWords.length; i++) {
        if (!found) {
          filterList = mainTable.where((row) => row[searchColumn].contains(searchWords[i])).toList();

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
                return List.generate(headerRow.length, (index) =>
                    PopupMenuItem<int> (
                      value: index,
                      child: ListTile(
                        title: Text("Search ${headerRow[index]["text"]}"),
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
              hintText: "Search ${headerRow[searchColumn]["text"].toLowerCase()}...",
              border: InputBorder.none,
            ),

            onChanged: (String value){
              if(value.isNotEmpty){
                searchWords(value.toUpperCase());
              }
              else{
                filterList = List.of(mainTable);
              }

              setState(() {});
            },
          ),

          trailing: IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              searchCtrl.clear();
              filterList = List.of(mainTable);
              setState(() {});
            },
          ),
        )
    );
  }

  Column _listTable({required double width, required double height}){
    double cellHeight = height/8;

    Widget tableHeader(){
      return Row(
        children: List.generate(headerRow.length, (index) => Expanded(
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
              child: GestureDetector(
                child: Center(
                    child: Text(
                      headerRow[index]["text"],
                      softWrap: true,
                      maxLines: 3,
                      overflow: TextOverflow.fade,
                      style: cellText
                  )
              ),
              onTap: (){
                showAlert(
                    context: context,
                    text: "Cell Text: ${headerRow[index]["text"]}\n\nCell Format: ${headerRow[index]["format"]}"
                );
              },
            )
          )
        ))
      );
    }

    Widget editRow(){
      return Row(
          children: List.generate(headerRow.length, (index) => Expanded(
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
                child: GestureDetector(
                  onTap:(){
                    setState((){
                      activeCell = index;
                    });
                  },
                  child: activeCell == index ? TextFormField(
                    autofocus: true,
                    initialValue: activeRow < 0 ? "" : mainTable[activeRow][index],
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    onTapOutside: (value){
                      setState((){
                        // Disable text edit on tap outside
                        activeCell = -1;
                      });
                    },
                    onChanged: (String value){
                      setState(() {
                          mainTable[activeRow][index] = value;
                      });
                      },
                  ) : Text(
                    activeRow < 0 ? "" : mainTable[activeRow][index],
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
      return GestureDetector(
          onTap: () {
            setState(() {
              activeRow = tableIndex;
              //debugPrint(mainTable[activeRow].toString());
            });
          },
          child: Row(
              children: List.generate(mainTable[tableIndex].length, (index) => Expanded(
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
                      mainTable[tableIndex][index],
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

    return Column(
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
          _searchBar(width),
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
        ]
    );
  }

  Widget _getMainBody(){
    double mediaHeight = MediaQuery.of(context).size.height;
    // Show blank page
    if(action == Action.blank){
      mainTable = List.empty();
      return _blank(mediaHeight);
    }
    else if(action == Action.upload){
      return _uploadPage();
    }
    else if(action == Action.view){
      if(isLoading){
        return Column(
            children: [
               SizedBox(height: mediaHeight/3),
               Text("Loading...", textAlign: TextAlign.center, style: blackText),
               Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: SvgPicture.asset("AS_logo_symbol.svg", height: 48.0),
               )
             ]
        );
      }
      else if(mainTable.isNotEmpty){
        return Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0, bottom: 8.0),
            child: _listTable(
              width: MediaQuery.of(context).size.width/1.5,
              height: mediaHeight /2,
            )
        );
      }
    }

    return _blank(mediaHeight);
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

showAlert({required BuildContext context, required String text, Color? color}) {
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
                      content: Text(text),
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

Future<void> loadSpreadSheet(List<int> bytes) async{
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

    headerRow = List.generate(
        table.rows[0].length, (index) => <String, dynamic>{"text" : table.rows[0][index].toString().toUpperCase(), "format" : CellFormat.words}
    );

    mainTable = List.generate(table.rows.length, (index) => List.generate(headerRow.length, (index2) => table.rows[index][index2].toString().toUpperCase()));
    mainTable.removeAt(0); // Remove header from main
    oldTable = List.of(mainTable); // Copy loaded maintable for later use

    masterCategory = List.generate(table.rows.length, (index) => table.rows[index][2].toString().toUpperCase()).toSet().toList();
    return;
  }
  catch (e){
    //debugPrint("The Spreadsheet has errors and was not loaded!\n--> $e");
    return;
  }
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