"""Factory for Search agent - enables switching between Gemini and Claude"""

from backend.config import ClaudeConfig

def search_interview_questions(job_description):
    """
    Search for common interview questions and experiences
    Automatically selects between Claude and Gemini based on configuration
    """
    if ClaudeConfig.SEARCH_USE_CLAUDE:
        from .agent_claude import search_interview_questions as claude_impl
        return claude_impl(job_description)
    else:
        from .agent import search_interview_questions as gemini_impl
        return gemini_impl(job_description)

