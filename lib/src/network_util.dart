import 'dart:convert';

import '../src/utils/polyline_decoder.dart';
import '../src/utils/polyline_request.dart';
import 'package:http/http.dart' as http;

import 'utils/polyline_result.dart';

class NetworkUtil {
  static const String STATUS_OK = "ok";

  ///Get the encoded string from google directions api
  ///
  Future<List<PolylineResult>> getRouteBetweenCoordinatesOld({
    required PolylineRequest request,
    String? googleApiKey,
  }) async {
    List<PolylineResult> results = [];

    var response = await http.get(
      request.toUri(apiKey: googleApiKey),
      headers: request.headers,
    );
    if (response.statusCode == 200) {
      var parsedJson = json.decode(response.body);
      if (parsedJson["status"]?.toLowerCase() == STATUS_OK &&
          parsedJson["routes"] != null &&
          parsedJson["routes"].isNotEmpty) {
        List<dynamic> routeList = parsedJson["routes"];
        for (var route in routeList) {
          results.add(PolylineResult(
            points: PolylineDecoder.run(route["overview_polyline"]["points"]),
            errorMessage: "",
            status: parsedJson["status"],
            totalDistanceValue: route['legs']
                .map((leg) => leg['distance']['value'])
                .reduce((v1, v2) => v1 + v2),
            distanceTexts: <String>[
              ...route['legs'].map((leg) => leg['distance']['text'])
            ],
            distanceValues: <int>[
              ...route['legs'].map((leg) => leg['distance']['value'])
            ],
            overviewPolyline: route["overview_polyline"]["points"],
            totalDurationValue: route['legs']
                .map((leg) => leg['duration']['value'])
                .reduce((v1, v2) => v1 + v2),
            durationTexts: <String>[
              ...route['legs'].map((leg) => leg['duration']['text'])
            ],
            durationValues: <int>[
              ...route['legs'].map((leg) => leg['duration']['value'])
            ],
            endAddress: route["legs"].last['end_address'],
            startAddress: route["legs"].first['start_address'],
          ));
        }
      } else {
        throw Exception(
            "Unable to get route: Response ---> ${parsedJson["status"]} ");
      }
    }
    return results;
  }
   Future<List<PolylineResult>> getRouteBetweenCoordinates({
    required PolylineRequest request,
    required String googleApiKey,
  }) async {
    List<PolylineResult> results = [];
    final Uri url = Uri.parse("https://routes.googleapis.com/directions/v2:computeRoutes");

    // Construct request body
    final Map<String, dynamic> requestBody = {
      "origin": {
        "location": {
          "latLng": {"latitude": request.origin.latitude, "longitude": request.origin.longitude}
        }
      },
      "destination": {
        "location": {
          "latLng": {"latitude": request.destination.latitude, "longitude": request.destination.longitude}
        }
      },
      "travelMode": "DRIVE",// Example: "DRIVE"
    };

    print("🔹 API Request: ${jsonEncode(requestBody)}");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": googleApiKey,
        "X-Goog-FieldMask": "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline",
      },
      body: jsonEncode(requestBody),
    );

    print("🔹 API Response Code: ${response.statusCode}");
    print("🔹 API Response: ${response.body}");

    if (response.statusCode == 200) {
      final parsedJson = json.decode(response.body);

      if (parsedJson["routes"] != null && parsedJson["routes"].isNotEmpty) {
        for (var route in parsedJson["routes"]) {
          results.add(PolylineResult(
            points: PolylineDecoder.run(route["polyline"]["encodedPolyline"]),
            errorMessage: "",
            status: STATUS_OK,
            totalDistanceValue: route["distanceMeters"],
            distanceTexts: [route["distanceMeters"].toString() + " meters"],
            distanceValues: [route["distanceMeters"]],
            overviewPolyline: route["polyline"]["encodedPolyline"],
            totalDurationValue: _parseDuration(route["duration"]),
            durationTexts: [_formatDuration(route["duration"])],
            durationValues: [_parseDuration(route["duration"])],
            startAddress: "Start Location", // No direct address in API response
            endAddress: "End Location",
          ));
        }
      }
    } else {
      throw Exception("Failed to fetch routes: ${response.body}");
    }

    return results;
  }

  /// Converts Google API duration format "1094s" to an integer (seconds)
  int _parseDuration(String duration) {
    return int.parse(duration.replaceAll("s", ""));
  }

  /// Formats duration into a human-readable format (e.g., "18 min")
  String _formatDuration(String duration) {
    int seconds = _parseDuration(duration);
    int minutes = (seconds / 60).round();
    return "$minutes min";
  }

}
