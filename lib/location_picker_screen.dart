import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
//import 'package:geolocator/geolocator.dart';
import 'package:chat_application/services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final Function(LatLng, String?) onLocationSelected;

  const LocationPickerScreen({Key? key, required this.onLocationSelected})
      : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late GoogleMapController _mapController;
  LatLng? _selectedLocation;
  String? _address;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _getAddress();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddress() async {
    if (_selectedLocation != null) {
      final address = await LocationService.getAddressFromCoordinates(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      setState(() => _address = address);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                widget.onLocationSelected(_selectedLocation!, _address);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 2,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: (LatLng location) {
              setState(() {
                _selectedLocation = location;
                _address = null;
              });
              _getAddress();
            },
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selectedLocation'),
                      position: _selectedLocation!,
                    ),
                  }
                : {},
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_address != null && !_isLoading)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _address ?? 'Selected Location',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Lat: ${_selectedLocation?.latitude.toStringAsFixed(4)}, '
                      'Lng: ${_selectedLocation?.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        onPressed: _getCurrentLocation,
      ),
    );
  }
}
