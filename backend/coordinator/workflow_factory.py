"""
Workflow Factory - Automatically selects between Gemini and Claude workflows
"""

from backend.config import ClaudeConfig


async def run_preparation_workflow(*args, **kwargs):
    """
    Run preparation workflow using Claude or Gemini based on configuration
    Automatically selects the appropriate implementation
    """
    if ClaudeConfig.USE_CLAUDE:
        from .preparation_workflow_claude import run_preparation_workflow as claude_impl
        return await claude_impl(*args, **kwargs)
    else:
        from .preparation_workflow import run_preparation_workflow as gemini_impl
        return await gemini_impl(*args, **kwargs)


def run_preparation_workflow_sync(*args, **kwargs):
    """
    Synchronous wrapper that automatically selects implementation
    """
    if ClaudeConfig.USE_CLAUDE:
        from .preparation_workflow_claude import run_preparation_workflow_sync as claude_impl
        return claude_impl(*args, **kwargs)
    else:
        from .preparation_workflow import run_preparation_workflow_sync as gemini_impl
        return gemini_impl(*args, **kwargs)

