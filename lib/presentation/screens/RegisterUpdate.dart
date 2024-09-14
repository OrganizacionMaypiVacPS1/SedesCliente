import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttapp/Config/Config.dart';
import 'package:fluttapp/Models/Profile.dart';
import 'package:fluttapp/presentation/screens/Carnetizador/HomeCarnetizador.dart';
import 'package:fluttapp/presentation/screens/Cliente/HomeClient.dart';
import 'package:fluttapp/presentation/screens/SearchLocation.dart';
import 'package:fluttapp/presentation/services/alert.dart';
import 'package:fluttapp/presentation/services/services_firebase.dart';
import 'package:fluttapp/services/connectivity_service.dart';
import 'package:fluttapp/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart'; // Importa la librería crypto
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());
MostrarFinalizar mostrarFinalizar = MostrarFinalizar();
Member? carnetizadorglobal;
Mostrar_Finalizados_Update mostrarMensaje = Mostrar_Finalizados_Update();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RegisterUpdate(
        isUpdate: false,
        carnetizadorMember: null,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ignore: must_be_immutable
class RegisterUpdate extends StatefulWidget {
  final Member? userData;
  late final bool isUpdate;
  Member? carnetizadorMember;
  

  RegisterUpdate(
      {required this.isUpdate,
      this.userData,
      this.carnetizadorMember}) {
        carnetizadorglobal = carnetizadorMember;
  }
  @override
  _RegisterUpdateState createState() => _RegisterUpdateState();
}

class _RegisterUpdateState extends State<RegisterUpdate> {
  bool esCliente = false;
  final _formKey = GlobalKey<FormState>();
  String nombre = '';
  String apellido = '';
  var datebirthday;
  var dateCreation;
  String carnet = '';
  String telefono = '';
  String? selectedRole = 'Cliente';
  double latitude = 0;
  double longitude = 0;
  String email = '';
  String password = '';
  int status = 1;
  int? idRolSeleccionada;
  String nameJefe = "";
  int idJefe = 0;
  int idPerson = 0;
  Member? jefeDeCarnetizador;
  final ConnectivityService _connectivityService = ConnectivityService();
  GoogleMapController? _controller;
  bool isLoadingImage=true;
  File? imageLocal;
  String address="";
    String locationName = '';


  @override
  void initState() {
    super.initState();
    _connectivityService.initialize(context);
/*
    if(miembroActual!.id!=widget.userData?.id){
      image=null;
    }*/
    
    if (widget.userData?.id != null) {
      Cargar_Datos_Persona();
      if(image==null||miembroActual!.id!=widget.userData?.id){
        addImageToSelectedImages(widget.userData!.id);
      }else{
        imageLocal = image;
        isLoadingImage=false;
      }
    }else{
      isLoadingImage=false;
    }
    if (widget.userData?.role == "Cliente") {
      esCliente = true;
    } else if (widget.userData?.role == "Carnetizador") {
      esCliente = false;
    }else{
      esCliente = false;
    }
  }

  Future<void> addImageToSelectedImages(int idPerson) async {
  try {
    String imageUrl = await getImageUrl(idPerson);
    File tempImage = await _downloadImage(imageUrl);
    
    setState(() {
      imageLocal = tempImage;
      isLoadingImage=false;
    });
  } catch (e) {
    print('Error al obtener y descargar la imagen: $e');
    setState(() {
      isLoadingImage=false;
    });
  }
}

Future<String> getImageUrl(int idPerson) async {
  try {
    Reference storageRef = FirebaseStorage.instance.ref('cliente/$idPerson/imagenUsuario.jpg');
    return await storageRef.getDownloadURL();
  } catch (e) {
    print('Error al obtener URL de la imagen: $e');
    throw e;
  }
}

Future<File> _downloadImage(String imageUrl) async {
  final response = await http.get(Uri.parse(imageUrl));

  if (response.statusCode == 200) {
    final bytes = response.bodyBytes;
    final tempDir = await getTemporaryDirectory();
    final tempImageFile = File('${tempDir.path}/${DateTime.now().toIso8601String()}.jpg');
    await tempImageFile.writeAsBytes(bytes);
    return tempImageFile;
  } else {
    throw Exception('Error al descargar imagen');
  }
}


  @override
  void dispose() {
    _connectivityService.dispose();
    imageLocal = null;
    super.dispose();
  }

  void Cargar_Datos_Persona() async {
    idPerson = widget.userData!.id;

    nombre = widget.userData!.names;
    apellido = widget.userData!.lastnames!;
    datebirthday = widget.userData?.fechaNacimiento;
    dateCreation = widget.userData?.fechaCreacion;
    carnet = widget.userData!.carnet!;
    telefono = widget.userData!.telefono.toString();
    selectedRole = widget.userData!.role;

    latitude = widget.userData!.latitud;
    longitude = widget.userData!.longitud;
    email = widget.userData!.correo;

    setState(() {});
  }

  Future<void> registerUser() async {
    final url = Uri.parse('${Config.baseUrl}/register');
    if (selectedRole == 'Carnetizador') {
      idRolSeleccionada = 7;
    } else if (selectedRole == 'Administrador') {
      idRolSeleccionada = 5;
    }else if(selectedRole=='Super Admin'){
      idRolSeleccionada = 9;
    }
    else if(selectedRole=='Jefe de Brigada'){
      idRolSeleccionada = 6;
    }
    else {
      idRolSeleccionada = 8;
    }
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
        'Password': md5Password,
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

  Future<void> updateUser() async {
    final url = Uri.parse(
        '${Config.baseUrl}/update/' + idPerson.toString()); //
    if (selectedRole == 'Carnetizador') {
      idRolSeleccionada = 7;
    } else if (selectedRole == 'Administrador') {
      idRolSeleccionada = 5;
    }else if(selectedRole=='Super Admin'){
      idRolSeleccionada = 9;
    }
    else if(selectedRole=='Jefe de Brigada'){
      idRolSeleccionada = 6;
    }
    else {
      idRolSeleccionada = 8;
    }
    // Calcula el hash MD5 de la contraseña
    final response = await http.put(
      url,
      body: jsonEncode({
        'id': idPerson,
        'Nombres': nombre,
        'Apellidos': apellido,
        'FechaNacimiento': datebirthday.toIso8601String(),
        'Carnet': carnet,
        'Telefono': telefono,
        'IdRol': idRolSeleccionada,
        'Latitud': latitude,
        'Longitud': longitude,
        'Correo': email,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Registro exitoso
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el usuario')),
      );
    }
    miembroActual!.id == idPerson;

    if (miembroActual!.id == idPerson) {
      miembroActual!.names = nombre;
      miembroActual!.lastnames = apellido;
      miembroActual!.fechaNacimiento = datebirthday;
      miembroActual!.carnet = carnet;
      miembroActual!.telefono = int.parse(telefono);
      miembroActual!.role = selectedRole;
      miembroActual!.latitud = latitude;
      miembroActual!.longitud = longitude;
      miembroActual!.correo = email;
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
        imageLocal = File(pickedImage.path);
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
      if(widget.isUpdate==false){
        userId = await getNextIdPerson();
      }
      
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();
      print("Ultimo ID =======" + "---" + idPerson.toString());
      String carpeta = 'cliente/$userId';

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

  Future<bool> deleteImage(int userId) async {
    try {
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();
      print("ID ------------" + userId.toString());
      String carpeta = 'cliente/$userId/imagenUsuario.jpg';

      await storageRef.child(carpeta).delete();

      return true;
    } catch (e) {
      print('Error al eliminar imagen de mascota: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isUpdate
        ? 'Actualizar Usuario'
        : 'Registrar Usuario'; // Título dinámico
    File? selectedImage;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: Colors.black)),
        backgroundColor: Color.fromARGB(255, 241, 245, 255),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: isConnected.value? Stack(children: [
        Container(
          color: Colors.white,
          /*decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/Splash.png'),
              fit: BoxFit.cover,
            ),
          ),*/
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
                      imageLocal != null ?InkWell(
                        onTap: () {
                          showPicker(context, (File file) {
                            setState(() {
                              imageLocal = file;
                            });
                          });
                        },
                        child: CircleAvatar(
                          backgroundImage: FileImage(imageLocal!),
                          radius: 100,
                          child: null,
                        ),
                      ): InkWell(
                        onTap: () {
                          showPicker(context, (File file) {
                            setState(() {
                              imageLocal = file;
                            });
                          });
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage: null,
                              radius: 100,
                              child: isLoadingImage ? null : Icon(Icons.camera_alt, size: 50.0),
                            ),
                            if (isLoadingImage)
                              Positioned.fill(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 60, 
                                    height: 60, 
                                    child: SpinKitCircle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
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
                  maxLength: 100,
                  icon: Icons.person,
                ),
                _buildTextField(
                  initialData: apellido,
                  label: 'Apellidos',
                  onChanged: (value) => apellido = value,
                  validator: (value) =>
                      value!.isEmpty ? 'El nombre no puede estar vacío.' : null,
                  maxLength: 45,
                  icon: Icons.person,
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.date_range, // Cambia esto al icono que prefieras
                      color: Color.fromARGB(255, 92, 142, 203),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Fecha Nacimiento",
                      style: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                    ),
                  ],
                ),
                _buildDateOfBirthField(
                  label: 'Fecha Nacimiento',
                  onChanged: (value) => datebirthday = value,
                ),
                _buildTextField(
                  initialData: carnet,
                  label: 'Carnet',
                  onChanged: (value) => carnet = value,
                  validator: (value) =>
                      value!.isEmpty ? 'El carnet no puede estar vacío.' : null,
                  maxLength: 45,
                  icon: Icons.badge
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
                  icon: Icons.call,
                ),
                Row(
                children: [
                  Icon(
                    Icons.location_on, // Cambia esto al icono que prefieras
                    color: Color.fromARGB(255, 92, 142, 203),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Dirección",
                    style: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                  ),
                ],
              ),
                _buildMap(latitude, longitude),
                SizedBox(height: 10),
                ElevatedButton(
                  style: ButtonStyle(
                    minimumSize: MaterialStateProperty.all(
                        Size(double.infinity, 55)), // Adjust the height as needed
                    backgroundColor:
                        MaterialStateProperty.all(Colors.white), // Fondo blanco
                    elevation: MaterialStateProperty.all(0), // Sin sombra
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10), // Borde redondeado
                        side: BorderSide(
                          color: Color.fromARGB(
                              255, 92, 142, 203), // Color del borde
                          width: 2.0, // Ancho del borde
                        ),
                      ),
                    ),
                  ),
                  child: Text("Selecciona una ubicación", style: TextStyle(color: Colors.black),),
                  onPressed: () async {
                    await Permisos();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPicker(),
                      ),
                    );
                    if (result != null) {
                      
                    address = await getAddressFromLatLng(
                      result.latitude,
                      result.longitude,
                      'AIzaSyBaqF8pGcAaGUm7oE3KbHWsjUfBdCEBujM',
                    );
                    setState(() {
                      latitude = result.latitude;
                      longitude = result.longitude;
                      locationName = address;
                    });
                      _controller!.animateCamera(
                          CameraUpdate.newLatLng(LatLng(latitude, longitude))
                      );
                    }
                  },
                  
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    locationName,
                    style: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
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
                  icon: Icons.mail,
                ),
                widget.isUpdate
                    ? Container()
                    : _buildTextField(
                        initialData: "",
                        label: 'Contraseña',
                        onChanged: (value) => password = value,
                        obscureText: true,
                        maxLength: 10,
                        icon: Icons.password
                      ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    dateCreation = new DateTime.now();
                    status = 1;

                    if (esCliente == false) {
                      if (_formKey.currentState!.validate() &&
                          latitude != '' &&
                          selectedRole != '' &&
                          datebirthday != null) {
                        if (widget.isUpdate) {
                          await showLoadingDialog(context, () async {
                            await updateUser();
                            //deleteImage(idPerson);
                            if(miembroActual!.id==idPerson){image = imageLocal;}
                            await uploadImage(imageLocal, idPerson);
                          });

                          showSnackbar(context, "Actualización con éxito");
                          Navigator.pop(context, 1);
                          
                          /*mostrarMensaje.Mostrar_Finalizados_Carnetizadores(
                              context,
                              "Actualización con éxito de Carnetizador",
                              miembroActual!.id);*/
                        } else{
                          await showLoadingDialog(context, () async {
                            await registerUser();
                            if(miembroActual!.id==idPerson){image = imageLocal;}
                            await uploadImage(imageLocal, idPerson);
                          });
                          showSnackbar(context, "Registro Exitoso");
                          Navigator.pop(context, 1);

                          //mostrarMensaje.Mostrar_Finalizados_Carnetizadores(context, 'Registro Exitoso',miembroActual!.id);
                        }
                      }else if (password != "") {

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
                        }else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ingrese todos los campos')),
                        );
                      }
                    } else if (esCliente == true) {
                      if (_formKey.currentState!.validate() &&
                          latitude != '' &&
                          selectedRole != '' &&
                          datebirthday != null) {
                        if (widget.isUpdate) {
                          await showLoadingDialog(context, () async {
                            await updateUser();
                            //deleteImage(idPerson);
                            if(miembroActual!.id==idPerson){image = imageLocal;}
                            await uploadImage(imageLocal, idPerson);
                          });

                          if (widget.carnetizadorMember?.role == 'Carnetizador') {
                            showSnackbar(context, "Actualización con éxito de Cliente con Carnetizador");
                            /*mostrarMensaje.Mostrar_Finalizados_Carnetizadores(
                                context,
                                "Actualización con éxito de Cliente con Carnetizador",
                                miembroActual!.id);*/
                          } else {
                            showSnackbar(context, "Actualización con éxito de Cliente");
                            /*mostrarMensaje.Mostrar_Finalizados_Clientes(
                                context,
                                "Actualización con éxito de Cliente",
                                widget.userData!.id);*/
                          }
                          Navigator.pop(context, 1);
                        } else{
                          
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ingrese todos los campos')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    backgroundColor: Colors.green,
                  ),
                  child: Text(
                      widget.isUpdate ? 'Actualizar' : 'Registrar Usuario'),
                  
                ),
              ],
            ),
          ),
        )
      ]): Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Splash.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(child: Text('Error: Connection failed'))),
    );
  }

  Widget _buildMap(double lat, double lng) {
    return Container(
      height: 150,
      width: double.infinity,
      child: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _controller = controller;
        },
        initialCameraPosition: CameraPosition(
          target: LatLng(lat, lng),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: MarkerId('memberLocation'),
            position: LatLng(lat, lng),
          ),
        },
      ),
    );
  }

  Widget _buildDateOfBirthField({
    required String label,
    required Function(DateTime?) onChanged,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white, // Fondo blanco
            borderRadius: BorderRadius.circular(10), // Borde redondeado
            border: Border.all(
              color: Color.fromARGB(255, 92, 142, 203), // Color del borde
              width: 2.0, // Ancho del borde
            ),
          ),
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
              style: TextStyle(
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, // Fondo transparente
              elevation: 0, // Sin sombra
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
    IconData? icon, 
    required int maxLength,
  }) {
    return Column(
      children: [
        Row(
          children: [
            if (icon != null)
              // Verifica si se proporcionó un icono
              Padding(
                padding: const EdgeInsets.all(
                    0), // Ajusta el espacio según sea necesario
                child: Icon(
                  icon,
                  color: Color.fromARGB(255, 92, 142,
                      203), // Establece el color del icono como blanco
                ),
              ),
            Expanded(
              child: TextFormField(
                initialValue: initialData,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle:
                      TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                ),
                onChanged: onChanged,
                validator: validator,
                keyboardType: keyboardType,
                obscureText: obscureText,
                maxLength: maxLength,
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
      ],
    );
  }
}
