#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

# Wrapped in a function so bash reads the whole script before running it,
# and editing the file mid-run can't break it
main() {
  local model="$1"
  local revision="$2"
  local dest="s3://$3/models/${model}/${revision}"

  # Uploaded last, so it only exists once the whole model is there
  if aws s3 ls "${dest}/.complete" >/dev/null; then
    ok "${model}@${revision} is already in S3"
    return
  fi

  command -v hf >/dev/null || die "Missing hf (pip install huggingface_hub)"

  DIR="$(mktemp -d)"
  trap 'rm -rf "$DIR"' EXIT

  log "Downloading ${model}@${revision} from Hugging Face"
  # vLLM's S3 loader only reads safetensors, so skip the other weight formats,
  # and the repo files vLLM never reads
  hf download "$model" --revision "$revision" --local-dir "$DIR" \
    --exclude "*.bin" --exclude "*.pt" --exclude "*.pth" --exclude "*.gguf" \
    --exclude "*.onnx" --exclude "onnx/*" --exclude "*.msgpack" --exclude "*.h5" \
    --exclude "*.tflite" --exclude "*.ot" --exclude "original/*" --exclude "coreml/*" \
    --exclude "openvino/*" --exclude "*.md" --exclude ".gitattributes" --exclude "LICENSE*"

  log "Syncing to ${dest}"
  aws s3 sync "$DIR" "$dest" --exclude ".cache/*"

  local completed_at
  completed_at="$(date -u +%FT%TZ)"
  echo "$completed_at" | aws s3 cp - "${dest}/.complete"
  ok "Uploaded ${model}@${revision}"
}

main "$@"
