#!/usr/bin/env bash
# Creates a cloud-init NoCloud ISO for Talos. Supports:
#   - Remote (qemu+ssh): LIBVIRT_SSH_DEST set — streams tarball over SSH, runs cloud-localds on host
#   - Local (qemu:///system): LIBVIRT_SSH_DEST empty — runs cloud-localds locally
# Expects env: CLOUDINIT_ISO_PATH, USER_DATA_B64, META_DATA_B64, NETWORK_CONFIG_B64 (LIBVIRT_SSH_DEST optional)

set -euo pipefail

: "${CLOUDINIT_ISO_PATH:?CLOUDINIT_ISO_PATH is required}"
: "${USER_DATA_B64:?USER_DATA_B64 is required}"
: "${META_DATA_B64:?META_DATA_B64 is required}"
: "${NETWORK_CONFIG_B64:?NETWORK_CONFIG_B64 is required}"

local_tmp=$(mktemp -d)
trap 'rm -rf "${local_tmp}"' EXIT

printf '%s' "${USER_DATA_B64}" | base64 -d > "${local_tmp}/user-data"
printf '%s' "${META_DATA_B64}" | base64 -d > "${local_tmp}/meta-data"
printf '%s' "${NETWORK_CONFIG_B64}" | base64 -d > "${local_tmp}/network-config"

if [[ -n "${LIBVIRT_SSH_DEST:-}" ]]; then
  # Remote: stream tarball over single SSH
  tmp_dir="/tmp/ci-$(basename "${CLOUDINIT_ISO_PATH}" -cloudinit.iso)"
  tar cf - -C "${local_tmp}" user-data meta-data network-config | \
    ssh "${LIBVIRT_SSH_DEST}" "mkdir -p ${tmp_dir} && \
      tar xf - -C ${tmp_dir} && \
      cloud-localds -N ${tmp_dir}/network-config ${tmp_dir}/cloudinit.iso ${tmp_dir}/user-data -m ${tmp_dir}/meta-data && \
      sudo mv ${tmp_dir}/cloudinit.iso ${CLOUDINIT_ISO_PATH} && \
      rm -rf ${tmp_dir}"
else
  # Local: run cloud-localds on this host
  cloud-localds -N "${local_tmp}/network-config" "${CLOUDINIT_ISO_PATH}" "${local_tmp}/user-data" -m "${local_tmp}/meta-data"
fi
