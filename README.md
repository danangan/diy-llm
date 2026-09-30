# DIY LLM

This project is about deploying a LLM runtime to AWS EKS using the following:

- https://github.com/danangan/terraform-aws-k8s to stand uop the k8s cluster:
  - Use the auto mode to simplify setup
  - Restrict the GPU instances to be the smallest instance
  - The CPU instances can be whatever a

- https://github.com/danangan/k8s-obstack to set up observability
  - Should be deployed to dedicated node pool for isolation
  - Should be deployed to its own namespace (obstack) in kubernetes
  - Ingress for the grafana ui via load balancer

Feature:
- UI to interact with the LLM using open source https://openwebui.com/
- Backend to serve the LLM model using vLLM (only use open sourced model for now)
- For this project purpose, just deploy 1 pod since it's limited to 1GPU and we don't want to share GPU with multiple deployment
- Ingress for the ui using load balancer ingress

CI/CD
- Build and deploy changes to the code of the LLM UI and LLM runtime via github workflow, deployed using helm

Project structure:

/infra -> contains terraform root code that uses:
  - uses https://github.com/danangan/terraform-aws-k8s to create the base of the cluster
  - uses https://github.com/danangan/k8s-obstack to set up the observability stack
/diy-llm -> contains the helm chart of the LLM application (UI and runtime/backend) and any application code required (if it requires pythin, dockerfile etc)

## Layout

- `infra`: one Terraform root module for the VPC, EKS with managed node groups, the model bucket, the CI/CD IAM user and obstack
- `script-utils/teardown-infra.sh`: deletes everything
- `app/chart`: Helm chart for the UI and the vLLM runtime
- `.github/scripts/upload-model.sh`: uploads the model to S3
- `.github/workflows/lint.yaml`: lints the chart on pull requests
- `.github/workflows/deploy.yaml`: run by hand; lints, uploads the model, builds and deploys

## Setup

Needs Terraform, the AWS CLI, kubectl and Helm.

1. Create the infrastructure (~25 min). The UI and Grafana each need a hostname in a Route53 hosted zone, and an ACM certificate in the same region covering it (one certificate can cover both). Copy `infra/example.tfvars` to `infra/local.auto.tfvars` and fill it in. `certificate_id` is the last part of the certificate's ARN.

   ```sh
   terraform -chdir=infra init && terraform -chdir=infra apply
   $(terraform -chdir=infra output -raw kubeconfig_command)
   ```

2. Create an access key for the CI/CD user:

   ```sh
   aws iam create-access-key --user-name "$(terraform -chdir=infra output -raw deployment_user_name)"
   ```

3. In the GitHub repository, under Settings > Secrets and variables > Actions, add:

   - Secrets: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from step 2, and `HF_TOKEN` if the model is gated
   - Variables: `AWS_REGION`, `EKS_CLUSTER_NAME`, `MODEL_BUCKET`, `UI_HOST` and `UI_CERTIFICATE_ARN`, from `terraform -chdir=infra output` (`region`, `cluster_name`, `model_bucket`, `ui_host`, `ui_certificate_arn`)

4. Run the `deploy` workflow from the Actions tab (or `gh workflow run deploy.yaml`). It uploads the model and deploys. The first start takes ~15 min.

The UI and Grafana are at the hosts set in `ui_dns` and `grafana_dns`. Grafana's admin password:

```sh
$(terraform -chdir=infra output -raw grafana_password_command)
```

Delete everything with `./script-utils/teardown-infra.sh`.

## Cost

Roughly $700/month if left running in us-east-1, about $385 of it for the GPU node. Scale the GPU node group to zero when you're not using it (see [app/README.md](app/README.md#turning-off-the-gpu)).
