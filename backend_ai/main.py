from fastapi import FastAPI, HTTPException, BackgroundTasks, UploadFile, File
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
            "model_version": "v3.1-20260211",
            "file": {"type": "jpg", "file_token": image_token},
            "pbr": True, 
            "texture": True,
            "face_limit": 20000,      # Strict geometry limit to prevent 40MB+ files
            "texture_size": 1024      # Half the standard resolution to save 75% VRAM
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

def process_3d_generation(task_id: str, upload_path: str):
    print(f"\n[AI-LOG] [START] Task {task_id}")
    TASKS[task_id] = {"status": "processing", "progress": 5, "message": "Starting generation..."}
    try:
        tripo = TripoService(TRIPO_API_KEY)
        TASKS[task_id].update({"progress": 10, "message": "Uploading image..."})
        image_token = tripo.upload_file(upload_path)
        
        TASKS[task_id].update({"progress": 20, "message": "Creating 3D mesh..."})
        tripo_task_id = tripo.create_task(image_token)
        
        glb_url = None
        max_retries = 150
        for i in range(max_retries):
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
            time.sleep(2)
        else:
            raise Exception("TripoSR timed out after 5 minutes")

        if not glb_url:
            raise Exception("Generation succeeded but no GLB URL found in output")
            
        TASKS[task_id].update({"progress": 85, "message": "Downloading model..."})
        glb_response = requests.get(glb_url, timeout=60)
        final_filename = f"{task_id}_model.glb"
        final_path = f"static/generated/{final_filename}"
        with open(final_path, "wb") as f: f.write(glb_response.content)

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
    except Exception as e:
        print(f"[AI-LOG] [ERROR] Task {task_id} failed: {str(e)}")
        TASKS[task_id] = {"status": "failed", "progress": 100, "message": str(e)}

@app.post("/generate-3d")
async def generate_3d(background_tasks: BackgroundTasks, image: UploadFile = File(...)):
    print(f"\n[AI-LOG] Received request to generate 3D model: {image.filename}")
    task_id = str(uuid.uuid4())
    upload_path = f"static/uploads/{task_id}_{image.filename}"
    with open(upload_path, "wb") as buffer: 
        shutil.copyfileobj(image.file, buffer)
    
    TASKS[task_id] = {"status": "queued", "progress": 0, "message": "Queued..."}
    
    # Run in executor so event loop stays free for /task-status polling
    loop = asyncio.get_event_loop()
    loop.run_in_executor(_executor, process_3d_generation, task_id, upload_path)
    
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
