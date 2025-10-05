"""
Claude AI Client Wrapper
Provides a unified interface for interacting with Anthropic's Claude API
"""

import os
import json
import asyncio
from typing import Optional, Dict, Any, List, AsyncGenerator
from anthropic import AsyncAnthropic, Anthropic
from backend.config import ClaudeConfig


class ClaudeClient:
    """
    Wrapper for Claude API to handle common operations like:
    - Text generation
    - JSON generation
    - Streaming responses
    - Error handling
    """
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize Claude client
        
        Args:
            api_key: Optional API key. If not provided, reads from environment
        """
        self.api_key = api_key or ClaudeConfig.ANTHROPIC_API_KEY
        if not self.api_key:
            raise ValueError(
                "ANTHROPIC_API_KEY not found. "
                "Please set it in your .env file or pass it to the constructor."
            )
        
        self.client = AsyncAnthropic(api_key=self.api_key)
        self.sync_client = Anthropic(api_key=self.api_key)
    
    async def generate(
        self,
        prompt: str,
        system_prompt: str = "",
        model: str = ClaudeConfig.DEFAULT_MODEL,
        max_tokens: int = ClaudeConfig.DEFAULT_MAX_TOKENS,
        temperature: float = ClaudeConfig.DEFAULT_TEMPERATURE,
        **kwargs
    ) -> str:
        """
        Generate text response from Claude
        
        Args:
            prompt: User prompt/input
            system_prompt: System instructions for Claude
            model: Claude model to use
            max_tokens: Maximum tokens in response
            temperature: Sampling temperature (0-1)
            **kwargs: Additional parameters for Claude API
        
        Returns:
            Generated text response
        """
        try:
            response = await self.client.messages.create(
                model=model,
                max_tokens=max_tokens,
                temperature=temperature,
                system=system_prompt if system_prompt else None,
                messages=[{"role": "user", "content": prompt}],
                **kwargs
            )
            
            return response.content[0].text
        
        except Exception as e:
            raise Exception(f"Claude API error: {str(e)}")
    
    async def generate_json(
        self,
        prompt: str,
        system_prompt: str = "",
        model: str = ClaudeConfig.DEFAULT_MODEL,
        max_tokens: int = ClaudeConfig.DEFAULT_MAX_TOKENS,
        **kwargs
    ) -> Dict[Any, Any]:
        """
        Generate JSON response from Claude
        
        Args:
            prompt: User prompt/input
            system_prompt: System instructions for Claude
            model: Claude model to use
            max_tokens: Maximum tokens in response
            **kwargs: Additional parameters
        
        Returns:
            Parsed JSON response as dictionary
        """
        # Add JSON instruction to system prompt
        json_instruction = "\n\nYou MUST respond with valid JSON only. No additional text or explanation."
        full_system_prompt = (system_prompt + json_instruction) if system_prompt else json_instruction
        
        text_response = await self.generate(
            prompt=prompt,
            system_prompt=full_system_prompt,
            model=model,
            max_tokens=max_tokens,
            temperature=0.3,  # Lower temperature for structured output
            **kwargs
        )
        
        # Extract JSON from response (handles markdown code blocks)
        return self._extract_json(text_response)
    
    async def stream(
        self,
        prompt: str,
        system_prompt: str = "",
        model: str = ClaudeConfig.DEFAULT_MODEL,
        max_tokens: int = ClaudeConfig.DEFAULT_MAX_TOKENS,
        temperature: float = ClaudeConfig.DEFAULT_TEMPERATURE,
        **kwargs
    ) -> AsyncGenerator[str, None]:
        """
        Stream text response from Claude
        
        Args:
            prompt: User prompt/input
            system_prompt: System instructions
            model: Claude model to use
            max_tokens: Maximum tokens in response
            temperature: Sampling temperature
            **kwargs: Additional parameters
        
        Yields:
            Text chunks as they're generated
        """
        try:
            async with self.client.messages.stream(
                model=model,
                max_tokens=max_tokens,
                temperature=temperature,
                system=system_prompt if system_prompt else None,
                messages=[{"role": "user", "content": prompt}],
                **kwargs
            ) as stream:
                async for text in stream.text_stream:
                    yield text
        
        except Exception as e:
            raise Exception(f"Claude streaming error: {str(e)}")
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        system_prompt: str = "",
        model: str = ClaudeConfig.DEFAULT_MODEL,
        max_tokens: int = ClaudeConfig.DEFAULT_MAX_TOKENS,
        temperature: float = ClaudeConfig.DEFAULT_TEMPERATURE,
        **kwargs
    ) -> str:
        """
        Multi-turn conversation with Claude
        
        Args:
            messages: List of message dicts with 'role' and 'content'
                     Example: [{"role": "user", "content": "Hello"}, 
                               {"role": "assistant", "content": "Hi!"}]
            system_prompt: System instructions
            model: Claude model to use
            max_tokens: Maximum tokens
            temperature: Sampling temperature
            **kwargs: Additional parameters
        
        Returns:
            Assistant's response text
        """
        try:
            response = await self.client.messages.create(
                model=model,
                max_tokens=max_tokens,
                temperature=temperature,
                system=system_prompt if system_prompt else None,
                messages=messages,
                **kwargs
            )
            
            return response.content[0].text
        
        except Exception as e:
            raise Exception(f"Claude chat error: {str(e)}")
    
    async def stream_chat(
        self,
        messages: List[Dict[str, str]],
        system_prompt: str = "",
        model: str = ClaudeConfig.DEFAULT_MODEL,
        max_tokens: int = ClaudeConfig.DEFAULT_MAX_TOKENS,
        temperature: float = ClaudeConfig.DEFAULT_TEMPERATURE,
        **kwargs
    ) -> AsyncGenerator[str, None]:
        """
        Stream multi-turn conversation
        
        Args:
            messages: Conversation history
            system_prompt: System instructions
            model: Claude model
            max_tokens: Maximum tokens
            temperature: Sampling temperature
            **kwargs: Additional parameters
        
        Yields:
            Text chunks as they're generated
        """
        try:
            async with self.client.messages.stream(
                model=model,
                max_tokens=max_tokens,
                temperature=temperature,
                system=system_prompt if system_prompt else None,
                messages=messages,
                **kwargs
            ) as stream:
                async for text in stream.text_stream:
                    yield text
        
        except Exception as e:
            raise Exception(f"Claude stream chat error: {str(e)}")
    
    @staticmethod
    def _extract_json(text: str) -> Dict[Any, Any]:
        """
        Extract JSON from Claude's response, handling markdown code blocks
        
        Args:
            text: Raw text response from Claude
        
        Returns:
            Parsed JSON as dictionary
        """
        # Try direct parse first
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass
        
        # Try to extract from markdown code blocks
        if "```json" in text:
            start = text.find("```json") + 7
            end = text.find("```", start)
            json_str = text[start:end].strip()
        elif "```" in text:
            start = text.find("```") + 3
            end = text.find("```", start)
            json_str = text[start:end].strip()
        else:
            # Try to find JSON-like structure
            start = text.find("{")
            end = text.rfind("}") + 1
            if start != -1 and end > start:
                json_str = text[start:end]
            else:
                raise ValueError(f"Could not extract JSON from response: {text[:200]}")
        
        try:
            return json.loads(json_str)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in response: {str(e)}\n{json_str[:200]}")


# Global client instance (singleton pattern)
_claude_client: Optional[ClaudeClient] = None


def get_claude_client() -> ClaudeClient:
    """
    Get or create global Claude client instance
    
    Returns:
        Shared ClaudeClient instance
    """
    global _claude_client
    if _claude_client is None:
        _claude_client = ClaudeClient()
    return _claude_client


# Convenience functions for quick usage
async def generate_text(prompt: str, system_prompt: str = "", **kwargs) -> str:
    """Quick text generation"""
    client = get_claude_client()
    return await client.generate(prompt, system_prompt, **kwargs)


async def generate_json_response(prompt: str, system_prompt: str = "", **kwargs) -> Dict[Any, Any]:
    """Quick JSON generation"""
    client = get_claude_client()
    return await client.generate_json(prompt, system_prompt, **kwargs)


async def stream_text(prompt: str, system_prompt: str = "", **kwargs) -> AsyncGenerator[str, None]:
    """Quick streaming"""
    client = get_claude_client()
    async for chunk in client.stream(prompt, system_prompt, **kwargs):
        yield chunk

