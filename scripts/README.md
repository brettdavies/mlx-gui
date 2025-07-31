# MLX-GUI Scripts

This folder contains build and deployment scripts for the MLX-GUI application.

## 📁 Scripts Overview

### 🔨 Build Scripts

#### `build_app.sh`
**Purpose:** Creates a standalone macOS app bundle using PyInstaller  
**Usage:** `./scripts/build_app.sh`  
**Output:** `dist/MLX-GUI.app` (1.2GB standalone app)  
**Features:**
- ✅ Handles complex MLX ecosystem dependencies
- ✅ Resolves SSL conflicts with OpenCV
- ✅ Includes audio (Whisper, Parakeet) and vision (MLX-VLM) support
- ✅ Creates menu bar app (no dock icon)
- ✅ Applies 200+ lines of runtime fixes
- ✅ Uses 12+ custom PyInstaller hooks

#### `sign_app.sh`
**Purpose:** Signs and notarizes the app bundle for distribution  
**Usage:** `./scripts/sign_app.sh`  
**Requirements:** Apple Developer account with Team ID  
**Features:**
- ✅ Creates zip archive for notarization
- ✅ Submits to Apple for notarization
- ✅ Staples notarization result to app
- ✅ Verifies notarization status

#### `upload_pip.sh`
**Purpose:** Uploads package to PyPI (pip = destination, uses uv for building)  
**Usage:** `./scripts/upload_pip.sh`  
**Requirements:** ~/.pypirc configured with PyPI credentials  
**Features:**
- ✅ Installs build tools with uv
- ✅ Builds package with uv build
- ✅ Verifies package integrity
- ✅ Uploads to PyPI with confirmation

### 🔐 Security Files

#### `entitlements.plist`
**Purpose:** Defines macOS app security entitlements  
**Usage:** Referenced by build script for code signing  
**Entitlements:**
- `com.apple.security.cs.allow-jit` - Allows JIT compilation (MLX/PyTorch)
- `com.apple.security.cs.allow-unsigned-executable-memory` - Allows dynamic code execution
- `com.apple.security.cs.disable-library-validation` - Allows unsigned libraries

**⚠️ Security Note:** These entitlements are necessary for ML functionality but reduce security.

## 🚀 Workflow

### Standard Build Process
```bash
# 1. Build the app
./scripts/build_app.sh

# 2. Sign and notarize (optional)
./scripts/sign_app.sh

# 3. Upload to PyPI (optional)
./scripts/upload_pip.sh
```

### Build System
All scripts use uv for fast dependency resolution and package building.

## 📋 Requirements

### Build Requirements
- Python 3.11+
- PyInstaller
- All MLX ecosystem dependencies
- macOS (for app bundle creation)

### Signing Requirements
- Apple Developer account ($99/year)
- Team ID from Apple Developer portal
- App-specific password for notarization

## 🔧 Customization

### Build Configuration
- Edit `build_app.sh` to modify PyInstaller options
- Custom hooks are in the `hooks/` directory
- Runtime fixes are in the `rthooks/` directory

### Signing Configuration
- Edit `sign_app.sh` to change Apple ID or paths
- Modify `entitlements.plist` to adjust security permissions
