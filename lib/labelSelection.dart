import 'package:flutter/material.dart';
import 'package:freshcls/provider/infer_provider.dart';
import 'package:provider/provider.dart';

// 기타 선택 화면 UI
class LabelSeletionScreen extends StatefulWidget {
  final int infer_no;
  final List<int> predict_labels;
  final Map<int, String> labelMap;
  final List<int> labelList;
  final Function() parentNotify;
  final Function(dynamic, dynamic) sendFeedback;

  const LabelSeletionScreen({Key? key, required this.infer_no, required this.predict_labels, required this.labelMap, required this.labelList, required this.parentNotify, required this.sendFeedback}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LabelSeletionScreenState();
}


class _LabelSeletionScreenState extends State<LabelSeletionScreen>{
  late Table table;

  // late InferProvider _inferProvider;

  @override
  void initState() {
    // _inferProvider = Provider.of<InferProvider>(context, listen: false);
    List<TableRow> listTableRow = [];
    List<Widget> listCell = [];
    int idx = 0;
    widget.labelList.forEach((element) {
      listCell.add(
          TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Container(
                height: 32,
                color: Colors.green,
                child: ElevatedButton(
                  onPressed: widget.predict_labels.contains(element) ? null : () async {
                    widget.sendFeedback(widget.infer_no, element);
                    widget.parentNotify();
                    Navigator.pop(context);
                  },
                  child: Text(widget.labelMap[element]!),
                ),
              )
          )
      );

      if(idx%3 == 2) {
        listTableRow.add(
            TableRow(
              children: listCell,
            )
        );
        listCell = [];
      }
      idx += 1;
    });
    if(idx%3 != 0) {
      while (idx%3 != 0) {
        listCell.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Container(
                height: 32,
              ),
            )
        );
        idx += 1;
      }
      listTableRow.add(
          TableRow(
            children: listCell,
          )
      );
    }
    setState(() {
      table = Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: listTableRow,
      );
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Label')),
      body: SingleChildScrollView(child: table,),
    );
  }
}