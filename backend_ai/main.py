from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import List, Optional
import numpy as np
from gradio_client import Client, handle_file
import os
import uuid
from dotenv import load_dotenv

# Load environment variables
load_dotenv()
HF_TOKEN = os.getenv("HF_TOKEN")

app = FastAPI(title="Spatial AI Recommendation Service")

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

class ThreeDRequest(BaseModel):
    image_url: str

class ThreeDResponse(BaseModel):
    glb_url: str
    message: str

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
    insights = []
    
    # ... (Proportional Analysis, Style Compatibility, Color Harmony logic remains same)
    # 1. Proportional Analysis
    total_footprint = 0
    for item in context.placed_furniture:
        total_footprint += item.dimensions[0] * item.dimensions[2]
    
    utilization_ratio = total_footprint / context.room_area if context.room_area > 0 else 0
    
    if utilization_ratio > 0.6:
        insights.append(AIResponse(type="Warning", title="Space Crowded", message=f"Your room is {int(utilization_ratio*100)}% full.", impact_score=0.9))
    elif utilization_ratio < 0.2 and len(context.placed_furniture) > 0:
        insights.append(AIResponse(type="Suggestion", title="Room feels Empty", message="There is significant open space.", impact_score=0.4))

    # 2. Style Compatibility
    if context.placed_furniture:
        styles = [item.style for item in context.placed_furniture]
        dominant_style = max(set(styles), key=styles.count)
        compatible = STYLE_RULES.get(dominant_style, [])
        if compatible:
            insights.append(AIResponse(type="Suggestion", title="Style Match Found", message=f"Since you like {dominant_style}, check out {compatible[0]} style.", impact_score=0.7))

    # 3. Color Harmony
    if context.placed_furniture:
        colors = [item.base_color for item in context.placed_furniture]
        dominant_color = max(set(colors), key=colors.count)
        harmony = COLOR_HARMONY.get(dominant_color, [])
        if harmony:
             insights.append(AIResponse(type="Harmony", title="Color Balance", message=f"Try adding accents in {harmony[0]}.", impact_score=0.6))

    return insights

@app.post("/generate-3d", response_model=ThreeDResponse)
async def generate_3d(request: ThreeDRequest):
    print(f"\n[AI-LOG] Received 3D generation request for URL: {request.image_url}")
    try:
        print("[AI-LOG] Connecting to HF Space: microsoft/TRELLIS.2...")
        client = Client("microsoft/TRELLIS.2", token=HF_TOKEN)
        
        # 1. Preprocess
        print("[AI-LOG] Step 1/3: Preprocessing image...")
        try:
            client.predict(
                input=handle_file(request.image_url),
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
                image=handle_file(request.image_url),
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
        if isinstance(result, (list, tuple)) and len(result) > 0:
            glb_path = result[0]
        else:
            glb_path = result
            
        print(f"[AI-LOG] SUCCESS! Final GLB path: {glb_path}")
        
        return ThreeDResponse(
            glb_url=glb_path, 
            message="3D Model generated successfully"
        )
    except Exception as e:
        import traceback
        error_detail = traceback.format_exc()
        print(f"\n[AI-LOG] CRITICAL EXCEPTION:\n{error_detail}")
        raise HTTPException(status_code=500, detail=f"AI Pipeline Error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
