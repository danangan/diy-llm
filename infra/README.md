# infra

One root module:

- `main.tf`: VPC, EKS and the cpu and gpu node groups, from [terraform-aws-k8s](https://github.com/danangan/terraform-aws-k8s)
- `model-storage.tf`: the S3 bucket for models, and read access to it for the runtime pods
- `deploy.tf`: the IAM user the GitHub workflow logs in as
- `dns.tf`: the UI and Grafana hosts (`ui_dns`, `grafana_dns`) pointing at the ALB they share, each with its own ACM certificate. See `example.tfvars`.
- `observability.tf`: [obstack](https://github.com/danangan/k8s-obstack) (values in `helm-values/obstack.yaml`) in the `default` namespace on its own node in one AZ, with its GPU metrics on (DCGM Exporter on the GPU nodes)

```sh
terraform -chdir=infra init && terraform -chdir=infra apply
```

Defaults to region `us-east-1`, cluster `llm-cluster` and app name `diy-llm` (used to name the bucket, the CI/CD user and the runtime role). State is local.

## Node groups

- `cpu`: the UI and cluster add-ons, on `t3.large`
- `gpu`: vLLM, on one `g4dn.xlarge` with a 100 GiB disk for the vLLM image. Tainted `nvidia.com/gpu=true:NoSchedule`.
- `obstack`: one `t4g.large` in `obstack_availability_zone` (`us-east-1a`). Labelled `workload=obstack`, tainted `dedicated=obstack:NoSchedule`. EBS volumes are zonal, so keeping this node in one AZ keeps it next to obstack's volumes. It uses the module's node security group, looked up by its `<cluster>-node` tag, to reach the other nodes.

Node groups don't scale on their own: the GPU node runs until you scale its group down (see `app/README.md`).

## Notes

- The GPU nodes' AMI has the NVIDIA driver but not the Kubernetes device plugin. The module installs it.
- The CI/CD user can write to the model bucket and edit workloads in the cluster. The app runs in the `default` namespace.
- The runtime pods get read access to the model bucket through EKS Pod Identity, for the `llm-runtime` service account in `default`. S3 traffic goes through a VPC endpoint rather than the NAT gateway.
- Keep `kubernetes_version` in EKS standard support. Extended support costs 6x.
- If pulling the obstack chart fails with `docker-credential-desktop`, remove `credsStore` from `~/.docker/config.json`, or run with `DOCKER_CONFIG=$(mktemp -d)`.
- `../script-utils/teardown-infra.sh` removes the Helm releases first and waits for their load balancers and volumes to go, then destroys the rest.
