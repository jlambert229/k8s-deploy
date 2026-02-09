# Node Autoscaler for Proxmox/Terraform

Automatically scales worker nodes in your Talos Kubernetes cluster based on resource utilization.

## How It Works

The autoscaler monitors average CPU usage across all nodes and:
- **Scales up** when CPU exceeds the threshold (default: 80%)
- **Scales down** when CPU drops below the threshold (default: 30%)
- Updates `terraform.tfvars` with the new `worker_count`
- Runs `terraform apply` to create/destroy VMs
- Talos automatically joins new nodes to the cluster

## Installation

The autoscaler is installed as a systemd service.

### Status

```bash
# Check if running
sudo systemctl status k8s-node-autoscaler

# View live logs
sudo journalctl -u k8s-node-autoscaler -f

# View recent activity
sudo journalctl -u k8s-node-autoscaler -n 50
```

### Control

```bash
# Start
sudo systemctl start k8s-node-autoscaler

# Stop
sudo systemctl stop k8s-node-autoscaler

# Restart
sudo systemctl restart k8s-node-autoscaler

# Disable (prevent auto-start on boot)
sudo systemctl disable k8s-node-autoscaler

# Enable (auto-start on boot)
sudo systemctl enable k8s-node-autoscaler
```

## Configuration

Edit `autoscaler.env`:

```bash
# Scaling thresholds
SCALE_UP_THRESHOLD=80        # CPU % to trigger scale-up
SCALE_DOWN_THRESHOLD=30      # CPU % to trigger scale-down

# Worker limits
MIN_WORKERS=2                # Minimum workers (never go below)
MAX_WORKERS=6                # Maximum workers (never exceed)

# Timing
CHECK_INTERVAL=60            # Seconds between checks
COOLDOWN_SECONDS=300         # Minimum time between scaling operations
```

After editing, restart the service:

```bash
sudo systemctl restart k8s-node-autoscaler
```

## Monitoring

### Real-time Monitoring

```bash
# Watch cluster metrics
watch -n 5 "kubectl top nodes && echo && kubectl get nodes"

# Follow autoscaler decisions
sudo journalctl -u k8s-node-autoscaler -f
```

### Check Autoscaler State

```bash
# Current worker count
terraform output -raw worker_ips | jq 'length'

# Current CPU usage
kubectl top nodes
```

## Testing

### Simulate High Load

To test scale-up, generate CPU load:

```bash
# Deploy CPU stress test
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: stress-test
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "4", "--timeout", "300s"]
    resources:
      requests:
        cpu: "2000m"
      limits:
        cpu: "4000m"
EOF

# Monitor autoscaler response
sudo journalctl -u k8s-node-autoscaler -f
```

After ~60s (CHECK_INTERVAL), the autoscaler should detect high CPU and scale up.

### Simulate Low Load

To test scale-down:

```bash
# Delete stress test
kubectl delete pod stress-test

# Wait 5 minutes (COOLDOWN_SECONDS)
# Monitor autoscaler
sudo journalctl -u k8s-node-autoscaler -f
```

After cooldown, if CPU remains low, autoscaler will scale down.

## Troubleshooting

### Autoscaler Not Scaling

**Check logs:**
```bash
sudo journalctl -u k8s-node-autoscaler -n 100
```

**Common issues:**

1. **In cooldown period**
   - Wait for COOLDOWN_SECONDS (default: 5 min) after last scaling operation

2. **Already at MIN/MAX_WORKERS**
   - Check current worker count: `kubectl get nodes`
   - Adjust limits in `autoscaler.env`

3. **Terraform errors**
   - Check Terraform state: `cd /home/owner/Repos/k8s-deploy && terraform plan`
   - Ensure Proxmox has capacity for new VMs

4. **Metrics unavailable**
   - Verify metrics-server: `kubectl get pods -n kube-system -l k8s-app=metrics-server`
   - Test metrics: `kubectl top nodes`

### Service Not Starting

```bash
# Check service status
sudo systemctl status k8s-node-autoscaler

# Check for errors
sudo journalctl -u k8s-node-autoscaler -n 50

# Verify Python dependencies
/home/owner/Repos/k8s-deploy/addons/node-autoscaler/venv/bin/python -c "import kubernetes; print('OK')"
```

### Manual Test

Test the autoscaler manually without systemd:

```bash
cd /home/owner/Repos/k8s-deploy/addons/node-autoscaler
source autoscaler.env
venv/bin/python autoscaler-webhook.py
```

Press Ctrl+C to stop.

## Safety Features

1. **Cooldown period** prevents rapid scaling oscillation
2. **MIN_WORKERS** ensures cluster always has minimum capacity
3. **MAX_WORKERS** prevents runaway scaling (cost control)
4. **Terraform state** prevents concurrent modifications

## Disabling

To temporarily disable autoscaling without uninstalling:

```bash
sudo systemctl stop k8s-node-autoscaler
sudo systemctl disable k8s-node-autoscaler
```

To re-enable:

```bash
sudo systemctl enable k8s-node-autoscaler
sudo systemctl start k8s-node-autoscaler
```

## Uninstalling

```bash
# Stop and disable service
sudo systemctl stop k8s-node-autoscaler
sudo systemctl disable k8s-node-autoscaler

# Remove service file
sudo rm /etc/systemd/system/k8s-node-autoscaler.service
sudo systemctl daemon-reload
```

## See Also

- [AUTOSCALING.md](../../AUTOSCALING.md) - Full autoscaling documentation
- [Terraform configuration](../../terraform.tfvars) - Current cluster config
