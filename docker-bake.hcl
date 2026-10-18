# docker buildx bake [target]   (default: mai, r, python)

variable "REGISTRY" { default = "ghcr.io/mai-lib" }
variable "TAG"      { default = "latest" }
variable "MAI_REF"  { default = "main" }
variable "RMAI_REF" { default = "main" }

group "default" {
  targets = ["mai", "r", "python"]
}

target "_common" {
  dockerfile = "Dockerfile"
  args = {
    MAI_REF  = MAI_REF
    RMAI_REF = RMAI_REF
  }
}

target "mai" {
  inherits = ["_common"]
  target   = "mai"
  tags     = ["${REGISTRY}/mai:${TAG}"]
}

target "r" {
  inherits = ["_common"]
  target   = "r"
  tags     = ["${REGISTRY}/mai-r:${TAG}"]
}

target "python" {
  inherits = ["_common"]
  target   = "python"
  tags     = ["${REGISTRY}/mai-python:${TAG}"]
}

# R-devel with the proposed ALTREP Extract_array_subset method, for rmai's
# mmap-backed ALTREP results (github.com/mdsumner/r-variants). Not in the
# default group; build with `docker buildx bake r-array-subset`.
target "r-array-subset" {
  inherits = ["r"]
  args = {
    R_IMAGE = "ghcr.io/mdsumner/r-variants:array-subset"
  }
  tags = ["${REGISTRY}/mai-r:array-subset"]
}
