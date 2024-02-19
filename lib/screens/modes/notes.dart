import 'package:every_door/constants.dart';
import 'package:every_door/helpers/draw_style.dart';
import 'package:every_door/helpers/tile_layers.dart';
import 'package:every_door/models/note.dart';
import 'package:every_door/providers/editor_settings.dart';
import 'package:every_door/providers/imagery.dart';
import 'package:every_door/providers/location.dart';
import 'package:every_door/providers/notes.dart';
import 'package:every_door/screens/editor/map_chooser.dart';
import 'package:every_door/screens/editor/note.dart';
import 'package:every_door/widgets/loc_marker.dart';
import 'package:every_door/widgets/map_drag_create.dart';
import 'package:every_door/widgets/painter.dart';
import 'package:every_door/widgets/status_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NotesPane extends ConsumerStatefulWidget {
  final Widget? areaStatusPanel;

  const NotesPane({super.key, this.areaStatusPanel});

  @override
  ConsumerState<NotesPane> createState() => _NotesPaneState();
}

class _NotesPaneState extends ConsumerState<NotesPane> {
  static const kEnablePainter = true;

  static const kToolEraser = "eraser";
  static const kToolScribble = "scribble";
  static const kZoomOffset = -1.0;

  String _currentTool = kToolScribble;
  List<BaseNote> _notes = [];
  final controller = MapController();
  final _mapKey = GlobalKey();
  LatLng? newLocation;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      updateNotes();
    });
  }

  updateNotes() async {
    final notes = await ref
        .read(notesProvider)
        .fetchAllNotes(center: controller.camera.center, radius: 3000);
        // .fetchAllNotes(bounds: controller.camera.visibleBounds);
    if (!mounted) return;
    setState(() {
      _notes = notes.where((n) => !n.deleting).toList();
    });
  }

  _openNoteEditor(OsmNote? note, [LatLng? location]) async {
    if (location != null) {
      setState(() {
        newLocation = location;
      });
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) => NoteEditorPane(
        note: note,
        location:
            location ?? note?.location ?? ref.read(effectiveLocationProvider),
      ),
    );
    setState(() {
      newLocation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final leftHand = ref.watch(editorSettingsProvider).leftHand;
    final tileLayer = TileLayerOptions(ref.watch(selectedImageryProvider));
    final loc = AppLocalizations.of(context)!;

    // Rotate the map according to the global rotation value.
    ref.listen(rotationProvider, (_, double newValue) {
      if ((newValue - controller.camera.rotation).abs() >= 1.0)
        controller.rotate(newValue);
    });

    ref.listen(effectiveLocationProvider, (_, LatLng next) {
      controller.move(next, controller.camera.zoom);
      updateNotes();
    });
    ref.listen(notesProvider, (_, next) {
      updateNotes();
    });

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                key: _mapKey,
                mapController: controller,
                options: MapOptions(
                  initialCenter: ref.read(effectiveLocationProvider),
                  minZoom: kEditMinZoom + kZoomOffset - 0.1,
                  maxZoom: kEditMaxZoom,
                  initialZoom: ref.watch(zoomProvider) + kZoomOffset,
                  initialRotation: ref.watch(rotationProvider),
                  interactionOptions: InteractionOptions(
                    // TODO: remove drag when adding map drawing
                    flags: InteractiveFlag.pinchMove |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag,
                    rotationThreshold: kRotationThreshold,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: tileLayer.urlTemplate,
                    wmsOptions: tileLayer.wmsOptions,
                    tileProvider: tileLayer.tileProvider,
                    minNativeZoom: tileLayer.minNativeZoom,
                    maxNativeZoom: tileLayer.maxNativeZoom,
                    maxZoom: tileLayer.maxZoom,
                    tileSize: tileLayer.tileSize,
                    tms: tileLayer.tms,
                    subdomains: tileLayer.subdomains,
                    additionalOptions: tileLayer.additionalOptions,
                    userAgentPackageName: tileLayer.userAgentPackageName,
                    reset: tileResetController.stream,
                  ),
                  LocationMarkerWidget(tracking: false),
                  PolylineLayer(
                    polylines: [
                      for (final drawing in _notes.whereType<MapDrawing>())
                        Polyline(
                          points: drawing.coordinates,
                          color: drawing.style.color,
                          strokeWidth: drawing.style.stroke,
                          isDotted: drawing.style.dashed,
                          borderColor: drawing.style.casing,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final osmNote in _notes.whereType<OsmNote>())
                        Marker(
                          point: osmNote.location,
                          width: 50.0,
                          height: 50.0,
                          child: Center(
                            child: GestureDetector(
                              child: Container(
                                padding: EdgeInsets.all(10.0),
                                color: Colors.transparent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(20.0),
                                    color: osmNote.isChanged
                                        ? Colors.yellow.withOpacity(0.8)
                                        : Colors.white.withOpacity(0.8),
                                  ),
                                  child: SizedBox(width: 30.0, height: 30.0),
                                ),
                              ),
                              onTap: () {
                                _openNoteEditor(osmNote);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  DragButtonWidget(
                    mapKey: _mapKey,
                    button: DragButton(
                      icon: Icons.add,
                      tooltip: loc.notesAddNote,
                      alignment: leftHand
                          ? Alignment.bottomLeft
                          : Alignment.bottomRight,
                      onDragEnd: (pos) {
                        _openNoteEditor(null, pos);
                      },
                      onTap: () async {
                        final pos = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapChooserPage(
                                location: controller.camera.center),
                          ),
                        );
                        if (pos != null) _openNoteEditor(null, pos);
                      },
                    ),
                  ),
                ],
              ),
              if (kEnablePainter) ...[
                PainterWidget(
                  map: controller,
                  onDrawn: (coords) {
                    final note = MapDrawing(
                      coordinates: coords,
                      pathType: _currentTool,
                    );
                    ref.read(notesProvider).saveNote(note);
                  },
                  onTap: (location) {
                    // TODO: find an object at the point (note) and open its details.
                    // TODO: for eraser, delete drawings under tap.
                  },
                  onMapMove: () {
                    updateNotes();
                  },
                  style:
                      kTypeStyles[_currentTool] ?? kTypeStyles[kToolScribble]!,
                ),
                if (!ref.watch(notesProvider).undoIsEmpty)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: ElevatedButton(
                      child: Text('Undo'),
                      onPressed: () {
                        ref.read(notesProvider).undoChange();
                      },
                    ),
                  ),
              ],
              ApiStatusPane(),
            ],
          ),
        ),
        if (widget.areaStatusPanel != null) widget.areaStatusPanel!,
      ],
    );
  }
}
