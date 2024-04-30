import 'package:flutter/material.dart';
import 'item.dart';

class ItemTable {
  List<Item> items;
  List<String> column = [];

  ItemTable({
    required this.items, required this.column
  });

  factory ItemTable.fromList(List<Item> list){
    return ItemTable(
      items: List.generate(list.length, (index) =>
          Item(
          id: list[index].id,
          barcode: list[index].barcode,
          category: list[index].category,
          description: list[index].description,
          uom: list[index].uom,
          price: list[index].price,
          date: list[index].date,
          ordercode: list[index].ordercode,
          nof: false
        ),
        growable: true
      ),
      column: List.generate(list.length, (index) => list[index].category.toString().toUpperCase()).toSet().toList(),
    );
  }

  addItem(Item item) {
    items.add(
      Item(
        id: item.id,
        barcode: item.barcode,
        category: item.category,
        description: item.description,
        uom: item.uom,
        price: item.price,
        date: item.date,
        ordercode: item.ordercode,
        nof: false,
      )
    );
    sortTable();
  }

  removeItem(int index){
    items.removeAt(index);
    sortTable();
  }

  Container cell(String text, double cellWidth, [Color? cellColor]) {
    cellColor ??= Colors.white24;
    return Container(
      width: cellWidth,
      height: 35.0,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: Colors.black,
          style: BorderStyle.solid,
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 4,
          softWrap: true,
        ),
      )
    );
  }

  Expanded cellFit(String text, [Color? cellColor]) {
    cellColor ??= Colors.white24;
    return Expanded(
      flex: 1,
      child: Container(
        height: 35.0,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: Colors.black,
            style: BorderStyle.solid,
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 4,
            softWrap: true,
          ),
        )
      )
    );
  }

  List<Widget> row(int index,{Color? cellColor}) {
    cellColor = cellColor ?? Colors.white24;
    return <Widget>[
      cell(items[index].id.toString(), 75, cellColor),
      cell(splitCodeString(items[index].barcode), 150, cellColor),
      cell(items[index].category, 150, cellColor),
      cell(items[index].description, 400, cellColor),
      cell(items[index].uom, 75, cellColor),
      cell(items[index].price, 75, cellColor),
      cellFit(items[index].date, outOfDate(items[index].date)),
      cellFit(splitCodeString(items[index].ordercode), cellColor),
      cell(items[index].nof.toString().toUpperCase(), 75),
    ];
  }

  List<Widget>rowImport(int index, {Color? cellColor}){
    cellColor = cellColor ?? Colors.white24;
    return <Widget>[
      cell(splitCodeString(items[index].barcode), 150, cellColor),
      cell(items[index].category, 150, cellColor),
      cell(items[index].description, 400, cellColor),
      cell(items[index].uom, 75, cellColor),
      cell(items[index].price, 75, cellColor),
      cellFit(items[index].date, outOfDate(items[index].date)),
      cellFit(splitCodeString(items[index].ordercode), cellColor),
      cell(items[index].nof.toString().toUpperCase(), 75),
    ];
  }

  List<Widget> header() {
    return [
      cell("ID", 75),
      cell("BARCODE", 150),
      cell("CATEGORY", 150),
      cell("DESCRIPTION", 400),
      cell("UOM", 75),
      cell("PRICE", 75),
      cellFit("DATE"),
      cellFit("ORDERCODE"),
      cell("NOF", 75),
    ];
  }

  // Sort alphabetically and calc new indices
  sortTable() {
    items.sort((x, y) => (x.description).compareTo((y.description)));
    for (int i = 0; i < items.length; i++) {
      items[i].id = i;
    }
  }

  // Splits barcode/ordercode string to show the first code plus the total count of the split
  String splitCodeString(String codeString) {
    int count = codeString.split(",").length - 1;
    return codeString.split(",").first + (count > 0 ? " (+$count)" : "");
  }

  // Get formatted date string and check if it is old (> 1 year)
  Color? outOfDate(String date) {
    int year = date.contains("/") ? int.parse(date.split("/").last) : int.parse(date.split("-").first);
    return (DateTime.now().year % 100) - (year % 100) > 0 ? Colors.red[800] : Colors.white24;
  }
}
