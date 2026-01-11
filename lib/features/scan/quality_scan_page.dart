import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:myapp/models/sorting_log.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:developer' as developer;

class QualityScanPage extends StatefulWidget {
  const QualityScanPage({super.key});

  @override
  State<QualityScanPage> createState() => _QualityScanPageState();
}

class _QualityScanPageState extends State<QualityScanPage> {
  final _formKey = GlobalKey<FormState>();
  final _partNoController = TextEditingController();
  final _partNameController = TextEditingController();
  final _operatorNameController = TextEditingController();
  final _supplierController = TextEditingController();
  final _quantitySortedController = TextEditingController();
  final _quantityNgController = TextEditingController();
  final _ngTypeController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  File? _image;
  bool _isScanning = false;

  Future<void> _scanBarcode() async {
    setState(() {
      _isScanning = true;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('rejected_parts')
          .child('${DateTime.now().toIso8601String()}.jpg');
      await storageRef.putFile(image);
      return await storageRef.getDownloadURL();
    } catch (e) {
      developer.log('Error uploading image: $e');
      return null;
    }
  }

  void _submitLog() async {
    if (_formKey.currentState!.validate()) {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImage(_image!);
      }

      final log = SortingLog(
        partNo: _partNoController.text,
        partName: _partNameController.text,
        quantitySorted: int.parse(_quantitySortedController.text),
        quantityNg: int.parse(_quantityNgController.text),
        ngType: _ngTypeController.text,
        operatorName: _operatorNameController.text,
        supplier: _supplierController.text,
        imageUrl: imageUrl,
        timestamp: Timestamp.now(),
      );

      await _firestoreService.addSortingLog(log);

      _formKey.currentState!.reset();
      setState(() {
        _image = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log submitted successfully!')),
        );
      }
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    final image = _image != null ? pw.MemoryImage(_image!.readAsBytesSync()) : null;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sorting Log', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Part Number: ${_partNoController.text}'),
              pw.Text('Part Name: ${_partNameController.text}'),
              pw.Text('Operator Name: ${_operatorNameController.text}'),
              pw.Text('Supplier: ${_supplierController.text}'),
              pw.Text('Total Quantity Sorted: ${_quantitySortedController.text}'),
              pw.Text('Quantity NG: ${_quantityNgController.text}'),
              pw.Text('NG Type: ${_ngTypeController.text}'),
              pw.SizedBox(height: 20),
              if (image != null) pw.Image(image),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Barcode')),
        body: MobileScanner(
          onDetect: (capture) {
            final Barcode barcode = capture.barcodes.first;
            if (barcode.rawValue != null) {
              _partNoController.text = barcode.rawValue!;
              _firestoreService.getPartName(barcode.rawValue!).then((partName) {
                if (partName != null) {
                  _partNameController.text = partName;
                }
              });
              setState(() {
                _isScanning = false;
              });
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QCSR - Quality Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _partNoController,
                decoration: InputDecoration(
                  labelText: 'Part Number',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Enter Part Number' : null,
              ),
              TextFormField(
                controller: _partNameController,
                decoration: const InputDecoration(labelText: 'Part Name'),
                validator: (value) => value!.isEmpty ? 'Enter Part Name' : null,
              ),
              TextFormField(
                controller: _operatorNameController,
                decoration: const InputDecoration(labelText: 'Operator Name'),
                validator: (value) => value!.isEmpty ? 'Enter Operator Name' : null,
              ),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Supplier / Factory Location'),
                validator: (value) => value!.isEmpty ? 'Enter Supplier' : null,
              ),
              TextFormField(
                controller: _quantitySortedController,
                decoration: const InputDecoration(labelText: 'Total Quantity Sorted'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter Quantity' : null,
              ),
              TextFormField(
                controller: _quantityNgController,
                decoration: const InputDecoration(labelText: 'Quantity NG (Non-Good)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Enter Quantity' : null,
              ),
              TextFormField(
                controller: _ngTypeController,
                decoration: const InputDecoration(labelText: 'NG Type'),
              ),
              const SizedBox(height: 20),
              _image == null ? const Text('No image selected.') : Image.file(_image!),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo of NG Part'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitLog,
                child: const Text('Submit Log'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
