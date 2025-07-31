#!/bin/bash

# MLX-GUI macOS App Builder
# This script builds a TRUE standalone macOS app bundle using PyInstaller

set -e

echo "🚀 Building MLX-GUI macOS App Bundle (TRUE STANDALONE)..."

# Check if we're in the right directory
if [ ! -f "pyproject.toml" ]; then
    echo "❌ Error: pyproject.toml not found. Run this script from the project root."
    exit 1
fi

# Use UV environment (no need to activate)
echo "📦 Using UV environment..."
# UV manages the environment automatically

# Ensure PyInstaller is available (should be installed via uv sync --extra app)
echo "📦 Verifying PyInstaller with UV..."
if ! uv run pyinstaller --version > /dev/null 2>&1; then
    echo "❌ PyInstaller not found. Run: uv sync --extra app --extra audio --extra vision"
    exit 1
fi
echo "✅ PyInstaller available via UV"

# Check for critical dependencies
echo "🔍 Checking critical dependencies..."
CRITICAL_DEPS=("mlx-lm" "mlx" "rumps" "fastapi" "uvicorn" "transformers" "huggingface-hub" "mlx-whisper" "parakeet-mlx" "mlx-vlm" "timm" "torchvision")
MISSING_DEPS=""

for dep in "${CRITICAL_DEPS[@]}"; do
    if ! uv run python -c "import ${dep//-/_}" > /dev/null 2>&1; then
        MISSING_DEPS="$MISSING_DEPS $dep"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "❌ Missing critical dependencies:$MISSING_DEPS"
    echo "💡 Install with: uv sync --extra app --extra audio --extra vision"
    echo "💡 Or add missing packages: uv add $MISSING_DEPS"
    exit 1
fi

echo "✅ All critical dependencies found"

# Show key MLX library versions for troubleshooting
echo "📋 Key MLX library versions:"
uv run python -c "
import mlx_lm, mlx_vlm
print(f'mlx-lm: {mlx_lm.__version__ if hasattr(mlx_lm, \"__version__\") else \"unknown\"}')
print(f'mlx-vlm: {mlx_vlm.__version__ if hasattr(mlx_vlm, \"__version__\") else \"unknown\"}')
"

# Audio and vision dependencies should be managed by uv.lock
echo "📦 Audio and vision dependencies managed by UV lock file..."
echo "ℹ️  To update dependencies, use: uv sync --upgrade"

# Initialize ffmpeg binaries to ensure they're downloaded
echo "📦 Downloading FFmpeg binaries..."
uv run python -c "
import ffmpeg
try:
    ffmpeg.init()
    print('✅ FFmpeg binaries downloaded successfully')
except Exception as e:
    print(f'⚠️ FFmpeg init failed: {e}')
    print('FFmpeg will be downloaded at runtime')
"

# OpenCV should be managed by UV dependencies
echo "📦 OpenCV managed by UV dependencies..."
uv run python -c "
try:
    import cv2
    print('✅ OpenCV available')
except ImportError:
    print('⚠️ OpenCV not available - may cause vision model issues')
"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
pkill -f MLX-GUI || true
sleep 2
rm -rf build/ dist/ MLX-GUI.spec app_icon.icns 2>/dev/null || true

# Create app icon from PNG
echo "🎨 Creating app icon from ./icon.png..."
if [ -f "./icon.png" ]; then
    # Create iconset directory
    mkdir -p app_icon.iconset

    # Generate different icon sizes using sips (built into macOS)
    sips -z 16 16 ./icon.png --out app_icon.iconset/icon_16x16.png
    sips -z 32 32 ./icon.png --out app_icon.iconset/icon_16x16@2x.png
    sips -z 32 32 ./icon.png --out app_icon.iconset/icon_32x32.png
    sips -z 64 64 ./icon.png --out app_icon.iconset/icon_32x32@2x.png
    sips -z 128 128 ./icon.png --out app_icon.iconset/icon_128x128.png
    sips -z 256 256 ./icon.png --out app_icon.iconset/icon_128x128@2x.png
    sips -z 256 256 ./icon.png --out app_icon.iconset/icon_256x256.png
    sips -z 512 512 ./icon.png --out app_icon.iconset/icon_256x256@2x.png
    sips -z 512 512 ./icon.png --out app_icon.iconset/icon_512x512.png
    sips -z 1024 1024 ./icon.png --out app_icon.iconset/icon_512x512@2x.png

    # Convert to icns format
    iconutil -c icns app_icon.iconset -o app_icon.icns

    # Clean up temporary iconset
    rm -rf app_icon.iconset

    echo "✅ App icon created: app_icon.icns"
else
    echo "⚠️  Warning: ./icon.png not found, using default icon"
fi

# Build the app using PyInstaller directly
echo "🔨 Building app bundle with PyInstaller..."

# Set environment variables to prevent model downloads during build
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_DATASETS_OFFLINE=1
export PYTORCH_DISABLE_CUDA_MALLOC=1
export PYTORCH_ENABLE_MPS_FALLBACK=1

# Create PyInstaller hooks directory if it doesn't exist
mkdir -p hooks

# Create custom hook for parakeet-mlx
cat > hooks/hook-parakeet_mlx.py << 'EOF'
from PyInstaller.utils.hooks import collect_all, collect_submodules

datas, binaries, hiddenimports = collect_all('parakeet_mlx')

# Bundle all submodules so STT works out of the box
hiddenimports.extend(collect_submodules('parakeet_mlx'))
EOF

# Create custom hook for audiofile
cat > hooks/hook-audiofile.py << 'EOF'
from PyInstaller.utils.hooks import collect_all

datas, binaries, hiddenimports = collect_all('audiofile')

# Additional hidden imports for audiofile
hiddenimports += [
    'audiofile.core',
    'audmath',
    'audeer',
    'soundfile',
    'cffi',
    'pycparser',
]
EOF

# Create custom hook for audresample
cat > hooks/hook-audresample.py << 'EOF'
from PyInstaller.utils.hooks import collect_all

datas, binaries, hiddenimports = collect_all('audresample')

# Additional hidden imports for audresample
hiddenimports += [
    'soxr',
    'numba',
    'llvmlite',
]
EOF

# Get FFmpeg binaries from current Python environment with flexible path detection
PYTHON_SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
VENV_BIN_DIR=".venv/bin"

# Try multiple possible ffmpeg locations
FFMPEG_PATHS=(
    "$PYTHON_SITE_PACKAGES/ffmpeg/binaries/ffmpeg"
    "$VENV_BIN_DIR/ffmpeg"
    "/opt/homebrew/bin/ffmpeg"
    "/usr/local/bin/ffmpeg"
)

FFPROBE_PATHS=(
    "$PYTHON_SITE_PACKAGES/ffmpeg/binaries/ffprobe"
    "$VENV_BIN_DIR/ffprobe"
    "/opt/homebrew/bin/ffprobe"
    "/usr/local/bin/ffprobe"
)

FFMPEG_BINARY=""
FFPROBE_BINARY=""

# Find ffmpeg binary
for path in "${FFMPEG_PATHS[@]}"; do
    if [ -f "$path" ]; then
        FFMPEG_BINARY="$path"
        echo "✅ Found FFmpeg binary at: $FFMPEG_BINARY"
        break
    fi
done

# Find ffprobe binary
for path in "${FFPROBE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        FFPROBE_BINARY="$path"
        echo "✅ Found FFprobe binary at: $FFPROBE_BINARY"
        break
    fi
done

if [ -n "$FFMPEG_BINARY" ] && [ -n "$FFPROBE_BINARY" ]; then
    # Copy to project directory for PyInstaller to pick up
    mkdir -p ./ffmpeg_binaries
    cp "$FFMPEG_BINARY" ./ffmpeg_binaries/ffmpeg
    cp "$FFPROBE_BINARY" ./ffmpeg_binaries/ffprobe
    chmod +x ./ffmpeg_binaries/*

    echo "📦 Copied FFmpeg binaries to ./ffmpeg_binaries/"
else
    echo "❌ FFmpeg binaries not found in any expected location"
    echo "   Tried paths:"
    for path in "${FFMPEG_PATHS[@]}"; do
        echo "   - $path"
    done
    echo "⚠️ Audio transcription will not work"
fi

# Create minimal hook for ffmpeg package data only (no binaries)
cat > hooks/hook-ffmpeg.py << 'EOF'
from PyInstaller.utils.hooks import collect_all
import os

# Collect only the Python module data (not binaries)
datas, _, hiddenimports = collect_all('ffmpeg')

# Remove binary files from datas to avoid conflicts
datas = [(src, dst) for src, dst in datas if not src.endswith(('ffmpeg', 'ffprobe'))]

# Empty binaries list since we handle them separately
binaries = []

print(f"✅ FFmpeg hook: Collected {len(datas)} data files (binaries handled separately)")
EOF

# Create custom hook for av (PyAV)
cat > hooks/hook-av.py << 'EOF'
from PyInstaller.utils.hooks import collect_all, collect_dynamic_libs

datas, binaries, hiddenimports = collect_all('av')

# Collect all av dynamic libraries (libav* dylibs)
av_dylibs = collect_dynamic_libs('av')
binaries.extend(av_dylibs)

# Additional hidden imports for av
hiddenimports += [
    'av',
    'av.audio',
    'av.codec',
    'av.container',
    'av.format',
    'av.stream',
    'av.video',
    'av.filter',
    'av.packet',
    'av.frame',
    'av.plane',
    'av.subtitles',
    'av.logging',
    'av.utils',
]
EOF

# Create custom hook for mlx-whisper
cat > hooks/hook-mlx_whisper.py << 'EOF'
from PyInstaller.utils.hooks import collect_all

datas, binaries, hiddenimports = collect_all('mlx_whisper')

# Additional hidden imports for mlx-whisper
hiddenimports += [
    'mlx_whisper.transcribe',
    'mlx_whisper.load_models',
    'mlx_whisper.audio',
]
EOF

# Create custom hook for MLX-LM to include all model architectures
cat > hooks/hook-mlx_lm.py << 'EOF'
from PyInstaller.utils.hooks import collect_all, collect_submodules

# Collect all MLX-LM data files and submodules
datas, binaries, hiddenimports = collect_all('mlx_lm')

# Ensure ALL model submodules are included (this is critical!)
hiddenimports.extend(collect_submodules('mlx_lm'))

# Explicitly include model files that PyInstaller might miss
hiddenimports.extend([
    'mlx_lm.models.qwen3',
    'mlx_lm.models.qwen2',
    'mlx_lm.models.qwen',
    'mlx_lm.models.gemma3_text',
    'mlx_lm.models.gemma',
    'mlx_lm.models.llama',
    'mlx_lm.models.mistral',
    'mlx_lm.models.cache',
    'mlx_lm.models.switch_layers',
    'mlx_lm.models.rope_utils',
])

print("✅ MLX-LM hook: All model architectures and submodules collected")
EOF

# Create custom hook for transformers to ensure all processor modules are included
cat > hooks/hook-transformers.py << 'EOF'
from PyInstaller.utils.hooks import collect_all, collect_submodules

# The "Sledgehammer" approach: collect EVERYTHING from transformers.
# This is the most robust way to ensure all dynamic modules, models,
# and processors are included, preventing "Could not import module" errors.

datas, binaries, hiddenimports = collect_all('transformers')

# Recursively collect all submodules. This is the key to solving the problem.
hiddenimports.extend(collect_submodules('transformers'))

print("✅ Aggressive transformers hook: All submodules collected.")
EOF

# Replace cv2 hook with expert-level SSL conflict resolution
cat > hooks/hook-cv2.py << 'EOF'
"""
Expert OpenCV hook that aggressively removes ALL OpenSSL/crypto libraries
to prevent conflicts with Python's built-in _ssl module.
Based on official PyInstaller hooks documentation.
"""

from PyInstaller.utils.hooks import collect_all, collect_dynamic_libs
from PyInstaller.compat import is_darwin, is_win
import os

# Collect everything from cv2 first
datas, binaries, hiddenimports = collect_all('cv2')

# Comprehensive list of SSL/crypto library patterns that MUST be excluded
SSL_CONFLICT_PATTERNS = [
    # Generic SSL patterns
    'ssl', 'crypto', 'openssl',
    # Version-specific patterns
    'libssl.1.1', 'libcrypto.1.1',
    'libssl.3', 'libcrypto.3',
    'libssl.1.0', 'libcrypto.1.0',
    # Platform-specific patterns
    'ssleay32', 'libeay32',  # Windows
    'libssl.dylib', 'libcrypto.dylib',  # macOS generic
    'libssl.so', 'libcrypto.so',  # Linux
]

def is_ssl_library(file_path: str) -> bool:
    """
    Determine if a file is an SSL/crypto library that could conflict.
    Uses comprehensive pattern matching.
    """
    if not file_path:
        return False

    basename = os.path.basename(file_path).lower()

    # Check against all known SSL patterns
    for pattern in SSL_CONFLICT_PATTERNS:
        if pattern in basename:
            return True

    return False

def filter_ssl_conflicts(file_list):
    """
    Filter out SSL libraries from a list of (src, dest) tuples.
    """
    filtered = []
    excluded_count = 0

    for src, dest in file_list:
        if is_ssl_library(src):
            print(f"   🚫 Excluding SSL conflict: {os.path.basename(src)}")
            excluded_count += 1
        else:
            filtered.append((src, dest))

    if excluded_count > 0:
        print(f"   ✅ Excluded {excluded_count} SSL libraries from OpenCV")

    return filtered

# Apply aggressive SSL filtering to binaries
print("🔍 OpenCV Hook: Filtering SSL conflicts from binaries...")
original_binary_count = len(binaries)
binaries = filter_ssl_conflicts(binaries)

# Apply same filtering to datas (OpenCV sometimes puts dylibs here)
print("🔍 OpenCV Hook: Filtering SSL conflicts from datas...")
original_data_count = len(datas)
datas = filter_ssl_conflicts(datas)

# Platform-specific additional cleanup
if is_darwin:
    # On macOS, be extra aggressive about crypto libs
    def is_macos_crypto(path):
        basename = os.path.basename(path).lower()
        return any(x in basename for x in ['.dylib']) and any(x in basename for x in ['crypto', 'ssl'])

    binaries = [(src, dest) for src, dest in binaries if not is_macos_crypto(src)]
    datas = [(src, dest) for src, dest in datas if not is_macos_crypto(src)]

elif is_win:
    # On Windows, exclude SSL DLLs
    def is_windows_ssl(path):
        basename = os.path.basename(path).lower()
        return basename.endswith('.dll') and any(x in basename for x in ['ssl', 'crypto'])

    binaries = [(src, dest) for src, dest in binaries if not is_windows_ssl(src)]

# Essential hidden imports for OpenCV
hiddenimports += [
    'cv2',
    'cv2.cv2',
    'numpy',
    # Core OpenCV modules that might be dynamically imported
    'cv2.typing',
    'cv2.dnn',
    'cv2.imgproc',
    'cv2.imgcodecs',
    'cv2.videoio',
    'cv2.highgui'
]

# Final validation
final_binary_count = len(binaries)
final_data_count = len(datas)

print(f"✅ OpenCV SSL Conflict Resolution Complete:")
print(f"   📦 Binaries: {original_binary_count} → {final_binary_count}")
print(f"   📄 Datas: {original_data_count} → {final_data_count}")
print(f"   🛡️  All SSL/crypto libraries removed to prevent _ssl conflicts")
EOF

# Create custom hook for mlx-vlm
cat > hooks/hook-mlx_vlm.py << 'EOF'
from PyInstaller.utils.hooks import collect_all

datas, binaries, hiddenimports = collect_all('mlx_vlm')

# Additional hidden imports for mlx-vlm
hiddenimports += [
    'mlx_vlm.generate',
    'mlx_vlm.load',
    'mlx_vlm.utils',
    'mlx_vlm.prompt_utils',
    'mlx_vlm.models',
    'mlx_vlm.models.base',
    'mlx_vlm.models.gemma3n',
    'mlx_vlm.models.qwen2_vl',
    'mlx_vlm.models.llava',
    'mlx_vlm.models.idefics',
    'timm',
    'timm.models',
    'timm.models.vision_transformer',
    'timm.models.convnext',
    'timm.models.swin_transformer',
    'timm.layers',
    'timm.data',
    'torchvision',
    'torchvision.transforms',
    'torchvision.models',
]
EOF

# Create custom hook for mlx to ensure internal helper modules are bundled without duplicating the core lib
cat > hooks/hook-mlx.py << 'EOF'
from PyInstaller.utils.hooks import collect_all

datas, binaries, hiddenimports = collect_all('mlx')

# Explicitly include lazy-imported helpers
hiddenimports += [
    'mlx._reprlib_fix',
    'mlx._os_warning',
]
EOF

# Create custom hook for awkward_cpp
cat > hooks/hook-awkward_cpp.py << 'EOF'
from PyInstaller.utils.hooks import collect_all, collect_dynamic_libs

datas, binaries, hiddenimports = collect_all('awkward_cpp')

# Collect all awkward_cpp dynamic libraries (libawkward.dylib)
awkward_dylibs = collect_dynamic_libs('awkward_cpp')
binaries.extend(awkward_dylibs)

# Additional hidden imports for awkward_cpp
hiddenimports += [
    'awkward_cpp',
    'awkward_cpp.libawkward',
]
EOF

# Create a temporary directory for runtime hooks
HOOKS_DIR="rthooks"
mkdir -p "$HOOKS_DIR"

# Path for the consolidated runtime hook
ALL_FIXES_HOOK="$HOOKS_DIR/pyi_rth_all_fixes.py"

# Create the consolidated runtime hook file
echo "Creating consolidated runtime hook: $ALL_FIXES_HOOK"
cat > "$ALL_FIXES_HOOK" << EOL
# rthooks/pyi_rth_all_fixes.py
# This file is dynamically generated by build_app.sh

import sys
import os

print("--- Running MLX-GUI Runtime Fixes ---")

# -- Fix for ffmpeg/av --
try:
    if getattr(sys, 'frozen', False):
        bundle_dir = sys._MEIPASS

        # Fix for ffmpeg
        ffmpeg_path = os.path.join(bundle_dir, 'ffmpeg')
        if os.path.exists(ffmpeg_path):
            os.environ['PATH'] = f"{os.path.dirname(ffmpeg_path)}{os.pathsep}{os.environ.get('PATH', '')}"
            # print("✅ FFmpeg binary path configured.")
        else:
            # Fallback for older ffmpeg-binaries structure
            ffmpeg_dir = os.path.join(bundle_dir, 'ffmpeg-binaries', 'bin')
            if os.path.exists(ffmpeg_dir):
                os.environ['PATH'] = f"{ffmpeg_dir}{os.pathsep}{os.environ.get('PATH', '')}"
                # print("✅ FFmpeg binary (fallback) path configured.")
            else:
                import ffmpeg
                print("⚠️ FFmpeg binary path not found in bundle.")


        # Fix for av
        av_dir = os.path.join(bundle_dir, 'av')
        if os.path.exists(av_dir):
            os.environ['AV_ROOT'] = av_dir
            # print("✅ PyAV (av) libraries configured.")
        else:
            print("⚠️ PyAV (av) libraries not found in bundle.")

except Exception as e:
    print(f"⚠️ Error in ffmpeg/av fix: {e}")


# -- PyTorch/Triton conflict fix --
try:
    if getattr(sys, 'frozen', False):
        # Prevent PyTorch from registering conflicting TORCH_LIBRARY namespaces
        import os
        os.environ['TORCH_SHOW_CPP_STACKTRACES'] = '0'
        os.environ['PYTORCH_DISABLE_CUDNN_V8_API'] = '1'

        # Mock problematic PyTorch modules to prevent double registration
        import sys
        from types import ModuleType

        # Create mock modules for problematic torch components
        mock_triton = ModuleType('triton')
        mock_triton.__path__ = []
        mock_triton.__spec__ = type('MockSpec', (), {
            'name': 'triton',
            'origin': None,
            'submodule_search_locations': []
        })()
        mock_triton.__version__ = '2.0.0'
        sys.modules['triton'] = mock_triton

        # Prevent torchvision.ops from causing conflicts
        try:
            import torchvision
            if hasattr(torchvision, 'ops'):
                # Replace ops with a minimal version
                class MockOps:
                    pass
                torchvision.ops = MockOps()
        except ImportError:
            pass

        print("✅ PyTorch/Triton conflict prevention applied")

except Exception as e:
    print(f"⚠️ Error applying PyTorch/Triton fix: {e}")

# -- Comprehensive transformers metadata fix --
try:
    if getattr(sys, 'frozen', False):
        # Patch importlib.metadata before any imports that might need it
        import importlib.metadata
        import importlib.util
        from types import SimpleNamespace

        class FakeDistribution:
            def __init__(self, name, version, requires=None):
                self.metadata = {
                    'Name': name,
                    'Version': version,
                    'Requires-Dist': requires or []
                }
                self.version = version
                self.name = name
                # Required by Python 3.12 importlib.metadata
                self._normalized_name = name.replace('_', '-').lower()
                self._requires = requires or []

            def read_text(self, filename):
                if filename == 'METADATA':
                    lines = [f"Name: {self.name}", f"Version: {self.version}"]
                    if self._requires:
                        lines.extend([f"Requires-Dist: {req}" for req in self._requires])
                    return "\\n".join(lines) + "\\n"
                return ""

            @property
            def requires(self):
                return self._requires

            @property
            def entry_points(self):
                return []

            @property
            def files(self):
                return []

        # Comprehensive fake package registry with proper version constraints
        fake_packages = {
            'tqdm': ('4.67.1', ['colorama ; platform_system == "Windows"']),
            'transformers': ('4.53.1', [
                'filelock', 'huggingface-hub>=0.23.2,<1.0', 'numpy>=1.17',
                'packaging>=20.0', 'pyyaml>=5.1', 'regex!=2019.12.17',
                'requests', 'safetensors>=0.4.1', 'tokenizers<0.21,>=0.20'
            ]),
            'tokenizers': ('0.21.2', []),
            'huggingface-hub': ('0.33.2', [
                'filelock', 'fsspec>=2023.5.0', 'packaging>=20.9',
                'pyyaml>=5.1', 'requests', 'tqdm>=4.42.1', 'typing-extensions>=3.7.4.3'
            ]),
            'safetensors': ('0.5.3', []),
            'regex': ('2024.11.6', []),
            'requests': ('2.32.4', ['certifi>=2017.4.17', 'charset-normalizer<4,>=2', 'idna<4,>=2.5', 'urllib3<3,>=1.21.1']),
            'filelock': ('3.18.0', []),
            'pyyaml': ('6.0.2', []),
            'numpy': ('2.2.6', []),
            'packaging': ('25.0', []),
            'certifi': ('2024.12.14', []),
            'charset-normalizer': ('3.4.0', []),
            'idna': ('3.10', []),
            'urllib3': ('2.3.0', []),
            'typing-extensions': ('4.12.2', []),
            'fsspec': ('2024.12.0', []),
            'jinja2': ('3.1.2', ['MarkupSafe>=2.0']),
            'Jinja2': ('3.1.2', ['MarkupSafe>=2.0']),
            'MarkupSafe': ('2.1.3', [])
        }

        # Store originals
        original_distribution = importlib.metadata.distribution
        original_distributions = importlib.metadata.distributions

        def patched_distribution(name):
            try:
                return original_distribution(name)
            except importlib.metadata.PackageNotFoundError:
                if name in fake_packages:
                    version, requires = fake_packages[name]
                    print(f"🔧 Creating fake metadata for {name} v{version}")
                    return FakeDistribution(name, version, requires)
                # Try alternative name formats
                alt_name = name.replace('-', '_').replace('_', '-')
                if alt_name in fake_packages:
                    version, requires = fake_packages[alt_name]
                    print(f"🔧 Creating fake metadata for {name} (alt: {alt_name}) v{version}")
                    return FakeDistribution(name, version, requires)
                raise

        def patched_distributions():
            """Return all available distributions including fake ones"""
            try:
                real_dists = list(original_distributions())
            except:
                real_dists = []

            # Add fake distributions
            for name, (version, requires) in fake_packages.items():
                try:
                    # Only add if not already present
                    original_distribution(name)
                except importlib.metadata.PackageNotFoundError:
                    real_dists.append(FakeDistribution(name, version, requires))

            return real_dists

        # Apply patches
        importlib.metadata.distribution = patched_distribution
        importlib.metadata.distributions = patched_distributions

        print("✅ Comprehensive transformers metadata patching applied")

        # Test import
        import transformers
        print("✅ Transformers imported successfully with metadata patches")

except Exception as e:
    print(f"⚠️ Error applying transformers metadata fix: {e}")
    # Try basic import anyway
    try:
        import transformers
        print("✅ Transformers imported without metadata patches")
    except Exception as import_err:
        print(f"❌ Transformers import failed completely: {import_err}")

# -- Fix for cv2/OpenCV --
# This is more of a check to ensure transformers can find cv2
try:
    import cv2
    print("✅ Minimal cv2 available for feature detection.")
except ImportError:
    print("⚠️ cv2 (OpenCV) not found, which may affect some vision models.")
except Exception as e:
    print(f"⚠️ An unexpected error occurred during cv2 check: {e}")

# -- Robust patch for missing Gemma3N VLM bias parameter --
try:
    import mlx_vlm.utils as vlm_utils

    if not getattr(vlm_utils, '__bias_patch_applied', False):

        orig_sanitize = vlm_utils.sanitize_weights

        def _ensure_bias(weights):
            bias_key = 'vision_tower.timm_model.conv_stem.conv.bias'
            weight_key = 'vision_tower.timm_model.conv_stem.conv.weight'
            if bias_key not in weights and weight_key in weights:
                try:
                    import mlx.core as mx
                    w = weights[weight_key]
                    out_channels = w.shape[0] if hasattr(w, 'shape') else len(w)
                    dtype = getattr(w, 'dtype', mx.float32)
                    weights[bias_key] = mx.zeros((out_channels,), dtype=dtype)
                    print('✅ Injected zero VLM conv_stem bias')
                except Exception as e:
                    print(f'⚠️ Bias injection failed: {e}')

        def patched_sanitize(model_obj, weights, config=None):
            _ensure_bias(weights)  # pre-patch
            try:
                weights = orig_sanitize(model_obj, weights, config)
            except Exception as first_err:
                _ensure_bias(weights)
                try:
                    weights = orig_sanitize(model_obj, weights, config)
                except Exception:
                    raise first_err
            return weights

        vlm_utils.sanitize_weights = patched_sanitize
        vlm_utils.__bias_patch_applied = True
except Exception as e:
    print(f'⚠️ Unable to apply VLM bias patch: {e}')

print("--- Runtime Fixes Completed ---")

EOL

# Base PyInstaller command
PYINSTALLER_CMD=(
    "pyinstaller"
    "src/mlx_gui/app_main.py"
    "--name" "MLX-GUI"
    "--windowed"
    "--noconfirm"
    "--clean"
    "--onedir" # Use onedir for macOS .app bundles
    "--additional-hooks-dir" "hooks"
    "--runtime-hook" "$ALL_FIXES_HOOK"
    "--icon" "app_icon.icns"
    "--osx-bundle-identifier" "org.matthewrogers.mlx-gui"
    "--copy-metadata" "tqdm"
    "--copy-metadata" "regex"
    "--copy-metadata" "safetensors"
    "--copy-metadata" "filelock"
    "--copy-metadata" "numpy"
    "--copy-metadata" "requests"
    "--copy-metadata" "packaging"
    "--copy-metadata" "pyyaml"
    "--copy-metadata" "tokenizers"
    "--copy-metadata" "huggingface-hub"
    "--copy-metadata" "transformers"
    "--copy-metadata" "timm"
    "--copy-metadata" "torch"
    "--copy-metadata" "torchvision"
    "--copy-metadata" "sentencepiece"
    "--copy-metadata" "Pillow"
    "--copy-metadata" "av"
    "--copy-metadata" "parakeet-mlx"
    "--copy-metadata" "mlx-vlm"
    "--copy-metadata" "mlx-lm"
    "--copy-metadata" "Jinja2"
    "--copy-metadata" "jinja2"
    "--copy-metadata" "MarkupSafe"
    "--copy-metadata" "opencv-python-headless"
    "--copy-metadata" "scipy"
    "--copy-metadata" "scikit-learn"
    "--copy-metadata" "numba"
    "--copy-metadata" "librosa"
    "--copy-metadata" "soundfile"
    "--copy-metadata" "datasets"
    "--copy-metadata" "gradio"
    "--copy-metadata" "fastapi"
    "--copy-metadata" "uvicorn"
    "--copy-metadata" "mlx"
    "--copy-metadata" "mlx-embedding-models"
    "--copy-metadata" "mlx-embeddings"
    "--copy-metadata" "ffmpeg"
    "--copy-metadata" "ffmpeg-binaries"
    "--copy-metadata" "awkward_cpp"
    # Include HTML templates and media assets
    "--add-data" "src/mlx_gui/templates:mlx_gui/templates"
    "--add-data" "media:media"
    "--hidden-import" "scipy.sparse.csgraph._validation"
    "--hidden-import" "mlx._reprlib_fix"
    "--hidden-import" "Jinja2"
    "--hidden-import" "jinja2"
    "--hidden-import" "MarkupSafe"
    "--hidden-import" "mlx_lm"
    "--hidden-import" "mlx_lm.models"
    "--hidden-import" "mlx_lm.models.qwen3"
    "--hidden-import" "mlx_lm.models.gemma3_text"
    "--hidden-import" "mlx_embedding_models"
    "--hidden-import" "mlx_embeddings"
    "--hidden-import" "ffmpeg"
    "--hidden-import" "awkward_cpp"
    "--hidden-import" "awkward_cpp.libawkward"
    "--exclude-module" "tkinter"
    "--exclude-module" "PySide6"
    "--exclude-module" "PyQt6"
    "--exclude-module" "wx"
    # Aggressive SSL conflict prevention
    "--exclude-module" "OpenSSL"
    "--exclude-module" "pyOpenSSL"
    # Exclude problematic PyTorch/Triton modules that cause TORCH_LIBRARY conflicts
    "--exclude-module" "torch.utils.cpp_extension"
    "--exclude-module" "triton"
    "--exclude-module" "torchvision.io"
    "--exclude-module" "torchvision.ops"
    # Exclude problematic binaries by pattern
    "--exclude" "*libcrypto*.dylib"
    "--exclude" "*libssl*.dylib"
    "--exclude" "*triton*"
    "--exclude" "*libtorch*"
)

# Read version from Python module using UV
VERSION=$(uv run python -c "from src.mlx_gui import __version__; print(__version__)")
echo "📝 Building version: $VERSION"

# Create a custom .spec file for maximum control over SSL library exclusion
echo "🔨 Creating custom spec file for SSL conflict resolution..."
cat > MLX-GUI.spec << 'SPEC_EOF'
# -*- mode: python ; coding: utf-8 -*-

import os
from PyInstaller.utils.hooks import collect_all, collect_dynamic_libs

# Environment for model downloads prevention
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'
os.environ['HF_DATASETS_OFFLINE'] = '1'

def selective_ssl_filter(datas_or_binaries):
    """
    Smart SSL library filtering - only exclude OpenCV's conflicting SSL libraries
    while preserving Python's required SSL dependencies
    """

    filtered = []
    for item in datas_or_binaries:
        # Handle different tuple formats (binaries vs datas)
        if len(item) == 2:
            src, dest = item
        elif len(item) == 3:
            dest, src, typecode = item
        else:
            # Unknown format, keep as-is
            filtered.append(item)
            continue

        # Only exclude OpenCV's SSL libraries specifically
        should_exclude = False

        # Check if this is from OpenCV's bundled libraries that cause conflicts
        if 'cv2' in src and ('libssl' in src or 'libcrypto' in src):
            should_exclude = True
        # Also exclude mbedcrypto from OpenCV
        elif 'cv2' in src and 'mbedcrypto' in src:
            should_exclude = True
        # Exclude general OpenCV SSL/crypto dylibs that end up in the wrong place
        elif src.endswith('__dot__dylibs/libssl.3.dylib') or src.endswith('__dot__dylibs/libcrypto.3.dylib'):
            should_exclude = True

        if should_exclude:
            print(f"🚫 SPEC: Excluding OpenCV SSL library: {os.path.basename(src)}")
        else:
            filtered.append(item)

    return filtered

a = Analysis(
    ['src/mlx_gui/app_main.py'],
    pathex=[],
    binaries=[
        ('ffmpeg_binaries/ffmpeg', 'ffmpeg'),
        ('ffmpeg_binaries/ffprobe', 'ffprobe'),
    ],
    datas=[
        ('src/mlx_gui/templates', 'mlx_gui/templates'),
        ('media', 'media'),
    ],
    hiddenimports=[
        'scipy.sparse.csgraph._validation',
        'mlx._reprlib_fix',
        'Jinja2',
        'cv2',
        'cv2.cv2',
        'transformers',
        'transformers.utils',
        'transformers.models',
        'tqdm',
        'tqdm.auto'
    ],
    hookspath=['hooks'],
    hooksconfig={},
    runtime_hooks=['rthooks/pyi_rth_all_fixes.py'],
    excludes=[
        'tkinter', 'PySide6', 'PyQt6', 'wx',
        'OpenSSL', 'pyOpenSSL',
        'torch.utils.cpp_extension', 'triton',
        'torchvision.io', 'torchvision.ops'
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)

# Post-process to remove SSL conflicts and add system SSL libraries
print("🛡️  SPEC: Applying selective SSL filtering and adding system SSL libraries...")
original_binary_count = len(a.binaries)
original_data_count = len(a.datas)

a.binaries = selective_ssl_filter(a.binaries)
a.datas = selective_ssl_filter(a.datas)

# Add system SSL libraries that Python needs
import subprocess
try:
    # Find the system OpenSSL libraries that Python uses
    result = subprocess.run(['python', '-c', 'import ssl; print(ssl.OPENSSL_VERSION)'],
                          capture_output=True, text=True)
    print(f"Python SSL version: {result.stdout.strip()}")

    # Add the system libssl and libcrypto libraries
    # These are typically in /opt/homebrew/lib/ or /usr/local/lib/
    ssl_paths = [
        '/opt/homebrew/lib/libssl.3.dylib',
        '/opt/homebrew/lib/libcrypto.3.dylib',
        '/usr/local/lib/libssl.3.dylib',
        '/usr/local/lib/libcrypto.3.dylib'
    ]

    for ssl_path in ssl_paths:
        if os.path.exists(ssl_path):
            basename = os.path.basename(ssl_path)
            a.binaries.append((basename, ssl_path, 'BINARY'))
            print(f"✅ Added system SSL library: {basename}")

except Exception as e:
    print(f"⚠️  Could not add system SSL libraries: {e}")

# Note: Metadata collection for transformers causes build issues
# The app works without perfect metadata, so we'll skip this for now
print("📝 Skipping metadata collection to avoid build conflicts")

print(f"   📦 Binaries filtered: {original_binary_count} → {len(a.binaries)}")
print(f"   📄 Datas filtered: {original_data_count} → {len(a.datas)}")

pyz = PYZ(a.pure, a.zipped_data, cipher=None)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='MLX-GUI',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='MLX-GUI',
)

app = BUNDLE(
    coll,
    name='MLX-GUI.app',
    icon='app_icon.icns',
    bundle_identifier='org.matthewrogers.mlx-gui',
    info_plist={
        'LSUIElement': True,
        'CFBundleShortVersionString': '1.2.1',
        'CFBundleVersion': '1.2.1',
    },
)

SPEC_EOF

# Run PyInstaller with the custom spec file using UV
echo "🔨 Building app bundle with custom spec file..."
uv run pyinstaller MLX-GUI.spec --noconfirm --clean

# Clean up temporary hook files
echo "🧹 Cleaning up temporary hook files..."
rm -rf "$HOOKS_DIR"

# Check if build was successful
if [ -d "dist/MLX-GUI.app" ]; then
    echo "✅ App bundle built successfully!"
    echo "📍 Location: dist/MLX-GUI.app"

    # Fix the Info.plist to make it a menu bar app (no dock icon) - BEFORE signing
    echo "🔧 Converting to menu bar app (removing dock icon)..."
    INFO_PLIST="dist/MLX-GUI.app/Contents/Info.plist"

    if [ -f "$INFO_PLIST" ]; then
        # Add LSUIElement=true to make it a menu bar app
        /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$INFO_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$INFO_PLIST"

        # Add version information to Info.plist
        /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$INFO_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"

        /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$INFO_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$INFO_PLIST"

        echo "✅ App converted to menu bar app (no dock icon)"
        echo "   - App will only appear in the menu bar"
        echo "   - No dock icon will be shown"
        echo "   - Version set to: $VERSION"
    else
        echo "⚠️  Warning: Could not find Info.plist at $INFO_PLIST"
    fi

    # Code signing section
    echo ""
    echo "🔐 Code Signing..."

    # Check if we have a Developer ID Application certificate
    CERT_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')

    if [ -n "$CERT_NAME" ]; then
        echo "📝 Found certificate: $CERT_NAME"
        echo "🔏 Signing app bundle..."

        # Sign all executables and libraries first (deep signing)
        codesign --force --deep --sign "$CERT_NAME" --options runtime --entitlements scripts/entitlements.plist "dist/MLX-GUI.app"

        # Verify the signature
        if codesign --verify --verbose "dist/MLX-GUI.app" 2>/dev/null; then
            echo "✅ App successfully signed!"
            echo "🛡️  This will eliminate macOS security warnings"

            # Show signature info
            echo ""
            echo "📜 Signature Info:"
            codesign -dv --verbose=4 "dist/MLX-GUI.app" 2>&1 | grep -E "(Identifier|TeamIdentifier|Authority)"
        else
            echo "⚠️  Warning: Code signing verification failed"
            echo "   The app was built but may show security warnings"
        fi
    else
        echo "⚠️  No Developer ID Application certificate found"
        echo "   App will show security warnings when downloaded"
        echo "   To fix this:"
        echo "   1. Get an Apple Developer account ($99/year)"
        echo "   2. Create a Developer ID Application certificate"
        echo "   3. Install it in Keychain Access"
        echo "   4. Re-run this build script"
    fi

    echo ""
    echo "🎉 You can now:"
    echo "   1. Run: open dist/MLX-GUI.app"
    echo "   2. Copy to /Applications: cp -R dist/MLX-GUI.app /Applications/"
    echo "   3. Create a DMG installer"
    echo ""
    echo "📋 App Info:"
    echo "   - Size: $(du -sh dist/MLX-GUI.app | cut -f1)"
    echo "   - Type: TRUE STANDALONE (no Python required!)"
    echo "   - Includes: All Python runtime, MLX binaries, audio & vision support, and dependencies"
    if [ -n "$CERT_NAME" ]; then
        echo "   - Code Signed: ✅ (no security warnings)"
    else
        echo "   - Code Signed: ❌ (will show security warnings)"
    fi
    echo ""
    echo "🎯 This is a REAL standalone app!"
    echo "   - No Python installation required on target system"
    echo "   - No virtual environment needed"
    echo "   - Fully self-contained"
else
    echo "❌ Build failed! App bundle not found at dist/MLX-GUI.app"
    echo "   Check the output above for errors."
    exit 1
fi

echo ""
echo "🔗 Next steps:"
echo "   • Test the app: open dist/MLX-GUI.app"
echo "   • Create DMG installer for easy distribution"
echo "   • App is ready for sharing with anyone - no setup required!"
echo "   • Audio & Vision support included: Whisper, Parakeet, and MLX-VLM models work out of the box (filtered OpenCV - no SSL conflicts)"