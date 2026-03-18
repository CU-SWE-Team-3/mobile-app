import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  final ValueNotifier<bool> _isPasswordValid = ValueNotifier(false);
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier(false);
  final TextEditingController _passwordController = TextEditingController();
  final ValueNotifier<String?> _errorMessage = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
        backgroundColor: Colors.black12,

        appBar: AppBar(
            centerTitle: true,
            toolbarHeight: 90,
            leadingWidth: 90,
            leading: Padding(
              padding: EdgeInsets.only(left: 17, top: 30, bottom:10),
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
            title: const Padding(padding:  EdgeInsets.only(top: 20),
              child: Text("Welcome back!",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'modern sans-serif font'
                ),
              ),)
        ),

        body:
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.01,
            vertical: screenHeight * 0.01,
          ),
          child: Container(
            child:
            Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top:40, right: 50),
                    child: const Text('Your email address or profile URL',
                      textAlign: TextAlign.start,
                      style:  TextStyle(
                          color: Colors.grey,
                          fontSize: 17
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 30, bottom: 35),
                    child: const Text('BioBeats1234567@gmail.com',  //Mock
                      textAlign: TextAlign.left,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: _errorMessage,
                    builder: (context, errorMsg, child){
                      return ValueListenableBuilder<bool>(
                          valueListenable: _isPasswordVisible,
                          builder: (context, isVisible, child){
                            // Only show a real error (not null, not blank space)
                            final String? displayError =
                            (errorMsg != null && errorMsg.trim().isNotEmpty)
                                ? errorMsg
                                : null;
                            return SizedBox(
                                width: 380,
                                child:
                                TextField(
                                  controller: _passwordController,
                                  textAlignVertical: TextAlignVertical.top,
                                  obscureText: !isVisible, //for hiding the written password
                                  cursorColor: Colors.orange,
                                  style:const TextStyle(color: Colors.white),
                                  onChanged: (Value){
                                    if(Value.isEmpty){
                                      _isPasswordValid.value = false;
                                      _errorMessage.value = null; // null = no error shown
                                    } else if (Value.length < 8){
                                      _isPasswordValid.value = false;
                                      _errorMessage.value = 'Password must contain min 8 characters';
                                    } else {
                                      _isPasswordValid.value = true;
                                      _errorMessage.value = null;
                                    }
                                  },
                                  decoration:
                                  InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 22, horizontal: 12,
                                      ),
                                      labelText: 'Your Password (min. 8 characters)',
                                      labelStyle: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16
                                      ),
                                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                                      errorText: displayError,
                                      errorStyle: TextStyle(color: Colors.white, fontSize: 16),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          isVisible
                                              ? Icons.visibility_off : Icons.visibility,
                                          size: 30,
                                          color: Colors.grey,
                                        ),
                                        onPressed: (){
                                          _isPasswordVisible.value = !_isPasswordVisible.value;
                                        },
                                      ),
                                      errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.red, width: 1.5),
                                          borderRadius: BorderRadius.circular(5)
                                      ),
                                      filled: true,
                                      fillColor: Colors.white24,
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(5),
                                          borderSide: BorderSide(color: Colors.grey, width: 1)
                                      ),
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(5),
                                          borderSide: BorderSide(color:Colors.grey, width:1)
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(5),
                                          borderSide: BorderSide(color: Colors.white54, width: 1.5)
                                      )
                                  ),
                                )
                            );
                          }
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                      valueListenable: _isPasswordValid,
                      builder: (context, isValied, child){
                        return SizedBox(
                            width: 400,
                            child: ElevatedButton(
                              // onPressed: () => context.push('/register'),
                              style: TextButton.styleFrom( backgroundColor: const Color(0xFF888888),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                              onPressed: isValied ? () {
                                print('continue');
                              }: null,
                              child:
                              GestureDetector(
                                child:
                                Container(
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: isValied ?
                                    Colors.white : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  margin: EdgeInsets.only(top: 10),
                                  child: Center(
                                    child: Text('Continue',
                                      textAlign : TextAlign.center,
                                      style: TextStyle(
                                        color: isValied ? Colors.black : Colors.grey[700],
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                        );
                      }
                  ),
                  GestureDetector(
                    onTap: (){
                      print("Forgot"); //check
                    },
                    child:
                    Container(
                        margin: EdgeInsets.only(right: 180, top: 20),
                        child: const Text("Forgot your password?",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        )
                    ),
                  )
                ]
            ),
          ),
        )
    );
  }
}
