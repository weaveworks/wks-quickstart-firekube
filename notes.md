# Firekube

## Files

1. Installation files:
   1. cluster.yaml: 
      1. wksctl provider spec for creating the cluster
      2. contains network block details
      3. specifies docker version and config map details
   2. machines.yaml:
      1. details for master and worker nodes
      2. specify kubernetes version and ssh details
2. Configmap boilerplate files:
   1. docker-config.yaml
   2. repo-config.yaml
   3. Where file name is: `<configmap-name>-config.yaml`


## Prerequisites

https://ignite.readthedocs.io/en/stable/dependencies/

## Setup kubernetes

``` bash
# Add kubernetes repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt update

# Install docker (including containerd)
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl status docker
sudo usermod -aG docker ${USER}

# Install kubernetes
apt install -y apt-transport-https kubeadm kubelet kubectl

# Forward packets to real servers
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/10-kubernetes.conf
# Bind ips that don't exist yet (i.e. virtual ips) for HA load balancing, etc.
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.d/10-kubernetes.conf
```

## Setup CNI

``` bash
export CNI_VERSION=v0.8.6
export ARCH=$([ $(uname -m) = "x86_64" ] && echo amd64 || echo arm64)
curl -sSL https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz | tar -xz -C /opt/cni/bin

sudo bash -c 'echo 10.61.0.1 > /var/lib/cni/networks/ignite-cni-bridge/last_reserved_ip.0'
```

# List running VMs
sudo ignite ps

# List Docker (OCI) and kernel images imported into Ignite
sudo ignite images
sudo ignite kernels

# Get the boot logs of the VM
sudo ignite logs my-vm

# Log into the VM
<!-- sudo ignite ssh firekube-node0 -->
sudo ignite attach firekube-node0

To detach from the TTY, enter the key combination ^P^Q (Ctrl + P + Q)

## Install Helm

``` bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update              # Make sure we get the latest list of charts
helm search repo stable | grep -v "DEPRECATED"
```

In stall weave scope:

``` bash
helm install scope stable/weave-scope
helm install grafana stable/grafana
helm install traefik traefik/traefik
# helm install stable/grafana --generate-name
# helm install stable/weave-scope --generate-name
helm ls
kubectl -n default port-forward $(kubectl -n default get endpoints \
weave-scope-1591255216-weave-scope -o jsonpath='{.subsets[0].addresses[0].targetRef.name}') 8080:4040
```

## Releases

https://github.com/jkcfg/jk/releases
https://github.com/weaveworks/footloose/releases
https://github.com/weaveworks/ignite/releases
https://github.com/weaveworks/wksctl/releases

https://kubernetes.io/docs/setup/production-environment/container-runtimes/
https://github.com/docker/docker-ce/releases
https://github.com/fluxcd/flux/releases
https://github.com/memcached/memcached/wiki/ReleaseNotes
https://kubernetes.io/docs/setup/release/version-skew-policy/
https://docs.docker.com/engine/release-notes/
https://kubernetes.io/docs/setup/release/version-skew-policy/
https://wksctl.readthedocs.io/en/stable/get-started.html
https://hub.docker.com/r/weaveworks/ignite-centos/tags
https://wksctl.readthedocs.io/en/stable/index.html
