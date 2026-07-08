import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:bimobondapp/core/services/device_location_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatAttachmentPicker {
  ChatAttachmentPicker._();

  static final ImagePicker _imagePicker = ImagePicker();

  static Future<ChatAttachmentDraft?> pickFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return ChatAttachmentDraft(
      type: 'IMAGE',
      content: '',
      filePath: file.path,
    );
  }

  static Future<ChatAttachmentDraft?> pickFromCamera() async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null) return null;
    return ChatAttachmentDraft(
      type: 'IMAGE',
      content: '',
      filePath: file.path,
    );
  }

  static Future<ChatAttachmentDraft?> pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;
    return ChatAttachmentDraft(
      type: 'VIDEO',
      content: '',
      filePath: file.path,
    );
  }

  static Future<ChatAttachmentDraft?> pickFile() async {
    const typeGroup = XTypeGroup(
      label: 'files',
      extensions: <String>[],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return null;

    final path = file.path;
    if (path.isEmpty) return null;

    final name = file.name.trim().isNotEmpty
        ? file.name
        : path.split(Platform.pathSeparator).last;
    return ChatAttachmentDraft(
      type: 'FILE',
      content: name,
      filePath: path,
    );
  }

  static Future<ChatAttachmentDraft?> pickCurrentLocation() async {
    final position = await DeviceLocationService.getCurrentPosition();
    if (position == null) return null;

    final payload = ChatLocationPayload(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    return ChatAttachmentDraft(
      type: 'LOCATION',
      content: payload.toJsonString(),
    );
  }

  static Future<ChatAttachmentDraft?> pickContact() async {
    if (!await _ensureContactsPermission()) return null;

    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return null;

    final name = contact.displayName.trim();
    final phone = contact.phones.isNotEmpty
        ? contact.phones.first.number.trim()
        : '';

    if (name.isEmpty || phone.isEmpty) return null;

    final payload = ChatContactPayload(name: name, phone: phone);
    return ChatAttachmentDraft(
      type: 'CONTACT',
      content: payload.toJsonString(),
    );
  }

  static Future<bool> _ensureContactsPermission() async {
    if (await FlutterContacts.requestPermission()) return true;

    final status = await Permission.contacts.request();
    return status.isGranted || status.isLimited;
  }
}
