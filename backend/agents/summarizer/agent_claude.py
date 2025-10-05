"""Resume summarization agent - Claude version
Converts user's resume content into structured JSON format using Claude API
"""

import json
import os
import asyncio
import sys
import re

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../")))

# Import unified config
from backend.config import set_google_cloud_env_vars, ClaudeConfig
from backend.services.claude_client import ClaudeClient, get_claude_client
from .prompt import SUMMARIZER_PROMPT

# Load environment variables
set_google_cloud_env_vars()


def summarize_resume(resume_text, linkedinLink, githubLink, portfolioLink, additionalInfo, job_description):
    """
    Analyze and summarize user resume and related information using Claude
    
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
    return asyncio.run(_run_summarizer_claude(
        resume_text, linkedinLink, githubLink, portfolioLink, additionalInfo, job_description
    ))


async def _run_summarizer_claude(resume_text, linkedinLink, githubLink, portfolioLink, additionalInfo, job_description):
    """Internal async function that executes the Claude API call"""
    
    # Prepare input data
    input_data = f"""
    ## Resume Content
    {resume_text}
    
    ## LinkedIn URL (SEARCH THIS EXACT URL)
    {linkedinLink}
    
    ## GitHub URL (SEARCH THIS EXACT URL)
    {githubLink}
    
    ## Portfolio URL (SEARCH THIS EXACT URL)
    {portfolioLink}
    
    ## Additional Information
    {additionalInfo}
    
    ## Job Description
    {job_description}
    """
    
    try:
        # Get Claude client
        client = get_claude_client()
        
        # Call Claude API with JSON generation
        result = await client.generate_json(
            prompt=input_data,
            system_prompt=SUMMARIZER_PROMPT,
            model=ClaudeConfig.BUDGET_MODEL,  # Use Haiku for summarization (cost-effective)
            max_tokens=8000  # Larger limit for comprehensive summaries
        )
        
        return result
    
    except Exception as e:
        # Fallback: if JSON parsing fails, try regular generation
        print(f"Error in Claude summarizer: {str(e)}")
        
        try:
            client = get_claude_client()
            response_text = await client.generate(
                prompt=input_data,
                system_prompt=SUMMARIZER_PROMPT,
                model=ClaudeConfig.BUDGET_MODEL,
                max_tokens=8000
            )
            
            # Manual JSON extraction
            return _extract_json_fallback(response_text)
        
        except Exception as e2:
            return {
                "error": f"Error in Claude summarizer: {str(e2)}",
                "raw_response": str(e2)
            }


def _extract_json_fallback(response_text: str) -> dict:
    """Fallback JSON extraction from response text"""
    
    try:
        # Try markdown JSON pattern first
        markdown_json_pattern = r"```(?:json)?\s*([\s\S]*?)\s*```"
        markdown_matches = re.findall(markdown_json_pattern, response_text)
        
        if markdown_matches:
            clean_json_str = markdown_matches[0].strip()
            return json.loads(clean_json_str)
        else:
            # Try direct JSON parse
            return json.loads(response_text)
            
    except json.JSONDecodeError:
        try:
            # Extract JSON object from text
            start_index = response_text.find('{')
            end_index = response_text.rfind('}') + 1
            if start_index >= 0 and end_index > start_index:
                json_str = response_text[start_index:end_index]
                return json.loads(json_str)
            else:
                raise ValueError("Could not find valid JSON in the response")
        except Exception as e:
            return {
                "error": f"Error parsing response: {str(e)}",
                "raw_response": response_text
            }

