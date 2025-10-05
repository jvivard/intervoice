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
    
    try {
      debugPrint('[AudioService] Requesting microphone access...');
      
      // Request microphone access
      final audioConstraints = {
        'echoCancellation': true,
        'noiseSuppression': true,
        'sampleRate': 16000, // 16kHz for speech
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
      
      // Create MediaRecorder with appropriate MIME type
      final options = web.MediaRecorderOptions(
        mimeType: 'audio/webm;codecs=opus',
      );
      
      _mediaRecorder = web.MediaRecorder(_mediaStream!, options);
      
      // Handle data available event
      _mediaRecorder!.ondataavailable = (web.Event event) {
        final blobEvent = event as web.BlobEvent;
        final blob = blobEvent.data;
        
        if (blob != null && blob.size > 0) {
          _processBlobToBytes(blob);
        }
      }.toJS;
      
      // Start recording with 100ms timeslice for streaming
      _mediaRecorder!.start(100);
      _isRecording = true;
      
      onRecordingStart?.call();
      debugPrint('[AudioService] Recording started');
      
    } catch (e) {
      debugPrint('[AudioService] Error starting recording: $e');
      throw Exception('Failed to start recording: $e');
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

