import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mapTools;

import 'dart:convert';

class Server {

  Map<String, LatLng> intersectionLocs = {};

  //intersectionNro, statusJson
  Map<String, dynamic> intersectionsStatusData = {};

  Map<String, dynamic> lightGroupsByDirection = {};


  loadLigthGroups() async {
    String lightGroupsResponse = await rootBundle.loadString('assets/lightGroups.json');
    lightGroupsByDirection = json.decode(lightGroupsResponse);
  }

  //LatLong, routeName
  Map<LatLng, String> triggerPoints = {
    LatLng(61.503598, 23.816772): 'tays:sammonaukio',
    LatLng(61.490728, 23.812822): 'vuohenoja:ita',
    LatLng(61.486406, 23.829730): 'vuohenoja:lansi',
    LatLng(61.478624, 23.871017): 'vt9S:messukylankatu',
    LatLng(61.480922, 23.872790): 'vt9N:sammonvaltatie',
  };

  //Polygon coordinates (counter clockwise order), routeName
  Map<List<mapTools.LatLng>, String> triggerAreas = {
    [mapTools.LatLng(61.497292, 23.881377), mapTools.LatLng(61.497175, 23.881034),
      mapTools.LatLng(61.497799, 23.879403), mapTools.LatLng(61.498015, 23.879873)]: 'linnainmaa:teiskontie',

    [mapTools.LatLng(61.498869, 23.782754), mapTools.LatLng(61.498859, 23.780938),
      mapTools.LatLng(61.498978, 23.780947), mapTools.LatLng(61.498987, 23.782747)]: 'itsenäisyydenkatu:hippos',
  };

  //Routename, [numero;suunta:suunta]
  Map<String, List<String>> routes = {
    'itsenäisyydenkatu:hippos': ['428;1:2', '401;1:2', '424;1:2', '423;1', '501;1', '601;1:2'],
    'linnainmaa:teiskontie': ['608;3'],
    'tays:sammonaukio': ['601;3:4', '501;2', '423;2', '424;3:4', '401;3:4'],
    'vt9S:messukylankatu': ['663;3'],
    'vt9N:sammonvaltatie': ['666;3'],
    'vuohenoja:ita': ['509;1'],
    'vuohenoja:lansi': ['509;3'],
  };

  List<String> getAllDirectionsFromIntersection(String intersectionNro) {
    String route = intersectionNro + ";";
    Iterable<String> directions = getDirectionGroupsFromIntersection(intersectionNro)!.keys;
    route += directions.join(":");
    return [route];
  }

  Map<String, dynamic>? getDirectionGroupsFromIntersection(String intersectionNro) {
    return lightGroupsByDirection[intersectionNro];
  }

  Map<String, dynamic>? getIntersections() {
    return lightGroupsByDirection;
  }

  Map<String, LatLng> getIntersectionLocs() {
    return intersectionLocs;
  }

  List<String> getRoute(routeName) {
    return routes[routeName]!;
  }

  bool isSameColor(String status1, String status2) {
  if (status1 == status2) {
    return true;
  }
  if (("ABCDEFGH9".contains(status1) && "ABCDEFGH9".contains(status2)) ||
      (":<0".contains(status1) && ":<0".contains(status2)) ||
      ("1345678".contains(status1) && "1345678".contains(status2))) {
    return true;
  }
  return false;
}

  updateStatusData(String intersectionNro, Map<String, dynamic> json) {
    intersectionsStatusData.update(intersectionNro, (_) => json, ifAbsent: () => json);
  }
}