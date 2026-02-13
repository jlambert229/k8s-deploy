# --- State Migrations ---
# moved blocks preserve existing resources when refactoring. Remove after
# everyone has applied; they are no-ops once state is migrated.

moved {
  from = local_sensitive_file.kubeconfig
  to   = local_sensitive_file.generated["kubeconfig"]
}

moved {
  from = local_sensitive_file.talosconfig
  to   = local_sensitive_file.generated["talosconfig"]
}
