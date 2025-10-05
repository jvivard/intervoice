import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workflow.dart';
import '../services/workflow_service.dart';
import '../services/auth_service.dart';
import '../widgets/navbar.dart';
import '../widgets/login_prompt.dart';
import 'interview_prepare_page.dart';
import 'mock_interview_page.dart';
import 'profile_page.dart';
import 'qa_page.dart';
import 'feedback_page.dart';
import 'dart:convert';
import 'package:web/web.dart' as web;
import '../theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  String? _selectedWorkflowId; // for passing selected workflow to QA page

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.upload_file, label: 'Prepare'),
    _NavItem(icon: Icons.record_voice_over, label: 'Mock Interview'),
    _NavItem(icon: Icons.quiz, label: 'Q&A'),
    _NavItem(icon: Icons.assessment, label: 'Feedback'),
    _NavItem(icon: Icons.person, label: 'Profile'),
  ];

  List<Widget> get _pages => [
    _WorkbenchPage(onViewQA: (workflowId) {
      setState(() {
        _selectedIndex = 3; // QA page index
        _selectedWorkflowId = workflowId;
      });
    }),
    InterviewPreparePage(onNavigateToDashboard: () {
      setState(() {
        _selectedIndex = 0; 
      });
    }),
    const MockInterviewPage(),
    QAPage(preSelectedWorkflowId: _selectedWorkflowId),
    const FeedbackPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        debugPrint('🏠 Dashboard building...');
        debugPrint('👤 User: ${authService.userName}');
        debugPrint('📧 Email: ${authService.userEmail}');
        
        // Check if user is logged in first
        if (!authService.isLoggedIn) {
          return LoginPrompt(authService: authService);
        }
        
        // Show loading indicator if auth service is still initializing
        if (authService.userName == null && authService.userEmail == null) {
          return Scaffold(
            backgroundColor: AppTheme.lightGray,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.primaryBlue,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading your dashboard...',
                    style: TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Scaffold(
          body: Row(
            children: [
              // Enhanced Sidebar
              Material(
                elevation: 0,
                child: Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    border: Border(
                      right: BorderSide(
                        color: AppTheme.borderGray,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      // Logo/app name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.bubble_chart, color: AppTheme.primaryBlue, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Intervoice', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 20, 
                                color: AppTheme.darkGray
                              )
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Nav items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _navItems.length - 1,
                          itemBuilder: (context, idx) {
                            final item = _navItems[idx];
                            final selected = _selectedIndex == idx;
                            return _SidebarButton(
                              icon: item.icon,
                              label: item.label,
                              selected: selected,
                              onTap: () => setState(() => _selectedIndex = idx),
                            );
                          },
                        ),
                      ),
                      
                      // Enhanced User Profile Section
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderGray),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedIndex = 5),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                            backgroundColor: _selectedIndex == 5 ? AppTheme.primaryBlue : AppTheme.borderGray,
                                    child: Icon(
                                      Icons.person, 
                                      color: _selectedIndex == 5 ? AppTheme.surfaceWhite : AppTheme.mediumGray, 
                                      size: 20
                                    ),
                                  ),
                                  // Online indicator
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppTheme.successGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.surfaceWhite,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authService.userName ?? 'John Doe',
                                      style: TextStyle(
                                        color: AppTheme.darkGray,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      authService.userEmail ?? 'john@example.com',
                                      style: TextStyle(
                                        color: AppTheme.mediumGray,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 16,
                                  color: AppTheme.mediumGray,
                                ),
                                onSelected: (value) {
                                  if (value == 'logout') {
                                    authService.signOut();
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'profile',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, size: 16, color: AppTheme.mediumGray),
                                        const SizedBox(width: 8),
                                        Text('View Profile', style: TextStyle(color: AppTheme.darkGray)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'logout',
                                    child: Row(
                                      children: [
                                        Icon(Icons.logout, size: 16, color: AppTheme.errorRed),
                                        const SizedBox(width: 8),
                                        Text('Sign Out', style: TextStyle(color: AppTheme.errorRed)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main content
              Expanded(
                child: Container(
                  color: AppTheme.lightGray,
                  child: _pages[_selectedIndex],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarButton({required this.icon, required this.label, required this.selected, required this.onTap});
  
  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
                color: widget.selected 
                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                    : _isHovered 
                        ? AppTheme.borderGray.withValues(alpha: 0.3)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: widget.selected 
                    ? Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3))
                    : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.selected 
                                ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.icon, 
                            color: widget.selected 
                                ? AppTheme.primaryBlue 
                                : _isHovered 
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGray, 
                            size: 20
                          ),
                        ),
                        const SizedBox(width: 12),
                Text(
                          widget.label,
                  style: TextStyle(
                            fontSize: 14,
                            color: widget.selected 
                                ? AppTheme.primaryBlue 
                                : _isHovered 
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGray,
                            fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// Sophisticated workbench page with dark theme and enhanced UI
class _WorkbenchPage extends StatefulWidget {
  final Function(String workflowId)? onViewQA;
  
  const _WorkbenchPage({this.onViewQA});
  
  @override
  State<_WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<_WorkbenchPage> with TickerProviderStateMixin {
  final WorkflowService _workflowService = WorkflowService();
  List<Workflow> workflows = [];
  bool _loading = true;
  String? _error;
  
  // Local state management - track workflow status (frontend UI only, not synced with backend)
  Map<String, String> _workflowStates = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const String _localStorageKey = 'workflow_status_map';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadWorkflows();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Load status from local storage (auto-restore after page refresh)
  Map<String, String> _loadStatusFromLocal() {
    final jsonStr = web.window.localStorage[_localStorageKey];
    if (jsonStr == null) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
      return map.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  // Save status to local storage (frontend UI only, doesn't affect backend)
  void _saveStatusToLocal() {
    web.window.localStorage[_localStorageKey] = jsonEncode(_workflowStates);
  }

  // Initialize: all workflows default to 'In Progress'
  Future<void> _loadWorkflows() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final loadedWorkflows = await _workflowService.getWorkflows();
      final localStatus = _loadStatusFromLocal();
      setState(() {
        workflows = loadedWorkflows;
        _loading = false;
        _workflowStates = {
          for (var workflow in workflows)
            workflow.id: localStatus[workflow.id] ?? 'In Progress'
        };
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // User toggles status - only affects local UI and localStorage
  void _toggleWorkflowState(String workflowId) {
    setState(() {
      final currentState = _workflowStates[workflowId] ?? 'In Progress';
      _workflowStates[workflowId] = currentState == 'In Progress' ? 'Complete' : 'In Progress';
      _saveStatusToLocal();
    });
  }

  void _showWorkflowDetail(Workflow workflow) {
    final currentState = _workflowStates[workflow.id] ?? 'In Progress';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        title: Text(
          workflow.position,
          style: TextStyle(
            color: AppTheme.darkGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company: ${workflow.company}',
              style: TextStyle(color: AppTheme.darkGray),
            ),
            Text(
              'Status: $currentState',
              style: TextStyle(color: AppTheme.darkGray),
            ),
            if (workflow.personalExperience != null) ...[
              const SizedBox(height: 8),
              const Text('Preparation completed', style: TextStyle(color: Colors.green)),
            ],
          ],
        ),
        actions: [
          if (workflow.personalExperience != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Use callback to notify parent to switch to QA page
                widget.onViewQA?.call(workflow.id);
              },
              icon: Icon(Icons.quiz, color: AppTheme.primaryBlue),
              label: Text('View Q&A', style: TextStyle(color: AppTheme.primaryBlue)),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleWorkflowState(workflow.id);
            },
            child: Text(
              'Mark as ${currentState == 'In Progress' ? 'Complete' : 'In Progress'}',
              style: TextStyle(color: AppTheme.primaryBlue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.mediumGray)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryBlue,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading your interviews...',
              style: TextStyle(
                color: AppTheme.mediumGray,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 24),
            Text(
              'Error: $_error',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadWorkflows,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: AppTheme.surfaceWhite,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Enhanced NavBar
          Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.borderGray, width: 1),
                    ),
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your interview preparation progress',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Main content with statistics and interview cards
        Expanded(
          child: Padding(
              padding: const EdgeInsets.all(32.0),
            child: workflows.isEmpty
                  ? _buildEmptyState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Dashboard Statistics
                        _buildStatisticsSection(),
                        const SizedBox(height: 40),
                        
                        // My Interviews section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                      Text(
                        'My Interviews',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGray,
                        ),
                            ),
                            Text(
                              '${workflows.length} total',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.mediumGray,
                              ),
                            ),
                          ],
                      ),
                      const SizedBox(height: 24),
                        
                        // Enhanced interview cards grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 24,
                              childAspectRatio: 1.2,
                          ),
                          itemCount: workflows.length,
                          itemBuilder: (context, idx) {
                            final workflow = workflows[idx];
                            final currentState = _workflowStates[workflow.id] ?? 'In Progress';
                              return _buildInterviewCard(workflow, currentState);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderGray),
            ),
            child: Icon(
              Icons.work_outline,
              size: 80,
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No interviews found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGray,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start preparing for your interviews to see them here',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final activeInterviews = _workflowStates.values.where((state) => state == 'In Progress').length;
    final completedInterviews = _workflowStates.values.where((state) => state == 'Complete').length;
    final totalInterviews = workflows.length;
    final avgProgress = totalInterviews > 0 ? ((completedInterviews / totalInterviews) * 100).round() : 0;

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.work_outline,
          title: 'Active Interviews',
          value: '$activeInterviews',
          subtitle: 'Currently preparing',
          color: AppTheme.primaryBlue,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          icon: Icons.trending_up,
          title: 'Avg. Progress',
          value: '$avgProgress%',
          subtitle: 'Across all interviews',
          color: AppTheme.successGreen,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          icon: Icons.check_circle_outline,
          title: 'Mock Interviews',
          value: '$completedInterviews',
          subtitle: 'Completed this month',
          color: AppTheme.warningOrange,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGray,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterviewCard(Workflow workflow, String currentState) {
    final progress = _calculateProgress(workflow, currentState);
    final interviewType = _getInterviewType(workflow);
    final lastActivity = _getLastActivity(workflow);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
                              onTap: () => _showWorkflowDetail(workflow),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
                                decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderGray),
                                  boxShadow: [
                                    BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with badges
                Row(
                                    children: [
                    _buildBadge(interviewType, _getTypeColor(interviewType)),
                    const Spacer(),
                    _buildStatusBadge(currentState),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Job title
                                      Text(
                                        workflow.position, 
                                        style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                                          color: AppTheme.darkGray,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Company
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 16,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                                        workflow.company, 
                                        style: TextStyle(
                                          fontSize: 14, 
                          color: AppTheme.mediumGray,
                        ),
                        overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                const SizedBox(height: 16),
                
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGray,
                          ),
                        ),
                        Text(
                          '$progress%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: AppTheme.borderGray,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          currentState == 'Complete' ? AppTheme.successGreen : AppTheme.primaryBlue,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                
                // Footer with activity
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lastActivity,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppTheme.mediumGray,
                    ),
                  ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Complete':
        color = AppTheme.successGreen;
        break;
      case 'In Progress':
        color = AppTheme.primaryBlue;
        break;
      default:
        color = AppTheme.mediumGray;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  int _calculateProgress(Workflow workflow, String currentState) {
    if (currentState == 'Complete') return 100;
    if (workflow.personalExperience != null) return 75;
    return 25;
  }

  String _getInterviewType(Workflow workflow) {
    final title = workflow.position.toLowerCase();
    if (title.contains('software') || title.contains('engineer') || title.contains('developer')) {
      return 'Technical';
    } else if (title.contains('product') || title.contains('manager')) {
      return 'Product';
    } else if (title.contains('data') || title.contains('analyst')) {
      return 'Data';
    } else if (title.contains('design') || title.contains('ux')) {
      return 'Design';
    }
    return 'General';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Technical':
        return AppTheme.primaryBlue;
      case 'Product':
        return AppTheme.successGreen;
      case 'Data':
        return AppTheme.warningOrange;
      case 'Design':
        return AppTheme.errorRed;
      default:
        return AppTheme.mediumGray;
    }
  }

  String _getLastActivity(Workflow workflow) {
    // Mock data - in real app, this would come from backend
    final random = DateTime.now().millisecondsSinceEpoch % 3;
    switch (random) {
      case 0:
        return '2 days ago';
      case 1:
        return '5 days ago';
      default:
        return 'Never';
    }
  }
} 