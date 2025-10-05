"""
Agent factory for Summarizer - selects between Gemini and Claude based on configuration
"""

import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../")))

from backend.config import set_google_cloud_env_vars, ClaudeConfig

# Load environment variables
set_google_cloud_env_vars()


def summarize_resume(resume_text, linkedinLink, githubLink, portfolioLink, additionalInfo, job_description):
    """
    Analyze and summarize user resume using configured AI provider
    
    This function automatically selects between Gemini and Claude based on configuration.
    
    Args:
        resume_text: Resume text content extracted from PDF
        linkedinLink: LinkedIn link or related information
        githubLink: GitHub link or related information
        portfolioLink: Portfolio link or related information
        additionalInfo: Additional information provided by the user
        job_description: Target job description
        
    Returns:
        dict: Structured resume summary information
    """
    
    if ClaudeConfig.SUMMARIZER_USE_CLAUDE:
        # Use Claude version
        from .agent_claude import summarize_resume as claude_summarize
        print("📘 Using Claude for resume summarization")
        return claude_summarize(
            resume_text, linkedinLink, githubLink, portfolioLink, additionalInfo, job_description
        )
    else:
        # Use Gemini version
        from .agent import summarize_resume as gemini_summarize
        print("🔷 Using Gemini for resume summarization")
        return gemini_summarize(
            resume_text, linkedinLink, githubLink, portfolioLink, additionalInfo, job_description
        )

