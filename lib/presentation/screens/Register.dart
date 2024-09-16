import 'dart:io';
import 'dart:typed_data';

import 'package:fluttapp/Config/Config.dart';
import 'package:fluttapp/Models/Profile.dart';
import 'package:fluttapp/presentation/screens/SearchLocation.dart';
import 'package:fluttapp/presentation/services/alert.dart';
import 'package:fluttapp/presentation/services/services_firebase.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart'; // Importa la librería crypto
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image/image.dart' as img;

void main() => runApp(MyApp());
MostrarFinalizarLogin mostrarFinalizar = MostrarFinalizarLogin();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Register(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Register extends StatefulWidget {
  @override
  _RegisterUpdateState createState() => _RegisterUpdateState();
}

class _RegisterUpdateState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  String nombre = '';
  String apellido = '';
  var datebirthday;
  var dateCreation;
  String carnet = '';
  String telefono = '';
  String? selectedRole = 'Cliente';
  String latitude = '';
  String longitude = '';
  String email = '';
  String password = '';
  int status = 1;
  int? idRolSeleccionada;
  String nameJefe = "";
  int idJefe = 0;
  int idPerson = 0;
  Member? jefeDeCarnetizador;

  void initState() {
    super.initState();
  }

  Future<bool> checkEmailExist(String email) async {
    final url = Uri.parse('${Config.baseUrl}/checkemail/$email');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return true; // El correo existe en la base de datos
    } else if (response.statusCode == 404) {
      return false; // El correo no existe en la base de datos
    } else {
      throw Exception('Error al checkear el email la contraseña');
    }
  }

  Future<void> registerUser() async {
    final url = Uri.parse('${Config.baseUrl}/register');
    if (selectedRole == 'Carnetizador') {
      idRolSeleccionada = RoleMember.carnetizador;
    } else if (selectedRole == 'Cliente') {
      idRolSeleccionada = RoleMember.cliente;
    }else if(selectedRole=='Super Admin'){
      idRolSeleccionada = RoleMember.superAdmin;
    }
    else if(selectedRole=='Jefe de Brigada'){
      idRolSeleccionada = RoleMember.jefeBrigada;
    }
    else {
      idRolSeleccionada = RoleMember.admin;
    }

    // Calcula el hash MD5 de la contraseña
    String md5Password = md5.convert(utf8.encode(password)).toString();

    final response = await http.post(
      url,
      body: jsonEncode({
        'Nombres': nombre,
        'Apellidos': apellido,
        'FechaNacimiento': datebirthday.toIso8601String(),
        'FechaCreacion': dateCreation.toIso8601String(),
        'Carnet': carnet,
        'Telefono': telefono,
        'IdRol': idRolSeleccionada,
        'Latitud': latitude,
        'Longitud': longitude,
        'Correo': email,
        'Password': md5Password, // Envía la contraseña en formato MD5
        'Status': status,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Registro exitoso
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar el usuario')),
      );
    }
  }

  Future<void> Permisos() async {
    LocationPermission permiso;
    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        return Future.error('Error');
      }
    }
  }

  File? _image;

Future<void> _getImageFromGallery() async {
  final picker = ImagePicker();
  final pickedImage = await picker.pickImage(source: ImageSource.gallery);

  if (pickedImage != null) {
    File imageFile = File(pickedImage.path);

    img.Image? image = img.decodeImage(imageFile.readAsBytesSync());

    if (image != null) {
      image = img.bakeOrientation(image);
      await imageFile.writeAsBytes(img.encodeJpg(image));
    }

    setState(() {
      if (image != null) {
        _image = File(pickedImage.path);
      }
    });
  }
}

  Future<List<int>> compressImage(File imageFile) async {
    // Leer la imagen
    List<int> imageBytes = await imageFile.readAsBytes();

    // Decodificar la imagen
    img.Image image = img.decodeImage(Uint8List.fromList(imageBytes))!;

    // Comprimir la imagen con una calidad específica (85 en este caso)
    List<int> compressedBytes = img.encodeJpg(image, quality: 85);

    return compressedBytes;
  }

  Future<bool> uploadImage(File? image, int userId) async {
    try {
      int idPerson = await getNextIdPerson();
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();
      print("Ultimo ID =======" + "---" + idPerson.toString());
      String carpeta = 'cliente/$idPerson';

      if (image != null) {
        firebase_storage.Reference imageRef =
            storageRef.child('$carpeta/imagenUsuario.jpg');

        // Comprimir la imagen antes de subirla
        List<int> compressedBytes = await compressImage(image);

        await imageRef.putData(Uint8List.fromList(compressedBytes));
      }

      return true;
    } catch (e) {
      print('Error al subir la imagen: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Registrar Usuario'; // Título dinámico
    File? selectedImage;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/Splash.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: (){
                          showPicker(context, (File file) {
                            setState(() {
                              _image = file;
                            });
                          });
                        },
                        child: _image == null
                            ? Text('Seleccionar Imagen')
                            : Image.file(_image!,
                                height: 100, width: 100, fit: BoxFit.cover),
                      ),
                      SizedBox(height: 20),
                      selectedImage != null
                          ? Image.file(
                              selectedImage!,
                              height: 200,
                              width: 200,
                            )
                          : Container(),
                    ],
                  ),
                ),
                _buildTextField(
                  initialData: nombre,
                  label: 'Nombres',
                  onChanged: (value) => nombre = value,
                  validator: (value) =>
                      value!.isEmpty ? 'El nombre no puede estar vacío.' : null,
                  maxLength: 100, // Establece el máximo de caracteres a 100
                ),
                _buildTextField(
                  initialData: apellido,
                  label: 'Apellidos',
                  onChanged: (value) => apellido = value,
                  validator: (value) =>
                      value!.isEmpty ? 'El nombre no puede estar vacío.' : null,
                  maxLength: 45,
                ),
                SizedBox(height: 10),
                Text("Fecha Nacimiento:",
                    style: TextStyle(color: Colors.white)),
                _buildDateOfBirthField(
                  label: 'Seleccionar Fecha Nacimiento',
                  onChanged: (value) => datebirthday = value,
                  validator: (value) => value!.isEmpty
                      ? 'La fecha de nacimiento no debe estar vacio'
                      : null,
                ),
                _buildTextField(
                  initialData: carnet,
                  label: 'Carnet',
                  onChanged: (value) => carnet = value,
                  validator: (value) =>
                      value!.isEmpty ? 'El carnet no puede estar vacío.' : null,
                  maxLength: 45,
                ),
                _buildTextField(
                  initialData: telefono,
                  label: 'Teléfono',
                  onChanged: (value) => telefono = value,
                  validator: (value) => value!.isEmpty
                      ? 'El Teléfono no puede estar vacía.'
                      : null,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                ),
                Text("Dirección:", style: TextStyle(color: Colors.white)),
                ElevatedButton(
                  child: Text("Selecciona una ubicación"),
                  onPressed: () async {
                    await Permisos();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPicker(),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        latitude = result.latitude.toString();
                        longitude = result.longitude.toString();
                      });
                    }
                  },
                  
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    latitude + " " + longitude,
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                _buildTextField(
                  initialData: email,
                  label: 'Email',
                  onChanged: (value) => email = value,
                  validator: (value) =>
                      value!.isEmpty ? 'El email no puede estar vacío.' : null,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 45,
                ),
                _buildTextField(
                  initialData: "",
                  label: 'Contraseña',
                  onChanged: (value) => password = value,
                  obscureText: true,
                  maxLength: 10,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    dateCreation = DateTime.now();
                    status = 1;

                    if (_formKey.currentState!.validate() &&
                        latitude != '' &&
                        datebirthday != null) {
                      if (password != "") {
                        bool emailExists = await checkEmailExist(email);
                        if (emailExists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'El correo ya existe en la base de datos'),
                            ),
                          );
                        } else {
                          await showLoadingDialog(context, () async {
                             await registerUser();
                            idPerson = await getNextIdPerson();
                            print("ultimo id ======" + idPerson.toString());
                            uploadImage(_image, idPerson);   
                          });

                          showSnackbar(context, "Registro con éxito!");
                          Navigator.pop(context);


                          /*mostrarFinalizar.Mostrar_FinalizadosLogin(
                              context, "Registro con éxito!");*/
                        }
                      }

                      // Verificar si el número de teléfono empieza con 7 o 8
                      RegExp regex = RegExp(r'^[7-8]');
                      if (!regex.hasMatch(telefono)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'El número de teléfono debe empezar con 7 u 8'),
                          ),
                        );
                        return;
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ingrese todos los campos'),
                        ),
                      );
                    }
                  },
                  child: Text('Registrar Usuario'),
                  
                )
              ],
            ),
          ),
        )
      ]),
    );
  }

  Widget _buildDateOfBirthField({
    required String label,
    required Function(DateTime?) onChanged,
    required String? Function(dynamic value) validator,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              datebirthday = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );

              if (datebirthday != null) {
                onChanged(datebirthday);
                setState(() {});
              }
            },
            child: Text(
              datebirthday != null
                  ? "${datebirthday.day}/${datebirthday.month}/${datebirthday.year}"
                  : label,
              style: TextStyle(color: Colors.white),
            ),
            
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget _buildTextField({
    required String initialData,
    required String label,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    required int maxLength,
  }) {
    return Column(
      children: [
        TextFormField(
          initialValue: initialData,
          style: TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.black),
          ),
          onChanged: onChanged,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
        ),
        SizedBox(height: 15),
      ],
    );
  }
}
