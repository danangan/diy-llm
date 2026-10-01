# DIY LLM

This project deploys an open-source LLM to AWS EKS and serves it as an OpenAI-compatible API, e.g. for coding agents.

Features:
- API served by vLLM, with an open-source model (`Qwen/Qwen2.5-Coder-14B-Instruct-AWQ` by default), API key auth and tool calling
- One pod on one GPU, since the GPU isn't shared between deployments
- HTTPS on your own Route53 domain, through an ALB ingress
- Observability via https://github.com/danangan/k8s-obstack
  - k8s metrics
  - host metrics
  - gpu metrics
  - vLLM runtime metrics

CI/CD:
- A GitHub workflow uploads the model to S3 and deploys the runtime with Helm

## Architecture

- EKS with three node groups: `cpu` (cluster add-ons), `gpu` (vLLM, one `g4dn.xlarge`) and `obstack` (the observability stack, pinned to one AZ)
- The model is stored in S3. vLLM streams the weights from S3 to the GPU on start.
- One ALB serves `https://<api host>/v1` (vLLM) and `https://<grafana host>` (Grafana), each with its own ACM certificate
- vLLM pushes metrics and traces to obstack

## Project Structure

- `infra/`: Terraform root module. It uses:
  - https://github.com/danangan/terraform-aws-k8s to create the base of the cluster
  - https://github.com/danangan/k8s-obstack to set up the observability stack
- `app/`: the Helm chart of the LLM runtime ([app/README.md](app/README.md))
- `.github/`: the lint and deploy workflows, and their scripts
- `script-utils/`: the teardown script

## Setup

### Prerequisites

Terraform, the AWS CLI, kubectl and Helm. The API and Grafana each need a hostname in a Route53 hosted zone, and an ACM certificate in the same region covering it (one certificate can cover both).

### Deployment steps

1. Clone the repo, then copy `infra/example.tfvars` to `infra/local.auto.tfvars` and fill it in. `certificate_id` is the last part of the certificate's ARN.

2. Create the infrastructure (~25 min):

   ```sh
   terraform -chdir=infra init && terraform -chdir=infra apply
   aws eks update-kubeconfig --region "$(terraform -chdir=infra output -raw region)" --name "$(terraform -chdir=infra output -raw cluster_name)"
   ```

3. Create an access key for the CI/CD user:

   ```sh
   aws iam create-access-key --user-name "$(terraform -chdir=infra output -raw deployment_user_name)"
   ```

4. In the GitHub repository, under Settings > Secrets and variables > Actions, add:

   - Secrets: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from step 3, and `HF_TOKEN` if the model is gated
   - Variables: `AWS_REGION`, `EKS_CLUSTER_NAME`, `MODEL_BUCKET`, `API_HOST` and `API_CERTIFICATE_ARN`, from `terraform -chdir=infra output` (`region`, `cluster_name`, `model_bucket`, `api_host`, `api_certificate_arn`)

5. Run the `deploy` workflow from the Actions tab (or `gh workflow run deploy.yaml`). It uploads the model and deploys. The first start takes ~15 min. To deploy from your machine instead, run `./.github/scripts/deploy.sh`.

### Using the API

It's OpenAI-compatible, at `https://<api host>/v1`, with tool calling on, so coding agents and OpenAI SDKs can use it. The API key:

```sh
API_KEY="$(eval "$(terraform -chdir=infra output -raw api_key_command)")"
```

```sh
curl https://llm.example.com/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen2.5-Coder-14B-Instruct-AWQ", "messages": [{"role": "user", "content": "Hi"}]}'
```

The context length is 16384 tokens (`--max-model-len` in `app/chart/templates/llm-runtime.yaml`).

### Grafana

Grafana is at `https://<grafana host>`. Its admin password:

```sh
eval "$(terraform -chdir=infra output -raw grafana_password_command)"
```

### Teardown

Delete everything with `./script-utils/teardown-infra.sh`.
