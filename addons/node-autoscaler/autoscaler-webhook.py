#!/usr/bin/env python3
"""
Simple webhook-based node autoscaler for Proxmox/Terraform clusters.

Monitors cluster resource pressure and triggers Terraform to scale worker nodes.
This is a basic implementation - production use should add proper error handling,
metrics, and integration with a cluster autoscaler framework.

Requirements:
- kubectl access to the cluster
- Terraform configured in the k8s-deploy directory
- Python 3.8+

Install dependencies:
  pip install kubernetes flask requests

Usage:
  python autoscaler-webhook.py

Environment variables:
  TERRAFORM_DIR: Path to Terraform config (default: /home/owner/Repos/k8s-deploy)
  CHECK_INTERVAL: Seconds between checks (default: 60)
  SCALE_UP_THRESHOLD: CPU % to trigger scale-up (default: 80)
  SCALE_DOWN_THRESHOLD: CPU % to trigger scale-down (default: 30)
  MIN_WORKERS: Minimum worker nodes (default: 2)
  MAX_WORKERS: Maximum worker nodes (default: 10)
"""

import os
import subprocess
import time
import json
from datetime import datetime
from kubernetes import client, config

# Configuration from environment
TERRAFORM_DIR = os.getenv("TERRAFORM_DIR", "/home/owner/Repos/k8s-deploy")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "60"))
SCALE_UP_THRESHOLD = int(os.getenv("SCALE_UP_THRESHOLD", "80"))
SCALE_DOWN_THRESHOLD = int(os.getenv("SCALE_DOWN_THRESHOLD", "30"))
MIN_WORKERS = int(os.getenv("MIN_WORKERS", "2"))
MAX_WORKERS = int(os.getenv("MAX_WORKERS", "10"))
COOLDOWN_SECONDS = 300  # 5 minutes between scaling operations

last_scale_time = 0


def get_cluster_metrics():
    """Get cluster CPU and memory utilization."""
    try:
        config.load_kube_config()
        v1 = client.CoreV1Api()
        
        # Get node metrics using kubectl top (requires metrics-server)
        result = subprocess.run(
            ["kubectl", "top", "nodes", "--no-headers"],
            capture_output=True,
            text=True,
            check=True
        )
        
        lines = result.stdout.strip().split("\n")
        total_cpu_usage = 0
        total_cpu_capacity = 0
        
        for line in lines:
            parts = line.split()
            if len(parts) >= 3:
                # Parse CPU usage (e.g., "1234m" -> 1.234 cores)
                cpu_usage = parts[1].rstrip("m")
                cpu_pct = parts[2].rstrip("%")
                
                total_cpu_usage += float(cpu_pct)
        
        avg_cpu = total_cpu_usage / len(lines) if lines else 0
        return avg_cpu
    
    except Exception as e:
        print(f"Error getting metrics: {e}")
        return None


def get_current_worker_count():
    """Get current worker count from Terraform state."""
    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=TERRAFORM_DIR,
            capture_output=True,
            text=True,
            check=True
        )
        
        outputs = json.loads(result.stdout)
        worker_ips = outputs.get("worker_ips", {}).get("value", {})
        return len(worker_ips)
    
    except Exception as e:
        print(f"Error getting worker count: {e}")
        return None


def scale_workers(new_count):
    """Scale worker nodes by updating Terraform variable and applying."""
    global last_scale_time
    
    try:
        print(f"[{datetime.now()}] Scaling workers to {new_count}")
        
        # Update terraform.tfvars
        tfvars_path = os.path.join(TERRAFORM_DIR, "terraform.tfvars")
        with open(tfvars_path, "r") as f:
            lines = f.readlines()
        
        # Replace worker_count line
        with open(tfvars_path, "w") as f:
            for line in lines:
                if line.strip().startswith("worker_count"):
                    f.write(f"worker_count = {new_count}\n")
                else:
                    f.write(line)
        
        # Apply Terraform changes
        subprocess.run(
            ["terraform", "apply", "-auto-approve"],
            cwd=TERRAFORM_DIR,
            check=True
        )
        
        last_scale_time = time.time()
        print(f"[{datetime.now()}] Successfully scaled to {new_count} workers")
        return True
    
    except Exception as e:
        print(f"Error scaling workers: {e}")
        return False


def autoscaler_loop():
    """Main autoscaler loop."""
    global last_scale_time
    
    print(f"Starting autoscaler (check every {CHECK_INTERVAL}s)")
    print(f"Scale up threshold: {SCALE_UP_THRESHOLD}% CPU")
    print(f"Scale down threshold: {SCALE_DOWN_THRESHOLD}% CPU")
    print(f"Worker range: {MIN_WORKERS}-{MAX_WORKERS}")
    
    while True:
        try:
            # Get current state
            avg_cpu = get_cluster_metrics()
            current_workers = get_current_worker_count()
            
            if avg_cpu is None or current_workers is None:
                print(f"[{datetime.now()}] Skipping cycle - metrics unavailable")
                time.sleep(CHECK_INTERVAL)
                continue
            
            print(f"[{datetime.now()}] CPU: {avg_cpu:.1f}%, Workers: {current_workers}")
            
            # Check cooldown
            time_since_scale = time.time() - last_scale_time
            if time_since_scale < COOLDOWN_SECONDS:
                remaining = COOLDOWN_SECONDS - time_since_scale
                print(f"  In cooldown period ({remaining:.0f}s remaining)")
                time.sleep(CHECK_INTERVAL)
                continue
            
            # Scale up if CPU is high
            if avg_cpu > SCALE_UP_THRESHOLD and current_workers < MAX_WORKERS:
                new_count = min(current_workers + 1, MAX_WORKERS)
                print(f"  High CPU detected - scaling up to {new_count}")
                scale_workers(new_count)
            
            # Scale down if CPU is low
            elif avg_cpu < SCALE_DOWN_THRESHOLD and current_workers > MIN_WORKERS:
                new_count = max(current_workers - 1, MIN_WORKERS)
                print(f"  Low CPU detected - scaling down to {new_count}")
                scale_workers(new_count)
            
            else:
                print(f"  No scaling needed")
        
        except Exception as e:
            print(f"[{datetime.now()}] Error in autoscaler loop: {e}")
        
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    autoscaler_loop()
