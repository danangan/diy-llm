#!/usr/bin/env bash
# Copies a model from Hugging Face to S3, where vLLM loads it from. Does
# nothing if it's already there. Set HF_TOKEN for gated models.
#
# Usage: upload-model.sh <model> <revision> <bucket>
# Needs the AWS CLI, and `hf` (pip install huggingface_hub) to upload.

set -euo pipefail

MODEL="$1"
REVISION="$2"
DEST="s3://$3/models/${MODEL}/${REVISION}"

# Uploaded last, so it only exists once the whole model is there
if aws s3 ls "${DEST}/.complete" >/dev/null; then
  echo "${MODEL}@${REVISION} is already in S3"
  exit 0
fi

command -v hf >/dev/null || { echo "Missing hf (pip install huggingface_hub)" >&2; exit 1; }

DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

echo "Downloading model $MODEL from HF..."
# vLLM's S3 loader only reads safetensors, so skip the other weight formats,
# and the repo files vLLM never reads
hf download "$MODEL" --revision "$REVISION" --local-dir "$DIR" \
  --exclude "*.bin" --exclude "*.pt" --exclude "*.pth" --exclude "*.gguf" \
  --exclude "*.onnx" --exclude "onnx/*" --exclude "*.msgpack" --exclude "*.h5" \
  --exclude "*.tflite" --exclude "*.ot" --exclude "original/*" --exclude "coreml/*" \
  --exclude "openvino/*" --exclude "*.md" --exclude ".gitattributes" --exclude "LICENSE*"

echo "Syncing into S3..."
aws s3 sync "$DIR" "$DEST" --exclude ".cache/*" --only-show-errors
date -u +%FT%TZ | aws s3 cp - "${DEST}/.complete"
