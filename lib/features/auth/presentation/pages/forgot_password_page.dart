import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForgotPasswordPage extends ConsumerWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        backgroundColor: Colors.black12,
        appBar: AppBar(
            centerTitle: true,
            toolbarHeight: 80,
            leadingWidth: 90,
            leading: Padding(
              padding: EdgeInsets.only( top: 30, bottom:5),
              child: CircleAvatar(
                backgroundColor: Colors.grey[850],
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_sharp, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.pop(context);
                    print("Back");
                  },
                ),
              ),
            ),
            backgroundColor: Colors.black12,
            title: const Padding(padding:  EdgeInsets.only(top: 23),
              child:  Text("Reset password",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'modern sans-serif font'
                ),
              ),
            )
        ),
        body:
        Column(
          children: [
            SizedBox(
              width: 380, // change this value to your desired width
              child: Container(
                margin: EdgeInsets.only(top: 20),
                child: TextField(
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: Colors.orange,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                      labelText: 'Your email address',
                      labelStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.white24,
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: Colors.grey, width: 1)
                      ),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: Colors.white54, width: 1.5)
                      )
                  ),
                ),
              ),
            ),

            Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 20, left:15, right: 15),
                  child: const Text("If the email address is in our database, "
                      "we will send you an email to reset your password.Need help?",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'modern sans-serif font'
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: (){
                    print("Need help"); //check
                  },
                  child: const Padding(padding: EdgeInsets.only(right: 228),
                      child:Text("visit our Help Center.",

                        style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 16
                        ),
                      )
                  )
                ),
                GestureDetector(
                  onTap:(){
                    print("reset link"); // checking that its working
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: 20),
                    width:380,
                    height: 55,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5)
                    ),
                    child: const Center(
                      child: Text('Send reset link',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'modern sans-serif font'
                          )
                      ),
                    ),
                  )
                )
              ],
            )
          ],
        )
    );
  }
}
