# Cirrus cloud-init assets

GitHub Gist delivery is deprecated and unsupported for this deployment.

Cloud-init bootstrap assets must be versioned under this `cloud-init/`
directory and downloaded from a named branch or immutable commit in this
repository. Secrets must be supplied through the OpenShift Secret mounts and
must never be embedded in either the repository URL or cloud-init user data.
