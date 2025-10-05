import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../models/workflow.dart';
import '../models/interview.dart';
import '../services/workflow_service.dart';
import '../services/interview_service.dart';
import '../services/audio_service.dart';
import '../widgets/navbar.dart';
import '../theme/app_theme.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

// interview state enum
enum InterviewState {
  selectWorkflow,    // select workflow
  readyToStart,      // workflow selected, ready to start
  interviewing,      // interviewing
  showingFeedback    // showing feedback
}

class MockInterviewPage extends StatefulWidget {
  const MockInterviewPage({super.key});

  @override
  State<MockInterviewPage> createState() => _MockInterviewPageState();
}

class _MockInterviewPageState extends State<MockInterviewPage> {
  final WorkflowService _workflowService = WorkflowService();
  final InterviewService _interviewService = InterviewService();
  final AudioService _audioService = AudioService();
  
  // Interview state management
  InterviewState _currentState = InterviewState.selectWorkflow;
  
  // Workflow selection state
  Workflow? _selectedWorkflow;
  List<Workflow> _availableWorkflows = [];
  bool _loadingWorkflows = true;
  String? _workflowsError;
  
  // Interview duration selection
  int _selectedDuration = 15; // default 15 minutes
  final List<int> _durationOptions = [5, 10, 15, 20, 30, 45, 60];
  
  // Interview mode selection
  bool _isVoiceMode = false; // false = text, true = voice
  bool _isRecording = false; // Voice recording state
  bool _isPlayingAudio = false; // AI audio playback state
  
  // Interview state
  List<ChatMessage> _messages = [];
  String _streamingMessage = '';  // Current streaming message from AI
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _loadingChat = false;
  String? _sessionId;
  bool _wsConnected = false;
  bool _interviewActuallyStarted = false; // Flag to track if interview actually started

  // Real-time timer state
  DateTime? _interviewStartTime;
  Timer? _interviewTimer;
  Duration _elapsedTime = Duration.zero;
  
  // Feedback state
  Map<String, dynamic>? _feedbackData;
  bool _loadingFeedback = false;
  String? _feedbackError;
  bool _feedbackRequested = false;
  
  // Polling state
  Timer? _feedbackPollingTimer;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 30; 
  static const Duration _pollingInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _loadAvailableWorkflows();
    _initializeAudioService();
  }

  Future<void> _initializeAudioService() async {
    try {
      await _audioService.initialize();
      
      // Set up audio service callbacks
      _audioService.onAudioChunk = (Uint8List audioData) {
        // Convert audio data to base64 and send via WebSocket
        final base64Audio = base64Encode(audioData);
        _interviewService.sendAudioData(base64Audio);
      };
      
      _audioService.onRecordingStart = () {
        setState(() => _isRecording = true);
      };
      
      _audioService.onRecordingStop = () {
        setState(() => _isRecording = false);
      };
      
      _audioService.onPlaybackStart = () {
        setState(() => _isPlayingAudio = true);
      };
      
      _audioService.onPlaybackComplete = () {
        setState(() => _isPlayingAudio = false);
      };
      
      debugPrint('[MockInterview] Audio service initialized');
    } catch (e) {
      debugPrint('[MockInterview] Failed to initialize audio service: $e');
    }
  }

  Future<void> _loadAvailableWorkflows() async {
    try {
      setState(() {
        _loadingWorkflows = true;
        _workflowsError = null;
      });
      
      // get all workflows, then filter out the ones that are not prepared (have personalExperience)
      final allWorkflows = await _workflowService.getWorkflows();
      final availableWorkflows = allWorkflows
          .where((workflow) => workflow.personalExperience != null)
          .toList();
      
      setState(() {
        _availableWorkflows = availableWorkflows;
        _loadingWorkflows = false;
      });
    } catch (e) {
      setState(() {
        _workflowsError = e.toString();
        _loadingWorkflows = false;
      });
    }
  }

  void _selectWorkflow(Workflow workflow) {
    setState(() {
      _selectedWorkflow = workflow;
      _currentState = InterviewState.readyToStart;
    });
  }

  Future<void> _startInterview() async {
    if (_selectedWorkflow == null) return;
    
    setState(() {
      _currentState = InterviewState.interviewing;
      _loadingChat = true;
    });

    try {
      // 1. first call /interviews/start API
      final sessionData = await _interviewService.startInterviewSession(
        _selectedWorkflow!.id,
        _selectedDuration, // use user selected duration
        _isVoiceMode, // use selected mode (text or voice)
      );

      // 2. get connection information from API response
      final sessionId = sessionData['session_id'];
      final websocketParameter = sessionData['websocket_parameter'];

      // 3. set WebSocket listener
      _interviewService.setWebSocketListeners(
        onMessageReceived: (message) {
          setState(() {
            _messages.add(message);
            // Mark interview as actually started when first message is received
            if (!_interviewActuallyStarted) {
              _interviewActuallyStarted = true;
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        },
        onAudioReceived: (base64AudioData) async {
          // Play received audio in voice mode
          if (_isVoiceMode) {
            try {
              await _audioService.playAudio(base64AudioData);
            } catch (e) {
              debugPrint('[MockInterview] Error playing audio: $e');
            }
          }
        },
        onDisconnected: () async {
          setState(() => _wsConnected = false);
          _stopInterviewTimer(); // stop timer when disconnected
          // Only trigger feedback flow if interview actually started and not already requested
          if (_feedbackRequested || !_interviewActuallyStarted) return;
          _feedbackRequested = true;
          if (_sessionId != null && _selectedWorkflow != null) {
            setState(() => _loadingFeedback = true);
            _startFeedbackPolling();
          }
        },
        onError: (error) {
          setState(() => _wsConnected = false);
          _stopInterviewTimer(); // stop timer on error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('WebSocket error: $error')),
          );
        },
      );

      // 4. connect WebSocket
      await _interviewService.connectWebSocket(sessionId, websocketParameter);
      
      setState(() {
        _sessionId = sessionId;
        _wsConnected = _interviewService.isWebSocketConnected;
        _messages.clear();
        _loadingChat = false;
      });

      // 5. Start the interview timer
      _startInterviewTimer();

    } catch (e) {
      setState(() {
        _loadingChat = false;
        _wsConnected = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start interview: $e')),
      );
    }
  }

  void _goBackToWorkflowSelection() {
    setState(() {
      _currentState = InterviewState.selectWorkflow;
      _selectedWorkflow = null;
      _messages.clear();
      _wsConnected = false;
      _feedbackData = null;
      _feedbackError = null;
      _feedbackRequested = false;
      _pollingAttempts = 0;
      _elapsedTime = Duration.zero;
      _interviewStartTime = null;
      _interviewActuallyStarted = false; // Reset the interview started flag
    });
    _stopInterviewTimer();
    _feedbackPollingTimer?.cancel();
    _interviewService.disconnectWebSocket();
  }

  // end interview method
  Future<void> _endInterview() async {
    if (_sessionId == null) return;

    _stopInterviewTimer(); // stop timer when ending interview

    setState(() {
      _loadingFeedback = true;
      _feedbackError = null;
    });

    try {
      // 1. send end signal through WebSocket 
      if (_wsConnected) {
        _interviewService.sendMessage(json.encode({
          'type': 'control',
          'action': 'end_interview',
          'reason': 'user_stopped'
        }));
      }

      // 2. disconnect WebSocket
      _interviewService.disconnectWebSocket();
    } catch (e) {
      setState(() {
        _feedbackError = e.toString();
        _loadingFeedback = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end interview: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _selectedWorkflow == null || !_interviewService.isWebSocketConnected) return;
    
    final userMessage = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _sending = true;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    
    try {
      // send to WebSocket
      _interviewService.sendMessage(text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  // Build text input widget for text mode
  Widget _buildTextInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderGray),
            ),
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.darkGray,
              ),
              decoration: const InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: _sending ? null : _sendMessage,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  // Build voice controls widget for voice mode
  Widget _buildVoiceControls() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Prevent overflow
        children: [
          // Status indicator
          if (_isPlayingAudio)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI is speaking...',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          // Microphone button
          GestureDetector(
            onTapDown: (_) async {
              if (_isPlayingAudio) return; // Don't record while AI is speaking
              try {
                await _audioService.startRecording();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to start recording: $e'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            onTapUp: (_) async {
              if (_audioService.isRecording) {
                try {
                  await _audioService.stopRecording();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to stop recording: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            onTapCancel: () async {
              if (_audioService.isRecording) {
                try {
                  await _audioService.stopRecording();
                } catch (e) {
                  debugPrint('[MockInterview] Error canceling recording: $e');
                }
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : AppTheme.primaryBlue,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : AppTheme.primaryBlue).withOpacity(0.3),
                    blurRadius: _isRecording ? 20 : 10,
                    spreadRadius: _isRecording ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording ? 'Recording...' : 'Hold to speak',
            style: TextStyle(
              color: _isRecording ? Colors.red : AppTheme.mediumGray,
              fontSize: 14,
              fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _feedbackPollingTimer?.cancel();
    _stopInterviewTimer();
    _interviewService.disconnectWebSocket();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: NavBar(
          title: _getHeaderTitle(),
          actions: _buildNavBarActions(),
        ),
      ),
      body: Column(
        children: [
        // Main content
        Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
          child: _buildCurrentPage(),
            ),
          ),
        ],
      ),
    );
  }

  // build main header
  Widget _buildMainHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderGray),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getHeaderTitle(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGray,
            ),
          ),
          ..._buildNavBarActions() ?? [],
        ],
      ),
    );
  }

  // get header title according to the current state
  String _getHeaderTitle() {
    switch (_currentState) {
      case InterviewState.selectWorkflow:
        return 'Mock Interview';
      case InterviewState.readyToStart:
        return 'Prepare for Your Interview';
      case InterviewState.interviewing:
        return 'Interview in Progress';
      case InterviewState.showingFeedback:
        return 'Interview Feedback';
      default:
        return 'Mock Interview';
    }
  }

  // build NavBar actions
  List<Widget>? _buildNavBarActions() {
    switch (_currentState) {
      case InterviewState.readyToStart:
        return [
          // Back to Selection button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentState = InterviewState.selectWorkflow;
                  _selectedWorkflow = null;
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Selection'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
              ),
            ),
          ),
        ];
      case InterviewState.interviewing:
        return [
          // STOP Interview button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _endInterview,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('STOP Interview'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Back to Selection button
          TextButton.icon(
            onPressed: _goBackToWorkflowSelection,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Selection'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.mediumGray,
            ),
          ),
        ];
      case InterviewState.showingFeedback:
        return [
          // Back to Selection button
          TextButton.icon(
            onPressed: _goBackToWorkflowSelection,
            icon: const Icon(Icons.refresh),
            label: const Text('Start another interview'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
            ),
          ),
        ];
      default:
        return null;
    }
  }

  // build the page according to the current state
  Widget _buildCurrentPage() {
    switch (_currentState) {
      case InterviewState.selectWorkflow:
        return _buildWorkflowSelectionPage();
      case InterviewState.readyToStart:
        return _buildReadyToStartPage();
      case InterviewState.interviewing:
        return _buildChatPage();
      case InterviewState.showingFeedback:
        return _buildFeedbackPage();
    }
  }

  Widget _buildWorkflowSelectionPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 32.0),
      child: Container(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a Position for Mock Interview',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose one of your prepared workflows to start the mock interview',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            if (_loadingWorkflows)
              const Center(child: CircularProgressIndicator())
            else if (_workflowsError != null)
              Center(child: Text('Error: $_workflowsError'))
            else if (_availableWorkflows.isEmpty)
              const Center(child: Text('No prepared workflows available.'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _availableWorkflows.length,
                  itemBuilder: (context, index) {
                    final workflow = _availableWorkflows[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        title: Text(
                          workflow.position,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                      fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          workflow.company,
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _selectWorkflow(workflow),
                      ),
                    );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyToStartPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 32.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // Interview Details Card
            Container(
              width: double.infinity,
                padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderGray),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                  ),
                ],
              ),
                child: Column(
                children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 48,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                          Text(
                      'Ready to Start Your Mock Interview?',
                      style: TextStyle(
                        fontSize: 28,
                              fontWeight: FontWeight.bold,
                        color: AppTheme.darkGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Interview Details
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderGray),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.work_outline,
                            'Position',
                            _selectedWorkflow?.position ?? '',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.business,
                            'Company',
                            _selectedWorkflow?.company ?? '',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.timer_outlined,
                            'Duration',
                            '$_selectedDuration minutes',
                              ),
                            ],
                          ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Duration Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                    Text(
                    'Interview Duration',
                    style: TextStyle(
                                        fontSize: 16,
                      fontWeight: FontWeight.w600,
                            color: AppTheme.darkGray,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _durationOptions.map((duration) {
                            final isSelected = duration == _selectedDuration;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedDuration = duration;
                                });
                              },
                                        child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                          ),
                    decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryBlue
                                      : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryBlue
                                        : AppTheme.borderGray,
                                  ),
                                          ),
                                          child: Text(
                                  '$duration min',
                                            style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.darkGray,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                        );
                      }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Interview Mode Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interview Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGray,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Text Mode Button
                            Expanded(
                              child: InkWell(
                                onTap: () {
                          setState(() {
                                    _isVoiceMode = false;
                                  });
                                },
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                              decoration: BoxDecoration(
                                    color: !_isVoiceMode
                                        ? AppTheme.primaryBlue
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: !_isVoiceMode
                                          ? AppTheme.primaryBlue
                                          : AppTheme.borderGray,
                                      width: 2,
                                    ),
                                  ),
        child: Column(
          children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        color: !_isVoiceMode
                                            ? Colors.white
                                            : AppTheme.darkGray,
                                        size: 32,
            ),
            const SizedBox(height: 8),
            Text(
                                        'Text Chat',
              style: TextStyle(
                                          color: !_isVoiceMode
                                              ? Colors.white
                                              : AppTheme.darkGray,
                                          fontWeight: !_isVoiceMode
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Voice Mode Button
            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isVoiceMode = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isVoiceMode
                                        ? AppTheme.primaryBlue
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isVoiceMode
                                          ? AppTheme.primaryBlue
                                          : AppTheme.borderGray,
                                      width: 2,
                                    ),
                                  ),
                          child: Column(
                            children: [
                                      Icon(
                                        Icons.mic,
                                        color: _isVoiceMode
                                            ? Colors.white
                                            : AppTheme.darkGray,
                                        size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                        'Voice Chat',
              style: TextStyle(
                                          color: _isVoiceMode
                                              ? Colors.white
                                              : AppTheme.darkGray,
                                          fontWeight: _isVoiceMode
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                fontSize: 14,
              ),
            ),
                                      const SizedBox(height: 4),
            Text(
                                        '🎙️ Real-time',
              style: TextStyle(
                                          color: _isVoiceMode
                                              ? Colors.white70
                                              : AppTheme.mediumGray,
                fontSize: 12,
              ),
                              ),
                            ],
                          ),
                                ),
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Start Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _startInterview,
                        icon: Icon(
                          _isVoiceMode ? Icons.mic : Icons.play_arrow,
                          size: 24,
                        ),
                        label: Text(
                          _isVoiceMode ? 'Start Voice Interview' : 'Start Text Interview',
                                  style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Back Button
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentState = InterviewState.selectWorkflow;
                          _selectedWorkflow = null;
                        });
                      },
                      icon: Icon(Icons.arrow_back, color: AppTheme.mediumGray),
                      label: Text(
                        'Choose Different Workflow',
                        style: TextStyle(color: AppTheme.mediumGray),
                        ),
            ),
          ],
                  ),
                ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
        children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.mediumGray,
                  ),
                ),
                Expanded(
                  child: Text(
            value,
                    style: TextStyle(
              fontSize: 14,
              color: AppTheme.darkGray,
                    ),
                  ),
                ),
              ],
    );
  }

  Widget _buildChatPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 32.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Top info bar - redesigned
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFe6cfe6).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.record_voice_over,
                        color: Color(0xFF263238),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mock Interview: ${_selectedWorkflow?.position}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF263238),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Company: ${_selectedWorkflow?.company}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Timer display section
                    if (_interviewStartTime != null) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_elapsedTime),
                                style: TextStyle(
                                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRemainingTime(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Chat messages
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderGray),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: _loadingChat
                            ? const Center(
                                child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Color(0xFF263238),
                                      ),
                                ),
                              )
                            : _messages.isEmpty && _streamingMessage.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                    child: Text(
                                        _wsConnected
                                            ? 'Waiting for the interviewer to start...'
                                            : 'Connecting...',
                                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(20),
                                    itemCount: _messages.length + (_streamingMessage.isNotEmpty ? 1 : 0),
                                    itemBuilder: (context, idx) {
                                      if (idx == _messages.length && _streamingMessage.isNotEmpty) {
                                        // Render the streaming message
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                                            ),
                                            margin: const EdgeInsets.symmetric(vertical: 8),
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceWhite,
                                              border: Border.all(color: AppTheme.borderGray),
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(18),
                                                topRight: Radius.circular(18),
                                                bottomLeft: Radius.circular(6),
                                                bottomRight: Radius.circular(18),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.06),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              _streamingMessage,
                                              style: TextStyle(
                                                color: AppTheme.darkGray,
                                                fontSize: 15,
                                                height: 1.4,
                                              ),
                                            ),
      ),
    );
  }

                                      final msg = _messages[idx];
                                      final isUser = msg.role == 'user';
                                      return Align(
                                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                                          ),
                                          margin: const EdgeInsets.symmetric(vertical: 8),
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: isUser ? AppTheme.primaryBlue : AppTheme.surfaceWhite,
                                            border: isUser ? null : Border.all(color: AppTheme.borderGray),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(18),
                                              topRight: const Radius.circular(18),
                                              bottomLeft: Radius.circular(isUser ? 18 : 6),
                                              bottomRight: Radius.circular(isUser ? 6 : 18),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.06),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            msg.content,
                                            style: TextStyle(
                                              color: isUser ? Colors.white : AppTheme.darkGray,
                                              fontSize: 15,
                                              height: 1.4,
                                            ),
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      
                      // Input area - conditional based on mode
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppTheme.borderGray),
                          ),
                        ),
                        child: _isVoiceMode ? _buildVoiceControls() : _buildTextInput(),
                                  ),
                                ],
                              ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Minimal feedback page to satisfy build and show result
  Widget _buildFeedbackPage() {
    if (_loadingFeedback) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feedbackError != null) {
      return Center(child: Text(_feedbackError!));
    }
    if (_feedbackData == null) {
      return const Center(child: Text('No feedback available yet.'));
    }
    return SingleChildScrollView(
                  padding: const EdgeInsets.all(24), 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
          const Text('Interview Feedback', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
          Text(const JsonEncoder.withIndent('  ').convert(_feedbackData)),
                const SizedBox(height: 24), 
          ElevatedButton(
            onPressed: _goBackToWorkflowSelection,
            child: const Text('Back to selection'),
          )
        ],
      ),
    );
  }

  // Helper to scroll to the bottom of the chat
  void _scrollToBottom() {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
  }

  void _startInterviewTimer() {
    _interviewStartTime = DateTime.now();
    _interviewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_interviewStartTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_interviewStartTime!);
        });
      }
    });
  }

  void _stopInterviewTimer() {
    _interviewTimer?.cancel();
  }

  void _startFeedbackPolling() {
    _feedbackPollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      if (_pollingAttempts >= _maxPollingAttempts) {
            timer.cancel();
            setState(() {
          _feedbackError = 'Failed to retrieve feedback. Please try again later.';
              _loadingFeedback = false;
            });
        return;
      }

      _pollingAttempts++;
      try {
        final feedback = await _interviewService.getInterviewFeedback(
          _selectedWorkflow!.id,
          _sessionId!,
        );
        if (feedback.isNotEmpty) {
            timer.cancel();
            setState(() {
            _feedbackData = feedback;
              _loadingFeedback = false;
            _currentState = InterviewState.showingFeedback;
            });
          }
        } catch (e) {
        // Continue polling on error, but stop if max attempts are reached
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatRemainingTime() {
    final totalDuration = Duration(minutes: _selectedDuration);
    final remaining = totalDuration - _elapsedTime;
    if (remaining.isNegative) {
      return 'Time out: ${_formatDuration(_elapsedTime - totalDuration)}';
    }
    return 'Remaining time: ${_formatDuration(remaining)}';
  }
}
