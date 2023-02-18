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
    LatLng(61.498947, 23.784609): 'sammonaukio:tamk',
    LatLng(61.503598, 23.816772): 'tamk:sammonaukio',
    LatLng(61.490728, 23.812822): 'vuohenoja:ita',
    LatLng(61.486406, 23.829730): 'vuohenoja:lansi',
    LatLng(61.478624, 23.871017): 'vt9S:messukylankatu',
    LatLng(61.480922, 23.872790): 'vt9N:sammonvaltatie',
  };

  //Polygon coordinates, routeName
  Map<List<mapTools.LatLng>, String> triggerAreas = {
    [mapTools.LatLng(61.497292, 23.881377), mapTools.LatLng(61.497175, 23.881034),
      mapTools.LatLng(61.497799, 23.879403), mapTools.LatLng(61.498027, 23.879886)]: 'linnainmaa:teiskontie',
  };

  //Routename, [numero;suunta:suunta]
  Map<String, List<String>> routes = {
    'linnainmaa:teiskontie': ['608;3'],
    'sammonaukio:tamk': ['401;1:2', '424;1:2'],
    'tamk:sammonaukio': ['601;3:4'],
    'vuohenoja:ita': ['509;1'],
    'vuohenoja:lansi': ['509;3'],
    'vt9S:messukylankatu': ['663;3'],
    'vt9N:sammonvaltatie': ['666;3'],
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

  updateStatusData(String intersectionNro, Map<String, dynamic> json) {
    intersectionsStatusData.update(intersectionNro, (_) => json, ifAbsent: () => json);
  }
}