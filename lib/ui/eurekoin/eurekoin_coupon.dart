import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import './eurekoin.dart';

typedef CouponEurekoinItemBodyBuilder<T> = Widget Function(CouponEurekoinItem<T> item);
typedef ValueToString<T> = String Function(T value);

class DualHeaderWithHint extends StatelessWidget {
  const DualHeaderWithHint({this.name, this.error, this.showHint});

  final String name;
  final String error;
  final bool showHint;

  Widget _crossFade(Widget first, Widget second, bool isExpanded) {
    return AnimatedCrossFade(
      firstChild: first,
      secondChild: second,
      firstCurve: const Interval(0.0, 0.6, curve: Curves.fastOutSlowIn),
      secondCurve: const Interval(0.4, 1.0, curve: Curves.fastOutSlowIn),
      sizeCurve: Curves.fastOutSlowIn,
      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: <Widget>[
      Expanded(
        flex: 3,
        child: Container(
          padding: EdgeInsets.only(left: 15.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle(
                style: Theme.of(context).textTheme.subhead,
                child: Text(name)
            ),
          ),
        ),
      ),
      Expanded(
          flex: 3,
          child: Container(
              margin: const EdgeInsets.only(left: 24.0),
              child: _crossFade(
                  DefaultTextStyle(
                      style: Theme.of(context).textTheme.subhead,
                      child: Text(error, style: TextStyle(color: Colors.red))
                  ),
                  DefaultTextStyle(
                      style: Theme.of(context).textTheme.subhead,
                      child: Text("")
                  ),
                  showHint
              )
          )
      )
    ]);
  }
}

class CollapsibleBody extends StatelessWidget {
  const CollapsibleBody(
      {this.margin = EdgeInsets.zero, this.child, this.onSave, this.onCancel});

  final EdgeInsets margin;
  final Widget child;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Column(children: <Widget>[
      Container(
          margin: const EdgeInsets.only(right: 24.0, bottom: 24.0),
          child: Center(
              child: DefaultTextStyle(
                  style: textTheme.caption.copyWith(fontSize: 15.0),
                  child: child))),
      const Divider(height: 1.0),
      Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child:
          Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
            Container(
                margin: const EdgeInsets.only(right: 8.0),
                child: FlatButton(
                    onPressed: onSave,
                    textTheme: ButtonTextTheme.normal,
                    child: const Text('Send'))),
            Container(
                margin: const EdgeInsets.only(right: 8.0),
                child: FlatButton(
                    onPressed: onCancel,
                    child: const Text('Cancel')))
          ]))
    ]);
  }
}

class CouponEurekoinItem<T> {
  CouponEurekoinItem({this.name,this.builder, this.error, this.valueToString});

  final String name;
  String error;
  final CouponEurekoinItemBodyBuilder<T> builder;
  final ValueToString<T> valueToString;
  TextEditingController couponController = new TextEditingController();
  bool isExpanded = false;
  bool isError = false;

  ExpansionPanelHeaderBuilder get headerBuilder {
    return (BuildContext context, bool isExpanded) {
      return DualHeaderWithHint(
          name: name,
          error: error,
          showHint: isExpanded);
    };
  }

  Widget build() => builder(this);
}

var formKey = GlobalKey<FormState>();

class EurekoinCoupon extends StatefulWidget {

  EurekoinCoupon({Key key, this.name, this.email, this.parent}):super (key: key);
  final String name;
  final String email;
  final EurekoinHomePageState parent;
  @override
  _EurekoinCouponState createState() => _EurekoinCouponState();
}

class _EurekoinCouponState extends State<EurekoinCoupon> {

  List<CouponEurekoinItem<dynamic>> _couponEurekoinItem;
  FirebaseUser currentUser;
  final loginKey = 'itsnotvalidanyways';

  @override
  void initState() {
    super.initState();

    _couponEurekoinItem = <CouponEurekoinItem<dynamic>>[
      CouponEurekoinItem<String>(
        name: 'Redeem Coupon',
        error: '',
        valueToString: (String value) => value,
        builder: (CouponEurekoinItem<String> item) {
          void close() {
            setState(() {
              item.isExpanded = false;
            });
          }
          return Form(
            key: formKey,
            child: Builder(
              builder: (BuildContext context) {
                return CollapsibleBody(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    onSave: () {
                      if (formKey.currentState.validate()) {
                        String coupon = item.couponController.text;
                        Future<int> result = couponEurekoin(coupon);
                        result.then((value) {
                          print(value);
                          if (value == 0)
                          {
                            setState(() {
                              item.error = "Successful!";
                            });
                            widget.parent.getUserEurekoin();
                            widget.parent.transactionsHistory();
                          }
                          else if (value == 2)
                            setState(() {
                              item.error = "Invalid Coupon";
                            });
                          else if (value == 3)
                            setState(() {
                              item.error = "Already Used";
                            });
                          else if (value == 4)
                            setState(() {
                              item.error = "Coupon Expired";
                            });
                          setState(() {
                            item.couponController.text = '';
                          });
                          Form.of(context).reset();
                          close();
                        });
                      }
                    },
                    onCancel: () {
                      setState(() {
                        item.error='';
                        item.couponController.text = '';
                      });
                      Form.of(context).reset();
                      close();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextFormField(

                          controller: item.couponController,
                          decoration: InputDecoration(
                            labelText: "Coupon Code",
                             labelStyle: TextStyle(color: Colors.grey),
                          ),
                          validator: (val)=> val == ""? val : null
                      ),
                    )
                );
              },
            ),
          );
        },
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData= Theme.of(context);
    return new Theme(
        data: themeData,
        child: SingleChildScrollView(
            child: new DefaultTextStyle(
              style: themeData.textTheme.subhead,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Container(
                  child: Theme(
                      data: themeData,
                      //.copyWith(cardColor: Colors.grey.shade50),
                      child: ExpansionPanelList(
                          expansionCallback: (int index, bool isExpanded) {
                            setState(() {
                              _couponEurekoinItem[index].isExpanded = !isExpanded;
                            });
                            if(_couponEurekoinItem[index].isExpanded==true)
                              widget.parent.moveDown();
                          },
                          children: _couponEurekoinItem.map((CouponEurekoinItem<dynamic> item) {
                            return ExpansionPanel(
                              isExpanded: item.isExpanded,
                              headerBuilder: item.headerBuilder,
                              body: item.build(),
                            );
                          }).toList())),
                ),
              ),
            )));
  }

  Future<int> couponEurekoin(String coupon) async {
    var email = widget.email;
    var bytes = utf8.encode("$email"+"$loginKey");
    var encoded = sha1.convert(bytes);
    String apiUrl = "https://ekoin.nitdgplug.org/api/coupon/?token=$encoded&code=$coupon";
    print(apiUrl);
    http.Response response = await http.get(apiUrl);
    print(response.body);
    var status = json.decode(response.body)['status'];
    return int.parse(status);
  }

}