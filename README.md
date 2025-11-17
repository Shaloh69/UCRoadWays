# 🚦 Flutter Road Mapping App

A Flutter-based road mapping application inspired by **OpenLayers**.  
This project uses:

- [flutter_map](https://pub.dev/packages/flutter_map) → Interactive map (like Leaflet/OpenLayers)  
- [turf_dart](https://pub.dev/packages/turf_dart) → Geometry & spatial analysis (distance, area, etc.)  
- [geojson](https://pub.dev/packages/geojson) → Export and import road networks as GeoJSON  

The app allows you to **draw roads (polylines), process them, and save/export coordinates as JSON** — even works offline with MBTiles.

---

## ✨ Features
- 🗺️ Display maps with OpenStreetMap tiles  
- 📍 Add markers and draw roads (polylines/polygons)  
- 📏 Measure distances using Turf.js functions (via `turf_dart`)  
- 💾 Export drawn features to **GeoJSON**  
- 📂 Save/load road systems from local storage  
- 📡 Support for offline maps using `.mbtiles` or cached tiles  

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0 or higher)  
- Android Studio or VS Code  
- For Android Emulator: enable **Intel HAXM/AEHD** or **WHPX** for performance  

### Installation
```bash
# Clone the repository
git clone https://github.com/your-username/flutter-road-mapping.git
cd flutter-road-mapping

# Get dependencies
flutter pub get

# Run on emulator or device
flutter run
```

### ⚠️ Build Issues on Windows?

If you encounter build errors (especially after moving the project or Flutter SDK), see:
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Quick fixes for common errors
- **[FLUTTER_SETUP_WINDOWS.md](FLUTTER_SETUP_WINDOWS.md)** - Detailed Windows setup guide
- **[PROJECT_RESET_GUIDE.md](PROJECT_RESET_GUIDE.md)** - Complete project reset (when all else fails)

**Quick fixes:**
```cmd
fix_flutter_path.bat      # Fix Flutter SDK path issues
fix_gradle_locks.bat      # Fix Gradle file lock errors
reset_flutter_project.bat # Complete project reset (nuclear option)
