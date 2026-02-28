# AirGuard AI Frontend


AirGuard AI: Proactive Health Intelligence & Viral Forecasting


AirGuard AI is an innovative, AI-powered health intelligence platform designed to address real-world environmental challenges. By integrating real-time Air Quality Index (AQI) monitoring with predictive viral forecasting, the application empowers users—particularly those in high-density urban areas—to understand the link between environmental conditions and respiratory health risks.


🔗 Public Access

You can access the live functional prototype here: https://airguardai.web.app/


🛠️ Installation & Setup

To run the AirGuard AI Flutter application locally, follow these steps:


**Prerequisites**

* **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install) (Stable channel).
* **Dart SDK**: Included with the Flutter bundle.
* **IDE**: VS Code or Android Studio with Flutter plugins.


**Local Setup**

1. **Clone the Repository**:
```bash
git clone https://github.com/qiphy/airguardai_frontend
cd airguardai_frontend

```


2. **Install Dependencies**:
```bash
flutter pub get

```


3. **Run the Application**:
* **For Web**:
```bash
flutter run -d chrome

```


* **For Mobile**:
```bash
flutter run

```

⚙️ Backend Documentation

For detailed information on API endpoints, Google AI integration, and server setup, please refer to the Backend Repository (https://github.com/qiphy/airguardai_backend).


🚀 Overview

AirGuard AI moves beyond static data by using Google’s technology stack to provide hyper-local risk assessments. The system identifies correlations between air quality (PM2.5) and potential viral outbreaks (such as Influenza or Tuberculosis), providing actionable insights and early warnings to help citizens safeguard their health.


✨ Key Features

Real-Time Monitoring: Instant updates on AQI, temperature, and humidity based on the user's GPS location.

Gemini Viral Forecast: An AI-driven engine that synthesizes environmental data to provide predictive insights into viral trends and health risks.

Hyper-Local Risk Assessment: Tailored health information specific to the user's current surroundings.

AI Transparency: Explains the "why" behind health risks, such as correlating a surge in respiratory distress cases with elevated AQI levels.

Actionable Advice: Personalized recommendations, such as suggesting indoor activities or mask-wearing during high-risk periods.


🛠️ Technical Architecture

The project utilizes a scalable, cross-platform architecture designed for high performance and zero-budget resource efficiency.

Frontend: Built with Flutter (Dart) for a high-performance, single-codebase UI compatible with both Android and iOS.

Backend & Hosting: Powered by Firebase Cloud to handle scalable infrastructure and the project's "Freemium" model.

AI Engine: Gemini AI is used for processing complex data and generating predictive insights that traditional algorithms cannot handle.

Design & Prototyping: Utilized Google AI Studio for UI/UX design and Nano Banana Pro for generative AI assets.


📊 How It Works: The Risk Calculation

The system employs a two-step "Bio-Spark" engine to estimate risks:

Step 1 — Genetic Similarity: Analyzes viral protein sequences using machine learning to identify genetic patterns.

Step 2 — Environmental Susceptibility: Assesses real-time AQI and PM2.5 data. It applies a sub-linear biological response model to estimate how current conditions might impact respiratory vulnerability.

Final Indicator: Combines these factors into a surveillance probability for airborne viral risks.


🌍 Strategic Alignment (SDGs)

SDG 3 (Good Health & Well-being): Strengthening early warning systems for national health risks.

SDG 10 (Reduced Inequalities): Providing free, hyper-local AI health insights to ensure health protection access for all income groups, including the B40.

SDG 11 (Sustainable Cities & Communities): Reducing environmental impacts through smart city air quality monitoring.


🔮 2026 Roadmap

Current: Launching AirGuard AI with real-time monitoring in urban Malaysia.

Hardware Integration: Launching AirGuard HomeKit, a physical detector for indoor air quality, humidity, and temperature.

Predictive Mapping: Developing hotspot mapping for the Ministry of Health (KKM) to enhance resource allocation.

Expansion: Scaling services to major Southeast Asian cities by year-end.


👥 The Team: Duo Core

Group Members: Oh Kuan Qi & Ng Jin Heng
