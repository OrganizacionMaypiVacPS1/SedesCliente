import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:card_swiper/card_swiper.dart';
import 'package:fluttapp/Config/Config.dart';
import 'package:fluttapp/Models/Mascota.dart';
import 'package:fluttapp/Models/Propietario.dart';
import 'package:fluttapp/presentation/services/services_firebase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';


class ViewMascotasInfo extends StatelessWidget {
  final Mascota mascota;

  Future<Propietario> fetchOwnerById(int id) async {
    final response = await http
        .get(Uri.parse('${Config.baseUrl}/getpropietariobyid2/$id'));

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
      return Propietario.fromJson(data);
    } else {
      throw Exception('Failed to load owner');
    }
  }

  ViewMascotasInfo(this.mascota);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Propietario>(
      future: fetchOwnerById(mascota.idPersona),
      builder: (BuildContext context, AsyncSnapshot<Propietario> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SpinKitCircle(
                      color: Color(0xFF5C8ECB),
                      size: 50.0,
                    );
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          Propietario propietario = snapshot.data!;
          return InfoMascotas(mascota: mascota, propietario: propietario);
        }
      },
    );
  }
}

// ignore: must_be_immutable
class InfoMascotas extends StatefulWidget {
    final Mascota mascota;
    final Propietario propietario;
    InfoMascotas({required this.mascota, required this.propietario});
  @override
  _InfoMascotasState createState() => _InfoMascotasState();
}

class _InfoMascotasState extends State<InfoMascotas> {
  File? _fotoCarnetVacunacion;
  bool loadCarnet = true;

  @override
  void initState(){
    super.initState();
    getCarnetImage(widget.mascota.idPersona, widget.mascota.idMascotas).then((file) {
      setState(() {
        _fotoCarnetVacunacion = file;
      });
      
    });
  }


/*
  List<String> imagenes = [
    'assets/Perro.png',
    'assets/Perro.png',
    'assets/Perro.png',
    'assets/Perro.png',
    'assets/Perro.png',
  ];
*/

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

  final GlobalKey _qrKey = GlobalKey();



  List<String> imagenes = [
    'cliente/16/1.jpg',
    'cliente/16/2.jpg',
    'cliente/16/3.jpg',
  ];

/*
SizedBox(
                  height: 300,
                  child: Swiper(
                    itemCount: imagenes.length,
                    viewportFraction: 0.8,
                    scale: 0.9,
                    itemBuilder: (BuildContext context, int index) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        elevation: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ],
                            image: DecorationImage(
                              image: NetworkImage(
                                  'https://firebasestorage.googleapis.com/v0/b/flutter-test-d1cb6.appspot.com/o/${"20"[index]}?alt=media'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
*/
final ScreenshotController screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromARGB(255, 241, 245, 255),
          title: Text(
            'Datos de la Mascota',
            style: TextStyle(color: const Color.fromARGB(255, 70, 65, 65)),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            color: Color(0xFF5C8ECB),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/Splash.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 10,
                ),
                FutureBuilder<List<String>>(
                  //future: getImagesUrls('cliente', mascota.idPersona, mascota.idMascotas),
                  future: getImagesUrls(
                      'cliente', widget.mascota.idPersona, widget.mascota.idMascotas),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<String>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SpinKitCircle(
                      color: Color(0xFF5C8ECB),
                      size: 50.0,
                    );
                    } else if (snapshot.hasError) {
                      print('Lista de URLs de imágenes: ${snapshot.data}');
                      return Text('Error: ${snapshot.error}');
                    } else {
                      print('Lista de URLs: ${snapshot.data}');
                      List<String> imagenes = snapshot.data!;
                      print(
                          'Lista de URLs de imágenes: $imagenes'); // Añade este print
                      return SizedBox(
                        height: 300,
                        child: Swiper(
                          itemCount: imagenes.length,
                          viewportFraction: 0.8,
                          scale: 0.9,
                          itemBuilder: (BuildContext context, int index) {
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              elevation: 5,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      spreadRadius: 5,
                                      blurRadius: 7,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: NetworkImage(imagenes[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                  },
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  child: Card(
                    margin: EdgeInsets.all(10),
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pets,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nombre de la Mascota:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.nombre,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.category,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Raza:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.raza,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.cake,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edad:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.edad.toString(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.color_lens,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Color:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.color,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.description,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Descripción:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.descripcion,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.wc,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sexo:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.sexo=='M'?'Macho':'Hembra',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.pets,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Especie:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.especie=='P'?'Perro':'Gato',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.cut,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Castrado:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.castrado==1?'Si':'No',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha Ultima Vacuna:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.mascota.fechaUltimaVacuna==null?'Sin Vacuna':
                                    DateFormat('yyyy-MM-dd').format(widget.mascota.fechaUltimaVacuna!),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if(_fotoCarnetVacunacion!=null)
                          Center(child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    content: _fotoCarnetVacunacion==null
                                      ? Center(child: Text('Sin Carnet Registrado'),) 
                                      : Image.file(_fotoCarnetVacunacion!), 
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text("Cerrar"),
                                        onPressed: () {
                                          Navigator.of(context).pop(); 
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                                
                            },
                            child: Text('Ver Carnet de Vacunación'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 28, 100, 209), 
                              foregroundColor: Colors.white, 
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),) 
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  child: Card(
                    margin: EdgeInsets.all(10),
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Propietario',
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nombres:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.propietario.nombres,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Apellidos:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.propietario.apellidos,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.mail,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Correo:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.propietario.correo,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Teléfono:',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    widget.propietario.telefono.toString(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              Spacer(),
                              InkWell(
                                onTap: () {
                                  launchWhatsApp(widget.propietario.telefono.toString());
                                },
                                child: Container(
                                  padding: EdgeInsets.all(8), 
                                  decoration: BoxDecoration(
                                    color: Colors.green[700], 
                                    borderRadius: BorderRadius.circular(20), 
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2), 
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: Offset(0, 1), 
                                      ),
                                    ],
                                  ),
                                  child: FaIcon(
                                    FontAwesomeIcons.whatsapp,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          if(widget.propietario.latitud!=0.1)_buildMap(widget.propietario.latitud, widget.propietario.longitud),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  child: Card(
                    margin: EdgeInsets.all(10),
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        children: [
                         Screenshot(
                            key: _qrKey,
                            controller: screenshotController,
                            child:Container(
                              decoration: BoxDecoration(color: Colors.white),
                              child:  Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0, top: 10.0, right: 10.0, left: 10.0), 
                                  child: Image(
                                    image: AssetImage('assets/Univallenavbar.png'),
                                  ),
                                ),
                                QrImageView(
                                  backgroundColor: Colors.white,
                                  data: widget.mascota.idMascotas.toString(),
                                  version: QrVersions.auto,
                                  size: 200.0,
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                ),
                              ],
                            ),)
                          )
                          ,SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () async {
                              await takeScreenshot(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 28, 100, 209), 
                              foregroundColor: Colors.white, 
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text('Descargar QR'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(double lat, double lng) {
  return Container(
    height: 150, 
    width: double.infinity, 
    child: GoogleMap(
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
  
Future<void> takeScreenshot(BuildContext context) async {    

    Uint8List? image = await screenshotController.capture();

    if (image != null) {

      String fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}';
      final result = await ImageGallerySaver.saveImage(image, name: fileName);
      if (result['isSuccess']) {
        Mostrar_Mensaje(context,'Guardado' );
      } else {
        Mostrar_Mensaje(context,'Error al Guardar' );
      }
    } else {
      Mostrar_Mensaje(context,'Error al Guardar' );
    }
  }
}
