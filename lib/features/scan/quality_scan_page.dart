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

class NgEntry {
  final TextEditingController typeController = TextEditingController();
  final TextEditingController operatorController = TextEditingController();
  File? image;

  void dispose() {
    typeController.dispose();
    operatorController.dispose();
  }
}

class QualityScanPage extends StatefulWidget {
  const QualityScanPage({super.key});

  @override
  State<QualityScanPage> createState() => _QualityScanPageState();
}

class _QualityScanPageState extends State<QualityScanPage> {
  final _formKey = GlobalKey<FormState>();
  final _partNoController = TextEditingController();
  final _partNameController = TextEditingController();
  final _supplierController = TextEditingController();
  final _factoryLocationController = TextEditingController();
  final List<TextEditingController> _operatorControllers = [TextEditingController()];
  final _quantitySortedController = TextEditingController();
  final _quantityNgController = TextEditingController();
  final _remarksController = TextEditingController();

  final List<NgEntry> _ngEntries = [NgEntry()];
  final FirestoreService _firestoreService = FirestoreService();
  bool _isScanning = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _partNoController.dispose();
    _partNameController.dispose();
    _supplierController.dispose();
    _factoryLocationController.dispose();
    for (var controller in _operatorControllers) {
      controller.dispose();
    }
    _quantitySortedController.dispose();
    _quantityNgController.dispose();
    _remarksController.dispose();
    for (var entry in _ngEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _isScanning = true;
    });
  }

  Future<void> _pickImage(NgEntry entry) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        entry.image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('rejected_parts')
          .child('${DateTime.now().toIso8601String()}_${image.path.split('/').last}');
      await storageRef.putFile(image);
      return await storageRef.getDownloadURL();
    } catch (e) {
      developer.log('Error uploading image: $e');
      return null;
    }
  }

  void _addNgEntry() {
    setState(() {
      _ngEntries.add(NgEntry());
    });
  }

  void _removeNgEntry(int index) {
    if (_ngEntries.length > 1) {
      setState(() {
        _ngEntries[index].dispose();
        _ngEntries.removeAt(index);
      });
    }
  }

  void _submitLog() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        List<NgDetail> ngDetails = [];
        for (var entry in _ngEntries) {
          String? imageUrl;
          if (entry.image != null) {
            imageUrl = await _uploadImage(entry.image!);
          }
          ngDetails.add(NgDetail(
            type: entry.typeController.text,
            operatorName: entry.operatorController.text,
            imageUrl: imageUrl,
          ));
        }

        final log = SortingLog(
          partNo: _partNoController.text,
          partName: _partNameController.text,
          quantitySorted: int.parse(_quantitySortedController.text),
          quantityNg: int.parse(_quantityNgController.text),
          supplier: _supplierController.text,
          factoryLocation: _factoryLocationController.text,
          operators: _operatorControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
          ngDetails: ngDetails,
          remarks: _remarksController.text,
          timestamp: Timestamp.now(),
        );

        await _firestoreService.addSortingLog(log);

        if (mounted) {
          _showSuccessDialog();
          _resetForm();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Sorting log has been submitted successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _partNoController.clear();
    _partNameController.clear();
    _supplierController.clear();
    _factoryLocationController.clear();
    
    for (var c in _operatorControllers) {
      c.dispose();
    }
    _operatorControllers.clear();
    _operatorControllers.add(TextEditingController());

    _quantitySortedController.clear();
    _quantityNgController.clear();
    _remarksController.clear();
    for (var entry in _ngEntries) {
      entry.dispose();
    }
    setState(() {
      _ngEntries.clear();
      _ngEntries.add(NgEntry());
    });
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    List<pw.Widget> ngWidgets = [];
    for (var entry in _ngEntries) {
      final image = entry.image != null ? pw.MemoryImage(entry.image!.readAsBytesSync()) : null;
      ngWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('NG Type: ${entry.typeController.text}'),
              pw.Text('Operator: ${entry.operatorController.text}'),
              if (image != null) pw.Container(height: 100, child: pw.Image(image)),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sorting Log Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Part Number: ${_partNoController.text}'),
              pw.Text('Part Name: ${_partNameController.text}'),
              pw.Text('Supplier: ${_supplierController.text}'),
              pw.Text('Total Quantity Sorted: ${_quantitySortedController.text}'),
              pw.Text('Quantity NG: ${_quantityNgController.text}'),
              pw.SizedBox(height: 10),
              pw.Text('Remarks: ${_remarksController.text}'),
              pw.SizedBox(height: 20),
              pw.Text('NG Details:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...ngWidgets,
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Job Information Card
                  _buildSectionCard(
                    title: 'JOB INFORMATION',
                    icon: Icons.assignment_outlined,
                    children: [
                      TextFormField(
                        controller: _partNoController,
                        decoration: InputDecoration(
                          labelText: 'Part Number',
                          prefixIcon: const Icon(Icons.numbers),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _scanBarcode,
                          ),
                        ),
                        validator: (value) => value!.isEmpty ? 'Enter Part Number' : null,
                      ),
                      TextFormField(
                        controller: _partNameController,
                        decoration: const InputDecoration(
                          labelText: 'Part Name',
                          prefixIcon: Icon(Icons.settings),
                        ),
                        validator: (value) => value!.isEmpty ? 'Enter Part Name' : null,
                      ),
                      TextFormField(
                        controller: _supplierController,
                        decoration: const InputDecoration(
                          labelText: 'Supplier Name',
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (value) => value!.isEmpty ? 'Enter Supplier' : null,
                      ),
                      TextFormField(
                        controller: _factoryLocationController,
                        decoration: const InputDecoration(
                          labelText: 'Factory / Line Location',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (value) => value!.isEmpty ? 'Enter Location' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Sorting Team Card
                  Card(
                    elevation: 2,
                    color: Colors.indigo.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.indigo.shade900, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.group, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('SORTING TEAM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._operatorControllers.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var controller = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        labelText: 'Operator ${idx + 1} Name',
                                        prefixIcon: const Icon(Icons.person_outline),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      validator: (value) => value!.isEmpty ? 'Enter Name' : null,
                                    ),
                                  ),
                                  if (_operatorControllers.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                      onPressed: () => setState(() {
                                        controller.dispose();
                                        _operatorControllers.removeAt(idx);
                                      }),
                                    ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _operatorControllers.add(TextEditingController())),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Add Team Member'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Production Volume
                  _buildSectionCard(
                    title: 'PRODUCTION VOLUME',
                    icon: Icons.inventory_2_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantitySortedController,
                              decoration: const InputDecoration(
                                labelText: 'Total Sorted',
                                prefixIcon: Icon(Icons.check_circle_outline, color: Colors.green),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value!.isEmpty ? 'Enter Qty' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _quantityNgController,
                              decoration: const InputDecoration(
                                labelText: 'Total NG',
                                prefixIcon: Icon(Icons.report_problem_outlined, color: Colors.orange),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) => value!.isEmpty ? 'Enter Qty' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. NG Details
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade900, width: 1.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.new_releases_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('NG DEFECT DETAILS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
                      ],
                    ),
                  ),
                  ..._ngEntries.asMap().entries.map((entry) {
                    int index = entry.key;
                    NgEntry detail = entry.value;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.red.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade900, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ENTRY #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                if (_ngEntries.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                                    onPressed: () => _removeNgEntry(index),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: detail.typeController,
                              decoration: const InputDecoration(
                                labelText: 'Defect Type',
                                prefixIcon: Icon(Icons.error_outline),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => value!.isEmpty ? 'Enter NG Type' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: detail.operatorController,
                              decoration: const InputDecoration(
                                labelText: 'Inspector Name',
                                prefixIcon: Icon(Icons.manage_accounts_outlined),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => value!.isEmpty ? 'Enter Name' : null,
                            ),
                            const SizedBox(height: 12),
                            detail.image != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Image.file(detail.image!, height: 180, width: double.infinity, fit: BoxFit.cover),
                                        Positioned(
                                          right: 8,
                                          top: 8,
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black54,
                                            radius: 18,
                                            child: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                              onPressed: () => setState(() => detail.image = null),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    height: 100,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey),
                                        SizedBox(height: 4),
                                        Text('No Photo Attached', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _pickImage(detail),
                              icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                              label: Text(detail.image == null ? 'Attach Defect Photo' : 'Change Photo', style: const TextStyle(color: Colors.white)),
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addNgEntry,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Another NG Entry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red.shade800,
                      side: BorderSide(color: Colors.red.shade900, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Remarks
                  _buildSectionCard(
                    title: 'FIXED FINDINGS / REMARKS',
                    icon: Icons.note_alt_outlined,
                    children: [
                      TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          hintText: 'Enter any additional notes or findings here...',
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitLog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('COMPLETE & SUBMIT LOG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      color: Colors.indigo.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade900, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}