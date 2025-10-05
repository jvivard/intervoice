"""
Preparation Workflow Coordinator - Claude version using agent factories
Custom orchestration to replace ADK Sequential Agent
"""

import os
import sys
import asyncio
import json
import traceback
import time
import secrets
import string
from typing import Optional

# Add the project root to the Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

# Import agent factories
from backend.agents.summarizer.agent_factory import summarize_resume
from backend.agents.search.agent_factory import search_interview_questions
from backend.agents.question_generator.agent_factory import generate_custom_questions
from backend.agents.answer_generator.agent_factory import generate_and_save_personalized_answers

# Import config
from backend.config import set_google_cloud_env_vars

# Load environment variables
set_google_cloud_env_vars()


def generate_session_id(input_data: str = ""):
    """Generate a random session ID similar to Firestore document IDs"""
    alphabet = string.ascii_letters + string.digits
    session_id = ''.join(secrets.choice(alphabet) for _ in range(20))
    return session_id


async def run_preparation_workflow(
    user_id: str,
    resume_text: str,
    job_description: str,
    linkedin_link: str = "",
    github_link: str = "", 
    portfolio_link: str = "",
    additional_info: str = "",
    num_questions: int = 50,
    session_id: Optional[str] = None,
):
    """
    Run the complete interview preparation workflow using Claude agents
    
    Args:
        user_id: User ID from frontend login system
        resume_text: Resume content (required)
        job_description: Target job description (required)
        linkedin_link: LinkedIn profile URL (optional)
        github_link: GitHub profile URL (optional)
        portfolio_link: Portfolio URL (optional)
        additional_info: Additional user information (optional)
        num_questions: Number of questions to generate (default: 50)
        session_id: Session ID (optional, will auto-generate if not provided)
    
    Returns:
        dict: Result with workflow completion status and generated data
    """
    try:
        # Auto-generate session_id if not provided
        if not session_id:
            input_signature = f"{user_id}{resume_text[:100]}{job_description[:100]}{time.time()}"
            session_id = generate_session_id(input_signature)
        
        workflow_id = session_id  # session_id serves as workflow_id
        
        print(f"=== Starting Claude workflow for user {user_id} ===")
        start_time = time.time()
        
        # Step 1: Process GitHub URL if provided
        github_analysis_result = ""
        if github_link and github_link.strip():
            try:
                from backend.services.github import GitHubAnalyzer
                github_analyzer = GitHubAnalyzer()
                github_analysis_result = github_analyzer.get_github_summary_for_workflow(github_link)
                print(f"✓ GitHub analysis completed: {len(github_analysis_result)} characters")
            except Exception as e:
                print(f"⚠ GitHub analysis failed: {e}")
        
        # Step 2: Analyze portfolio URL if provided
        portfolio_content = ""
        if portfolio_link and portfolio_link.strip():
            try:
                from backend.services.portfolio.portfolio_analyzer import analyze_portfolio_url
                portfolio_content = await analyze_portfolio_url(portfolio_link.strip())
                print(f"✓ Portfolio analysis completed: {len(portfolio_content)} characters")
            except Exception as e:
                print(f"⚠ Portfolio analysis failed: {e}")
        
        # Step 3: Summarize resume (using factory which selects Claude or Gemini)
        print("\n[1/4] Running summarizer agent...")
        step_start = time.time()
        
        personal_summary = await asyncio.to_thread(
            summarize_resume,
            resume_text,
            linkedin_link,
            github_analysis_result,
            portfolio_content,
            additional_info,
            job_description
        )
        
        print(f"✓ Summarizer completed in {time.time() - step_start:.2f}s")
        
        if isinstance(personal_summary, dict) and "error" in personal_summary:
            raise Exception(f"Summarizer error: {personal_summary['error']}")
        
        # Step 4: Search for industry FAQs (parallel with summarizer in original, but sequential here)
        print("\n[2/4] Running search agent...")
        step_start = time.time()
        
        industry_faqs = await asyncio.to_thread(
            search_interview_questions,
            job_description
        )
        
        print(f"✓ Search completed in {time.time() - step_start:.2f}s")
        
        if isinstance(industry_faqs, dict) and "error" in industry_faqs:
            print(f"⚠ Search error (continuing): {industry_faqs['error']}")
            industry_faqs = {}
        
        # Step 5: Generate questions
        print("\n[3/4] Running question generator agent...")
        step_start = time.time()
        
        questions_data = await asyncio.to_thread(
            generate_custom_questions,
            personal_summary,
            industry_faqs,
            num_questions
        )
        
        print(f"✓ Question generator completed in {time.time() - step_start:.2f}s")
        print(f"  Generated {len(questions_data) if isinstance(questions_data, list) else 0} questions")
        
        if isinstance(questions_data, dict) and "error" in questions_data:
            raise Exception(f"Question generator error: {questions_data['error']}")
        
        # Step 6: Generate answers and save to database
        print("\n[4/4] Running answer generator agent...")
        step_start = time.time()
        
        answers_result = await asyncio.to_thread(
            generate_and_save_personalized_answers,
            questions_data,
            personal_summary,
            user_id,
            workflow_id
        )
        
        print(f"✓ Answer generator completed in {time.time() - step_start:.2f}s")
        
        if isinstance(answers_result, dict) and "error" in answers_result:
            raise Exception(f"Answer generator error: {answers_result['error']}")
        
        # Step 7: Save PersonalExperience and Workflow title to database
        await _save_personal_experience_to_database(user_id, workflow_id, personal_summary)
        
        total_time = time.time() - start_time
        print(f"\n=== Claude workflow completed in {total_time:.2f}s ===")
        
        return {
            "success": True,
            "user_id": user_id,
            "session_id": session_id,
            "workflow_id": workflow_id,
            "completed_agents": ["summarizer", "search", "question_generator", "answer_generator"],
            "personal_summary": json.dumps(personal_summary, ensure_ascii=False),
            "industry_faqs": json.dumps(industry_faqs, ensure_ascii=False),
            "questions_data": json.dumps(questions_data, ensure_ascii=False),
            "final_answers": json.dumps(answers_result.get("answers", []), ensure_ascii=False),
            "execution_time_seconds": total_time
        }
        
    except Exception as e:
        print(f"❌ Error in Claude preparation workflow: {e}")
        print(traceback.format_exc())
        return {
            "success": False,
            "error": str(e),
            "user_id": user_id,
            "session_id": session_id if session_id else None,
            "workflow_id": workflow_id if 'workflow_id' in locals() else None
        }


async def _save_personal_experience_to_database(user_id, workflow_id, personal_summary):
    """Save personal experience and workflow to database"""
    try:
        if personal_summary and isinstance(personal_summary, dict) and "error" not in personal_summary:
            from backend.data.schemas import PersonalExperience, Workflow
            from backend.data.database import firestore_db
            
            # Save workflow title
            title = personal_summary.get("title", "")
            if title:
                workflow_data = Workflow(title=title)
                firestore_db.create_or_update_workflow(user_id, workflow_id, workflow_data)
                print(f"✓ Saved workflow title '{title}' to database")
            
            # Convert to PersonalExperience object for database storage
            personal_experience = PersonalExperience(
                resumeInfo=personal_summary.get("resumeInfo", ""),
                linkedinInfo=personal_summary.get("linkedinInfo", ""),
                githubInfo=personal_summary.get("githubInfo", ""),
                portfolioInfo=personal_summary.get("portfolioInfo", ""),
                additionalInfo=personal_summary.get("additionalInfo", ""),
                jobDescription=personal_summary.get("jobDescription", "")
            )
            
            # Save to database
            firestore_db.set_personal_experience(user_id, workflow_id, personal_experience)
            print(f"✓ Saved personal experience to database")
            
    except Exception as e:
        print(f"⚠ Could not save to database: {e}")


def run_preparation_workflow_sync(*args, **kwargs):
    """
    Synchronous wrapper for the async workflow function
    """
    return asyncio.run(run_preparation_workflow(*args, **kwargs))

