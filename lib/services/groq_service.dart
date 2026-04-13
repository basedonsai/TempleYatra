// Groq API service for real-time public transport information
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GroqService {
  static const String baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  final String apiKey;
  
  GroqService({required this.apiKey});
  
  /// Fetch public transport options for a route
  Future<PublicTransportInfo> getPublicTransportInfo({
    required String origin,
    required String destination,
    required DateTime travelDate,
    int numberOfPassengers = 1,
  }) async {
    final prompt = _buildTransportPrompt(origin, destination, travelDate, numberOfPassengers);
    
    try {
      final response = await _callGroqAPI(prompt);
      return _parseTransportResponse(response);
    } catch (e) {
      debugPrint('Groq API error: $e');
      return _getFallbackTransportInfo(origin, destination);
    }
  }
  
  String _buildTransportPrompt(String origin, String destination, DateTime date, int passengers) {
    return '''
    Provide public transportation options from "$origin" to "$destination" on ${_formatDate(date)} for $passengers passenger(s).
    
    Include real-time information for:
    1. Bus services (government and private)
    2. Train services (if applicable)
    3. Metro/Suburban rail (if applicable)
    4. Shared taxis/Auto-rickshaws
    
    For each option, provide:
    - Operator name
    - Departure/Arrival times
    - Travel duration
    - Cost per person in INR
    - Frequency of service
    - Booking requirements
    
    Respond in valid JSON format:
    {
      "options": [
        {
          "type": "bus/train/metro/shared",
          "operator": "operator name",
          "departure_time": "HH:MM",
          "arrival_time": "HH:MM",
          "duration_hours": X.X,
          "cost_per_person": XXX,
          "frequency": "hourly/daily/ondemand",
          "booking_required": true/false,
          "booking_url": "url or null",
          "notes": "important information"
        }
      ],
      "recommendations": {
        "cheapest": "option description",
        "fastest": "option description",
        "most_convenient": "option description"
      },
      "route_tips": ["tip1", "tip2"]
    }
    
    If no direct services are available, suggest the best connections with transfers.
    ''';
  }
  
  Future<String> _callGroqAPI(String prompt) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'user',
            'content': prompt
          }
        ],
        'temperature': 0.3,
        'max_tokens': 2000,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Request timed out.'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'];
      return content.toString();
    } else {
      throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
    }
  }
  
  PublicTransportInfo _parseTransportResponse(String response) {
    try {
      // Try to extract JSON from response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonString = response.substring(jsonStart, jsonEnd);
        final data = jsonDecode(jsonString);
        
        final options = (data['options'] as List).map((o) => TransportOption.fromJson(o)).toList();
        
        return PublicTransportInfo(
          options: options,
          cheapestOption: data['recommendations']['cheapest'],
          fastestOption: data['recommendations']['fastest'],
          mostConvenientOption: data['recommendations']['most_convenient'],
          routeTips: (data['route_tips'] as List).cast<String>(),
        );
      }
      
      return _getFallbackTransportInfo('Unknown', 'Unknown');
    } catch (e) {
      debugPrint('Error parsing Groq response: $e');
      return _getFallbackTransportInfo('Unknown', 'Unknown');
    }
  }
  
  PublicTransportInfo _getFallbackTransportInfo(String origin, String destination) {
    // Provide basic bus/train information for Hyderabad region
    return PublicTransportInfo(
      options: [
        TransportOption(
          type: 'bus',
          operator: 'TSRTC (Telangana State Road Transport Corp)',
          departureTime: '06:00',
          arrivalTime: '22:00',
          durationHours: 1.5,
          costPerPerson: 50,
          frequency: 'hourly',
          bookingRequired: false,
          bookingUrl: null,
          notes: 'Government bus service, regular departures',
        ),
        TransportOption(
          type: 'bus',
          operator: 'Private Bus Operators',
          departureTime: '05:00',
          arrivalTime: '23:00',
          durationHours: 1.0,
          costPerPerson: 80,
          frequency: '30-min',
          bookingRequired: true,
          bookingUrl: 'https://www.redbus.in',
          notes: 'AC and non-AC options available',
        ),
        TransportOption(
          type: 'shared',
          operator: 'Shared Auto/Taxi',
          departureTime: '06:00',
          arrivalTime: '21:00',
          durationHours: 0.75,
          costPerPerson: 30,
          frequency: 'ondemand',
          bookingRequired: false,
          bookingUrl: null,
          notes: 'Shared rides, fill and go',
        ),
      ],
      cheapestOption: 'TSRTC Bus (₹50)',
      fastestOption: 'Private Bus (₹80)',
      mostConvenientOption: 'Private Bus with AC',
      routeTips: [
        'Book private buses through redbus.in for confirmed seats',
        'TSRTC buses are cheaper but may be crowded',
        'Shared autos are good for short distances',
        'Metro rail available for specific corridors in Hyderabad',
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  /// Estimate bus fare for a given distance
  double estimateBusFare(double distanceKm, {bool isAC = false}) {
    // Base fare: ₹10 for first 5km, ₹1.5 per km thereafter
    if (distanceKm <= 5) {
      return isAC ? 20.0 : 10.0;
    }
    final baseFare = isAC ? 20.0 : 10.0;
    final additionalFare = (distanceKm - 5) * (isAC ? 3.0 : 1.5);
    return baseFare + additionalFare;
  }
  
  /// Estimate train fare for a given distance
  double estimateTrainFare(double distanceKm, {bool isSleeper = false}) {
    if (distanceKm <= 50) {
      return isSleeper ? 30.0 : 15.0;
    }
    final baseFare = isSleeper ? 30.0 : 15.0;
    final additionalFare = (distanceKm - 50) * (isSleeper ? 0.8 : 0.4);
    return baseFare + additionalFare;
  }
}

class PublicTransportInfo {
  final List<TransportOption> options;
  final String cheapestOption;
  final String fastestOption;
  final String mostConvenientOption;
  final List<String> routeTips;
  
  PublicTransportInfo({
    required this.options,
    required this.cheapestOption,
    required this.fastestOption,
    required this.mostConvenientOption,
    required this.routeTips,
  });
  
  /// Get cheapest option
  TransportOption? getCheapestOption() {
    if (options.isEmpty) return null;
    return options.reduce((a, b) => a.costPerPerson < b.costPerPerson ? a : b);
  }
  
  /// Get fastest option
  TransportOption? getFastestOption() {
    if (options.isEmpty) return null;
    return options.reduce((a, b) => a.durationHours < b.durationHours ? a : b);
  }
  
  /// Get options by type
  List<TransportOption> getOptionsByType(String type) {
    return options.where((o) => o.type.toLowerCase() == type.toLowerCase()).toList();
  }
}

class TransportOption {
  final String type;
  final String operator;
  final String departureTime;
  final String arrivalTime;
  final double durationHours;
  final double costPerPerson;
  final String frequency;
  final bool bookingRequired;
  final String? bookingUrl;
  final String notes;
  
  TransportOption({
    required this.type,
    required this.operator,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationHours,
    required this.costPerPerson,
    required this.frequency,
    required this.bookingRequired,
    this.bookingUrl,
    required this.notes,
  });
  
  factory TransportOption.fromJson(Map<String, dynamic> json) {
    return TransportOption(
      type: json['type'] ?? 'bus',
      operator: json['operator'] ?? 'Unknown',
      departureTime: json['departure_time'] ?? '00:00',
      arrivalTime: json['arrival_time'] ?? '00:00',
      durationHours: (json['duration_hours'] ?? 0).toDouble(),
      costPerPerson: (json['cost_per_person'] ?? 0).toDouble(),
      frequency: json['frequency'] ?? 'unknown',
      bookingRequired: json['booking_required'] ?? false,
      bookingUrl: json['booking_url'],
      notes: json['notes'] ?? '',
    );
  }
  
  String get formattedCost => '₹${costPerPerson.toStringAsFixed(0)}';
  
  String get formattedDuration {
    final hours = durationHours.floor();
    final minutes = ((durationHours - hours) * 60).round();
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
  
  bool get isBookable => bookingRequired && bookingUrl != null;
}
