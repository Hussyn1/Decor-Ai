import os
from huggingface_hub import InferenceClient
from dotenv import load_dotenv

load_dotenv()
HF_TOKEN = os.getenv("HF_TOKEN")

client = InferenceClient(token=HF_TOKEN)

def test_hf_img2img():
    # create a small dummy image
    with open("dummy.jpg", "wb") as f:
        f.write(b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xdb\x00C\x01\t\t\t\x0c\x0b\x0c\x18\r\r\x182!\x1c!22222222222222222222222222222222222222222222222222\xff\xc0\x00\x11\x08\x00\x08\x00\x08\x03\x01"\x00\x02\x11\x01\x03\x11\x01\xff\xc4\x00\x15\x00\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xc4\x00\x15\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xff\xc4\x00\x14\x11\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x0c\x03\x01\x00\x02\x11\x03\x11\x00?\x00\xfd\xfc\x8f\xff\xd9')
    
    try:
        image = client.image_to_image(
            image="dummy.jpg",
            prompt="Make this a modern living room",
            model="timbrooks/instruct-pix2pix"
        )
        print("Success with timbrooks/instruct-pix2pix:", image)
        return
    except Exception as e:
        print("Failed instruct-pix2pix:", e)
        
    try:
        image = client.image_to_image(
            image="dummy.jpg",
            prompt="Make this a modern living room",
            model="runwayml/stable-diffusion-v1-5"
        )
        print("Success with runwayml/stable-diffusion-v1-5:", image)
        return
    except Exception as e:
        print("Failed sd-v1.5:", e)

if __name__ == "__main__":
    test_hf_img2img()
