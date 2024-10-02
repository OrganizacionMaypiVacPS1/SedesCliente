import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttapp/Config/Config.dart';
import 'package:fluttapp/Models/Profile.dart';
import 'package:fluttapp/presentation/screens/Carnetizador/HomeCarnetizador.dart';
import 'package:fluttapp/presentation/screens/ChangePassword.dart';
import 'package:fluttapp/presentation/screens/Cliente/HomeClient.dart';
import 'package:fluttapp/presentation/screens/Register.dart';
import 'package:fluttapp/presentation/screens/RegisterUpdate.dart';
import 'package:fluttapp/presentation/services/auth_google.dart';
import 'package:fluttapp/presentation/services/services_firebase.dart';
import 'package:fluttapp/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:fluttapp/presentation/services/alert.dart';
import 'package:flutter_login_facebook/flutter_login_facebook.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

MostrarFinalizarLogin mostrarFinalizar = MostrarFinalizarLogin();

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController correoController = TextEditingController();
  TextEditingController contrasenaController = TextEditingController();
  String? mensajeErrorCorreo;
  String? mensajeErrorContrasena;
  final AuthGoogle authGoogle = AuthGoogle();
  int? memberId = 0;
  bool isloading = false;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  Future<Member?> authenticateHttp(String email, String password) async {
    final url = Uri.parse(
        '${Config.baseUrl}/user?correo=$email&password=$password');

    //${Config.baseUrl}/userbyrol?correo=pepe@gmail.com&password=827ccb0eea8a706c4c34a16891f84e7b

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      final member = Member.fromJson(data);

      miembroActual = member;
      await saveMemberIdToCache(member.id);

      insertToken();
      setState(() {
        isloading = false;
      });

      return member;
    } else if (response.statusCode == 404) {
      return null; // Usuario no encontrado
    } else {
      throw Exception('Error al autenticar el usuario');
    }
  }

  Future<void> saveMemberIdToCache(int memberId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('miembroLocal', memberId);
  }

  @override
  void initState() {
    super.initState();
    if (mounted) tryAutoLogin(context);
  }

  Future<void> tryAutoLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
final memberId = prefs.getInt('miembroLocal');

    if (memberId != null && memberId > 0) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text('Espere unos momentos....'),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  Center(
                    child: SpinKitFadingCube(
                      color: Color(0xFF5C8ECB),
                      size: 50.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

try {
        final member = await fetchMemberById(memberId);
        if (member != null) {
          miembroActual = member;
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ViewClient(
                  userId: miembroActual!.id,
                ),
              ),
            );
          }
        } else {
          // Manejar el caso en que el miembro no es encontrado
          Navigator.of(context, rootNavigator: true).pop();
          // Aquí podrías mostrar un mensaje o redirigir a otra pantalla
        }
      } catch (error) {
        Navigator.of(context, rootNavigator: true).pop();
        // Mostrar un mensaje de error o manejar el error de otra forma
        print('Error al intentar iniciar sesión: $error');
      }
      } else {
      // Manejar el caso en que no hay un memberId válido
      print('No se encontró un ID de miembro válido en SharedPreferences.');
    }
  }

  insertToken() async {
    final url = '${Config.baseUrl}/inserttoken';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'idPerson': miembroActual!.id,
        'token': token,
      }),
    );

    if (response.statusCode != 200) {
      print('Error al insertar el token');
    }
  }

  Future<Member?> recoverPassword(String email) async {
    final url = Uri.parse('${Config.baseUrl}/checkemail/$email');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      globalLoggedInMember = Member.fromJson2(data);

      return globalLoggedInMember;
    } else if (response.statusCode == 404) {
      return null; // Correo no encontrado en la base de datos
    } else {
      throw Exception('Error al recuperar la contraseña');
    }
  }

  Future<Member?> comprobarPassword(String email) async {
    final url =
        Uri.parse('${Config.baseUrl}/checkemailpassword/$email');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      globalLoggedInMember = Member.fromJson3(data);

      return globalLoggedInMember;
    } else if (response.statusCode == 404) {
      return null; // Correo no encontrado en la base de datos
    } else {
      throw Exception('Error al recuperar la contraseña');
    }
  }

  Future<bool> sendEmailAndUpdateCode(int userId) async {
    final code = generateRandomCode();
    final exists = await checkCodeExists(userId);
    final smtpServer = gmail('bdcbba96@gmail.com', 'ehbh ugsw srnj jxsf');

    final message = Message()
      ..from = Address('bdcbba96@gmail.com', 'Admin')
      ..recipients.add(globalLoggedInMember!.correo)
      ..subject = 'Cambiar Contraseña MaYpiVaC'
      ..text = 'Código de recuperación de contraseña: $code';

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
      // Actualiza la base de datos

      final url = exists
          ? Uri.parse(
              '${Config.baseUrl}/updateCode/$userId/$code') // URL para actualizar el código

          : Uri.parse(
              '${Config.baseUrl}/insertCode/$userId/$code'); // URL para insertar un nuevo registro

      final response = await (exists ? http.put(url) : http.post(url));

      if (response.statusCode == 200) {
        print('Código actualizado/insertado en la base de datos.');

        return true; // Devuelve true si todo fue exitoso
      } else {
        print('Error al actualizar/insertar el código en la base de datos.');

        return false; // Devuelve false en caso de error
      }
    } catch (e) {
      print('Message not sent.');

      print(e.toString());

      return false; // Devuelve false en caso de error
    }
  }

  String generateRandomCode() {
    final random = Random();
    final firstDigit =
        random.nextInt(9) + 1; // Genera un número aleatorio entre 1 y 9
    final restOfDigits = List.generate(4, (index) => random.nextInt(10)).join();
    final code = '$firstDigit$restOfDigits';

    return code;
  }
  //actualizar la base
  Future<bool> checkCodeExists(int userId) async {
    var userId = globalLoggedInMember?.id;

    final response = await http.get(
      Uri.parse(
          '${Config.baseUrl}/checkCodeExists/$userId'), // Reemplaza con la URL correcta de tu API
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data[
          'exists']; // Suponiendo que la API devuelve un booleano llamado "exists"
    } else {
      throw Exception('Error al verificar el código.');
    }
  }

  Future<void> _showEmailDialog(BuildContext context) async {
    String email = '';

    await showDialog<Member?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Ingrese el correo '),
          content: TextField(
            onChanged: (value) {
              email = value;
            },
            decoration: InputDecoration(labelText: 'Correo Electrónico'),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () async {
                // Mostrar el mensaje de espera
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Espere unos momentos....'),
                      content: SingleChildScrollView(
                        child: ListBody(
                          children: [
                            Center(
                              child: SpinKitFadingCube(
                                color: Colors.blue, // Color de la animación
                                size: 50.0, // Tamaño de la animación
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                //final member = await comprobarPassword(email);
                final member = await recoverPassword(email);

                /*if (member!.contrasena == null) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Confirmación"),
                        content: Text(
                            "No puede recuperar la contraseña si es usuario de Facebook o Google"),
                        actions: [
                          TextButton(
                            child: Text("Cancelar"),
                            onPressed: () {
                              Navigator.of(context)
                                  .pop(); // Cierra el cuadro de diálogo
                            },
                          )
                        ],
                      );
                    },
                  );
                } else {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Espere unos 3 segundos por favor...'),
                        content: Center(
                          child: SpinKitCircle(
                      color: Color(0xFF5C8ECB),
                      size: 50.0,
                    ),
                        ),
                      );
                    },
                  );*/

                  Future.microtask(() async {
                    final success = await sendEmailAndUpdateCode(member!.id);
                    // Cerrar el diálogo de espera

                    Navigator.of(context, rootNavigator: true).pop();

                    Navigator.of(context)
                        .pop(member); // Cerrar el diálogo y pasar el resultado

                    if (success) {
                      isLogin = 1;

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangePasswordPage(
                            member: globalLoggedInMember,
                          ),
                        ),
                      );

                      Mostrar_Mensaje(
                        context,
                        "Se ha enviado un código a tu correo electrónico.",
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Ocurrió un error al enviar el código de recuperación.'),
                        ),
                      );
                    }
                  });
                //}
              },
              child: Text('Recuperar Contraseña'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isloading
          ? Center(child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
            /*image: DecorationImage(
              image: AssetImage('assets/Splash.png'),
              fit: BoxFit.cover,
            ),*/
          ),
            child: CircularProgressIndicator(
                      color: Color(0xFF5C8ECB),
                      
                    )),) 
          : Container(
            color: Colors.white,
              /*decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/Splash.png'),
                  fit: BoxFit.cover,
                ),
              ),*/
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      "assets/Univallenavbar.png",
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: correoController,
                      maxLength: 45, // Establece el máximo de caracteres a 45
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico', //aca es el inicio de seccion
                        counterText:
                            '', // Si no quieres mostrar el contador de caracteres
                        errorText: mensajeErrorCorreo,
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlueAccent),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: contrasenaController,
                      obscureText: true,
                      maxLength: 10, // Establece el máximo de caracteres a 10
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        counterText:
                            '', // Si no quieres mostrar el contador de caracteres
                        errorText: mensajeErrorContrasena,
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlueAccent),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RegisterUpdate(isUpdate: false,)),
                            );
                          },
                          child: Text(
                            'Regístrate!',
                            style:
                                TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            _showEmailDialog(context);

                            isLogin =
                                1; // Mostrar el diálogo de recuperación de contraseña
                          },
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style:
                                TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        // Validación de campos vacíos
                        if (correoController.text.isEmpty ||
                            contrasenaController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Por favor, complete todos los campos.')),
                          );
                          return; // Sale de la función si hay campos vacíos
                        }

                        // Validación de formato de correo electrónico
                        /*if (!isValidEmail(correoController.text)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Ingrese un correo electrónico válido.')),
                          );
                          return; // Sale de la función si el correo es inválido
                        }*/

                        setState(() {
                          isloading = true;
                        });

                        final loggedInMember = await authenticateHttp(
                          correoController.text,
                          md5
                              .convert(utf8.encode(contrasenaController.text))
                              .toString(),
                        );

                        setState(() {
                          isloading = false;
                        });

                        if (loggedInMember != null) {
                          // Mostrar la animación de carga durante 2 segundos
                          setState(() {
                            isloading = true;
                          });
                          await Future.delayed(Duration(seconds: 2));
                          setState(() {
                            isloading = false;
                          });

                          setState(() {
                            _isAuthenticated = true;
                          });

                          if (loggedInMember.role == "Carnetizador" ||
                              loggedInMember.role == "Super Admin" ||
                              loggedInMember.role == "Administrador" ||
                              loggedInMember.role == "Jefe de Brigada" ||
                              loggedInMember.role == "Cliente") {
                            // Redirige al usuario a la página deseada
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ViewClient(userId: loggedInMember.id),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Rol de usuario desconocido')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Usuario o Contraseña Incorrectos')),
                          );
                        }
                      },
                      child: _isLoading
                          ? CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 4.0,
                            ) // Muestra una animación de carga
                          : Text('Iniciar sesión'),
                          style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isloading ? '' : 'O inicia sesión con:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          isloading
              ? Container()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /*ElevatedButton.icon(
                      onPressed: () {
                        _facebookLogin();
                      },
                      icon: Icon(Icons.facebook),
                      label: Text('Facebook'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),*/
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        try {
                          final GoogleSignInAccount? account = await GoogleSignIn().signIn();
                          final GoogleSignInAuthentication googleAuth = await account!.authentication;
                          final credential= GoogleAuthProvider.credential(
                            accessToken: googleAuth.accessToken,
                            idToken: googleAuth.idToken
                          );
                          UserCredential user = await FirebaseAuth.instance.signInWithCredential(credential);
                          setState(() {
                            isloading = true;
                          });

                          Member googleUser = Member(
                              names: "",
                              id: 0,
                              correo: "",
                              latitud: 0.1,
                              longitud: 0.1);

                          googleUser.correo = user.user!.email!;
                          googleUser.telefono =
                              user.user!.phoneNumber as int?;
                          googleUser.fechaCreacion = DateTime.now();
                          googleUser.status = 1;
                          googleUser.role = null;
                          googleUser.names =
                              user.user!.displayName!;
                                                  AdditionalUserInfo? additionalUserInfo =
                              user.additionalUserInfo;
                          if (additionalUserInfo != null) {
                            googleUser.names = user
                                .additionalUserInfo!.profile?["given_name"];
                            googleUser.lastnames = user
                                .additionalUserInfo!.profile?["family_name"];
                          }
                          try {
                            await GoogleSignIn().disconnect();

                            await GoogleSignIn().signOut();
                          } catch (error) {
                            print(
                                "Error al desconectar o cerrar sesión con Google: $error");
                          }
                          var res = await registerUser2(googleUser);

                          if (res == 1) {
                            miembroActual =
                                await getPersonByEMail(googleUser.correo);
                            await saveMemberIdToCache(miembroActual!.id);
                            insertToken();
                          } else {
                            Mostrar_Error1(context, "Error al iniciar sesión");

                            return;
                          }

                          setState(() {
                            isloading = false;
                          });

                          if (miembroActual!.role == "Carnetizador" ||
                              miembroActual!.role == "Super Admin") {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewClient(
                                  userId: miembroActual!.id,
                                ),
                              ),
                            );
                          } else if (miembroActual!.role == "Cliente") {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewClient(
                                  userId: miembroActual!.id,
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (error is PlatformException &&
                              error.code == 'sign_in_canceled') {
                            print(
                                "Inicio de sesión con Google cancelado por el usuario");
                          } else {
                            print("Error al iniciar sesión con Google: $error");
                          }
                        }
                      },
                      icon: Image(
                        image: AssetImage('assets/google.png'),
                        height: 24.0,
                      ),
                      label: Text('Continuar con Google'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$');

    return emailRegex.hasMatch(email);
  }

  Future<Member?> checkemailexist(String email) async {
    final url = Uri.parse('${Config.baseUrl}/checkemail/$email');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      globalLoggedInMember = Member.fromJson2(data);

      return globalLoggedInMember;
    } else if (response.statusCode == 404) {
      print("Correo no encontrado en la base de datos");

      return null;
    } else {
      throw Exception('Error al checkear el email la contraseña');
    }
  }

  Future<int> registerUser2(Member miembro) async {
    print(miembro.toString());

    final url = Uri.parse('${Config.baseUrl}/register');

    var idRol = 0;

    if (miembro.role == 'Carnetizador') {
      idRol = 7;
    } else if (miembro.role == 'Cliente') {
      idRol = 8;
    } else if (miembro.role == null) {
      idRol = 8;
    }

    String? md5Password = null;

    if (miembro.contrasena != null)
      md5Password = md5.convert(utf8.encode(miembro.contrasena!)).toString();

    final response = await http.post(
      url,
      body: jsonEncode({
        'Nombres': miembro.names,
        'Apellidos': miembro.lastnames,
        'FechaNacimiento': miembro.fechaNacimiento?.toIso8601String(),
        'FechaCreacion': miembro.fechaCreacion?.toIso8601String(),
        'Carnet': miembro.carnet,
        'Telefono': miembro.telefono,
        'IdRol': idRol,
        'Latitud': miembro.latitud,
        'Longitud': miembro.longitud,
        'Correo': miembro.correo,
        'Password': md5Password,
        'Status': miembro.status,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200 || response.statusCode == 400) {
      return 1;
    } else {
      return 0;
    }
  }

  _facebookLogin() async {
    Member? facebookUser;
    // Create an instance of FacebookLogin
    final fb = FacebookLogin();
    // Log in
    final res = await fb.logIn(permissions: [
      FacebookPermission.publicProfile, // Permiso para perfil

      FacebookPermission.email, // Permiso para tener el correo electrónico
    ]);
    // Check result status

    switch (res.status) {
      case FacebookLoginStatus.success:
        // Logged in
        // Send access token to server for validation and auth
        final FacebookAccessToken? accessToken =
            res.accessToken; // Obtener el token
        // Get profile data
        final profile = await fb.getUserProfile();
        // Get user profile image URL
        final imageUrl =
            await fb.getProfileImageUrl(width: 100); // Obtener la imagen

        print('Access token: ${accessToken?.token}');
        print('Hello, ${profile?.name}! You ID: ${profile?.userId}');
        print('Your profile image: $imageUrl');

        // Get email (since we request email permission)
        final email = await fb.getUserEmail();
        // Verificar si el correo de Facebook ya está registrado
        final existingMember = await checkemailexist(email!);

        if (existingMember != null) {
          miembroActual = existingMember;
          await saveMemberIdToCache(miembroActual!.id);
          insertToken();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ViewClient(userId: existingMember.id),
            ),
          );
        } else {
          // El usuario de Facebook no está registrado, regístralo

          final newMember =
              Member(names: "", lastnames: "",id: 0, correo: "", latitud: 0.1, longitud: 0.1);

          newMember.correo = email;
          newMember.fechaCreacion = DateTime.now();
          newMember.status = 1;
          newMember.role = null;
          newMember.names = profile!.firstName!;
          newMember.lastnames = profile.lastName!;
          newMember.role = "Cliente";
          // Agrega otros campos necesarios aquí

          final registrationResult = await registerUser2(newMember);

          if (registrationResult == 1) {
            miembroActual = (await checkemailexist(newMember.correo))!;
            await saveMemberIdToCache(miembroActual!.id);
            insertToken();
            // Registro exitoso, redirigir al usuario a la pantalla de menú

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ViewClient(userId: miembroActual!.id),
              ),
            );
          } else {
            // Error en el registro, manejar de acuerdo a tus necesidades
          }
        }
        break;

      case FacebookLoginStatus.cancel:
        // Usuario canceló el inicio de sesión
        break;

      case FacebookLoginStatus.error:
        // Error en el inicio de sesión
        print('Error while log in: ${res.error}');
        break;
    }
  }
}
