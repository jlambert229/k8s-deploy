# --- Talos Image Factory ---
# Builds a schematic with the requested extensions and downloads the
# nocloud disk image to Proxmox storage.

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.talos_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
      }
    }
  })
}

# Download the Talos nocloud raw image to Proxmox ISO storage.
# The image is decompressed on download and stored as a .img file
# that Proxmox can use as a boot disk source.
resource "proxmox_virtual_environment_download_file" "talos" {
  node_name               = var.proxmox_node
  content_type            = "iso"
  datastore_id            = var.image_storage
  file_name               = "talos-${var.talos_version}-${var.cluster_name}.img"
  url                     = "${var.talos_factory_url}/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
  overwrite_unmanaged     = true
}
