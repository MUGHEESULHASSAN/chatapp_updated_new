import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check location permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get the current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  static Future<String?> getAddressFromCoordinates(
      double lat, double lng) async {
    const apiKey = 'AIzaSyAj9n8GkUH-8Qev5B98MpvFtrGJggmTXQU';
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  static Future<String?> getStaticMapUrl(double lat, double lng) async {
    const apiKey = 'AIzaSyAj9n8GkUH-8Qev5B98MpvFtrGJggmTXQU';
    return 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=600x300&maptype=roadmap&markers=color:red%7C$lat,$lng&key=$apiKey';
  }
}
