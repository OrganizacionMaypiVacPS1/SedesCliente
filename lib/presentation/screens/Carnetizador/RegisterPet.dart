import 'dart:convert';
import 'dart:io';
import 'package:fluttapp/Config/Config.dart';
import 'package:fluttapp/presentation/littlescreens/validator.dart';
import 'package:fluttapp/presentation/screens/Carnetizador/ListMascotas.dart';
import 'package:fluttapp/presentation/screens/Cliente/HomeClient.dart';
import 'package:fluttapp/presentation/services/alert.dart';
import 'package:fluttapp/presentation/services/services_firebase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

int? idUser;

class RegisterPet extends StatefulWidget {
  late final int userId;
  RegisterPet({required this.userId}) {
    idUser = this.userId;
    print('ID de usuario en Buscar Clientes: $idUser');
  }

  @override
  _RegisterPetState createState() => _RegisterPetState();
}
class LettersOnlyTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final String newText = newValue.text.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

enum Castrado { si, no }
enum Especie { P, G }
enum Sexo { M, H }
class _RegisterPetState extends State<RegisterPet> {
  ValidadorCamposMascota validador = ValidadorCamposMascota();
  TextEditingController nombreController = TextEditingController();
  TextEditingController edadController = TextEditingController();
  TextEditingController descripcionController = TextEditingController();
  TextEditingController razaController = TextEditingController();
  TextEditingController colorController = TextEditingController();
  TextEditingController fechaUltimaVacunaController = TextEditingController();
  File? _fotoCarnetVacunacion;
  String? mensajeError;
  List<File?> _selectedImages = [];
  Mostrar_Finalizados_Update mostrarFinalizar = Mostrar_Finalizados_Update();
  Castrado? _castrado = Castrado.no;
  Castrado? _vacunado = Castrado.no;
  Especie? _especie = Especie.P;
  Sexo? _sexo = Sexo.M;
  DateTime fechaSeleccionada=DateTime.now();
  @override
  void initState() {
    super.initState();
    getPersonData();
    print("Estan llegando los datos del chico");
    print(miembroMascota!.names);
  }

  Future<void> _selectDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: fechaSeleccionada, 
    firstDate: DateTime(2000), 
    lastDate: DateTime.now(), 
  );
  if (picked != null && picked != fechaSeleccionada)
    setState(() {
      fechaSeleccionada = picked;
      fechaUltimaVacunaController.text = DateFormat('yyyy-MM-dd').format(picked); 
    });
}


  Future<void> getPersonData() async {
    miembroMascota = await getPersonById(idUsuario!);
  }

  Future<void> Confirmacion_Eliminar_Imagen(int index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Eliminar Imagen'),
          content: Text('¿Estás seguro de que deseas eliminar esta imagen?'),
          actions: <Widget>[
            TextButton(
              child: Text('Sí'),
              onPressed: () {
                setState(() {
                  _selectedImages.removeAt(index);
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

  Future<void> registerQr(int id) async {
    final url = Uri.parse('${Config.baseUrl}/registerqr');

    final response = await http.post(
      url,
      body: jsonEncode({
        'id': id.toString(),
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Registro exitoso
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar el qr')),
      );
    }
  }

  Future<bool> uploadImages(List<File?> images) async {
    try {
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();
      int ultimoId = await fetchLastPetId();
      String carpeta = 'cliente/${widget.userId}/$ultimoId';

      await registerQr(ultimoId);

      int contador = 1;

      for (var image in images) {
        if (image != null) {
          String imageName = '$contador';

          firebase_storage.Reference imageRef =
              storageRef.child('$carpeta/$imageName.jpg');

          // Comprimir la imagen antes de subirla
          List<int> compressedBytes = await compressImage(image);

          await imageRef.putData(Uint8List.fromList(compressedBytes));

          contador++;
        }
      }

      return true;
    } catch (e) {
      print('Error al subir imágenes: $e');
      return false;
    }
  }

  Future<bool> uploadLastDateVaccine(File? image) async {
    try {
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();
      int ultimoId = await fetchLastPetId();
      String carpeta = 'cliente/${widget.userId}/$ultimoId';

      //await registerQr(ultimoId);
      if (image != null) {
        String imageName = 'lastdate';

        firebase_storage.Reference imageRef =
            storageRef.child('$carpeta/$imageName.jpg');

        List<int> compressedBytes = await compressImage(image);

        await imageRef.putData(Uint8List.fromList(compressedBytes));
      }

      return true;
    } catch (e) {
      print('Error al subir imágenes: $e');
      return false;
    }
  }

  Future<int> fetchLastPetId() async {
    final response =
        await http.get(Uri.parse('${Config.baseUrl}/lastidmascota'));

    final dynamic data = json.decode(response.body);
    return data['ultimo_id'] as int;
  }

  Future<void> registerPet() async {
    int isCastrado=0;
    int isVacunado=0;
    String especie = 'P';
    String sexo = 'H';
    if(_sexo==Sexo.M){
      sexo='M';
    }
    if(_especie==Especie.G){
      especie='G';
    }
    if(_castrado==Castrado.si){
      isCastrado = 1;
    }
    if(_vacunado==Castrado.si){
      isVacunado = 1;
    }
    final url = Uri.parse('${Config.baseUrl}/registerPet');

    final response = await http.post(
      url,
      body: jsonEncode({
        'Nombre': nombreController.text,
        'Raza': razaController.text,
        'Edad': edadController.text,
        'Color': colorController.text,
        'Descripcion': descripcionController.text,
        'IdPersona': '${widget.userId}',
        'Sexo': sexo,
        'Especie': especie,
        'Castrado':isCastrado,
        'Vacunado':isVacunado,
        'FechaUltimaVacuna': fechaUltimaVacunaController.text==''?null: fechaUltimaVacunaController.text,
        //Foto Carnet Vacunacion
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Registro exitoso
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar la mascota')),
      );
    }
  }
  String valorSeleccionado = 'H'; // Valor por defecto seleccionado

  List<String> opciones = ['Hembra', 'Macho']; // Lista de opciones
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back),
            color: Colors.black,
            onPressed: () => Navigator.pop(context),
          ),
        backgroundColor: Color.fromARGB(255, 241, 245, 255),
        title: Text('Registro Mascota',
            style: TextStyle(color: const Color.fromARGB(255, 70, 65, 65))),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        /*
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Splash.png'),
            fit: BoxFit.cover,
          ),
        ),*/
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Image.asset(
                "assets/Univallenavbar.png",
              ),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  style: TextStyle(color: Colors.black), 
                  decoration: InputDecoration(
                    icon: Icon(Icons.pets, color: Color.fromARGB(255, 92, 142, 203)),
                    labelText: 'Nombre de la Mascota',
                    errorText: validador.mensajeErrorNombreMascota,
                    labelStyle: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                  ),
                  controller: nombreController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(30),
                    LettersOnlyTextFormatter(),
                  ],
                  maxLength: 30,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child:TextFormField(
                  style: TextStyle(color: Colors.black),
                  controller: descripcionController,
                  decoration: InputDecoration(
                    icon: Icon(Icons.description, color: Color.fromARGB(255, 92, 142, 203)),
                    labelText: 'Descripción de la Mascota',
                    errorText: validador.mensajeErrorDescripcionMascota,
                    labelStyle: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  maxLength: 200,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  style: TextStyle(color: Colors.black),
                  controller: edadController,
                  maxLength: 2,
                  decoration: InputDecoration(
                    icon: Icon(Icons.cake, color: Color.fromARGB(255, 92, 142, 203)),
                    labelText: 'Edad de la Mascota',
                    errorText: validador.mensajeErrorEdadMascota,
                    labelStyle: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),

            ListTile(
              leading: Icon(Icons.pets, color: Color.fromARGB(255, 92, 142, 203)),
              title: const Text('Especie'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<Especie>(
                    value: Especie.P,
                    groupValue: _especie,
                    onChanged: (Especie? value) {
                      setState(() { _especie = value; });
                    },
                  ),
                  Text('Perro'),
                  Radio<Especie>(
                    value: Especie.G,
                    groupValue: _especie,
                    onChanged: (Especie? value) {
                      setState(() { _especie = value; });
                    },
                  ),
                  Text('Gato'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                style: TextStyle(color: Colors.black),
                controller: razaController,
                decoration: InputDecoration(
                  icon: Icon(Icons.pets, color: Color.fromARGB(255, 92, 142, 203),),
                  labelText: 'Raza de la Mascota',
                  errorText: validador.mensajeErrorRazaMascota,
                  labelStyle: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                  LettersOnlyTextFormatter(),
                ],
                maxLength: 30,
              ),
            ),
            
            ListTile(
              leading: Icon(Icons.people, color: Color.fromARGB(255, 92, 142, 203)),
              title: const Text('Sexo'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<Sexo>(
                    value: Sexo.M,
                    groupValue: _sexo,
                    onChanged: (Sexo? value) {
                      setState(() { _sexo = value; });
                    },
                  ),
                  Text('Macho'),
                  Radio<Sexo>(
                    value: Sexo.H,
                    groupValue: _sexo,
                    onChanged: (Sexo? value) {
                      setState(() { _sexo = value; });
                    },
                  ),
                  Text('Hembra'),
                ],
              ),
            ),
            /*Row(
              children: [
                Icon(Icons.people, color: Color.fromARGB(255, 92, 142, 203)),
                SizedBox(width: 10), 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sexo', style: TextStyle(color: Color.fromARGB(255, 92, 142, 203))),
                    DropdownButton<String>(
                      value: valorSeleccionado,
                      onChanged: (String? newValue) {
                        setState(() {
                          valorSeleccionado = newValue!;
                        });
                      },
                      items: opciones
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value == 'Hembra' ? 'H' : 'M',
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),*/
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              style: TextStyle(color: Colors.black),
              controller: colorController,
              decoration: InputDecoration(
                icon: Icon(Icons.color_lens, color: Color.fromARGB(255, 92, 142, 203)),
                labelText: 'Color del Animal',
                errorText: validador.mensajeErrorColorMascota,
                labelStyle: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(30),
                LettersOnlyTextFormatter(),
              ],
              maxLength: 30,
            ),),
            
            ListTile(
              leading: Icon(Icons.cut, color: Color.fromARGB(255, 92, 142, 203)),
              title: const Text('Castrado'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<Castrado>(
                    value: Castrado.si,
                    groupValue: _castrado,
                    onChanged: (Castrado? value) {
                      setState(() { _castrado = value; });
                    },
                  ),
                  Text('Sí'),
                  Radio<Castrado>(
                    value: Castrado.no,
                    groupValue: _castrado,
                    onChanged: (Castrado? value) {
                      setState(() { _castrado = value; });
                    },
                  ),
                  Text('No'),
                ],
              ),
            ),
                        ListTile(
              leading: Icon(Icons.vaccines, color: Color.fromARGB(255, 92, 142, 203)),
              title: const Text('Con Vacuna'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<Castrado>(
                    value: Castrado.si,
                    groupValue: _vacunado,
                    onChanged: (Castrado? value) {
                      setState(() { _vacunado = value; });
                    },
                  ),
                  Text('Sí'),
                  Radio<Castrado>(
                    value: Castrado.no,
                    groupValue: _vacunado,
                    onChanged: (Castrado? value) {
                      setState(() { _vacunado = value; });
                    },
                  ),
                  Text('No'),
                ],
              ),
            ),
            
            if(_vacunado==Castrado.si)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () => _selectDate(context), 
                child: AbsorbPointer( 
                  child: TextField(
                    controller: fechaUltimaVacunaController,
                    decoration: InputDecoration(
                      icon: Icon(Icons.calendar_today, color: Color.fromARGB(255, 92, 142, 203)),
                      labelText: 'Fecha de última vacuna',
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.camera_alt, color: Color.fromARGB(255, 92, 142, 203)),
                    onPressed: () {
                      showPicker(context, (File file) {
                        setState(() {
                          _fotoCarnetVacunacion = file;
                        });
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Foto del carnet de vacunación',
                      style: TextStyle(color: Color.fromARGB(255, 92, 142, 203)),
                    ),
                  ),
                  
                  
                ],
              ),
            ),
            _fotoCarnetVacunacion != null
                  ? Container(
                      child: Image.file(
                        _fotoCarnetVacunacion!,
                        //width: 100, 
                        //height: 200, 
                        fit: BoxFit.cover, 
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color.fromARGB(255, 92, 142, 203)), 
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  : Container(), 
              SizedBox(height: 10),
              ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (_selectedImages.length < 3) {
                    final picker = ImagePicker();
                    final List<XFile>? pickedFiles =
                        await picker.pickMultiImage();

                    if (pickedFiles != null && pickedFiles.isNotEmpty) {
                      int availableSlots = 3 - _selectedImages.length;
                      List<File> newImages = pickedFiles
                          .take(availableSlots)
                          .map((file) => File(file.path))
                          .toList();

                      setState(() {
                        _selectedImages.addAll(newImages);
                      });

                      if (pickedFiles.length > availableSlots) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Se ha alcanzado el límite de 3 imágenes.'),
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Se ha alcanzado el límite de 3 imágenes.'),
                    ));
                  }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    backgroundColor: Color(0xFF5C8ECB),
                  ),
                  child: Text('Cargar Fotos de la Mascota'),
                ),
              SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _selectedImages.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final File? image = entry.value;
                    return GestureDetector(
                      onTap: () {
                        Confirmacion_Eliminar_Imagen(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: image != null
                            ? Image.file(
                                image,
                                width: 100,
                                height: 100,
                              )
                            : SizedBox(),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        /*setState(() {
                          isLoading =
                              true; // Comienza la carga al presionar el botón
                        });*/

                      bool camposValidos = validarCampos();

                      if (_selectedImages.length < 1) {
                        /*setState(() {
                          isLoading = false; // Detén la carga si hay un error
                        });*/
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Debe cargar al menos 1 imagen.'),
                        ));
                        return; 
                      }

                      if(_vacunado==Castrado.si&&fechaUltimaVacunaController.text==''){
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Debe Seleccionar la última fecha de vacuna'),
                        ));
                        return; 
                      }

                      if (camposValidos) {
                        await showLoadingDialog(context, () async{
                          await registerPet();

                          // Aquí se ejecuta el método uploadImages
                          await uploadImages(_selectedImages);
                          await uploadLastDateVaccine(_fotoCarnetVacunacion);
                        });
                        showSnackbar(context, "Registro de Mascota con éxito");
                        Navigator.pop(context, 1);


                        /*await mostrarFinalizar.Mostrar_Finalizados_Clientes(
                            context,
                            "Registro de Mascota con éxito",
                            miembroMascota!.id);*/

                          /*setState(() {
                            isLoading =
                            false; // Detén la carga después de completar la operación
                          });*/
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        backgroundColor: Colors.green,
                      ),
                      child: Text('Registrar Mascota'),
                    ),
                  SizedBox(height: 10),
                  Visibility(
                    visible: isLoading,
                    child: Center(
                      child: SpinKitThreeBounce(
                        // Aquí se usa el indicador ThreeBounce
                        color: Colors
                            .blue, // Puedes cambiar el color según tus preferencias
                        size:
                            50.0, // Puedes cambiar el tamaño según tus preferencias
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              ElevatedButton(
                  onPressed: isLoading?null: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    backgroundColor: Colors.red,
                  ),
                  child: Text('Cancelar'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool validarCampos() {
    bool nombreValido = validador.validarNombreMascota(nombreController.text);
    bool descripcionValido =
        validador.validarDescripcionMascota(descripcionController.text);
    bool edadValido = validador.validarEdadMascota(edadController.text);
    bool razaValido = validador.validarRazaMascota(razaController.text);
    bool colorValido = validador.validarColorMascota(colorController.text);

    setState(() {
      validador.mensajeErrorNombreMascota =
          nombreValido ? null : validador.mensajeErrorNombreMascota;
      validador.mensajeErrorDescripcionMascota =
          descripcionValido ? null : validador.mensajeErrorDescripcionMascota;
      validador.mensajeErrorEdadMascota =
          edadValido ? null : validador.mensajeErrorEdadMascota;
      validador.mensajeErrorRazaMascota =
          razaValido ? null : validador.mensajeErrorRazaMascota;
      validador.mensajeErrorColorMascota =
          colorValido ? null : validador.mensajeErrorColorMascota;
    });

    return nombreValido &&
        descripcionValido &&
        edadValido &&
        razaValido &&
        colorValido;
  }
}
