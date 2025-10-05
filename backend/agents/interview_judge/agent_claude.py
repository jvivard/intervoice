"""Interview Judge Agent - Claude version
Generate personalized interview feedback based on interview conversation
"""

import json
import os
import asyncio
import sys
import re
import requests
from duckduckgo_search import DDGS
import time

# Add the project root to the Python path if necessary
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../")))

# Import unified config
from backend.config import set_google_cloud_env_vars, ClaudeConfig
from backend.services.claude_client import ClaudeClient, get_claude_client
from .prompt import get_interview_judge_input_data, get_interview_judge_instruction
from backend.data.database import firestore_db
from backend.data.schemas import Feedback
from pydantic import ValidationError
from backend.coordinator.session_manager import session_service

# Load environment variables
set_google_cloud_env_vars()

# Import Tavily for search functionality
try:
    from tavily import TavilyClient
    TAVILY_AVAILABLE = True
except ImportError:
    TAVILY_AVAILABLE = False
    print("Warning: tavily-python not installed. Resource search will use DuckDuckGo.")


async def search_for_resources(topics: list) -> list:
    """
    Search for educational resources related to improvement topics
    
    Args:
        topics: List of topics to search for
        
    Returns:
        List of resource dictionaries with title and link
    """
    resources = []
    
    for topic in topics[:3]:  # Limit to top 3 topics
        if TAVILY_AVAILABLE and ClaudeConfig.TAVILY_API_KEY:
            try:
                tavily_client = TavilyClient(api_key=ClaudeConfig.TAVILY_API_KEY)
                search_result = tavily_client.search(
                    query=f"{topic} interview tips guide tutorial",
                    search_depth="basic",
                    max_results=1
                )
                
                if search_result.get('results'):
                    result = search_result['results'][0]
                    resources.append({
                        "title": result.get('title', f"{topic} - Resource"),
                        "link": result.get('url', '')
                    })
            except Exception as e:
                print(f"Tavily search error for {topic}: {e}")
                # Fallback to DuckDuckGo
                ddg_result = search_ddgs(f"{topic} interview tips")
                if ddg_result:
                    resources.append(ddg_result)
        else:
            # Use DuckDuckGo
            ddg_result = search_ddgs(f"{topic} interview tips")
            if ddg_result:
                resources.append(ddg_result)
    
    return resources


def run_judge_from_session(session):
    """
    Evaluate an interview by running the InterviewJudgeAgent using Claude and an existing session.

    Args:
        session: The session object with context already set.

    Returns:
        dict: JSON feedback from the judge agent.
    """
    return asyncio.run(_run_judge_from_session_claude(session))


async def _run_judge_from_session_claude(session):
    """Internal async function that executes the Claude API call"""
    
    # Prepare input data
    input_data = get_interview_judge_input_data(
        session.state.get("personal_experience", ""),
        session.state.get("transcript", ""),
        session.state.get("recommend_qas", "")
    )
    
    feedback_json = None
    try:
        # Get Claude client
        client = get_claude_client()
        
        # Call Claude API with JSON generation
        response_text = await client.generate(
            prompt=input_data,
            system_prompt=get_interview_judge_instruction(),
            model=ClaudeConfig.PREMIUM_MODEL,  # Use Sonnet for high-quality feedback
            max_tokens=4000,
            temperature=0.3  # Lower temperature for consistent, professional feedback
        )
        
        print("[DEBUG] Raw Feedback Agent Response (Claude):")
        print(response_text)
        
        # Parse and validate feedback
        result = parse_and_validate_feedback(response_text)
        
        if result["status"] == "valid":
            feedback_json = result["data"]
            
            # Validate and fix resource links
            for resource in feedback_json.get("resources", []):
                link = resource.get("link", "")
                if not is_valid_and_reachable_url(link):
                    print(f"[⚠️ Invalid link]: {link} – Regenerating via search...")
                    new_resource = search_ddgs(resource.get("title", "interview tips"))
                    resource["title"] = new_resource["title"]
                    resource["link"] = new_resource["link"]
            
            print("[DEBUG] Feedback is valid")
            feedback_json = deduplicate_resources(feedback_json)
            
            # Save to database
            save_result = save_feedback_to_db(session, feedback_json)
            if save_result.get("message"):
                print("[DEBUG] Feedback stored.")
        else:
            print("[ERROR] Feedback invalid or could not be parsed:")
            print(result)
        
        return feedback_json
    
    except Exception as e:
        print(f"[ERROR] Claude judge agent error: {str(e)}")
        return {
            "error": f"Error in Claude judge agent: {str(e)}"
        }
    
    finally:
        try:
            await session_service.delete_session(
                app_name=session.app_name,
                user_id=session.user_id,
                session_id=session.id
            )
            print(f"[CLEANUP]: Session {session.id} successfully closed.")
        except Exception as e:
            print(f"[CLEANUP ERROR]: Failed to close session {session.id}: {e}")


def parse_and_validate_feedback(response_text):
    """Extracts and validates feedback JSON from agent response."""
    try:
        # Clean response (e.g., remove markdown)
        match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", response_text)
        json_str = match.group(1).strip() if match else response_text
        
        # Try to extract JSON if not already clean
        if not json_str.strip().startswith('{'):
            start_index = response_text.find('{')
            end_index = response_text.rfind('}') + 1
            if start_index >= 0 and end_index > start_index:
                json_str = response_text[start_index:end_index]

        # Parse JSON
        parsed = json.loads(json_str)

        # Validate with schema
        validated = Feedback.model_validate(parsed)

        return {"status": "valid", "data": parsed}

    except ValidationError as ve:
        return {"status": "invalid", "errors": ve.errors(), "raw": response_text}
    except Exception as e:
        return {"status": "error", "message": str(e), "raw": response_text}


def save_feedback_to_db(session, validated):
    """
    Save a Feedback object to Firestore under a specific user and session.

    Args:
        session: Session object with user_id, workflow_id, and session id
        validated: Validated feedback dictionary
    """
    return firestore_db.set_feedback(
        session.user_id,
        session.state.get("workflow_id"),
        session.id,
        Feedback(**validated)
    )


def is_valid_and_reachable_url(url):
    """Check if a URL is valid and reachable"""
    try:
        response = requests.get(url, timeout=5)
        if response.status_code >= 400:
            return False
        content = response.text.lower()
        if "404" in content or "page not found" in content or "not available" in content:
            return False
        if len(content) < 500:  # arbitrary: prevent empty landing pages
            return False
        return True
    except Exception:
        return False


def deduplicate_resources(feedback_json):
    """Remove duplicate resources based on link"""
    seen_links = set()
    unique_resources = []
    
    for resource in feedback_json.get("resources", []):
        link = resource.get("link")
        if link and link not in seen_links:
            unique_resources.append(resource)
            seen_links.add(link)
    
    feedback_json["resources"] = unique_resources
    return feedback_json


def search_ddgs(topic: str, max_results: int = 1, delay: int = 1) -> dict:
    """
    Use DuckDuckGo to get a real search result link for a given topic
    """
    try:
        with DDGS() as ddgs:
            for result in ddgs.text(topic, max_results=max_results):
                if result and result.get("href", "").startswith("http"):
                    return {
                        "title": result.get("title", "Related resource"),
                        "link": result["href"]
                    }
        # Wait before retrying if no result found
        print(f"[Retry] No valid link found. Waiting {delay}s...")
        time.sleep(delay)
    except Exception as e:
        print(f"[Retry] Error: {e}. Waiting {delay}s...")
        time.sleep(delay)

    # Fallback if all attempts fail
    print("[Fallback] Using default backup link.")
    return {
        "title": "5 Tips To Ace a Behavioral-Based Interview",
        "link": "https://jobs.gartner.com/life-at-gartner/your-career/5-tips-to-ace-a-behavioral-based-interview/"
    }

