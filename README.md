
# Decor AR - AI-Powered Interior Design Application

Decor AR is a cutting-edge Flutter application that leverages Augmented Reality (AR) and Artificial Intelligence (AI) to revolutionize interior design. It allows users to visualize furniture in their real-world space, generate 3D models from 2D images, and receive intelligent design recommendations based on their room's spatial context.

![Decor AR Banner](https://via.placeholder.com/1200x400?text=Decor+AR+Application)

## 🌟 Key Features

*   **Augmented Reality Visualization:** Place generic and custom 3D furniture models into your room using ARCore.
*   **AI Design & Recommendations:**
    *   **Space Analysis:** Analyzes room dimensions and existing layout.
    *   **Smart Suggestions:** Provides "Warning", "Harmony", and "Style Conflict" insights.
    *   **Magic Arrange:** Suggests optimal placement for furniture.
*   **2D to 3D Conversion:** transform 2D images of furniture into interactive 3D models using generative AI integration.
*   **Project Management:** Save and load design projects with cloud synchronization.
*   **Interactive Tools:** Move, rotate, scale, and lock furniture items in real-time.
*   **LiDAR Support:** Utilizes LiDAR sensors (on supported devices) for precise depth mapping and occlusion.

## 🏗️ System Architecture

The application follows a clean, layered architecture separation of concerns, utilizing **GetX** for reactive state management and dependency injection.

### Architecture Diagram

```mermaid
graph TD
    subgraph Presentation_Layer [Presentation Layer (UI)]
        UI[Screens & Widgets]
        AR_Screen[AR View Screen]
        Builder[2D to 3D Builder]
    end

    subgraph State_Layer [State Management Layer (GetX)]
        ARC[ArViewController]
        PC[ProjectController]
        AuthC[AuthController]
        GenC[ThreeDGeneratorController]
    end

    subgraph Service_Layer [Service Layer]
        PS[ProjectService]
        AS[AuthService]
        AIS[AiRecommendationService]
        ARB[ArCoreBridge]
    end

    subgraph Infrastructure_Layer [Infrastructure & External]
        Backend[Node.js Backend / MongoDB]
        AI_Engine[Python AI Engine]
        AR_Plugin[AR Flutter Plugin / ARCore]
        Storage[SharedPreferences / Local]
    end

    %% Connections
    UI --> ARC
    UI --> PC
    UI --> AuthC
    AR_Screen --> ARC
    Builder --> GenC

    ARC --> ARB
    ARC --> PS
    ARC --> AIS
    PC --> PS
    AuthC --> AS

    PS <--> Backend
    AIS <--> AI_Engine
    ARB <--> AR_Plugin
    AS <--> Backend
    AS <--> Storage
```

### Component Breakdown

1.  **Presentation Layer:**
    *   Built with Flutter Widgets.
    *   `ArViewScreen`: The core AR interface.
    *   `TwoDToThreeDBuilder`: Interface for image upload and 3D preview.

2.  **State Management Layer (GetX):**
    *   `ArViewController`: Manages AR nodes, anchors, and scene state (Undo/Redo).
    *   `ProjectController`: Handles project CRUD operations and synchronization.
    *   `ThreeDGeneratorController`: Manages the state of the generative AI process.

3.  **Service Layer:**
    *   `ProjectService`: Handles HTTP requests to the Node.js backend for project persistence.
    *   `AiRecommendationService`: Communicates with the Python AI server to analyze spatial context.
    *   `ArNodeManager` & `ArCoreBridge`: Abstractions over the raw AR plugin to handle low-level AR operations.

4.  **Infrastructure:**
    *   **Node.js Backend:** Handles user authentication and project data storage.
    *   **Python AI Service:** Processes room data to generate design insights.
    *   **ARCore:** Google's platform for building augmented reality experiences.

## 🛠️ Tech Stack

*   **Frontend Framework:** Flutter (Dart)
*   **State Management:** GetX
*   **AR Engine:** `ar_flutter_plugin` (based on Google ARCore)
*   **3D Rendering:** `model_viewer_plus`, Standard GLB/gLTF formats
*   **Backend Services:**
    *   Node.js (Express) - Application Logic
    *   Python (Flask/FastAPI) - AI Inference
    *   MongoDB - Database
*   **Networking:** `http`, `dio` (implied)

## 🚀 Installation & Setup

### Prerequisites
*   Flutter SDK (3.9.2 or higher)
*   Android Studio / VS Code
*   Physical Android Device (Emulator support for AR is limited)
*   ARCore installed on the device

### Steps

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/yourusername/decor_ar_fyp.git
    cd decor_ar_fyp
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Configure API Endpoints**
    *   Open `lib/services/project_service.dart` and `lib/services/ai_recommendation_service.dart`.
    *   Update `baseUrl` to point to your local or hosted backend servers.
    *   *Note: For local testing on Android, use your machine's IP address (e.g., `192.168.x.x`) instead of `localhost`.*

4.  **Run the App**
    Connect your Android device and run:
    ```bash
    flutter run
    ```

## 📱 Usage Guide

1.  **Login/Register:** Create an account to save your projects.
2.  **Start AR Session:** Tap "Create New Project" or "Discover".
3.  **Scan Operations:** Move your phone slowly to detect floor planes (dotted surface).
4.  **Place Furniture:** Select an item from the carousel and tap on a detected plane.
5.  **Edit:** Tap an object to select it. Use gestures to rotate or pinch-to-scale.
6.  **AI Insights:** Open the "AI Stylist" panel to get real-time recommendations.
7.  **Save:** Tap the save icon to persist your room design.

## 🤝 Contributing

 Contributions are welcome! Please fork the repository and submit a pull request for review.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
