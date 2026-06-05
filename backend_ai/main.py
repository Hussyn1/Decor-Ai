from fastapi import FastAPI, HTTPException, BackgroundTasks, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional
import numpy as np
import os
import uuid
import shutil
import json
import requests
import cloudinary
import cloudinary.uploader
from dotenv import load_dotenv
import subprocess
import time
import asyncio
from concurrent.futures import ThreadPoolExecutor
import base64
from io import BytesIO
from PIL import Image
from google import genai
from google.genai import types as genai_types
import firebase_admin
from firebase_admin import credentials, messaging

_executor = ThreadPoolExecutor(max_workers=3)

# Load environment variables
load_dotenv()
HF_TOKEN = os.getenv("HF_TOKEN")
TRIPO_API_KEY = os.getenv("TRIPO_API_KEY")

# Configure Cloudinary
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

# Initialize Firebase Admin SDK for push notifications
try:
    firebase_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    firebase_b64 = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON_BASE64")
    
    if firebase_json:
        print("[AI-LOG] Loading Firebase credentials from FIREBASE_SERVICE_ACCOUNT_JSON env var")
        cred_dict = json.loads(firebase_json)
        _cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(_cred)
        print("[AI-LOG] ✅ Firebase Admin SDK initialized from JSON env")
    elif firebase_b64:
        print("[AI-LOG] Loading Firebase credentials from FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 env var")
        import base64
        decoded = base64.b64decode(firebase_b64).decode('utf-8')
        cred_dict = json.loads(decoded)
        _cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(_cred)
        print("[AI-LOG] ✅ Firebase Admin SDK initialized from Base64 env")
    else:
        _sa_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "serviceAccountKey.json")
        if os.path.exists(_sa_path):
            _cred = credentials.Certificate(_sa_path)
            firebase_admin.initialize_app(_cred)
            print(f"[AI-LOG] ✅ Firebase Admin SDK initialized from file: {_sa_path}")
        else:
            print(f"[AI-LOG] ⚠️ serviceAccountKey.json not found at {_sa_path} and no environment variables set.")
except Exception as _fe:
    print(f"[AI-LOG] ⚠️ Firebase init failed (FCM disabled): {_fe}")

app = FastAPI(title="Spatial AI Recommendation Service")

# Create static directory if it doesn't exist
os.makedirs("static/generated", exist_ok=True)
os.makedirs("static/uploads", exist_ok=True)

# Mount static files to serve generated models
app.mount("/static", StaticFiles(directory="static"), name="static")

# --- BACKGROUND TASKS TRACKING ---
# Dictionary to store task status: {task_id: {"status": str, "progress": int, "message": str, "result": str}}
TASKS = {}

# --- DATA MODELS ---

class FurnitureMetadata(BaseModel):
    id: str
    name: str
    style: str  # e.g., "Minimalist", "Industrial", "Bohemian"
    base_color: str
    dimensions: List[float]  # [width, height, depth] in meters

class SpatialContext(BaseModel):
    room_area: float  # sqm
    placed_furniture: List[FurnitureMetadata]
    available_catalog: List[FurnitureMetadata]

class AIResponse(BaseModel):
    type: str  # "Warning", "Suggestion", "Harmony"
    title: str
    message: str
    impact_score: float  # 0 to 1
    suggested_action: Optional[str] = None  # e.g., "FILTER_STYLE"
    suggested_value: Optional[str] = None   # e.g., "Industrial"

class ThreeDResponse(BaseModel):
    glb_url: str
    message: str

class ColorPaletteItem(BaseModel):
    name: str
    hex: str
    role: str
    why: str

class FurnitureRecommendation(BaseModel):
    item: str
    style: str
    color_suggestion: str
    why: str

class StylingRecommendation(BaseModel):
    color_palette: List[ColorPaletteItem]
    furniture_recommendations: List[FurnitureRecommendation]
    overall_design_summary: str
    visualization_prompt: Optional[str] = None

class StylingRequest(BaseModel):
    prompt: str
    room_type: Optional[str] = "Living Room"

class RoomScanRequest(BaseModel):
    image_base64: str
    placed_furniture: List[FurnitureMetadata]
    room_area: Optional[float] = None

class WallColorDetection(BaseModel):
    color_name: str
    hex: str
    location: str

class RoomScanResult(BaseModel):
    room_type: str
    wall_colors: List[WallColorDetection]
    lighting_condition: str
    existing_style: str
    harmony_score: int
    furniture_recommendations: List[FurnitureRecommendation]
    color_recommendations: List[ColorPaletteItem]
    layout_tips: List[str]
    conflicts: List[str]
    overall_summary: str

# --- CORE LOGIC ---

STYLE_RULES = {
    "Minimalist": ["Scandi", "Modern", "Japanese"],
    "Industrial": ["Minimalist", "Vintage", "Loft"],
    "Bohemian": ["Vintage", "Eclectic", "Ethno"],
    "Modern": ["Minimalist", "Industrial", "Bauhaus"]
}

COLOR_HARMONY = {
    "White": ["Grey", "Wood", "Teal"],
    "Black": ["Leather", "Gold", "White"],
    "Brown": ["Cream", "Deep Green", "Rust"],
    "Grey": ["Yellow", "Navy", "White"]
}

@app.get("/")
async def root():
    return {"status": "AI Service Online", "version": "1.0.0"}

@app.post("/analyze", response_model=List[AIResponse])
async def analyze_room(context: SpatialContext):
    print(f"\n[AI-LOG] Analyzing room with {len(context.placed_furniture)} items...")
    placed_items_str = ", ".join([f"{item.name} ({item.style}, {item.base_color})" for item in context.placed_furniture])
    
    prompt = f"""
    You are an expert interior designer. Analyze the following room setup:
    Room Area: {context.room_area} sqm
    Placed Furniture: {placed_items_str if placed_items_str else 'Empty Room'}
    
    Provide exactly 3 actionable design insights as a JSON list. 
    Respond ONLY with the JSON list.
    """

    API_URL = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3"
    headers = {"Authorization": f"Bearer {HF_TOKEN}"}

    try:
        response = requests.post(API_URL, headers=headers, json={
            "inputs": f"<s>[INST] {prompt} [/INST]",
            "parameters": {"max_new_tokens": 500, "return_full_text": False}
        }, timeout=30)
        
        result_text = response.json()[0].get('generated_text', '')
        clean_json = result_text[result_text.find("["):result_text.rfind("]")+1]
        insights_data = json.loads(clean_json)
        
        return [AIResponse(**item) for item in insights_data]
        
    except Exception as e:
        print(f"[AI-LOG] LLM Analysis failed: {str(e)}")
        return [AIResponse(type="Suggestion", title="Room Layout", message="Ensure enough walking space.", impact_score=0.5)]

class TripoService:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.tripo3d.ai/v2/openapi"
        self.headers = {"Authorization": f"Bearer {api_key}"}

    def upload_file(self, file_path: str):
        url = f"{self.base_url}/upload"
        with open(file_path, "rb") as f:
            files = {"file": (os.path.basename(file_path), f)}
            response = requests.post(url, headers=self.headers, files=files, timeout=60)
        data = response.json()
        if data.get("code") != 0: raise Exception(f"Tripo upload error: {data.get('message')}")
        return data["data"]["image_token"]

    def create_task(self, image_token: str):
        url = f"{self.base_url}/task"
        payload = {
            "type": "image_to_model",
            "model_version": "v2.0-20240919",  # v2 is significantly faster than v3.1
            "file": {"type": "jpg", "file_token": image_token},
            "pbr": False,         # Biggest speedup — skips full material baking pass (~40% faster)
            "texture": True,
            "face_limit": 10000,  # Lower poly = faster mesh generation, still good quality
            "texture_size": 512   # 512 vs 1024 = 4x less texture work on Tripo's side
        }
        response = requests.post(url, headers=self.headers, json=payload, timeout=30)
        data = response.json()
        if data.get("code") != 0: raise Exception(f"Tripo task error: {data.get('message')}")
        return data["data"]["task_id"]

    def get_task_status(self, task_id: str):
        url = f"{self.base_url}/task/{task_id}"
        response = requests.get(url, headers=self.headers, timeout=15)
        data = response.json()
        if data.get("code") != 0: raise Exception(f"Tripo status error: {data.get('message')}")
        return data["data"]

def optimize_glb(input_path: str, output_path: str) -> str:
    """Pass-through function. We disabled gltf-pipeline because it corrupts GLB headers for Android Sceneform."""
    print(f"[AI-LOG] Using Tripo-native optimized mesh: {input_path}")
    import shutil
    try:
        # Just copy the file to the output path without altering the GLB binary
        shutil.copy2(input_path, output_path)
        return output_path
    except Exception as e:
        print(f"[AI-LOG] Pass-through failed: {e}")
        return input_path

@app.get("/task-status/{task_id}")
async def get_task_status(task_id: str):
    if task_id not in TASKS:
        raise HTTPException(status_code=404, detail="Task not found")
    return TASKS[task_id]

def process_3d_generation(task_id: str, upload_path: str, fcm_token: str = None):
    print(f"\n[AI-LOG] [START] Task {task_id}")
    TASKS[task_id] = {"status": "processing", "progress": 5, "message": "Starting generation..."}
    try:
        tripo = TripoService(TRIPO_API_KEY)
        TASKS[task_id].update({"progress": 10, "message": "Uploading image..."})
        image_token = tripo.upload_file(upload_path)
        
        TASKS[task_id].update({"progress": 20, "message": "Creating 3D mesh..."})
        tripo_task_id = tripo.create_task(image_token)
        
        glb_url = None
        # Adaptive backoff: fast checks early (when Tripo is queuing/starting),
        # slower later (when it's actively generating textures — no point hammering)
        for i in range(180):
            task_data = tripo.get_task_status(tripo_task_id)
            status = task_data.get("status")
            progress = task_data.get("progress", 0)
            overall_progress = 20 + int(progress * 0.6)
            TASKS[task_id].update({"progress": overall_progress, "message": f"Generating... ({progress}%)"})
            
            if status == "success":
                output = task_data.get("output", {})
                glb_url = output.get("model") or output.get("pbr_model") or output.get("glb")
                break
            elif status == "failed":
                raise Exception(f"Tripo generation failed: {task_data.get('message', '')}")
            
            # Adaptive sleep: check every 1s for first 10 iterations,
            # every 2s for next 30, every 4s after that
            if i < 10:
                time.sleep(1)
            elif i < 40:
                time.sleep(2)
            else:
                time.sleep(4)
        else:
            raise Exception("TripoSR timed out after ~6 minutes")

        if not glb_url:
            raise Exception("Generation succeeded but no GLB URL found in output")
            
        TASKS[task_id].update({"progress": 85, "message": "Downloading model..."})
        final_path = f"static/generated/{task_id}_model.glb"
        # Stream download — avoids buffering the full 20-40MB GLB into RAM before writing
        with requests.get(glb_url, timeout=120, stream=True) as glb_response:
            glb_response.raise_for_status()
            with open(final_path, "wb") as f:
                for chunk in glb_response.iter_content(chunk_size=8192):
                    f.write(chunk)

        TASKS[task_id].update({"progress": 95, "message": "Optimizing model..."})
        optimized_path = f"static/generated/{task_id}_model_opt.glb"
        final_served_path = optimize_glb(final_path, optimized_path)
        
        # --- NEW: Upload to Cloudinary ---
        TASKS[task_id].update({"progress": 98, "message": "Uploading to Cloud..."})
        try:
            print(f"[AI-LOG] Uploading {final_served_path} to Cloudinary...")
            upload_result = cloudinary.uploader.upload(
                final_served_path, 
                resource_type="raw",
                public_id=f"furniture_3d/{task_id}.glb"
            )
            final_url = upload_result['secure_url']
            print(f"[AI-LOG] 🚀 CLOUDINARY UPLOAD SUCCESS!")
            print(f"[AI-LOG] URL: {final_url}")
            print(f"[AI-LOG] Check your Cloudinary Dashboard under 'Media Library' -> 'Folders' -> 'furniture_3d'")
            print(f"[AI-LOG] Note: .glb files are 'Raw' files and won't appear in the main Images tab.")
        except Exception as cloud_err:
            print(f"[AI-LOG] Cloudinary failed, falling back to local URL: {cloud_err}")
            final_url = f"/static/generated/{os.path.basename(final_served_path)}"

        TASKS[task_id].update({
            "status": "success", "progress": 100, 
            "message": "Complete!", "result": final_url
        })
        
        # Fire push notification if FCM token was provided
        if fcm_token:
            send_push_notification(fcm_token, task_id, final_url)
            
    except Exception as e:
        print(f"[AI-LOG] [ERROR] Task {task_id} failed: {str(e)}")
        TASKS[task_id] = {"status": "failed", "progress": 100, "message": str(e)}

def send_push_notification(fcm_token: str, task_id: str, glb_url: str):
    """Fire a push notification to the device when the 3D model is ready."""
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="3D Model Ready! 🛋️",
                body="Your furniture model is ready to place in AR. Tap to open!",
            ),
            data={
                "task_id": task_id,
                "glb_url": glb_url,
                "action": "OPEN_AR",
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="ar_model_ready",
                    icon="ic_notification",
                    color="#4A90E2",
                )
            ),
            token=fcm_token,
        )
        response = messaging.send(message)
        print(f"[AI-LOG] ✅ FCM notification sent: {response}")
    except Exception as e:
        print(f"[AI-LOG] ⚠️ FCM send failed (non-fatal): {str(e)}")


@app.post("/generate-3d")
async def generate_3d(
    background_tasks: BackgroundTasks,
    image: UploadFile = File(...),
    fcm_token: Optional[str] = Form(None),  # optional — gracefully skips notification if absent
):
    print(f"\n[AI-LOG] Received request to generate 3D model: {image.filename} | FCM: {'yes' if fcm_token else 'no'}")
    task_id = str(uuid.uuid4())
    upload_path = f"static/uploads/{task_id}_{image.filename}"
    with open(upload_path, "wb") as buffer: 
        shutil.copyfileobj(image.file, buffer)
    
    TASKS[task_id] = {"status": "queued", "progress": 0, "message": "Queued..."}
    
    # Run in executor so event loop stays free for /task-status polling
    loop = asyncio.get_event_loop()
    loop.run_in_executor(_executor, process_3d_generation, task_id, upload_path, fcm_token)
    
    print(f"[AI-LOG] Task created: {task_id}")
    return {"task_id": task_id}

@app.post("/recommend-style", response_model=StylingRecommendation)
async def recommend_style(request: StylingRequest):
    prompt = f"Interior designer concept for {request.room_type}: {request.prompt}. Return JSON."
    API_URL = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3"
    headers = {"Authorization": f"Bearer {HF_TOKEN}"}
    try:
        response = requests.post(API_URL, headers=headers, json={"inputs": f"<s>[INST] {prompt} [/INST]"}, timeout=30)
        result_text = response.json()[0].get('generated_text', '')
        clean_json = result_text[result_text.find("{"):result_text.rfind("}")+1]
        return StylingRecommendation(**json.loads(clean_json))
    except Exception as e:
        return StylingRecommendation(color_palette=[], furniture_recommendations=[], overall_design_summary="Error")

@app.post("/scan-room", response_model=RoomScanResult)
async def scan_room(request: RoomScanRequest):
    print(f"\n[AI-LOG] Scanning room with {len(request.placed_furniture)} items...")
    
    gemini_key = os.getenv("GEMINI_API_KEY")
    if not gemini_key or gemini_key == "YOUR_GEMINI_API_KEY_HERE":
        print("[AI-LOG] Gemini API Key not set or default placeholder. Using robust rich simulated recommendation response for testing.")
        
        # Build smart rich mock responses based on placed furniture styles and colors
        placed_styles = [f.style for f in request.placed_furniture]
        primary_style = placed_styles[0] if placed_styles else "Modern"
        
        placed_colors = [f.base_color for f in request.placed_furniture]
        color_theme = placed_colors[0] if placed_colors else "Off-White"
        
        harmony_score = 80 if request.placed_furniture else 50
        if len(request.placed_furniture) > 1:
            uniq_styles = set(placed_styles)
            if len(uniq_styles) > 1:
                harmony_score = 65
        
        # Dynamic advice based on user placement
        layout_tips = [
            "Maintain at least 70cm of clearance around placed items to ensure smooth walking pathways.",
            "Since your room has natural lighting, avoid blocking window areas with tall placed items.",
            "Consider placing your key accent pieces against the main wall to anchor the layout."
        ]
        
        conflicts = []
        if len(set(placed_styles)) > 1:
            conflicts.append(f"Style mismatch detected: Placed items blend multiple styles ({', '.join(set(placed_styles))}). Consider standardizing on {primary_style} for maximum visual harmony.")
        
        return RoomScanResult(
            room_type="Living Room",
            wall_colors=[
                WallColorDetection(color_name="Warm Off-White", hex="#F5F2EB", location="main wall"),
                WallColorDetection(color_name="Soft Grey Accent", hex="#E0E0E0", location="accent wall")
            ],
            lighting_condition="Bright natural lighting with warm neutral ambient tone",
            existing_style=primary_style,
            harmony_score=harmony_score,
            furniture_recommendations=[
                FurnitureRecommendation(
                    item="Sofa",
                    style=primary_style,
                    color_suggestion="Beige" if primary_style != "Industrial" else "Charcoal Grey",
                    why="Complements the primary style and serves as a solid foundation for the seating layout."
                ),
                FurnitureRecommendation(
                    item="Coffee Table",
                    style="Minimalist",
                    color_suggestion="#D2B48C",
                    why="A simple wooden coffee table introduces a natural element without cluttering the visual field."
                ),
                FurnitureRecommendation(
                    item="Lounge Chair",
                    style="Modern",
                    color_suggestion="Olive Green",
                    why="Adds a sophisticated pop of color that pairs beautifully with neutral backdrops."
                )
            ],
            color_recommendations=[
                ColorPaletteItem(
                    name="Sage Green",
                    hex="#8F9779",
                    role="Accent Wall",
                    why="Provides a calm, organic touch that complements wood textures and neutral colors."
                ),
                ColorPaletteItem(
                    name="Terracotta",
                    hex="#C26D51",
                    role="Decor Highlights",
                    why="Brings warmth and rustic richness when used in textiles, pillows, or art."
                )
            ],
            layout_tips=layout_tips,
            conflicts=conflicts,
            overall_summary=f"A spacious and well-lit area with an initial {primary_style} styling direction. By coordinating wood finishes and aligning the furniture's layout to emphasize natural light entryways, you will create a beautifully harmonious, inviting, and highly functional living environment."
        )

    try:
        if "base64," in request.image_base64:
            header, encoded = request.image_base64.split(",", 1)
        else:
            encoded = request.image_base64
        
        image_data = base64.b64decode(encoded)
        
        client = genai.Client(api_key=gemini_key)
        
        placed_str = json.dumps([f.dict() for f in request.placed_furniture], indent=2)
        prompt = f"""
        You are an elite interior designer. Analyze the uploaded image of a real-life room taken from our augmented reality (AR) app.
        The user has also placed several 3D AR furniture models in this physical space.
        
        Here is the metadata of the placed 3D AR furniture:
        {placed_str}
        
        Analyze both the physical room (visible in the photo) and the virtual furniture placed in it. You must return EXACTLY a JSON response containing:
        1. 'room_type': E.g., 'Living Room', 'Bedroom', 'Office', 'Dining Room', etc.
        2. 'wall_colors': A list of detected wall/ceiling/floor background colors including:
           - 'color_name': descriptive name (e.g., 'Warm Beige', 'Navy Blue')
           - 'hex': best-guess hex code (e.g., '#F5F5DC')
           - 'location': where it is (e.g., 'main wall', 'accent wall', 'ceiling', 'floor')
        3. 'lighting_condition': A brief summary of natural/artificial light and tone.
        4. 'existing_style': The apparent style of the physical space (e.g., 'Contemporary', 'Traditional', 'Bohemian', 'Industrial').
        5. 'harmony_score': An integer from 0 to 100 assessing style/color compatibility between the placed AR models and the real physical room.
        6. 'furniture_recommendations': A list of 2-3 additional items from a catalog that would fit perfectly:
           - 'item': furniture type (e.g., 'Sofa', 'Side Table', 'Rug', 'Floor Lamp')
           - 'style': style recommendation (e.g., 'Modern Scandi', 'Rustic')
           - 'color_suggestion': suggested color description
           - 'why': design reasoning
        7. 'color_recommendations': A list of 2 suggested paint colors or accent colors:
           - 'name': color name
           - 'hex': hex code
           - 'role': e.g., 'Accent Wall', 'Trim Paint', 'Textile Accent'
           - 'why': design justification
        8. 'layout_tips': List of 3-4 spatial layout or arrangement guidelines based on the spatial constraints seen in the photo.
        9. 'conflicts': List of any aesthetic/spatial clashes (e.g., style clashing, size scaling issues, blocked doorways).
        10. 'overall_summary': A 2-3 sentence overview of the design potential.
        
        Your entire output MUST be a valid JSON object matching the schema below. Do not wrap in markdown or anything else:
        {{
          "room_type": "string",
          "wall_colors": [
            {{
              "color_name": "string",
              "hex": "string",
              "location": "string"
            }}
          ],
          "lighting_condition": "string",
          "existing_style": "string",
          "harmony_score": 85,
          "furniture_recommendations": [
            {{
              "item": "string",
              "style": "string",
              "color_suggestion": "string",
              "why": "string"
            }}
          ],
          "color_recommendations": [
            {{
              "name": "string",
              "hex": "string",
              "role": "string",
              "why": "string"
            }}
          ],
          "layout_tips": [
            "string"
          ],
          "conflicts": [
            "string"
          ],
          "overall_summary": "string"
        }}
        """
        
        print("[AI-LOG] Sending image and context metadata to Gemini API...")
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=[
                prompt,
                genai_types.Part.from_bytes(data=image_data, mime_type='image/jpeg')
            ],
            config=genai_types.GenerateContentConfig(
                response_mime_type="application/json"
            )
        )
        
        print("[AI-LOG] Gemini API response received.")
        text_response = response.text.strip()
        if text_response.startswith("```"):
            if text_response.startswith("```json"):
                text_response = text_response[7:]
            else:
                text_response = text_response[3:]
            if text_response.endswith("```"):
                text_response = text_response[:-3]
        
        parsed_data = json.loads(text_response.strip())
        return RoomScanResult(**parsed_data)
        
    except Exception as e:
        print(f"[AI-LOG] [ERROR] Gemini API failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Gemini room scan failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

