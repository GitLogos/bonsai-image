#!/bin/bash
set -e

DEMO_DIR="/app"
cd "$DEMO_DIR"

echo "========================================================"
echo "    Bonsai Image 4B Endpoint Bootloader"
echo "========================================================"
echo ""

echo "Checking GPU / CUDA status..."
python3 -c "import torch; print('  PyTorch CUDA Available:', torch.cuda.is_available()); print('  Device Count:', torch.cuda.device_count())"
echo ""

: "${BONSAI_VARIANT:=ternary}"
echo "Selected Bonsai variant: ${BONSAI_VARIANT}"

case "$BONSAI_VARIANT" in
    ternary|binary) ;;
    *) echo "Error: BONSAI_VARIANT must be 'ternary' or 'binary' (got $BONSAI_VARIANT)" >&2; exit 1 ;;
esac

_model_dir="$DEMO_DIR/models/bonsai-image-4B-${BONSAI_VARIANT}-gemlite"
_ternary_dir="$DEMO_DIR/models/bonsai-image-4B-ternary-gemlite"
_binary_dir="$DEMO_DIR/models/bonsai-image-4B-binary-gemlite"

_active_transformer=$(ls -d "$_model_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)

if [ -z "$_active_transformer" ]; then
    echo "--------------------------------------------------------"
    echo " Model files for variant '${BONSAI_VARIANT}' not found in /app/models."
    echo " Automatically initiating HuggingFace download..."
    echo " (This might take several minutes on first startup)"
    echo "--------------------------------------------------------"
    ./scripts/download_model.sh --model "${BONSAI_VARIANT}-gemlite"
fi

_ternary_transformer=$(ls -d "$_ternary_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)
_binary_transformer=$(ls -d "$_binary_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)

_launched_transformer=$(ls -d "$_model_dir"/transformer-gemlite-* 2>/dev/null | head -1 || true)
if [ -z "$_launched_transformer" ]; then
    echo "Error: Failed to find or download transformer files under ${_model_dir}." >&2
    exit 1
fi

_default_backend="bonsai-${BONSAI_VARIANT}-gemlite"
_backend_module="scripts.local_backend:app"

export MFLUX_STUDIO_GPU_DEFAULT_BACKEND="$_default_backend"
export MFLUX_STUDIO_GPU_TEXT_ENCODER_PATH="$_model_dir/text_encoder-hqq-4bit"
export MFLUX_STUDIO_GPU_VAE_PATH="$_model_dir/vae"
export MFLUX_STUDIO_GPU_TOKENIZER_PATH="$_model_dir/text_encoder-hqq-4bit/tokenizer"
export MFLUX_STUDIO_GPU_TERNARY_TRANSFORMER_PATH="${_ternary_transformer:-$_ternary_dir/transformer-gemlite-int2}"
export MFLUX_STUDIO_GPU_BINARY_TRANSFORMER_PATH="${_binary_transformer:-$_binary_dir/transformer-gemlite-int1}"

echo "--------------------------------------------------------"
echo " Starting Next.js Frontend..."
echo " Interface: http://0.0.0.0:3000"
echo " NEXT_PUBLIC_BACKEND_URL: http://127.0.0.1:8000"
echo "--------------------------------------------------------"
echo ""

cd /app/vendor/image-studio/frontend
PORT=3000 HOSTNAME=0.0.0.0 NEXT_PUBLIC_BACKEND_URL="http://127.0.0.1:8000" npm start &
cd /app

echo "--------------------------------------------------------"
echo " Starting FastAPI / Uvicorn Server..."
echo " Default Backend: ${_default_backend}"
echo " Interface: 0.0.0.0:8000"
echo "--------------------------------------------------------"
echo ""

exec uvicorn "$_backend_module" --host 0.0.0.0 --port 8000
