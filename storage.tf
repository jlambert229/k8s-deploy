# --- NFS CSI Driver ---
# Installs the NFS CSI driver into kube-system so pods can mount NFS volumes.
# Required on Talos — host nfs-utils don't exist; the CSI driver handles NFS
# mounting inside its own container. The server/share come from the StorageClass
# parameters per-PVC; the chart does not need a default server.

resource "helm_release" "csi_driver_nfs" {
  count = var.nfs_server != null ? 1 : 0

  depends_on = [data.talos_cluster_health.this]

  name       = "csi-driver-nfs"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  version    = var.nfs_csi_version
  namespace  = "kube-system"

  wait    = true
  timeout = 120
}

# --- NFS StorageClass ---
# Dynamic provisioner: each PVC gets its own subdirectory under the NFS share.
# Matches the nfs-appdata StorageClass used by k8s-media-stack and other repos.

resource "kubernetes_storage_class_v1" "nfs_appdata" {
  count = var.nfs_server != null ? 1 : 0

  depends_on = [helm_release.csi_driver_nfs]

  metadata {
    name = "nfs-appdata"
  }

  storage_provisioner    = "nfs.csi.k8s.io"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    server = var.nfs_server
    share  = var.nfs_appdata_share
  }

  mount_options = ["nfsvers=3", "nolock"]
}
