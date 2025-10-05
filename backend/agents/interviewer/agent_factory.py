"""Factory for Interviewer agent - enables switching between Gemini and Claude"""

from backend.config import ClaudeConfig
import asyncio

async def start_agent_session(session_id, user_id, workflow_id, duration_minutes, is_audio=False):
    """
    Start an interview session
    Automatically selects between Claude and Gemini based on configuration
    """
    if ClaudeConfig.INTERVIEWER_USE_CLAUDE:
        from .agent_claude import start_agent_session as claude_impl
        return await claude_impl(session_id, user_id, workflow_id, duration_minutes, is_audio)
    else:
        from .agent import start_agent_session as gemini_impl
        return await gemini_impl(session_id, user_id, workflow_id, duration_minutes, is_audio)


async def agent_to_client_messaging(websocket, *args):
    """
    Handle agent to client messaging
    Automatically selects between Claude and Gemini based on configuration
    """
    if ClaudeConfig.INTERVIEWER_USE_CLAUDE:
        from .agent_claude import agent_to_client_messaging as claude_impl
        # Claude version only needs websocket and session
        return await claude_impl(websocket, args[1] if len(args) > 1 else args[0])
    else:
        from .agent import agent_to_client_messaging as gemini_impl
        # Gemini version needs websocket, live_events, and session
        return await gemini_impl(websocket, *args)


async def client_to_agent_messaging(websocket, *args):
    """
    Handle client to agent messaging
    Automatically selects between Claude and Gemini based on configuration
    """
    if ClaudeConfig.INTERVIEWER_USE_CLAUDE:
        from .agent_claude import client_to_agent_messaging as claude_impl
        # Claude version only needs websocket and session
        return await claude_impl(websocket, args[0] if args else None)
    else:
        from .agent import client_to_agent_messaging as gemini_impl
        # Gemini version needs websocket, live_request_queue, and session
        return await gemini_impl(websocket, *args)

