import 'package:every_door/constants.dart';
import 'package:every_door/helpers/multi_icon.dart';
import 'package:every_door/models/note.dart';
import 'package:every_door/models/plugin.dart';
import 'package:every_door/providers/location.dart';
import 'package:every_door/providers/notes.dart';
import 'package:every_door/screens/modes/definitions/base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

abstract class NotesModeDefinition extends BaseModeDefinition {
  List<BaseNote> notes = [];

  NotesModeDefinition(super.ref);

  @override
  MultiIcon getIcon(BuildContext context, bool outlined) {
    final loc = AppLocalizations.of(context)!;
    return MultiIcon(
      fontIcon: !outlined ? Icons.note_alt : Icons.note_alt_outlined,
      tooltip: loc.navNotesMode,
    );
  }

  @override
  Future<void> updateNearest() async {
    final location = ref.read(effectiveLocationProvider);
    final notes = await ref
        .read(notesProvider)
        .fetchAllNotes(center: location, radius: kNotesVisibilityRadius);
    // .fetchAllNotes(bounds: controller.camera.visibleBounds);
    this.notes = notes.where((n) => !n.deleting).toList();
    notifyListeners();
  }

  @override
  void updateFromJson(Map<String, dynamic> data, Plugin plugin) {
    if (data.containsKey('locked')) {
      print('setting locked to ${data["locked"]}');
      ref.read(drawingLockedProvider.notifier).state = data['locked']!;
    }
  }
}

class DefaultNotesModeDefinition extends NotesModeDefinition {
  DefaultNotesModeDefinition(super.ref);

  @override
  String get name => "notes";
}
