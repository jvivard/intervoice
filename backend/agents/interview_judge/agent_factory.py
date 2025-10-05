"""Factory for Interview Judge agent - enables switching between Gemini and Claude"""

from backend.config import ClaudeConfig

def run_judge_from_session(session):
    """
    Evaluate an interview based on session data
    Automatically selects between Claude and Gemini based on configuration
    """
    if ClaudeConfig.JUDGE_USE_CLAUDE:
        from .agent_claude import run_judge_from_session as claude_impl
        return claude_impl(session)
    else:
        from .agent import run_judge_from_session as gemini_impl
        return gemini_impl(session)

