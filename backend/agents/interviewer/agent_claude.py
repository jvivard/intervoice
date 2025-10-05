"""Mock Interview Agent - Claude version with streaming support
Note: Audio functionality requires external TTS/STT integration
"""

from datetime import datetime, timezone, timedelta
import asyncio, json, os, sys, re
from .prompt import get_background_prompt
from backend.data.database import firestore_db
from backend.data.schemas import Interview
from backend.agents.interview_judge.agent_claude import _run_judge_from_session_claude
from backend.coordinator.session_manager import session_service
from backend.services.claude_client import get_claude_client
from backend.config import ClaudeConfig

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../")))
from backend.config import set_google_cloud_env_vars

set_google_cloud_env_vars()

APP_NAME = "MockInterviewerAgent_Claude"


async def start_agent_session(session_id, user_id, workflow_id, duration_minutes, is_audio=False):
    """
    Starts a Claude-based interview session
    
    Note: is_audio parameter is kept for compatibility but audio is not yet supported with Claude
    If audio is needed, integrate external TTS/STT services (ElevenLabs, Whisper, etc.)
    """
    if is_audio:
        print("[WARNING] Audio mode not yet supported with Claude. Falling back to text mode.")
        is_audio = False
    
    session = await session_service.create_session(
        app_name=APP_NAME,
        user_id=user_id,
        session_id=session_id,
    )

    session.state.setdefault("transcript", [])
    session.state.setdefault("conversation_history", [])  # For Claude context
    session.state["workflow_id"] = workflow_id
    
    # Set up session timer
    setup_duration(session, duration_minutes)

    # Load candidate information
    personal_experience = firestore_db.get_personal_experience(user_id, workflow_id) or {}
    recommend_qas = firestore_db.get_recommended_qas(user_id, workflow_id) or []
    session.state["personal_experience"] = personal_experience
    session.state["recommend_qas"] = recommend_qas

    # Generate system instruction
    system_instruction = get_background_prompt(personal_experience, recommend_qas)
    session.state["system_instruction"] = system_instruction

    # Generate initial greeting
    client = get_claude_client()
    intro_message = "Please start the mock interview. Ask me to do a self introduction first."
    
    try:
        initial_response = await client.generate(
            prompt=intro_message,
            system_prompt=system_instruction,
            model=ClaudeConfig.PREMIUM_MODEL,
            max_tokens=ClaudeConfig.INTERVIEW_MAX_TOKENS,
            temperature=0.3
        )
        
        # Store in conversation history
        session.state["conversation_history"].append({
            "role": "user",
            "content": intro_message
        })
        session.state["conversation_history"].append({
            "role": "assistant",
            "content": initial_response
        })
        
        # Store in transcript
        session.state["transcript"].append({"role": "system", "message": intro_message})
        session.state["transcript"].append({"role": "AI", "message": initial_response})
        
        # Store initial response to send to client
        session.state["initial_response"] = initial_response
        
    except Exception as e:
        print(f"[ERROR] Failed to generate initial response: {e}")
        session.state["initial_response"] = "Hello! Let's begin the interview. Could you please introduce yourself?"

    return session


async def agent_to_client_messaging(websocket, session):
    """
    Agent to client communication using Claude streaming
    """
    if not session:
        print(f"[ERROR] Session {session.id} not found")
        return
    
    try:
        # Send initial response
        initial_response = session.state.get("initial_response", "")
        if initial_response:
            message = {
                "mime_type": "text/plain",
                "data": initial_response
            }
            await websocket.send_text(json.dumps(message))
            
            # Send turn complete
            await websocket.send_text(json.dumps({
                "turn_complete": True,
                "interrupted": False
            }))
        
        # Main loop - wait for session expiry or client messages
        while True:
            if is_session_expired(session):
                print(f"[SESSION ENDED] Session {session.id} expired")
                
                # Send final message
                goodbye_message = {
                    "mime_type": "text/plain",
                    "data": "⏰ Time's up! Thank you for participating in the mock interview. We'll save your transcript now."
                }
                await websocket.send_text(json.dumps(goodbye_message))
                
                end_message = {
                    "type": "end",
                    "data": "Conversation ended. Thank you for participating!"
                }
                await websocket.send_text(json.dumps(end_message))
                
                # Save transcript
                start_time = session.state.get("start_time")
                end_time = datetime.now(timezone.utc)
                duration = int((end_time - start_time).total_seconds() / 60)
                session.state["duration"] = duration
                
                save_transcript(session)
                
                # Generate feedback
                try:
                    await _run_judge_from_session_claude(session)
                    print("[DEBUG]: FEEDBACK GENERATED")
                except Exception as e:
                    print(f"[ERROR] Feedback generation failed: {e}")
                
                await websocket.close(code=1000)
                break
            
            # Sleep briefly to avoid tight loop
            await asyncio.sleep(0.5)
    
    except Exception as e:
        print(f"[ERROR] agent_to_client_messaging failed: {e}")


async def client_to_agent_messaging(websocket, session):
    """
    Client to agent communication - processes user messages and streams Claude responses
    """
    try:
        if not session:
            print(f"[ERROR] Session {session.id} not found")
            return

        client = get_claude_client()
        system_instruction = session.state.get("system_instruction", "")

        while True:
            message_json = await websocket.receive_text()
            message = json.loads(message_json)
            mime_type = message.get("mime_type")
            data = message.get("data")

            # Check for control messages
            try:
                control = json.loads(data)
                if (
                    isinstance(control, dict)
                    and control.get("type") == "control"
                    and control.get("action") == "end_interview"
                ):
                    print("[CLIENT TO AGENT]: Received end_interview control")
                    
                    # Calculate duration
                    start_time = session.state.get("start_time")
                    end_time = datetime.now(timezone.utc)
                    duration = int((end_time - start_time).total_seconds() / 60)
                    session.state["duration"] = duration
                    
                    # Save transcript
                    save_transcript(session)
                    print(f"[SAVE]: Transcript saved for session {session.id}")
                    
                    # Generate feedback
                    try:
                        await _run_judge_from_session_claude(session)
                        print(f"[FEEDBACK]: Feedback generated for session {session.id}")
                    except Exception as e:
                        print(f"[ERROR]: Failed to generate feedback: {e}")
                    
                    await websocket.close(code=1000)
                    break
            except Exception:
                pass

            if mime_type == "text/plain":
                # Record user message
                print(f"[CLIENT TO AGENT]: {data}")
                session.state["transcript"].append({"role": "user", "message": data})
                session.state["conversation_history"].append({
                    "role": "user",
                    "content": data
                })

                # Stream Claude response
                try:
                    full_response = ""
                    
                    # Stream response from Claude
                    async for chunk in client.stream(
                        prompt=data,
                        system_prompt=system_instruction,
                        model=ClaudeConfig.PREMIUM_MODEL,
                        max_tokens=ClaudeConfig.INTERVIEW_MAX_TOKENS,
                        temperature=0.3
                    ):
                        full_response += chunk
                        
                        # Send chunk to client
                        message = {
                            "mime_type": "text/plain",
                            "data": chunk
                        }
                        await websocket.send_text(json.dumps(message))
                    
                    # Send turn complete
                    await websocket.send_text(json.dumps({
                        "turn_complete": True,
                        "interrupted": False
                    }))
                    
                    # Store full response in history
                    session.state["conversation_history"].append({
                        "role": "assistant",
                        "content": full_response
                    })
                    session.state["transcript"].append({"role": "AI", "message": full_response})
                    
                    print(f"[AGENT TO CLIENT]: {full_response[:100]}...")
                
                except Exception as e:
                    print(f"[ERROR] Failed to generate Claude response: {e}")
                    error_message = {
                        "mime_type": "text/plain",
                        "data": "I apologize, but I encountered an error. Could you please repeat that?"
                    }
                    await websocket.send_text(json.dumps(error_message))
            
            elif mime_type == "audio/pcm":
                print("[WARNING] Audio mode not supported with Claude. Please use text mode.")
                error_message = {
                    "mime_type": "text/plain",
                    "data": "Audio input is not yet supported. Please type your response."
                }
                await websocket.send_text(json.dumps(error_message))
            
            else:
                raise ValueError(f"Mime type not supported: {mime_type}")
    
    except Exception as e:
        print(f"[ERROR] client_to_agent_messaging failed: {e}")


def is_session_expired(session):
    """Check if session has exceeded its duration"""
    start = session.state.get("start_time")
    duration = session.state.get("duration_minutes")
    if not start:
        return False
    return datetime.now(timezone.utc) > start + timedelta(minutes=duration)


def setup_duration(session, duration_minutes: int):
    """Set the start time and allowed duration for a session"""
    session.state["start_time"] = datetime.now(timezone.utc)
    session.state["duration_minutes"] = duration_minutes


def save_transcript(session):
    """Save interview transcript to database"""
    transcript = session.state.get("transcript", [])
    workflow_id = session.state.get("workflow_id")

    interview_data = Interview(
        transcript=transcript,
        duration_minutes=session.state.get("duration")
    )

    firestore_db.create_interview(
        user_id=session.user_id,
        session_id=session.id,
        workflow_id=workflow_id,
        interview_data=interview_data
    )
    print(f"[SAVE]: Transcript saved for session {session.id}")

