import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mapTools;
import 'main.dart';
import 'package:latlong2/latlong.dart' as latlong2;

Dio dio = Dio();

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late GoogleMapController mapController;
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  
  bool loadingData = true;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(61.49, 23.79), zoom: 13),
      mapToolbarEnabled: false,
      mapType: MapType.normal,
      markers: _markers,
      myLocationEnabled: true,
      polygons: _polygons,
      zoomControlsEnabled: false,
      onMapCreated: _onMapCreated,
      onTap: (LatLng) {
        updatePanelState(<String>[]);
      },
    ),

    loadingData ? Positioned(
        bottom: 10,
        left: 0,
        right: 0,
        child: Center(
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(seconds: 1),
            child: Text(
              '${(_markers.length / 250 * 100).toStringAsFixed(0)}% Loaded',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            )
          ),
        ),
      ) : Container()],
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    createMarkersToGoogleMap();
  }

  Marker createMarker(latlong2.LatLng loc, double color, String? markerText) {
    return Marker(markerId: MarkerId(loc.hashCode.toString()), position: LatLng(loc.latitude, loc.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(color),
      infoWindow: markerText != null ? InfoWindow(title: markerText) : InfoWindow.noText);
  }

  Marker createClickableMarker(latlong2.LatLng loc, double color, String? markerText, [List<String>? route]) {
    return Marker(markerId: MarkerId(loc.hashCode.toString()), position: LatLng(loc.latitude, loc.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(color),
      infoWindow: markerText != null ? InfoWindow(title: markerText) : InfoWindow.noText,
      onTap: () => updatePanelState(route!));
  }

  createMarkersToGoogleMap() async {
    await getServer().loadLigthGroups();
    await loadIntersectionLocations();

    for (latlong2.LatLng loc in getServer().triggerPoints.keys) {
      _markers.add(createClickableMarker(latlong2.LatLng(loc.latitude, loc.longitude), BitmapDescriptor.hueBlue, getServer().triggerPoints[loc],
        getServer().getRoute(getServer().triggerPoints[loc]),
      ));
    }
    for (List<mapTools.LatLng> coordinates in getServer().triggerAreas.keys) {
      List<LatLng> points = [];
      for (var c in coordinates) {
        points.add(LatLng(c.latitude, c.longitude));
      }
      _polygons.add(Polygon(
        polygonId: PolygonId(getServer().triggerAreas[coordinates]!),
        points: points,
        fillColor: Color.fromARGB(123, 69, 156, 226),
        strokeWidth: 0));
    }

    for (String intersectionNro in getServer().getIntersectionLocs().keys) {
      Map<String, dynamic> statusResponse = await getJson('http://trafficlights.tampere.fi/api/v1/deviceState/tre$intersectionNro');
      bool statusData = statusResponse.containsKey("signalGroup");
      double color = BitmapDescriptor.hueYellow;
      setState(() {
        if (getServer().getIntersections()!.containsKey(intersectionNro)) {
          color = BitmapDescriptor.hueGreen;
          _markers.add(createClickableMarker(getServer().getIntersectionLocs()[intersectionNro]!, statusData ? color : BitmapDescriptor.hueRed, intersectionNro,
            getServer().getAllDirectionsFromIntersection(intersectionNro)));
        } else {
          _markers.add(createMarker(getServer().getIntersectionLocs()[intersectionNro]!, statusData ? color : BitmapDescriptor.hueRed, intersectionNro));
        }
      });
    }
    loadingData = false;
  }

  loadIntersectionLocations() async {
    Map<String, dynamic> locResponseJson = await getJson('https://geodata.tampere.fi/geoserver/liikenneverkot/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=liikenneverkot:liikennevaloliittymat_point_gk24_gsview&outputFormat=json&srsName=EPSG:4326');

    for (var feature in locResponseJson["features"]) {
      Map<String, dynamic> properties = feature["properties"];
      String intersectionNro = properties["liva_nro"];

      if (feature["geometry"] != null) {
        Map<String, dynamic> geometry = feature["geometry"];
        dynamic coordinates = geometry["coordinates"];
        List<String> locs = coordinates.first.toString().replaceAll("[", "").replaceAll("]", "").split(",");
        
        getServer().getIntersectionLocs().putIfAbsent(intersectionNro, () => latlong2.LatLng(double.parse(locs.last), double.parse(locs.first)));
      }
    }
  }
}

class SlidePanel extends StatelessWidget {
  List<String> intersectionNumbers = [];
  ScrollController sc;
  Divider divider = const Divider(color: Colors.grey);
  
  SlidePanel(this.sc, this.intersectionNumbers, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var panelRows = getPanelRows();
    return FutureBuilder(
      future: panelRows,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          return snapshot.data;
        } else if (snapshot.hasError) {
          return Text('Virhe haettaessa tietoja!' + snapshot.stackTrace.toString());
        } else {
          return Center(child: Text("Loading..." + intersectionNumbers.join(", ")));
        }
      },);
  }

  createDirectionRow(List<Widget> groupRows, Map<String, dynamic> directionGroup, Map<String, String> statuses) {
    for (String deviceNro in directionGroup.keys) {
      List<Widget> elements = [];
      Map<String, dynamic> devicesByDirection = directionGroup[deviceNro];

      for (String light in devicesByDirection["lights"]) {
        List<String> idAndType = light.split(";"); 
        String status = statuses[idAndType[0]]!;
        elements.add(SizedBox(width: 80, child: Row(children: [currentLight(status), getIcon(idAndType[1])], mainAxisAlignment: MainAxisAlignment.center)));
      }
      Widget row = Row(children: elements, crossAxisAlignment: CrossAxisAlignment.center);

      groupRows.addAll([Text(devicesByDirection["cross"]![0], textAlign: TextAlign.center),
          SizedBox(child: row, height: 44), divider]);
    }
  }

  Widget currentLight(String status) {
    Color color = Colors.grey;
    if ("ABDEFGH9".contains(status)) {
      color = Colors.red.shade900;
    }
    else if ("C".contains(status)) {
      color = Colors.red.shade500;
    }
    else if (":<0".contains(status)) {
      color = Colors.yellow;
    }
    else if ("1345678".contains(status)) {
      color = Colors.green.shade900;
    }
    return _icon(Icons.circle, size: 34, color: color);
  }

  Widget getIcon(String id) {
    switch (id) {
      case '0': return _icon(Icons.people_rounded, size: 23);
      case '1': return _icon(Icons.arrow_back_rounded, size: 40);
      case '2': return _icon(Icons.arrow_upward_rounded, size: 40);
      case '3': return _icon(Icons.arrow_forward_rounded, size: 40);
      case 'R1': return Row(children: [_icon(Icons.tram_outlined), _icon(Icons.arrow_back_rounded)]);
      case 'R2': return Row(children: [_icon(Icons.tram_outlined), _icon(Icons.arrow_upward_rounded)]);
      case 'R3': return Row(children: [_icon(Icons.tram_outlined), _icon(Icons.arrow_forward_rounded)]);
      default: return _icon(Icons.local_taxi);
    }
  }

  getPanelRows() async {
    List<Widget> groupRows = <Widget>[];
    String currentNro = intersectionNumbers[0].substring(0, 3);
    
    for (String nroCodes in intersectionNumbers) {
      Map<String, String> statuses = {};
      String nextNro = nroCodes.split(';')[0];
      if (nextNro != currentNro) {
        groupRows.removeLast();
        groupRows.add(const Divider(color: Colors.grey, thickness: 2));
      }
      Map<String, dynamic> statusResponseJson = getServer().intersectionsStatusData[nextNro];
      if (!statusResponseJson.containsKey("signalGroup")) {
        continue;
      }
      for (Map<String, dynamic> device in statusResponseJson["signalGroup"]) {
        statuses.putIfAbsent(device["name"].toString().replaceAll("\"", "").replaceAll("_", ""), () => device["status"]);
      }
      Map<String, dynamic> directionGroup = getServer().getDirectionGroupsFromIntersection(nextNro)!;
      createDirectionRow(groupRows, directionGroup, statuses);
      currentNro = nextNro;
    }
    return ListView(children: groupRows, controller: sc, padding: const EdgeInsets.all(16));
  }

  Icon _icon(iconData, {double size = 20, Color color = Colors.black}) {
    return Icon(iconData, size: size, color: color);
  }
}

getJson(String url) async {
  try {
    final response = await dio.get(url);
    return response.data;
  } catch (e) {
    return {"error": {"No data."}};
  }
}