"""Factory for Answer Generator agent - enables switching between Gemini and Claude"""

from backend.config import ClaudeConfig

def generate_and_save_personalized_answers(questions_data, personal_summary, user_id, workflow_id):
    """
    Generate personalized interview answers and save them to database
    Automatically selects between Claude and Gemini based on configuration
    """
    if ClaudeConfig.ANSWER_GEN_USE_CLAUDE:
        from .agent_claude import generate_and_save_personalized_answers as claude_impl
        return claude_impl(questions_data, personal_summary, user_id, workflow_id)
    else:
        from .agent import generate_and_save_personalized_answers as gemini_impl
        return gemini_impl(questions_data, personal_summary, user_id, workflow_id)


def generate_personalized_answers(questions_data, personal_summary):
    """
    Generate personalized interview answers (without database save)
    Automatically selects between Claude and Gemini based on configuration
    """
    if ClaudeConfig.ANSWER_GEN_USE_CLAUDE:
        from .agent_claude import generate_personalized_answers as claude_impl
        return claude_impl(questions_data, personal_summary)
    else:
        from .agent import generate_personalized_answers as gemini_impl
        return gemini_impl(questions_data, personal_summary)

