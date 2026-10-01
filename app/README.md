# diy-llm

`chart/` is the Helm chart for the vLLM runtime, with the upstream `vllm/vllm-openai` image. It serves an OpenAI-compatible API at `https://<api host>/v1` (only `/v1` is public), with tool calling on for coding agents. vLLM requires an API key, which the chart generates once and keeps across deploys.

## Model storage

The CI/CD pipeline uploads the model to S3 (`s3://<bucket>/models/<model>/<revision>`) before deploying, if it isn't there yet. It skips weight formats vLLM doesn't use, and uploads a `.complete` marker last.

vLLM loads the model straight from S3, streaming the weights to the GPU (`--load-format=runai_streamer`). It keeps its compile cache on the node's disk (`emptyDir`), so container restarts are faster. A new pod starts with an empty cache.

## Changing the model

Set `runtime.model.name` and `revision` (ideally a commit) in `chart/values.yaml` and push. The model has to fit on a T4 (16 GiB) with room for the KV cache: up to about 7B parameters in fp16, or about 14B quantized to 4 bits (AWQ). It must have safetensors weights.

For a gated model, add your Hugging Face token as the `HF_TOKEN` repository secret.

## Observability

These go to obstack:

- vLLM metrics (latency, time to first token, throughput, KV cache use), pushed by a sidecar
- vLLM traces
- GPU metrics (utilization, memory, temperature, power) from NVIDIA's DCGM exporter, named `DCGM_FI_*`

## Deploying

`.github/workflows/lint.yaml` lints the chart on pull requests. `.github/workflows/deploy.yaml` is run by hand: it lints, uploads the model, and runs `helm upgrade`.

From your machine, `.github/scripts/deploy.sh` does the same. It needs `infra/` applied, the AWS CLI (logged in), Helm and `yq`, plus `hf` (`pip install huggingface_hub`) if the model isn't in S3 yet:

```sh
./.github/scripts/deploy.sh
```

## Turning off the GPU

The GPU node costs about $0.53/hour while it runs. Node groups don't scale on their own, so scale the runtime down, then the GPU node group:

```sh
kubectl scale deployment llm-runtime --replicas=0

GPU_GROUP="$(aws eks list-nodegroups --cluster-name llm-cluster --query 'nodegroups[?starts_with(@, `gpu`)] | [0]' --output text)"
aws eks update-nodegroup-config --cluster-name llm-cluster --nodegroup-name "$GPU_GROUP" \
  --scaling-config minSize=0,maxSize=1,desiredSize=0
```

To start it again, set `desiredSize=1` and scale the runtime back to 1 (or run the deploy workflow).
