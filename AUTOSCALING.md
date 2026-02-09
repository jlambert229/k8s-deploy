# Cluster Autoscaling

Comprehensive autoscaling for your Talos Kubernetes cluster with both **pod** and **node** autoscaling.

## Overview

| Type | Component | What It Does |
|------|-----------|--------------|
| **Pod** | Metrics Server | Provides resource metrics for autoscaling decisions |
| **Pod** | HPA (Horizontal) | Scales pod replicas based on CPU/memory usage |
| **Pod** | VPA (Vertical) | Adjusts pod resource requests/limits automatically |
| **Node** | Custom Autoscaler | Adds/removes worker VMs based on cluster load |

## Quick Start

### 1. Deploy Pod Autoscaling (HPA + VPA)

```bash
# Deploy metrics-server (required for HPA and VPA)
kubectl apply -f addons/metrics-server/metrics-server.yaml

# Wait for metrics-server to be ready
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Verify metrics are available
kubectl top nodes
kubectl top pods -A

# Deploy VPA
kubectl apply -f addons/vpa/vpa.yaml

# Verify VPA is running
kubectl get pods -n vpa-system
```

### 2. Test Pod Autoscaling

```bash
# Deploy HPA example
kubectl apply -f addons/examples/hpa-example.yaml

# Watch HPA status
kubectl get hpa nginx-demo --watch

# Generate load to test HPA
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://nginx-demo; done"

# Deploy VPA example
kubectl apply -f addons/examples/vpa-example.yaml

# Check VPA recommendations
kubectl describe vpa app-with-vpa
```

### 3. Enable Node Autoscaling

Node autoscaling for Proxmox requires a custom solution. We provide a simple Python-based autoscaler:

```bash
# Install dependencies
cd addons/node-autoscaler
pip install -r requirements.txt

# Configure (edit these as needed)
export TERRAFORM_DIR=/home/owner/Repos/k8s-deploy
export MIN_WORKERS=2
export MAX_WORKERS=10
export SCALE_UP_THRESHOLD=80
export SCALE_DOWN_THRESHOLD=30

# Run autoscaler
python autoscaler-webhook.py
```

For production, run this as a systemd service or in a container.

---

## Horizontal Pod Autoscaler (HPA)

HPA scales the number of pod replicas based on observed metrics.

### Basic HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Check HPA Status

```bash
# List all HPAs
kubectl get hpa -A

# Describe specific HPA
kubectl describe hpa my-app

# Watch HPA in real-time
kubectl get hpa my-app --watch
```

### Troubleshooting HPA

| Issue | Cause | Fix |
|-------|-------|-----|
| `<unknown>` metrics | Metrics server not running | Deploy metrics-server |
| Not scaling | No resource requests set | Add `resources.requests` to pods |
| Flapping | Thresholds too tight | Adjust `behavior.scaleDown.stabilizationWindowSeconds` |

---

## Vertical Pod Autoscaler (VPA)

VPA automatically adjusts CPU and memory requests/limits for your pods.

### VPA Update Modes

| Mode | Behavior |
|------|----------|
| `Off` | Only provides recommendations (no updates) |
| `Initial` | Sets requests on pod creation only |
| `Recreate` | Evicts and recreates pods with new requests |
| `Auto` | Recreates pods when recommendations change significantly |

### Basic VPA

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 2000m
        memory: 4Gi
```

### Check VPA Recommendations

```bash
# List all VPAs
kubectl get vpa -A

# Get recommendations
kubectl describe vpa my-app

# Output shows:
# - Lower Bound: Minimum recommended resources
# - Target: Recommended resources
# - Upper Bound: Maximum recommended resources
# - Uncapped Target: Recommendation without policy limits
```

### VPA Best Practices

1. **Start with `updateMode: "Off"`** to see recommendations without disruption
2. **Set `minAllowed` and `maxAllowed`** to prevent extreme recommendations
3. **Don't use VPA + HPA on the same metric** (use VPA for requests, HPA for replicas)
4. **Exclude critical pods** or use `updateMode: "Initial"` for stateful workloads

---

## Node Autoscaling

Node autoscaling for Proxmox/Terraform clusters uses a custom webhook that monitors cluster load and triggers Terraform to scale worker nodes.

### How It Works

```
┌─────────────────────────────────────────────────────┐
│         Autoscaler Webhook (Python)                 │
│                                                     │
│  1. Monitor: kubectl top nodes                     │
│  2. Decide: CPU > 80% → scale up                   │
│             CPU < 30% → scale down                 │
│  3. Execute: Update terraform.tfvars               │
│              terraform apply -auto-approve          │
└─────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────┐
│           Terraform (k8s-deploy)                    │
│                                                     │
│  • Creates/destroys Proxmox VMs                    │
│  • Talos auto-joins new nodes                      │
└─────────────────────────────────────────────────────┘
```

### Configuration

Edit environment variables in `addons/node-autoscaler/autoscaler-webhook.py`:

| Variable | Default | Description |
|----------|---------|-------------|
| `MIN_WORKERS` | 2 | Minimum worker nodes |
| `MAX_WORKERS` | 10 | Maximum worker nodes |
| `SCALE_UP_THRESHOLD` | 80 | CPU % to trigger scale-up |
| `SCALE_DOWN_THRESHOLD` | 30 | CPU % to trigger scale-down |
| `CHECK_INTERVAL` | 60 | Seconds between checks |
| `COOLDOWN_SECONDS` | 300 | Minimum time between scaling ops |

### Running as a Systemd Service

```bash
# Create service file
sudo tee /etc/systemd/system/k8s-node-autoscaler.service > /dev/null <<EOF
[Unit]
Description=Kubernetes Node Autoscaler for Proxmox
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/owner/Repos/k8s-deploy/addons/node-autoscaler
Environment="TERRAFORM_DIR=/home/owner/Repos/k8s-deploy"
Environment="MIN_WORKERS=2"
Environment="MAX_WORKERS=10"
Environment="SCALE_UP_THRESHOLD=80"
Environment="SCALE_DOWN_THRESHOLD=30"
ExecStart=/usr/bin/python3 autoscaler-webhook.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable k8s-node-autoscaler
sudo systemctl start k8s-node-autoscaler

# Check status
sudo systemctl status k8s-node-autoscaler
sudo journalctl -u k8s-node-autoscaler -f
```

### Running in Kubernetes (Advanced)

For a more integrated solution, you can run the autoscaler as a Kubernetes CronJob or Deployment. This requires:

1. **Service account** with permissions to read metrics
2. **Terraform backend** accessible from the pod (e.g., S3, GCS)
3. **Proxmox credentials** mounted as secrets

This is more complex and requires careful security configuration.

### Alternative: Karpenter

For a more sophisticated solution, consider [Karpenter](https://karpenter.sh/) with a custom provisioner for Proxmox. This requires:

- Writing a Proxmox cloud provider plugin
- Integrating with the Karpenter controller
- More development effort, but better integration with Kubernetes

---

## Monitoring Autoscaling

### Metrics Server

```bash
# Check metrics-server logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Verify metrics are working
kubectl top nodes
kubectl top pods -A
```

### HPA Events

```bash
# Watch HPA scaling events
kubectl get events --sort-by=.lastTimestamp | grep HorizontalPodAutoscaler

# Continuous monitoring
watch -n 5 "kubectl get hpa -A && kubectl top nodes"
```

### VPA Events

```bash
# Watch VPA recommendations
kubectl get events --sort-by=.lastTimestamp | grep VerticalPodAutoscaler

# Monitor VPA recommendations
watch -n 10 "kubectl get vpa -A"
```

### Node Autoscaler Logs

```bash
# If running as systemd service
sudo journalctl -u k8s-node-autoscaler -f

# If running manually
# Logs are printed to stdout
```

---

## Troubleshooting

### Metrics Server Issues

**Problem**: `kubectl top nodes` shows `error: Metrics API not available`

**Fix**:
```bash
# Check if metrics-server is running
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Check logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Redeploy if needed
kubectl delete -f addons/metrics-server/metrics-server.yaml
kubectl apply -f addons/metrics-server/metrics-server.yaml
```

### HPA Not Scaling

**Problem**: HPA shows `<unknown>/70%` for metrics

**Causes**:
1. Pods don't have resource requests set
2. Metrics server not ready
3. Target deployment has no matching pods

**Fix**:
```bash
# Verify pods have requests
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources.requests}'

# Add requests to your deployment
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

### VPA Not Updating Pods

**Problem**: VPA shows recommendations but doesn't update pods

**Causes**:
1. `updateMode: "Off"` (recommendation-only mode)
2. Recommendations within current requests
3. PodDisruptionBudget prevents eviction

**Fix**:
```bash
# Check VPA status
kubectl describe vpa <vpa-name>

# Change update mode
kubectl patch vpa <vpa-name> --type='json' -p='[{"op": "replace", "path": "/spec/updatePolicy/updateMode", "value": "Auto"}]'
```

### Node Autoscaler Not Scaling

**Problem**: Autoscaler detects high CPU but doesn't scale

**Causes**:
1. Already at MAX_WORKERS
2. In cooldown period
3. Terraform apply failed
4. Insufficient Proxmox resources

**Fix**:
```bash
# Check autoscaler logs
sudo journalctl -u k8s-node-autoscaler -n 50

# Manually verify Terraform can scale
cd /home/owner/Repos/k8s-deploy
terraform plan

# Check Proxmox resources
# Ensure enough CPU/RAM/storage for new VMs
```

---

## Best Practices

### General

1. **Start conservative** - Use low thresholds and small replica ranges initially
2. **Monitor for a week** before tuning aggressively
3. **Set resource requests/limits** on all pods
4. **Use PodDisruptionBudgets** to prevent disruption during scale-down

### HPA

- **Use `behavior`** to control scale-up/down speed
- **Combine CPU and memory metrics** for better decisions
- **Set realistic thresholds** (70-80% CPU is reasonable)
- **Avoid HPA on VPA-managed metrics** (use HPA for replicas, VPA for requests)

### VPA

- **Start with `updateMode: "Off"`** to observe recommendations
- **Set min/max bounds** to prevent extreme recommendations
- **Use `updateMode: "Initial"`** for stateful apps to avoid restarts
- **Monitor for recommendation flapping** and adjust bounds

### Node Autoscaling

- **Set MIN_WORKERS ≥ 2** for workload redundancy
- **Use conservative thresholds** (80% up, 30% down)
- **Ensure Proxmox has capacity** for MAX_WORKERS
- **Monitor Terraform state** for conflicts
- **Use longer cooldowns** (5+ minutes) to avoid flapping

---

## Cost Optimization

Autoscaling helps reduce costs by:

1. **Scale down during low usage** (nights, weekends)
2. **Right-size pods** with VPA to avoid over-provisioning
3. **Remove idle nodes** with node autoscaling
4. **Scale up only when needed** based on actual demand

For maximum savings:

- Set aggressive SCALE_DOWN_THRESHOLD (e.g., 20%)
- Use longer stabilization windows for HPA
- Enable VPA on all workloads to optimize requests
- Schedule non-critical workloads during off-peak hours

---

## References

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes VPA Documentation](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Talos Linux Cluster Autoscaler Discussion](https://github.com/siderolabs/talos/discussions/3939)
