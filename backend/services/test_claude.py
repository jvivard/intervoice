"""
Quick test script for Claude API integration
Run this to verify your Claude setup is working
"""

import asyncio
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.config import set_google_cloud_env_vars, ClaudeConfig
from backend.services.claude_client import ClaudeClient, get_claude_client

set_google_cloud_env_vars()


async def test_basic_generation():
    """Test basic text generation"""
    print("\n=== Test 1: Basic Text Generation ===")
    
    try:
        client = get_claude_client()
        
        response = await client.generate(
            prompt="Generate 3 technical interview questions for a Python developer.",
            system_prompt="You are an expert technical interviewer.",
            max_tokens=500
        )
        
        print(f"✅ Success!")
        print(f"Response:\n{response}\n")
        return True
    
    except Exception as e:
        print(f"❌ Failed: {str(e)}\n")
        return False


async def test_json_generation():
    """Test JSON generation"""
    print("\n=== Test 2: JSON Generation ===")
    
    try:
        client = get_claude_client()
        
        response = await client.generate_json(
            prompt="""Generate 2 interview questions about Python programming.
            Return as JSON with this structure:
            {
                "questions": [
                    {"id": 1, "question": "...", "difficulty": "medium"},
                    {"id": 2, "question": "...", "difficulty": "hard"}
                ]
            }""",
            system_prompt="You are a technical interviewer. Return ONLY valid JSON.",
            max_tokens=800
        )
        
        print(f"✅ Success!")
        print(f"JSON Response: {response}\n")
        print(f"Number of questions: {len(response.get('questions', []))}")
        return True
    
    except Exception as e:
        print(f"❌ Failed: {str(e)}\n")
        return False


async def test_streaming():
    """Test streaming responses"""
    print("\n=== Test 3: Streaming Text ===")
    
    try:
        client = get_claude_client()
        
        print("Streaming response: ", end="", flush=True)
        
        async for chunk in client.stream(
            prompt="Write a brief 2-sentence introduction about AI interview preparation.",
            system_prompt="You are a helpful assistant.",
            max_tokens=200
        ):
            print(chunk, end="", flush=True)
        
        print("\n\n✅ Streaming Success!\n")
        return True
    
    except Exception as e:
        print(f"\n❌ Streaming Failed: {str(e)}\n")
        return False


async def test_conversation():
    """Test multi-turn conversation"""
    print("\n=== Test 4: Multi-turn Conversation ===")
    
    try:
        client = get_claude_client()
        
        messages = [
            {"role": "user", "content": "What's the difference between list and tuple in Python?"},
            {"role": "assistant", "content": "Lists are mutable (can be changed) while tuples are immutable (cannot be changed after creation)."},
            {"role": "user", "content": "Give me a practical example."}
        ]
        
        response = await client.chat(
            messages=messages,
            system_prompt="You are a Python programming tutor. Keep responses concise.",
            max_tokens=300
        )
        
        print(f"✅ Success!")
        print(f"Response:\n{response}\n")
        return True
    
    except Exception as e:
        print(f"❌ Failed: {str(e)}\n")
        return False


async def main():
    """Run all tests"""
    print("=" * 60)
    print("CLAUDE API INTEGRATION TEST")
    print("=" * 60)
    
    # Check configuration
    print(f"\n📋 Configuration Check:")
    print(f"   API Key Set: {'✅ Yes' if ClaudeConfig.ANTHROPIC_API_KEY else '❌ No'}")
    print(f"   Default Model: {ClaudeConfig.DEFAULT_MODEL}")
    print(f"   Claude Enabled: {'✅ Yes' if ClaudeConfig.USE_CLAUDE else '❌ No'}")
    
    if not ClaudeConfig.ANTHROPIC_API_KEY:
        print("\n⚠️  ERROR: ANTHROPIC_API_KEY not set!")
        print("   Please add it to backend/.env file")
        print("   Get your key from: https://console.anthropic.com")
        return
    
    # Run tests
    results = []
    results.append(await test_basic_generation())
    results.append(await test_json_generation())
    results.append(await test_streaming())
    results.append(await test_conversation())
    
    # Summary
    print("=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    passed = sum(results)
    total = len(results)
    print(f"✅ Passed: {passed}/{total}")
    
    if passed == total:
        print("\n🎉 All tests passed! Claude integration is ready!")
    else:
        print(f"\n⚠️  {total - passed} test(s) failed. Check errors above.")


if __name__ == "__main__":
    asyncio.run(main())

