import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mapTools;
import 'map.dart';
import 'panel.dart';
import 'server.dart';

final appBar = AppBar(title: const Text('Tre traffic'), backgroundColor: Colors.blue[900]);
final Server _server = Server();

bool nextReached = false;
bool serviceEnabled = false;
bool timerRun = false;

List<String> _currentLigthGroupNumbers = [];
List<String> currentValues = [];

String nextIntersectionNro = '';

late Function updatePanelState;
late LatLng latestLocation;
late LocationPermission permission;
late Timer _timer;
late Timer locationUpdater;

Distance distance = const Distance();

void main() => runApp(MyApp()); 

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State {
  PanelController panelController = PanelController();
  Map<LatLng, String> areas = getServer().triggerPoints;

  @override
  Widget build(BuildContext context) {
    checkPermissionAndStartLocStream();
    updatePanelState = updatePanelContent;
    return MaterialApp(
      home: SafeArea(child: Scaffold(
        appBar: appBar,
        body: SlidingUpPanel(
          body: Container(child: MapView(), margin: const EdgeInsets.only(bottom: 79)),
          panelBuilder: (sc) => SlidePanel(sc, _currentLigthGroupNumbers),
          controller: panelController,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30.0), topRight: Radius.circular(30.0)),
          minHeight: 230,
          maxHeight: 230,
          isDraggable: false,
        ),
      )),
    );
  }

  checkLocation(LatLng currentLoc) {
    for (LatLng loc in areas.keys) {
      if (distance(LatLng(currentLoc.latitude, currentLoc.longitude), loc) < 40) {
        updatePanelContent(getServer().getRoute(areas[loc]));
      }
    }
    for (List<mapTools.LatLng> coordinates in getServer().triggerAreas.keys) {
      if (mapTools.PolygonUtil.containsLocation(mapTools.LatLng(currentLoc.latitude, currentLoc.longitude), coordinates, false)) {
        updatePanelContent(getServer().getRoute(getServer().triggerAreas[coordinates]));
      }
    }

    if (nextIntersectionNro != '') {
      double distanceNextCross = distance(LatLng(currentLoc.latitude, currentLoc.longitude), getServer().getIntersectionLocs()[nextIntersectionNro]!);
      if (!nextReached && distanceNextCross < 35) {
        nextReached = true;
      } else if (nextReached && distanceNextCross > 35) {
        nextReached = false;
        currentValues.removeWhere((nro) => nro.contains(nextIntersectionNro));
        nextIntersectionNro = '';
        if (currentValues.isEmpty) {
          hidePanel();
        }
      }
    }
  }

  checkPermissionAndStartLocStream() async {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
    Position? pos = await Geolocator.getLastKnownPosition();
    if (pos == null) {
      return;
    }
    latestLocation = LatLng(pos.latitude, pos.longitude);
    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) async {
            checkLocation(LatLng(position.latitude, position.longitude));
            double halfwayLat = (latestLocation.latitude + position.latitude) / 2;
            double halfwayLong = (latestLocation.longitude + position.longitude) / 2;

            checkLocation(LatLng(halfwayLat, halfwayLong));
        });
  }

  Future<Map<String, dynamic>> fetchIntersectionStatusData(String intersectionNro) async {
    Map<String, dynamic> responseJson = await getJson('http://trafficlights.tampere.fi/api/v1/deviceState/tre$intersectionNro');
    responseJson.remove("responseTs");
    responseJson.remove("timestamp");
    return responseJson;
  }

  hidePanel() {
    if (timerRun) {
      _timer.cancel();
      timerRun = false;
    }
    panelController.hide();
  }

  updatePanelContent(List<String> lightGroupNumbers) async {
    if (lightGroupNumbers.isEmpty) {
      hidePanel();
      return;
    }
    _currentLigthGroupNumbers = lightGroupNumbers;
    if (timerRun) {
      _timer.cancel();
    }
    timerRun = true;
    nextIntersectionNro = _currentLigthGroupNumbers[0].substring(0, 3);
    
    getServer().updateStatusData(nextIntersectionNro, await fetchIntersectionStatusData(nextIntersectionNro));
    panelController.show();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {updateLightStatuses();});
  }

  updateLightStatuses() async {
    for (String intersectionLightGroupIds in _currentLigthGroupNumbers) {
      String intersectionNro = intersectionLightGroupIds.substring(0, 3);
      Map<String, dynamic> responseJson = await fetchIntersectionStatusData(intersectionNro);
      dynamic intersectionLights = getServer().intersectionsStatusData[intersectionNro];
      if (intersectionLights == null) {
        getServer().intersectionsStatusData.putIfAbsent(intersectionNro, () => responseJson);
        continue;
      }
      dynamic responseList = responseJson["signalGroup"];
      dynamic deviceStatus = '';
      String newColor = '';
      for (int i = 0; i < responseList.length; i++) {
        deviceStatus = responseList[i]["status"];
        if (!getServer().isSameColor(deviceStatus, intersectionLights["signalGroup"][i]["status"])) {
          newColor = deviceStatus;
          responseList[i]["status"] = "x";
          getServer().updateStatusData(intersectionNro, responseJson);
          panelController.show();
          Future.delayed(const Duration(milliseconds: 130), () {
            responseList[i]["status"] = newColor;
            getServer().updateStatusData(intersectionNro, responseJson);
            panelController.show();
          });
        }
      }
    }
  }
}

Server getServer() {
  return _server;
}