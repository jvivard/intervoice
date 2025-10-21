# 🎯 Intervoice - AI-Powered Interview Preparation Platform

<div align="center">

![Intervoice Logo](https://img.shields.io/badge/Intervoice-Interview%20AI-purple?style=for-the-badge&logo=microphone)

**An intelligent platform that helps you ace your job interviews with AI-powered mock interviews and personalized feedback**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/)

</div>

## 🚀 Features

### 📋 Interview Preparation
- **Smart Workflow Management**: Create and manage interview workflows for different positions
- **Resume Analysis**: Upload your PDF resume for AI-powered analysis and optimization suggestions  
- **Personalized Q&A**: Get tailored interview questions based on your background and target role
- **Resource Recommendations**: Access curated learning materials and preparation resources

### 🤖 AI-Powered Mock Interviews
- **Real-time Conversations**: Engage in natural conversations with AI interviewer via text or voice
- **Adaptive Questioning**: Dynamic follow-up questions based on your responses
- **Session Management**: Timed interview sessions with automatic transcript generation
- **Multi-modal Support**: Text and audio communication options

### 📊 Intelligent Feedback System
- **Comprehensive Analysis**: Detailed performance evaluation across multiple dimensions
- **Strength Recognition**: Highlight what you did well during the interview
- **Improvement Areas**: Specific suggestions with examples and actionable advice
- **Progress Tracking**: Monitor your improvement over multiple interview sessions
- **Resource Library**: Curated links to help you improve identified weak areas

### 📈 Interview History & Analytics
- **Session History**: Access all your past interview transcripts and feedback
- **Position-based Filtering**: Filter interviews by specific job positions
- **Performance Trends**: Track your progress across different interview sessions
- **Exportable Reports**: Download interview transcripts and feedback for review

## 🛠️ Tech Stack

### Frontend
- **Flutter Web** - Cross-platform UI framework for responsive web applications
- **Dart** - Programming language optimized for building user interfaces
- **Material Design** - Google's design system for consistent UI/UX

### Backend
- **FastAPI** - Modern, fast Python web framework for building APIs
- **Python 3.9+** - Core backend programming language
- **Google ADK** - Agent Development Kit for AI agent orchestration
- **WebSocket** - Real-time bidirectional communication

### AI & ML
- **Claude 3.5 (Anthropic)** - Advanced language model for interview conversations (Primary)
- **Google Gemini 2.0** - Alternative AI model (Legacy support)
- **Anthropic API** - Claude AI integration
- **Google Cloud AI** - Cloud-based AI services and infrastructure (Optional)

### Database & Storage
- **Firestore** - NoSQL document database for scalable data storage
- **Firebase Auth** - Authentication and user management

## 📦 Installation & Setup

### Prerequisites
- **Flutter SDK** (3.0+)
- **Python** (3.10+) - 
- **Node.js** (16+)
- **Firebase Project** with Firestore and Authentication enabled
- **Claude API Key** 
- **Google Cloud Project** (Optional - for legacy Gemini support)

### 🔧 Backend Setup

1. **Clone the repository**
   ``
   git clone https://github.com/jvivard/intervoice
   ```

3. **Set up Python environment**
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   
   # Install Claude dependencies (recommended - latest)
   pip install -r requirements_claude.txt
   
   # OR install legacy Gemini dependencies
   # pip install -r requirements_working.txt
   ```

4. **Configure environment variables**
   Create a `.env` file in the `backend/` directory:
   
   ```bash
   # backend/.env
   
   # Claude AI (Primary)
   ANTHROPIC_API_KEY=sk-ant-your-key-here
   USE_CLAUDE=true
   
   # Optional: Google Cloud (for legacy Gemini support)
   GOOGLE_CLOUD_PROJECT=your-actual-project-id
   GOOGLE_CLOUD_LOCATION=us-central1
   GOOGLE_GENAI_USE_VERTEXAI=True
   
   # Optional: Search API (for search agent)
   TAVILY_API_KEY=your-tavily-key
   ```
   
   **Get your Claude API key**: Visit https://console.anthropic.com 

5. **Set up Firebase credentials**
   Create a `credentials` folder and put your `firebase_key.json` inside it

   ```bash
   FIREBASE_KEY_PATH=credentials/firebase_key.json #Or change it to your actual path of firebase_key.json
   ```

6. **Test Claude setup (optional but recommended)**
   ```bash
   # From project root
   python backend/services/test_claude.py
   ```

7. **Run the backend server**
   **Important:** Run from the project root directory, not from inside the backend folder
   # From project root
   uvicorn backend.app:app --reload --port 8000
   ```

### 🎨 Frontend Setup

1. **Navigate to frontend directory**
   ```bash
   cd frontend/mocker_web
   ```

2. **Install Flutter dependencies**
   flutter pub get
   ```

3. **Configure Firebase and Google Sign-In Client ID**
   - Add your `firebase_options.dart` file or change the ID and key to your own version in the existing `firebase_options.dart` file
   - Add your own Google Sign-In Client ID in `lib/services/auth_service.dart` and `web/index.html` file

4. **Run the web application**
   ```bash
   flutter run -d chrome --web-port 3000
   ```

## 📁 Project Structure

```
mocker/
├── backend/                    # Python FastAPI backend
│   ├── agents/                # AI agents (interviewer, judge)
│   ├── api/                   # REST API endpoints
│   ├── data/                  # Database models and schemas
│   ├── coordinator/           # Session management
│   └── service/              
├── frontend/                  # Flutter web frontend
│   └── mocker_web/
│       ├── lib/
│       │   ├── pages/         # UI pages/screens
│       │   ├── services/      # API service layer
│       │   ├── models/        # Data models
│       │   ├── widgets/       # Reusable UI components
│       │   └── config/        # App configuration
│       └── web/               # Web-specific assets
└── README.md                  # Project documentation
```

## 🎯 Usage

1. **Create Account**: Sign up using your email or social login
2. **Prepare Workflow**: Upload your resume and create a workflow for your target position
3. **Get Recommendation Q&A**: Review AI-generated interview questions tailored to your profile
4. **Practice Interview**: Start a mock interview session with our AI interviewer
5. **Receive Feedback**: Get detailed analysis and suggestions for improvement
6. **Track Progress**: Monitor your performance across multiple sessions

## 🔗 API Documentation

Once the backend is running, visit `http://localhost:8000/docs` for interactive API documentation powered by Swagger UI.

## 🤖 Claude AI Migration

Intervoice now uses **Claude 3.5** by Anthropic as the primary AI model, offering superior reasoning and analysis capabilities compared to Gemini.

- ✅ **Summarizer Agent** - Migrated (using Haiku for cost-efficiency)
- ✅ **Question Generator** - Migrated (using Sonnet for quality)
- ⏳ **Answer Generator** - Ready to migrate
- ⏳ **Interview Judge** - Ready to migrate
- ⏳ **Search Agent** - Requires Tavily API
- ⏳ **Mock Interviewer** - Text-only (audio requires additional setup)

### Gradual Migration
You can migrate agents one at a time using feature flags:

```bash
# backend/.env
USE_CLAUDE=false  # Default to Gemini

# Enable Claude per agent
SUMMARIZER_USE_CLAUDE=true
QUESTION_GEN_USE_CLAUDE=true
ANSWER_GEN_USE_CLAUDE=false  # Keep on Gemini
```

### Documentation
- 📘 **Setup Guide**: `SETUP_CLAUDE.md`
- 📖 **Migration Guide**: `CLAUDE_MIGRATION_GUIDE.md`
- 📊 **Progress Tracker**: `MIGRATION_PROGRESS.md`
- ⚡ **Quick Start**: `QUICK_START_CLAUDE.md`





`


## 🤝 Contributing

We welcome contributions! 

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

If you have any questions or need help, please:
- 📧 Contact support for assistance
- 💬 Join our community discussions
- 📖 Check the documentation

---

<div align="center">

**Built with ❤️ using Flutter, Python, and Google AI**

⭐ Star this repo if you find it helpful!

</div>
