from fastapi import FastAPI, HTTPException, BackgroundTasks, UploadFile, File
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional
import numpy as np
from gradio_client import Client, handle_file
import os
import uuid
import shutil
import json
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()
HF_TOKEN = os.getenv("HF_TOKEN")

app = FastAPI(title="Spatial AI Recommendation Service")

# Create static directory if it doesn't exist
os.makedirs("static/generated", exist_ok=True)
os.makedirs("static/uploads", exist_ok=True)

# Mount static files to serve generated models
app.mount("/static", StaticFiles(directory="static"), name="static")

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
    
    # Constructing the prompt for the LLM
    placed_items_str = ", ".join([f"{item.name} ({item.style}, {item.base_color})" for item in context.placed_furniture])
    
    prompt = f"""
    You are an expert interior designer. Analyze the following room setup:
    Room Area: {context.room_area} sqm
    Placed Furniture: {placed_items_str if placed_items_str else 'Empty Room'}
    
    Provide exactly 3 actionable design insights as a JSON list. 
    Each insight MUST have:
    - 'type': 'Warning', 'Suggestion', or 'Harmony'
    - 'title': Short descriptive title
    - 'message': 1-2 sentences of advice
    - 'impact_score': 0.0 to 1.0
    - 'suggested_action': (Optional) "FILTER_STYLE" to search the catalog
    - 'suggested_value': (Optional) The style name (e.g., 'Modern', 'Industrial', 'Vintage')
    
    Respond ONLY with the JSON list. Respond as a JSON list of objects, not a string. Do not include markdown formatting or "```json".
    """

    # Using HuggingFace Inference API with a capable model
    API_URL = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3"
    headers = {"Authorization": f"Bearer {HF_TOKEN}"}

    try:
        response = requests.post(API_URL, headers=headers, json={
            "inputs": f"<s>[INST] {prompt} [/INST]",
            "parameters": {"max_new_tokens": 500, "return_full_text": False}
        })
        
        # Checking for common API issues
        if response.status_code != 200:
            print(f"[AI-LOG] HF API Error: {response.text}")
            raise Exception(f"HF API returned status {response.status_code}")

        result = response.json()
        if isinstance(result, list) and len(result) > 0:
            result_text = result[0].get('generated_text', '')
        else:
            result_text = str(result)

        print(f"[AI-LOG] LLM Output: {result_text}")
        
        # Extract JSON if LLM returned it wrapped in text/markdown
        clean_json = result_text
        if "[" in clean_json and "]" in clean_json:
            clean_json = clean_json[clean_json.find("["):clean_json.rfind("]")+1]
        
        insights_data = json.loads(clean_json)
        
        # Map to pydantic model (handling small mismatches)
        processed_insights = []
        for item in insights_data:
            processed_insights.append(AIResponse(
                type=item.get('type', 'Suggestion'),
                title=item.get('title', 'AI Insight'),
                message=item.get('message', ''),
                impact_score=float(item.get('impact_score', 0.5)),
                suggested_action=item.get('suggested_action'),
                suggested_value=item.get('suggested_value')
            ))
            
        return processed_insights
        
    except Exception as e:
        print(f"[AI-LOG] LLM Analysis failed: {str(e)}")
        # Fallback to simple rule-based if LLM fails
        return [
            AIResponse(
                type="Suggestion", 
                title="Room Layout", 
                message="Ensure there is enough walking space of at least 1 meter between large items.", 
                impact_score=0.5
            )
        ]

@app.post("/generate-3d", response_model=ThreeDResponse)
async def generate_3d(image: UploadFile = File(...)):
    # Generate unique ID for this request
    request_id = str(uuid.uuid4())
    upload_path = f"static/uploads/{request_id}_{image.filename}"
    
    print(f"\n[AI-LOG] Received 3D generation request. Saving to {upload_path}...")
    
    try:
        # Save the uploaded file
        with open(upload_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
            
        print("[AI-LOG] File saved. Connecting to HF Space: microsoft/TRELLIS.2...")
        client = Client("microsoft/TRELLIS.2", token=HF_TOKEN)
        
        # 1. Preprocess
        print("[AI-LOG] Step 1/3: Preprocessing image...")
        try:
            # handle_file(upload_path) handles local file paths correctly for Gradio
            client.predict(
                input=handle_file(upload_path),
                api_name="/preprocess_image"
            )
            print("[AI-LOG] Step 1 finished successfully.")
        except Exception as e1:
            print(f"[AI-LOG] Step 1 Failed: {str(e1)}")
            raise e1

        # 2. Generate 3D Assets
        print("[AI-LOG] Step 2/3: Generating 3D assets (image_to_3d)...")
        try:
            client.predict(
                image=handle_file(upload_path),
                seed=0,
                resolution="1024",
                ss_guidance_strength=7.5,
                ss_guidance_rescale=0.7,
                ss_sampling_steps=12,
                ss_rescale_t=5.0,
                shape_slat_guidance_strength=7.5,
                shape_slat_guidance_rescale=0.5,
                shape_slat_sampling_steps=12,
                shape_slat_rescale_t=3.0,
                tex_slat_guidance_strength=1.0,
                tex_slat_guidance_rescale=0.0,
                tex_slat_sampling_steps=12,
                tex_slat_rescale_t=3.0,
                api_name="/image_to_3d"
            )
            print("[AI-LOG] Step 2 finished successfully.")
        except Exception as e2:
            print(f"[AI-LOG] Step 2 Failed: {str(e2)}")
            # Sometimes step 2 fails if step 1 didn't truly finish or if the queue was full
            raise e2

        # 3. Extract GLB
        print("[AI-LOG] Step 3/3: Extracting GLB model...")
        try:
            result = client.predict(
                decimation_target=300000,
                texture_size=2048,
                api_name="/extract_glb"
            )
            print("[AI-LOG] Step 3 finished successfully.")
        except Exception as e3:
            print(f"[AI-LOG] Step 3 Failed: {str(e3)}")
            raise e3
        
        # result is typically a tuple/list where the first element is the temp path to GLB
        # Gradio client downloads the result to a temporary directory on THIS server
        if isinstance(result, (list, tuple)) and len(result) > 0:
            temp_glb_path = result[0]
        else:
            temp_glb_path = result
            
        print(f"[AI-LOG] Generated GLB at temp path: {temp_glb_path}")
        
        # Move the generated file to our static directory so it can be served
        final_filename = f"{request_id}_model.glb"
        final_path = f"static/generated/{final_filename}"
        
        shutil.copy(temp_glb_path, final_path)
        print(f"[AI-LOG] Copied to public path: {final_path}")
        
        # Return the URL relative to our server
        # The frontend handles prepending the base URL if needed, or we can do it here
        # Returning /static/generated/filename.glb
        return ThreeDResponse(
            glb_url=f"/static/generated/{final_filename}", 
            message="3D Model generated successfully"
        )
        
    except Exception as e:
        import traceback
        error_detail = traceback.format_exc()
        print(f"\n[AI-LOG] CRITICAL EXCEPTION:\n{error_detail}")
        raise HTTPException(status_code=500, detail=f"AI Pipeline Error: {str(e)}")
    finally:
        # Cleanup upload if needed, or keep for debugging
        pass

@app.post("/recommend-style", response_model=StylingRecommendation)
async def recommend_style(request: StylingRequest):
    print(f"\n[AI-LOG] Global styling request: {request.prompt}")
    
    prompt = f"""
    You are a world-class interior designer. Generate a design concept for a {request.room_type} based on: "{request.prompt}"
    
    Respond ONLY with a valid JSON object:
    {{
      "color_palette": [
        {{ "name": "Deep Ocean", "hex": "#003366", "role": "Primary", "why": "Sets a calm tone" }},
        {{ "name": "Sand", "hex": "#C2B280", "role": "Neutral", "why": "Balances the deep blue" }}
      ],
      "furniture_recommendations": [
        {{ "item": "Velvet Sofa", "style": "Mid-Century", "color_suggestion": "Navy Blue", "why": "Acts as a bold centerpiece." }}
      ],
      "overall_design_summary": "A sophisticated coastal retreat inspired by the deep sea.",
      "visualization_prompt": "A {request.room_type} with {request.prompt}, photorealistic, professional lighting, 8k"
    }}
    
    Return at least 4 colors and 3 furniture items. No markdown. No code blocks. No backticks.
    """

    API_URL = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3"
    headers = {"Authorization": f"Bearer {HF_TOKEN}"}

    try:
        response = requests.post(API_URL, headers=headers, json={
            "inputs": f"<s>[INST] {prompt} [/INST]",
            "parameters": {"max_new_tokens": 800, "return_full_text": False}
        })
        
        if response.status_code != 200:
            raise Exception(f"HF API error: {response.text}")

        result_text = response.json()[0].get('generated_text', '')
        print(f"[AI-LOG] LLM Output: {result_text}")
        
        # Clean JSON extraction
        clean_json = result_text
        if "{" in clean_json and "}" in clean_json:
            clean_json = clean_json[clean_json.find("{"):clean_json.rfind("}")+1]
        
        data = json.loads(clean_json)
        return StylingRecommendation(**data)
        
    except Exception as e:
        print(f"[AI-LOG] Styling failed: {str(e)}")
        # Robust Fallback
        return StylingRecommendation(
            color_palette=[
                ColorPaletteItem(name="Slate", hex="#708090", role="Primary", why="Modern base"),
                ColorPaletteItem(name="Gold", hex="#FFD700", role="Accent", why="Adds warmth")
            ],
            furniture_recommendations=[
                FurnitureRecommendation(item="Minimalist Table", style="Modern", color_suggestion="Black", why="Clean lines")
            ],
            overall_design_summary="A clean modern aesthetic with subtle metal accents."
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
