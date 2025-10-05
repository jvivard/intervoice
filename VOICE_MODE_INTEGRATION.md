# 🎙️ Voice Mode Integration for Claude

## Current Status

- ✅ **Audio Recording**: Working (microphone captures audio)
- ✅ **Audio Transmission**: Working (audio sent to backend)
- ❌ **Audio Processing**: Not working (Claude doesn't support audio)

---

## Why Voice Mode Doesn't Work with Claude

Claude API is **text-only**. It cannot process audio directly.

**What happens:**
1. User speaks → Microphone records → Audio sent to backend
2. Backend receives `audio/pcm` data
3. Backend says: "Audio input is not yet supported"
4. No interactive response

**What's needed:**
- Speech-to-Text (STT) to convert audio → text
- Send text to Claude
- Claude responds with text
- Text-to-Speech (TTS) to convert text → audio (optional)

---

## Solution: Add Whisper STT Integration

### Step 1: Install Whisper

```bash
cd backend
pip install openai-whisper
```

### Step 2: Update Claude Interviewer Agent

Add STT processing in `backend/agents/interviewer/agent_claude.py`:

```python
import whisper
import tempfile
import base64

# Load Whisper model (do this once on startup)
_whisper_model = None

def get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        _whisper_model = whisper.load_model("base")  # or "small", "medium"
    return _whisper_model

async def transcribe_audio(audio_base64: str) -> str:
    """Convert audio to text using Whisper"""
    try:
        # Decode base64 audio
        audio_bytes = base64.b64decode(audio_base64)
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(suffix=".webm", delete=False) as temp_audio:
            temp_audio.write(audio_bytes)
            temp_path = temp_audio.name
        
        # Transcribe with Whisper
        model = get_whisper_model()
        result = model.transcribe(temp_path)
        
        # Clean up temp file
        os.remove(temp_path)
        
        return result["text"].strip()
    
    except Exception as e:
        print(f"[ERROR] Whisper transcription failed: {e}")
        return ""
```

### Step 3: Process Audio Messages

Replace the audio warning with STT:

```python
elif mime_type == "audio/pcm":
    print("[CLIENT TO AGENT]: Received audio data")
    
    # Transcribe audio to text
    transcribed_text = await transcribe_audio(data)
    
    if not transcribed_text:
        error_message = {
            "mime_type": "text/plain",
            "data": "Sorry, I couldn't hear that clearly. Could you try again?"
        }
        await websocket.send_text(json.dumps(error_message))
        continue
    
    print(f"[TRANSCRIBED]: {transcribed_text}")
    
    # Process as text (same as text/plain above)
    session.state["transcript"].append({"role": "user", "message": transcribed_text})
    session.state["conversation_history"].append({
        "role": "user",
        "content": transcribed_text
    })
    
    # Stream Claude response
    full_response = ""
    async for chunk in client.stream(
        prompt=transcribed_text,
        system_prompt=system_instruction,
        model=ClaudeConfig.PREMIUM_MODEL,
        max_tokens=ClaudeConfig.INTERVIEW_MAX_TOKENS,
        temperature=0.3
    ):
        full_response += chunk
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
    
    # Store in history
    session.state["conversation_history"].append({
        "role": "assistant",
        "content": full_response
    })
    session.state["transcript"].append({"role": "AI", "message": full_response})
```

---

## Alternative: Use Google Speech-to-Text

If you prefer Google STT (better for real-time):

```bash
pip install google-cloud-speech
```

```python
from google.cloud import speech

async def transcribe_audio_google(audio_base64: str) -> str:
    """Convert audio to text using Google STT"""
    client = speech.SpeechClient()
    
    audio = speech.RecognitionAudio(content=base64.b64decode(audio_base64))
    config = speech.RecognitionConfig(
        encoding=speech.RecognitionConfig.AudioEncoding.WEBM_OPUS,
        sample_rate_hertz=16000,
        language_code="en-US",
    )
    
    response = client.recognize(config=config, audio=audio)
    
    if response.results:
        return response.results[0].alternatives[0].transcript
    return ""
```

---

## Option 3: Switch Back to Gemini for Voice

If you want native audio support without STT integration:

```bash
# In backend/.env
USE_CLAUDE=false
INTERVIEWER_USE_CLAUDE=false  # Use Gemini for interviewer only
```

This gives you:
- ✅ Native audio support (Gemini Live)
- ✅ No STT integration needed
- ⚠️ Still uses Gemini instead of Claude

---

## Recommendation

**For Now:**
1. **Use Text Mode** - Works perfectly with Claude ✅
2. Voice mode is recording but needs STT integration

**For Production:**
1. Integrate Whisper STT (easiest, runs locally)
2. Or use Google Speech-to-Text (better quality, cloud-based)
3. Or keep Gemini for voice interviews, Claude for text

---

## Testing After STT Integration

Once you add STT:

1. Start interview in Voice mode
2. Hold mic button and speak
3. Backend logs: `[TRANSCRIBED]: your spoken text`
4. Claude receives text and responds
5. Response streams back to you
6. ✅ Full interactive voice interview!

---

## Summary

| Mode | Claude | Gemini |
|------|--------|--------|
| **Text** | ✅ Works | ✅ Works |
| **Voice** | ⚠️ Needs STT | ✅ Native Support |

**Your voice is being captured perfectly!** You just need to add the STT layer so Claude can understand it as text.

