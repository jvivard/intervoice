"""
Agent factory for Question Generator - selects between Gemini and Claude based on configuration
"""

import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../")))

from backend.config import set_google_cloud_env_vars, ClaudeConfig

# Load environment variables
set_google_cloud_env_vars()


def generate_custom_questions(personal_summary, industry_faqs, num_questions=50):
    """
    Generate customized interview questions using configured AI provider
    
    This function automatically selects between Gemini and Claude based on configuration.
    
    Args:
        personal_summary: Output from summarizer agent (dict with resume info)
        industry_faqs: Output from search agent (dict with industry questions)
        num_questions: Number of questions to generate (default: 50)
        
    Returns:
        list: Structured interview questions with customization
    """
    
    if ClaudeConfig.QUESTION_GEN_USE_CLAUDE:
        # Use Claude version
        from .agent_claude import generate_custom_questions as claude_generate
        print("📘 Using Claude for question generation")
        return claude_generate(personal_summary, industry_faqs, num_questions)
    else:
        # Use Gemini version
        from .agent import generate_custom_questions as gemini_generate
        print("🔷 Using Gemini for question generation")
        return gemini_generate(personal_summary, industry_faqs, num_questions)

