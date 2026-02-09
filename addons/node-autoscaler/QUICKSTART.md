# Node Autoscaler Quick Reference

## Status & Monitoring

```bash
# Check service status
sudo systemctl status k8s-node-autoscaler

# Watch live logs
sudo journalctl -u k8s-node-autoscaler -f

# View last 50 log entries
sudo journalctl -u k8s-node-autoscaler -n 50

# Monitor cluster in real-time
watch -n 5 "kubectl top nodes && echo && kubectl get nodes"
```

## Control

```bash
# Start
sudo systemctl start k8s-node-autoscaler

# Stop
sudo systemctl stop k8s-node-autoscaler

# Restart
sudo systemctl restart k8s-node-autoscaler

# Disable auto-start
sudo systemctl disable k8s-node-autoscaler

# Enable auto-start
sudo systemctl enable k8s-node-autoscaler
```

## Configuration

Edit `/home/owner/Repos/k8s-deploy/addons/node-autoscaler/autoscaler.env`:

```bash
# Scale up when avg CPU exceeds this percentage
SCALE_UP_THRESHOLD=80

# Scale down when avg CPU drops below this percentage  
SCALE_DOWN_THRESHOLD=30

# Minimum number of worker nodes (never go below)
MIN_WORKERS=2

# Maximum number of worker nodes (never exceed)
MAX_WORKERS=6

# Seconds between checks
CHECK_INTERVAL=60

# Minimum seconds between scaling operations
COOLDOWN_SECONDS=300
```

**After editing, restart the service:**
```bash
sudo systemctl restart k8s-node-autoscaler
```

## Testing

### Test Scale-Up

Deploy a CPU-intensive workload:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "4", "--timeout", "600s"]
    resources:
      requests:
        cpu: "2000m"
EOF

# Watch autoscaler respond
sudo journalctl -u k8s-node-autoscaler -f
```

Expected: After ~60s, autoscaler detects high CPU and scales up.

### Test Scale-Down

```bash
# Delete stress test
kubectl delete pod cpu-stress

# Wait 5 minutes (cooldown period)
# Then watch autoscaler scale down
sudo journalctl -u k8s-node-autoscaler -f
```

Expected: After cooldown + low CPU detection, autoscaler scales down.

## Troubleshooting

### No scaling happening

1. **Check if in cooldown:**
   ```bash
   sudo journalctl -u k8s-node-autoscaler -n 10
   ```
   Look for "In cooldown period" messages

2. **Check current limits:**
   ```bash
   kubectl get nodes | grep -c Ready  # Current node count
   cat autoscaler.env | grep -E "(MIN|MAX)_WORKERS"
   ```

3. **Check CPU usage:**
   ```bash
   kubectl top nodes
   ```

### Service won't start

```bash
# Check for errors
sudo journalctl -u k8s-node-autoscaler -n 50

# Verify Python dependencies
cd /home/owner/Repos/k8s-deploy/addons/node-autoscaler
venv/bin/python -c "import kubernetes; print('Dependencies OK')"

# Test manually
source autoscaler.env
venv/bin/python autoscaler-webhook.py
```

### Terraform errors

```bash
# Check Terraform state
cd /home/owner/Repos/k8s-deploy
terraform plan

# View Terraform logs in autoscaler output
sudo journalctl -u k8s-node-autoscaler -n 100 | grep -A 5 "terraform"
```

## Current Status

**Service:** `k8s-node-autoscaler.service`  
**Location:** `/home/owner/Repos/k8s-deploy/addons/node-autoscaler/`  
**Config:** `autoscaler.env`  
**Logs:** `sudo journalctl -u k8s-node-autoscaler`

**Current Settings:**
- Scale up at: 80% CPU
- Scale down at: 30% CPU  
- Worker range: 2-6 nodes
- Check interval: 60 seconds
- Cooldown: 5 minutes

## See Also

- [README.md](README.md) - Full documentation
- [AUTOSCALING.md](../../AUTOSCALING.md) - Complete autoscaling guide
