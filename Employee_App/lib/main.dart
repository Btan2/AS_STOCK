import 'package:flutter/material.dart';

String versionStr = "0.0.0+0";

// Fake user ID
int userID = 03452;
Staff currentUser = Staff(
    "Callum",
    "Buchanan",
    "6014",
    "14/08/1992",
    "email@email.com",
    true,
    "pass"
);

TextStyle get whiteText{ return const TextStyle(color: Colors.white, fontSize: 20.0);}
TextStyle get blackText{ return const TextStyle(color: Colors.black, fontSize: 20.0);}
TextStyle get greyText{ return const TextStyle(color: Colors.black12, fontSize: 20.0);}
final Color colorOk = Colors.blue.shade400;
const Color colorError = Colors.redAccent;
const Color colorConfirm = Colors.greenAccent;
const Color colorAwait = Colors.orange;
final Color colorDenied = Colors.redAccent.shade100;

List<Job> jobs = [
  Job("123", "30/10/2023", "News Plus", "News Agency", "Margaret River", "10:00", "5 hours", "N/A", ""),
  Job("456", "03/11/2023", "Broome Bar", "Alcohol Shop", "Broome", "3:00", "6 hours", "N/A", ""),
  Job("789", "03/11/2023", "Surfs Up", "Clothing Store", "High Wycombe", "3:00", "3 hours", "N/A", ""),
  Job("101112", "13/11/2023", "Perth Train station", "Government Building", "Perth City", "3:00", "3 hours", "N/A", ""),
  Job("131415", "14/11/2023",  "Legal Fun", "Smut Store", "Epstein Island", "3:00", "6 hours", "N/A", ""),
  Job("161718", "15/11/2023",  "News Plus Plus", "News Agency", "Albany", "3:00", "6 hours", "N/A", ""),
  Job("192021", "18/11/2023",  "Surfs Up No. 2", "Clothing Store", "Mandurah", "3:00", "6 hours", "N/A", ""),
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Put stuff that needs to loaded first here
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
      // theme: ThemeData(
      //   bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
      //   navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.black.withOpacity(0.0)),
      // ),
    ),
  );
}

class LoginPage extends StatefulWidget{
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPage();
}
class _LoginPage extends State<LoginPage> {
  TextEditingController usernameCtrl = TextEditingController();
  TextEditingController passwordCtrl = TextEditingController();

  bool authenticate(String u, String p){
    // 1. Access database
    // 2. Check if username exists
     // Use full name or assigned ID?
    // 3. Check if password is good
    return u.toUpperCase() == "USERNAME" && p.toUpperCase() == "PASS";
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
                    TextFormField(
                      controller: usernameCtrl,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          hintText: 'Username',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0),),
                          hintStyle: const TextStyle(color: Colors.black)
                      ),
                    ),
                    SizedBox(
                      height: 10.0,
                      width: MediaQuery.of(context).size.width,
                    ),
                    TextFormField(
                      controller: passwordCtrl,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          hintText: 'Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0),),
                          hintStyle: const TextStyle(color: Colors.black)
                      ),
                    ),
                    const SizedBox(
                        height: 10.0
                    ),
                    rBox(
                        context,
                        Colors.blue,
                        TextButton(
                          child: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 20.0)),
                          onPressed: () async {
                            // if(authenticate(usernameCtrl.text, passwordCtrl.text)){
                            //   Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
                            // }

                            Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
                          },
                        )
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
                      child: Text('Version: $versionStr', style: const TextStyle(color: Colors.blueGrey), textAlign: TextAlign.center,),
                    ),
                  ]
              )
          )
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<Job> _jobList = [];
  int _tabIndex = 0;
  final TabController _tabControl = TabController(length: 3, vsync: true);

  final int available = 0;
  final int applied = 1;
  final int settings = 2;
  // final int awaiting = 0;
  // final int confirmed = 1;
  // final int denied = 2;

  @override
  void initState() {
    super.initState();
    // Get available jobs from server
    // Get applied jobs list for this user from server
    _jobList = _getJobs(available);

    _tabControl.addListener(() {
      setState(() {
        _tabIndex = _tabControl.index;
      });

      //debugPrint("Selected Index: " + _tabControl.index.toString());
    });
  }

  List<Job> _getJobs(int listType){
    return listType == available ? jobs.where((job) => !job.finalized && !job.staffApplied.contains(userID)).toList() :
        listType == applied ? jobs.where((job) => job.staffApplied.contains(userID)).toList() : [];
  }

  String _getStatusString(Job job){
    if(job.finalized && !job.staffConfirmed.contains(userID)){
      return "JOB FINALIZED";
    }
    else if(job.staffConfirmed.contains(userID)){
      return "CONFIRMED";
    }
    else if(job.staffApplied.contains(userID)){
      return "AWAITING";
    }
    else{
      return "";
    }
  }

  Color _getStatusColor(Job job){
    if(job.finalized && !job.staffConfirmed.contains(userID)){
      return colorDenied;
    }
    else if(job.staffConfirmed.contains(userID)){
      return colorConfirm;
    }
    else if(job.staffApplied.contains(userID)){
      return colorAwait;
    }
    else{
      return Colors.white;
    }
  }

  Widget _headerPadding(String title, TextAlign l) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 10.0, bottom: 5),
      child: Text(title, textAlign: l, style: const TextStyle(color: Colors.blue,)),
    );
  }

  // Edit item or add new item
  _jobDetails({required BuildContext context, required Job job}) {
    itemField(String heading, String text){
      return Padding(
          padding: const EdgeInsets.only(left: 5.0, right: 5.0, top: 5.0, bottom: 5),
          child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _headerPadding(heading, TextAlign.left),
                ),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Text(text),
                    )
                ),
              ]
          )
      );
    }

    return showDialog(
        barrierDismissible: false,
        context: context,
        barrierColor: _getStatusColor(job),
        builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: SingleChildScrollView(
              child: AlertDialog(
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actionsPadding: const EdgeInsets.all(20.0),
                content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    //height: MediaQuery.of(context).size.height * 0.75,
                    child: SingleChildScrollView(
                      child: Column(
                          textDirection: TextDirection.ltr,
                          children: [
                            _tabIndex == applied ? Container(
                              height: 50.0,
                              color: _getStatusColor(job),
                              child: Text("Status: ${_getStatusString(job)}", style: const TextStyle(color: Colors.white), textAlign: TextAlign.center,)
                            ): Container(),
                            itemField("Job ID", job.id),
                            itemField("Date", job.date),
                            itemField("Business", job.business),
                            itemField("Business Type", job.type),
                            itemField("Job Location", job.location),
                            itemField("Start Time", job.startTime),
                            itemField("Duration", job.duration),
                            itemField("Travel Contribution", job.travelContribution),
                            job.notes.isNotEmpty ? itemField("Notes", job.notes) : Container(),
                          ]
                      ),
                    )
                ),
                //actionsOverflowDirection: VerticalDirection.up,
                actions: [
                  Column(
                      children: <Widget>[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _tabIndex == applied ? colorError : colorOk),
                          child: Text(_tabIndex == applied ? "Cancel Job" : "Apply to Job", style: whiteText),
                          onPressed: () async{
                            await confirmDialog(context, _tabIndex == applied ? "Cancel job application?" : "Apply to job?").then((value){
                              if(value){
                                setState((){
                                  if(_tabIndex == applied){
                                    job.staffApplied.remove(userID);
                                    _jobList = _getJobs(applied);
                                  }
                                  else{
                                    if(!job.finalized && !job.staffApplied.contains(userID)){
                                      job.staffApplied.add(userID);
                                      _jobList = _getJobs(available);
                                    }
                                  }
                                });

                                Navigator.pop(context);
                              }
                            });
                          },
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                          child: Text("Close", style: whiteText),
                          onPressed: (){
                            Navigator.pop(context);
                          },
                        ),
                      ]
                  )
                ],
              ),
            )
        )
    );
  }

  Widget showList(int m){
    return SingleChildScrollView(
        child: Center(
          child: Column(
              children: List.generate(_jobList.length, (index) => Card(
                child: ListTile(
                  tileColor: _getStatusColor(_jobList[index]),
                    title: Text("${_jobList[index].id}   ${_jobList[index].type}   ${_jobList[index].location}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever_sharp),
                      color: Colors.redAccent,
                      onPressed: () {
                        _jobList.removeAt(index);
                        setState(() {});
                      },
                    ),
                    onTap: () async{
                      if(m == available || m == applied){
                        _jobDetails(context: context, job: _jobList[index]);
                      }
                      else{
                        // settings
                      }
                    }
                ),
              ),
              )
          ),
        )
    );
  }

  Widget showSettings(){
    return SingleChildScrollView(
        child: Center(
          child: Column(
              children: <Widget>[
                Card(
                  child: ListTile(
                    title: const Text("Name:"),
                    subtitle: Text("${currentUser.getFirstName()} ${currentUser.getLastName()}")
                  )
                ),
                Card(
                  child: ListTile(
                    title: const Text("Date of Birth: "),
                    subtitle: Text(currentUser.getDob()),
                  )
                ),
                Card(
                  child: ListTile(
                    title: const Text("Postcode: "),
                    subtitle: TextButton(
                        onPressed: () async{
                          await textEditDialog(context, "Change Postcode", currentUser.postcode).then((value){
                            setState((){
                              currentUser.postcode = value;
                            });
                          });
                        },
                        child: Text(currentUser.postcode)
                    ),
                  )
                ),
                Card(
                  child: ListTile(
                    title: const Text("Email: "),
                    subtitle: TextButton(
                        onPressed: () async{
                          await textEditDialog(context, "Change Email", currentUser.email).then((value){
                            setState((){
                              currentUser.email = value;
                            });
                          });
                        },
                        child: Text(currentUser.email)
                    ),
                  )
                ),
                Card(
                  child: ListTile(
                    title: const Text("I Own Transportation: "),
                    subtitle: Checkbox(
                        value: currentUser.ownsTransport,
                        onChanged: (value){
                          setState((){
                            currentUser.ownsTransport = value as bool;
                          });
                        }
                    )
                  )
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                    onPressed: (){
                      changePasswordDialog(context);
                    },
                    child: const Text("Change Password")
                )
              ]
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      //length: 3,
      //initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: Center(
            child:Text(
              _tabIndex == available ? "Available Jobs" :
              _tabIndex == applied ? "Applied Jobs" :
              "Settings"
            )
          ),
          bottom: TabBar(
            onTap: (value) {
              _tabIndex = value;
              _jobList = _getJobs(value);
              setState(() {});
            },
            tabs: const [
              Tab(icon: Icon(Icons.file_copy)),
              Tab(icon: Icon(Icons.file_copy_outlined)),
              Tab(icon: Icon(Icons.settings)),
            ],
          ),
          //title: Text('Tabs Demo'),
        ),
        body: TabBarView(
          controller: _tabControl,
          children: [
            showList(available),
            showList(applied),
            showSettings()
          ],
        ),
      ),
    );
  }
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

Future<void> changePasswordDialog(BuildContext context) async{
  String oldPass = "";
  String newPass = "";

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
                      //title: Text("Change password"),
                      content: Column(
                        children: [
                          Card(
                              child: ListTile(
                                //leading: IconButton(icon: Icons.eye),
                                title: const Text("Old Password"),
                                subtitle: TextFormField(
                                  obscureText: true,
                                  //initialValue: originalText,
                                  autofocus: true,
                                  decoration: const InputDecoration(hintText: '', border: InputBorder.none),
                                  keyboardType: TextInputType.name,
                                  onChanged: (value) {
                                    oldPass = value;
                                    setState((){});
                                  },
                                ),
                              )
                          ),
                          Card(
                              child: ListTile(
                                title: const Text("New Password"),
                                subtitle: TextFormField(
                                  obscureText: true,
                                  //initialValue: originalText,
                                  autofocus: true,
                                  decoration: const InputDecoration(hintText: '', border: InputBorder.none),
                                  keyboardType: TextInputType.name,
                                  onChanged: (value) {
                                    newPass = value;
                                    setState((){});
                                  },
                                ),
                              )
                          ),
                        ]
                      ),

                      actions: <Widget>[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: colorDenied),
                          onPressed: () {
                            //newText = originalText;
                            setState((){});
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: colorOk),
                          onPressed: () {
                            currentUser.changePassword(oldPass, newPass);
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
                          style: ElevatedButton.styleFrom(backgroundColor: colorDenied),
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

Future<bool> confirmDialog(BuildContext context, String question) async {
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
                        title: Text(question, textAlign: TextAlign.center,),
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

class Staff{
  final String _firstName;
  final String _lastName;
  String postcode;
  final String _dob;
  String email;
  bool ownsTransport = false;
  String _password;
  bool _forkliftLicense = false;
  bool _heightLicense = false;
  bool _ewpLicense = false;
  String _id = "";
  String _rating = "";

  Staff(this._firstName, this._lastName, this.postcode, this._dob, this.email, this.ownsTransport, this._password){
    _rating = "C";
    _id = "01";
  }

  getFirstName(){
    return _firstName;
  }

  getLastName(){
    return _lastName;
  }

  getDob(){
    return _dob;
  }

  changePostcode(String newPostcode){
    postcode = newPostcode;
  }

  changeEmail(String newEmail){
    email = newEmail;
  }

  bool changePassword(String old, String newPass){
    // MUST AUTHENTICATE
    if(old == _password){
      _password = newPass;
      return true;
    }
    return false;
  }
}

class Job {
  String id = "";
  String date = "";
  String business = "";
  String type = "";
  String location = "";
  String startTime = "";
  String duration = "";
  String travelContribution = "";
  String notes = "";

  List<int> staffApplied = [];
  List<int> staffConfirmed = [];
  bool finalized = false;

  Job(
      this.id,
      this.date,
      this.business,
      this.type,
      this.location,
      this.startTime,
      this.duration,
      this.travelContribution,
      this.notes
      );
}