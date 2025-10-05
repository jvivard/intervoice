"""
Backend configuration management
Provides unified environment variable setup for all agents
"""

import os
from dotenv import load_dotenv
from pathlib import Path

def set_google_cloud_env_vars():
    """
    Load Google Cloud environment variables from backend/.env file
    """
    backend_dir = Path(__file__).parent
    env_file_path = backend_dir / ".env"
    load_dotenv(env_file_path)


class ClaudeConfig:
    """Configuration for Claude AI integration"""
    
    # Claude API settings
    ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
    
    # Model selection
    DEFAULT_MODEL = os.getenv("CLAUDE_MODEL", "claude-3-5-sonnet-20241022")
    BUDGET_MODEL = "claude-3-5-haiku-20241022"  # For bulk operations
    PREMIUM_MODEL = "claude-3-5-sonnet-20241022"  # For interviews
    
    # Token limits
    DEFAULT_MAX_TOKENS = 4000
    INTERVIEW_MAX_TOKENS = 300
    
    # Temperature settings
    DEFAULT_TEMPERATURE = 0.3
    CREATIVE_TEMPERATURE = 0.7
    
    # Feature flags for gradual migration
    USE_CLAUDE = os.getenv("USE_CLAUDE", "false").lower() == "true"
    
    # Agent-specific overrides
    SUMMARIZER_USE_CLAUDE = os.getenv("SUMMARIZER_USE_CLAUDE", str(USE_CLAUDE)).lower() == "true"
    QUESTION_GEN_USE_CLAUDE = os.getenv("QUESTION_GEN_USE_CLAUDE", str(USE_CLAUDE)).lower() == "true"
    ANSWER_GEN_USE_CLAUDE = os.getenv("ANSWER_GEN_USE_CLAUDE", str(USE_CLAUDE)).lower() == "true"
    SEARCH_USE_CLAUDE = os.getenv("SEARCH_USE_CLAUDE", str(USE_CLAUDE)).lower() == "true"
    INTERVIEWER_USE_CLAUDE = os.getenv("INTERVIEWER_USE_CLAUDE", str(USE_CLAUDE)).lower() == "true"
    JUDGE_USE_CLAUDE = os.getenv("JUDGE_USE_CLAUDE", str(USE_CLAUDE)).lower() == "true"
    
    # Search API settings (replaces Google Search)
    TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")
    SERPAPI_KEY = os.getenv("SERPAPI_KEY", "")


class PortfolioConfig:
    """Configuration for portfolio analysis service"""
    
    # Page loading timeout in seconds
    TIMEOUT = 30
    
    # Maximum content size to extract (characters)
    MAX_CONTENT_SIZE = 50000
    
    # User agent for web scraping
    USER_AGENT = "Portfolio-Analyzer/1.0"
    
    # Maximum number of projects to extract
    MAX_PROJECTS = 20
    
    # Maximum number of skills to extract
    MAX_SKILLS = 50
    
    # Common portfolio platforms and their selectors
    PLATFORM_SELECTORS = {
        "default": {
            "projects": ["[class*='project']", "[class*='portfolio']", "[class*='work']"],
            "skills": ["[class*='skill']", "[class*='tech']", "[class*='tool']"],
            "description": ["[class*='bio']", "[class*='about']", "[class*='description']"],
            "title": ["h1", "[class*='name']", "[class*='title']"]
        }
    }


class PDFConfig:
    """
    PDF processing configuration settings
    """
    # File size limits
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
    
    # Supported file extensions
    ALLOWED_EXTENSIONS = {'.pdf'}
    
    # Text quality thresholds
    MIN_TEXT_LENGTH = 30  # minimum characters for valid text
    MIN_TEXT_QUALITY_CHARS = 50  # minimum characters for quality analysis
    MIN_TEXT_QUALITY_WORDS = 5   # minimum words for quality analysis
    
    # PDF processing limits
    MAX_PAGE_COUNT = 50  # maximum pages to process