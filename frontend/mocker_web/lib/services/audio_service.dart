import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Audio service to handle microphone recording and audio playback for Flutter Web
class AudioService {
  // Audio recording
  web.MediaStream? _mediaStream;
  web.MediaRecorder? _mediaRecorder;
  bool _isRecording = false;
  bool _isRequestingAccess = false; // Prevent concurrent access requests
  
  // Audio playback
  web.AudioContext? _audioContext;
  bool _isPlaying = false;
  
  // Callbacks
  Function(Uint8List)? onAudioChunk;
  Function()? onRecordingStart;
  Function()? onRecordingStop;
  Function()? onPlaybackStart;
  Function()? onPlaybackComplete;
  
  /// Initialize audio context for playback
  Future<void> initialize() async {
    try {
      _audioContext = web.AudioContext();
      debugPrint('[AudioService] Initialized successfully');
    } catch (e) {
      debugPrint('[AudioService] Error initializing: $e');
      throw Exception('Failed to initialize audio service: $e');
    }
  }
  
  /// Start recording audio from microphone
  Future<void> startRecording() async {
    if (_isRecording) {
      debugPrint('[AudioService] Already recording');
      return;
    }
    
    if (_isRequestingAccess) {
      debugPrint('[AudioService] Already requesting microphone access, skipping duplicate request');
      return;
    }
    
    _isRequestingAccess = true;
    
    try {
      debugPrint('[AudioService] Requesting microphone access...');
      
      // Request microphone access (keep constraints minimal for compatibility)
      final audioConstraints = {
        'echoCancellation': true,
        'noiseSuppression': true,
      }.jsify();
      
      // NOTE: The `web` interop types expect JSAny for fields. Use `jsify` for maps and
      // wrap primitives in an object map when needed. Here, passing `video` flag as
      // a JS object ensures it is treated correctly by the interop layer.
      final constraints = web.MediaStreamConstraints(
        audio: audioConstraints!,
        video: ({'enabled': false}).jsify()!,
      );
      
      _mediaStream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      
      debugPrint('[AudioService] Microphone access granted');
      
      // Create MediaRecorder with a compatible MIME type (try fallbacks)
      final mimeCandidates = <String>[
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/ogg;codecs=opus', // Firefox
      ];

      web.MediaRecorder? recorder;
      for (final mime in mimeCandidates) {
        try {
          final opts = web.MediaRecorderOptions(mimeType: mime);
          recorder = web.MediaRecorder(_mediaStream!, opts);
          debugPrint('[AudioService] Using MediaRecorder mimeType: $mime');
          break;
        } catch (e) {
          debugPrint('[AudioService] MediaRecorder not supported for $mime: $e');
        }
      }

      // Final fallback: let browser decide without options
      recorder ??= web.MediaRecorder(_mediaStream!);
      _mediaRecorder = recorder;
      
      // Handle data available event
      _mediaRecorder!.ondataavailable = (web.Event event) {
        final blobEvent = event as web.BlobEvent;
        final blob = blobEvent.data;
        
        if (blob != null && blob.size > 0) {
          _processBlobToBytes(blob);
        }
      }.toJS;

      // Lifecycle events for better state tracking
      _mediaRecorder!.onstart = (web.Event event) {
        _isRecording = true;
        onRecordingStart?.call();
        debugPrint('[AudioService] MediaRecorder onstart');
      }.toJS;

      _mediaRecorder!.onstop = (web.Event event) {
        _isRecording = false;
        onRecordingStop?.call();
        debugPrint('[AudioService] MediaRecorder onstop');
      }.toJS;

      _mediaRecorder!.onerror = (web.Event event) {
        debugPrint('[AudioService] MediaRecorder onerror: $event');
      }.toJS;
      
      // Start recording; if timeslice not supported, retry without it
      try {
        _mediaRecorder!.start(100); // request frequent dataavailable events
        // onstart handler will set _isRecording
      } catch (e) {
        debugPrint('[AudioService] start(100) failed, checking state: $e');
        // Some browsers throw but actually begin recording; treat that as success
        if (_mediaRecorder!.state == 'recording') {
          debugPrint('[AudioService] MediaRecorder state is recording; proceeding');
        } else {
          debugPrint('[AudioService] retrying start() without timeslice');
          try {
            _mediaRecorder!.start();
            // onstart handler will set _isRecording
          } catch (e2) {
            // If state flipped to recording between attempts, accept success
            if (_mediaRecorder!.state == 'recording') {
              debugPrint('[AudioService] MediaRecorder state is recording after retry; proceeding');
            } else {
              debugPrint('[AudioService] start() failed: $e2');
              throw Exception('Failed to start recording: $e2');
            }
          }
        }
      }
      
      onRecordingStart?.call();
      debugPrint('[AudioService] Recording started');
      
    } catch (e) {
      debugPrint('[AudioService] Error starting recording: $e');
      throw Exception('Failed to start recording: $e');
    } finally {
      _isRequestingAccess = false;
    }
  }
  
  /// Stop recording audio
  Future<void> stopRecording() async {
    if (!_isRecording) {
      debugPrint('[AudioService] Not currently recording');
      return;
    }
    
    try {
      _mediaRecorder?.stop();
      
      // Stop all tracks
      final tracks = _mediaStream?.getAudioTracks().toDart;
      if (tracks != null) {
        for (final track in tracks) {
          track.stop();
        }
      }
      
      _mediaStream = null;
      _mediaRecorder = null;
      _isRecording = false;
      
      onRecordingStop?.call();
      debugPrint('[AudioService] Recording stopped');
      
    } catch (e) {
      debugPrint('[AudioService] Error stopping recording: $e');
      throw Exception('Failed to stop recording: $e');
    }
  }
  
  /// Process blob to bytes and invoke callback
  void _processBlobToBytes(web.Blob blob) async {
    try {
      final reader = web.FileReader();
      
      reader.onload = (web.Event event) {
        final arrayBuffer = (reader.result as JSArrayBuffer);
        final uint8List = arrayBuffer.toDart.asUint8List();
        
        if (uint8List.isNotEmpty && onAudioChunk != null) {
          onAudioChunk!(uint8List);
          debugPrint('[AudioService] Audio chunk processed: ${uint8List.length} bytes');
        }
      }.toJS;
      
      reader.readAsArrayBuffer(blob);
      
    } catch (e) {
      debugPrint('[AudioService] Error processing blob: $e');
    }
  }
  
  /// Play audio from base64-encoded PCM data
  Future<void> playAudio(String base64Data) async {
    if (_audioContext == null) {
      debugPrint('[AudioService] Audio context not initialized');
      return;
    }
    
    if (_isPlaying) {
      debugPrint('[AudioService] Already playing audio');
      return;
    }
    
    try {
      _isPlaying = true;
      onPlaybackStart?.call();
      debugPrint('[AudioService] Starting audio playback...');
      
      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);
      
      // Convert to Float32List for Web Audio API
      // Assuming 16-bit PCM, 16kHz, mono
      final pcm16 = bytes.buffer.asInt16List();
      final float32 = Float32List(pcm16.length);
      for (var i = 0; i < pcm16.length; i++) {
        float32[i] = pcm16[i] / 32768.0; // Convert to -1.0 to 1.0 range
      }
      
      // Create audio buffer
      const sampleRate = 16000;
      const channels = 1;
      final audioBuffer = _audioContext!.createBuffer(
        channels,
        float32.length,
        sampleRate,
      );
      
      // Copy data to buffer
      final channelData = audioBuffer.getChannelData(0).toDart;
      for (var i = 0; i < float32.length; i++) {
        channelData[i] = float32[i];
      }
      
      // Create source and play
      final source = _audioContext!.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(_audioContext!.destination);
      
      // Handle playback end
      source.onended = (web.Event event) {
        _isPlaying = false;
        onPlaybackComplete?.call();
        debugPrint('[AudioService] Playback completed');
      }.toJS;
      
      source.start();
      debugPrint('[AudioService] Audio playback started');
      
    } catch (e) {
      _isPlaying = false;
      debugPrint('[AudioService] Error playing audio: $e');
      throw Exception('Failed to play audio: $e');
    }
  }
  
  /// Check if currently recording
  bool get isRecording => _isRecording;
  
  /// Check if currently playing audio
  bool get isPlaying => _isPlaying;
  
  /// Clean up resources
  void dispose() {
    stopRecording();
    _audioContext?.close();
    _audioContext = null;
    debugPrint('[AudioService] Disposed');
  }
}

