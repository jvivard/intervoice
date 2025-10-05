"""Interview questions search agent - Claude version with Tavily search integration
Search the Internet for common interview questions and experiences
"""

import json
import os
import asyncio
import sys
import re

# Add the project root to the Python path if necessary
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../")))

# Import unified config
from backend.config import set_google_cloud_env_vars, ClaudeConfig
from backend.services.claude_client import ClaudeClient, get_claude_client
from .prompt import SEARCH_PROMPT

# Load environment variables
set_google_cloud_env_vars()

# Import Tavily for search functionality
try:
    from tavily import TavilyClient
    TAVILY_AVAILABLE = True
except ImportError:
    TAVILY_AVAILABLE = False
    print("Warning: tavily-python not installed. Search functionality will be limited.")


async def perform_web_search(query: str) -> str:
    """
    Perform web search using Tavily API
    
    Args:
        query: Search query string
        
    Returns:
        Formatted search results as string
    """
    if not TAVILY_AVAILABLE:
        return "Search unavailable: Tavily not installed"
    
    if not ClaudeConfig.TAVILY_API_KEY:
        return "Search unavailable: TAVILY_API_KEY not configured"
    
    try:
        tavily_client = TavilyClient(api_key=ClaudeConfig.TAVILY_API_KEY)
        
        # Perform search with Tavily
        search_result = tavily_client.search(
            query=query,
            search_depth="advanced",  # More comprehensive search
            max_results=10  # Get more results for better coverage
        )
        
        # Format results for Claude
        formatted_results = []
        for result in search_result.get('results', []):
            formatted_results.append({
                "title": result.get('title', ''),
                "url": result.get('url', ''),
                "content": result.get('content', ''),
                "score": result.get('score', 0)
            })
        
        # Return formatted string
        results_text = f"Search Query: {query}\n\n"
        results_text += f"Found {len(formatted_results)} results:\n\n"
        
        for i, result in enumerate(formatted_results, 1):
            results_text += f"{i}. {result['title']}\n"
            results_text += f"   URL: {result['url']}\n"
            results_text += f"   Content: {result['content'][:300]}...\n\n"
        
        return results_text
    
    except Exception as e:
        return f"Search error: {str(e)}"


def search_interview_questions(job_description):
    """
    Search for common interview questions and experiences based on job description using Claude
    
    Args:
        job_description: The complete job description text
        
    Returns:
        dict: Structured interview questions and experiences
    """
    return asyncio.run(_run_searcher_claude(job_description))


async def _run_searcher_claude(job_description):
    """Internal async function that executes the Claude API call with search integration"""
    
    # Extract job title and key information from job description
    job_title = _extract_job_title(job_description)
    
    # Perform multiple searches to gather comprehensive information
    search_queries = [
        f"{job_title} interview questions",
        f"{job_title} technical interview questions",
        f"{job_title} behavioral interview questions",
        f"{job_title} interview experience",
        f"{job_title} common interview questions 2024"
    ]
    
    # Execute all searches
    all_search_results = []
    for query in search_queries:
        result = await perform_web_search(query)
        all_search_results.append(f"=== {query} ===\n{result}\n")
    
    # Combine search results
    combined_search_results = "\n".join(all_search_results)
    
    # Prepare input data for Claude
    input_data = f"""
    ## Job Description
    {job_description}
    
    ## Search Results from Web
    {combined_search_results}
    
    Based on the above job description and web search results, organize the common interview questions and experiences for this position.
    """
    
    try:
        # Get Claude client
        client = get_claude_client()
        
        # Call Claude API with JSON generation
        result = await client.generate_json(
            prompt=input_data,
            system_prompt=SEARCH_PROMPT,
            model=ClaudeConfig.BUDGET_MODEL,  # Use Haiku for cost-effective search processing
            max_tokens=6000  # Large limit for comprehensive search results
        )
        
        return result
    
    except Exception as e:
        # Fallback: if JSON parsing fails, try regular generation
        print(f"Error in Claude search agent: {str(e)}")
        
        try:
            client = get_claude_client()
            response_text = await client.generate(
                prompt=input_data,
                system_prompt=SEARCH_PROMPT,
                model=ClaudeConfig.BUDGET_MODEL,
                max_tokens=6000
            )
            
            # Manual JSON extraction
            return _extract_json_fallback(response_text)
        
        except Exception as e2:
            return {
                "error": f"Error in Claude search agent: {str(e2)}",
                "raw_response": str(e2)
            }


def _extract_job_title(job_description: str) -> str:
    """
    Extract job title from job description
    Simple heuristic - looks for common patterns
    """
    lines = job_description.strip().split('\n')
    
    # Look for title in first few lines
    for line in lines[:5]:
        line = line.strip()
        if line and not line.startswith('#'):
            # Remove common prefixes
            for prefix in ['Position:', 'Job Title:', 'Role:', 'Title:']:
                if line.startswith(prefix):
                    line = line[len(prefix):].strip()
            
            # If line is not too long, likely a title
            if len(line) < 100 and len(line.split()) < 10:
                return line
    
    # Fallback: return first line
    return lines[0] if lines else "Unknown Position"


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

