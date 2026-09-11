import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static const String _apiKey = 'AIzaSyDFcFSj2lCtou1oAf_QwEXkliWuPGfrkt8';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Fetches the current GPS coordinates of the device.
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Converts coordinates into a human-readable address.
  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
      }
    } catch (e) {
      print("Error in reverse geocoding: $e");
    }
    return "";
  }

  /// Fetches address suggestions from Google Places Autocomplete API.
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('$_baseUrl/autocomplete/json?input=$query&key=$_apiKey&libraries=places&language=en');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
    } catch (e) {
      print("Error in autocomplete: $e");
    }
    return [];
  }

  /// Fetches latitude and longitude for a specific place ID.
  Future<Map<String, double>?> getPlaceDetails(String placeId) async {
    final url = Uri.parse('$_baseUrl/details/json?place_id=$placeId&key=$_apiKey&language=en');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return {
            'lat': location['lat'] as double,
            'lng': location['lng'] as double,
          };
        }
      }
    } catch (e) {
      print("Error fetching place details: $e");
    }
    return null;
  }
}
