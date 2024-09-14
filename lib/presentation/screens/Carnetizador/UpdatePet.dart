import 'dart:convert';
import 'dart:io';
import 'package:fluttapp/Config/Config.dart';
import 'package:fluttapp/Models/Mascota.dart';
import 'package:fluttapp/presentation/littlescreens/validator.dart';
import 'package:fluttapp/presentation/screens/Carnetizador/ListMascotas.dart';
import 'package:fluttapp/presentation/screens/Cliente/HomeClient.dart';
import 'package:fluttapp/presentation/services/alert.dart';
import 'package:fluttapp/presentation/services/services_firebase.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class UpdatePet extends StatefulWidget {
  final Mascota mascota; // Agregar este campo para recibir el objeto Mascota

  UpdatePet(this.mascota); // Constructor que recibe una Mascota

  @override
  _UpdatePetState createState() => _UpdatePetState();
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
class _UpdatePetState extends State<UpdatePet> {
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
  List<String> _imageUrls = [];
  bool isLoadingImages = true;
  Castrado? _castrado = Castrado.no;
  Castrado? _vacunado = Castrado.no;
  Especie? _especie = Especie.P;
  Sexo? _sexo = Sexo.M;
  DateTime fechaSeleccionada=DateTime.now();
  bool loadCarnet = true;

  @override
  void initState() {
    super.initState();
    getImagesUrls(
            'cliente', widget.mascota.idPersona, widget.mascota.idMascotas)
        .then((urls) {
      setState(() {
        _imageUrls = urls;
      });
    });
    addImageUrlsToSelectedImages(
        'cliente', widget.mascota.idPersona, widget.mascota.idMascotas);
    getCarnetImage(widget.mascota.idPersona, widget.mascota.idMascotas);
    // Asignar los valores de la Mascota a los controladores
    nombreController.text = widget.mascota.nombre;
    edadController.text = widget.mascota.edad.toString();
    descripcionController.text = widget.mascota.descripcion;
    razaController.text = widget.mascota.raza;
    colorController.text = widget.mascota.color;
    if(widget.mascota.especie=='G'){
      _especie = Especie.G;
    }
    if(widget.mascota.sexo=='H'){
      _sexo = Sexo.H;
    }
    if(widget.mascota.fechaUltimaVacuna!=null){
      _vacunado=Castrado.si;
      fechaUltimaVacunaController.text = DateFormat('yyyy-MM-dd').format(widget.mascota.fechaUltimaVacuna!); 
    }
  }

Future<File?> getCarnetImage(int idPerson, int idMascota) async {
  try {
    String imageUrl = await getImageUrl(idPerson, idMascota);
    File tempImage = await _downloadImageLast(imageUrl);
    
    setState(() {
      _fotoCarnetVacunacion = tempImage;
      loadCarnet = false;
    });
    return _fotoCarnetVacunacion;
  } catch (e) {
    print('Error al obtener y descargar la imagen: $e');
    setState(() {
      loadCarnet = false;
    });
  }
  
  return null;
}

Future<String> getImageUrl(int idPerson, int idMascota) async {
  try {
    Reference storageRef = FirebaseStorage.instance.ref('cliente/$idPerson/$idMascota/lastdate.jpg');
    return await storageRef.getDownloadURL();
  } catch (e) {
    print('Error al obtener URL de la imagen: $e');
    throw e;
  }
}

Future<File> _downloadImageLast(String imageUrl) async {
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

  Future<bool> uploadLastDateVaccine(File? image, int userId, int petId) async {
    try {
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();
      String carpeta = 'cliente/${userId}/$petId';

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

  Future<List<String>> getImagesUrls(
      String carpeta, int idCliente, int idMascota) async {
    List<String> imageUrls = [];

    try {
      Reference storageRef =
          FirebaseStorage.instance.ref('$carpeta/$idCliente/$idMascota');
      ListResult result = await storageRef.list();

      for (var item in result.items) {
        String downloadURL = await item.getDownloadURL();
        imageUrls.add(downloadURL);
      }
    } catch (e) {
      print('Error al obtener URLs de imágenes: $e');
    }

    return imageUrls;
  }

  Future<void> addImageUrlsToSelectedImages(
      String carpeta, int idCliente, int idMascota) async {
    try {
      List<String> imageUrls =
          await getImagesUrls(carpeta, idCliente, idMascota);
      for (String url in imageUrls) {
        File tempImage = await _downloadImage(url);
        setState(() {
          _selectedImages.add(tempImage);
        });
      }
      setState(() {
        isLoadingImages = false;
      });
    } catch (e) {
      print('Error al obtener y descargar las imágenes: $e');
    }
  }

  Future<File> _downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final tempImageFile =
          File('${tempDir.path}/${DateTime.now().toIso8601String()}.jpg');
      await tempImageFile.writeAsBytes(bytes);
      return tempImageFile;
    } else {
      throw Exception('Error al descargar imagen');
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

  Future<bool> uploadImages(List<File?> images, int userId, int petId) async {
    try {
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();
      print("Ultimo ID ======== $userId" + "---" + petId.toString());
      String carpeta = 'cliente/$userId/$petId';

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

  Future<bool> deletePetFolder(int userId, int petId) async {
    try {
      final firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref();

      String carpeta = 'cliente/$userId/$petId';

      // Listamos los elementos en la carpeta de la mascota
      firebase_storage.ListResult listResult =
          await storageRef.child(carpeta).listAll();

      // Eliminamos cada elemento individualmente
      for (var item in listResult.items) {
        await item.delete();
      }

      return true;
    } catch (e) {
      print('Error al eliminar carpeta de mascota: $e');
      return false;
    }
  }

  Future<void> updatePet() async {
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
    final url = Uri.parse('${Config.baseUrl}/updatemascota/' +
        widget.mascota.idMascotas.toString());

    final response = await http.put(
      url,
      body: jsonEncode({
        'id': widget.mascota.idMascotas,
        'Nombre': nombreController.text,
        'Raza': razaController.text,
        'Edad': int.parse(edadController.text),
        'Color': colorController.text,
        'Descripcion': descripcionController.text,
        'IdPersona': widget
            .mascota.idPersona, 
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
      // Mascota actualizada exitosamente
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la mascota')),
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
        backgroundColor: Color.fromARGB(255, 241, 245, 255),
        title: Text('Actualizar Mascota',
            style: TextStyle(color: const Color.fromARGB(255, 70, 65, 65))),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        /*decoration: BoxDecoration(
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
                child:  AbsorbPointer( 
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
            if(loadCarnet)
            SpinKitCircle(
                      color: Color(0xFF5C8ECB),
                      size: 50.0,
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
                onPressed: isLoadingImages || isLoading
                    ? null
                    : () async {
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
                  backgroundColor: isLoadingImages
                      ? Color.fromARGB(255, 130, 141, 153)
                      : Color(0xFF5C8ECB),
                ),
                child: Text('Cargar Fotos de la Mascota'),
                
              ),
              SizedBox(height: 20),
              isLoadingImages
                  ? SpinKitCircle(
                      color: Color(0xFF5C8ECB),
                      size: 50.0,
                    )
                  : SingleChildScrollView(
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
              SizedBox(height: 20),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed:isLoadingImages || isLoading
                    ? null: () async {

                      /*setState(() {
                        isLoading =
                            true; // Comienza la carga al presionar el botón
                      });*/

                      bool camposValidos = validarCampos();
                      if (camposValidos) {
                        await showLoadingDialog(context, () async{
                        deletePetFolder(widget.mascota.idPersona,
                            widget.mascota.idMascotas);
                        await uploadImages(
                            _selectedImages,
                            widget.mascota.idPersona,
                            widget.mascota.idMascotas);
                        await updatePet();
                        await uploadLastDateVaccine(_fotoCarnetVacunacion, widget.mascota.idPersona, widget.mascota.idMascotas);

                        /*await mostrarFinalizar.Mostrar_Finalizados_Clientes(
                            context,
                            "Mascota actualizada con éxito",
                            miembroActual!.id);*/
                        });
                        showSnackbar(context, "Mascota actualizada con éxito");
                        Navigator.pop(context, 1);

  
                      }

                      /*setState(() {
                        isLoading =
                            false; // Detén la carga después de completar la operación
                      });*/
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      backgroundColor:
                          Colors.green, // Cambiar el color del botón aquí
                    ),
                    child: Text('Actualizar Mascota'),
                  ),

                  SizedBox(
                      height:
                          16), // Espacio entre el botón y el indicador de carga

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
                onPressed: isLoading?null: () async {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),    
                  backgroundColor: Colors.red, // Cambiar el color del botón aquí
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
