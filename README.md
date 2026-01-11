# Quality Control System Report (QCSR)

QCSR (formerly SortMaster) is a Flutter application designed for quality control and inventory management in a manufacturing environment. It allows users to log sorting activities, track non-good (NG) parts, and view real-time production analytics.

## 🚀 Features

*   **Barcode/QR Scanning:** Quick entry for part numbers using the device camera.
*   **Quality Logging:** Capture total sorted quantities, NG counts, and specific defect types.
*   **Photo Evidence:** Attach photos of rejected parts directly to logs.
*   **PDF Reporting:** Generate and export professional PDF reports for individual logs or dashboard summaries.
*   **Real-time Analytics:** A comprehensive management dashboard with charts showing hourly production trends, NG rates, and operator performance.
*   **Firebase Integration:** Fully connected to Firestore and Firebase Storage for secure, cloud-based data management.
*   **Seeding Tool:** Built-in sample data generator in the Dashboard for quick testing.

## 🎨 Design System

*   **Theme:** Material 3 with Deep Purple branding.
*   **Modes:** Full support for Light and Dark modes.
*   **Typography:** 
    *   Headlines: *Oswald*
    *   Titles/Buttons: *Roboto*
    *   Body: *Open Sans*

## 🛠️ Getting Started

### Prerequisites

*   Flutter SDK (stable version)
*   Firebase Project (connected via `google-services.json` and `firebase_options.dart`)

### Installation

1. Clone the repository.
2. Run `flutter pub get` to install dependencies.
3. Build the release APK:
   ```bash
   flutter build apk --release
   ```

## 📂 Project Structure

*   `lib/features/scan`: Scanning and logging logic.
*   `lib/features/dashboard`: Real-time charts and data visualization.
*   `lib/services`: Firebase and PDF generation services.
*   `lib/models`: Data structures.
