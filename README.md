# Firekube

Firekube is a Kubernetes cluster working on top of [ignite][gh-ignite] and
[firecracker][gh-firecracker]. Firekube clusters are operated with
[GitOps][ww-gitops].

[ignite][gh-ignite] and [firecracker][gh-firecracker] only work on Linux as
they need [KVM][kvm]. Fortunately we also offer a mode where the Kubernetes
nodes are running inside containers which will on both Linux and macOS.

## Creating a Firekube cluster

1. Fork this repository.

1. Clone your fork and `cd` into it. Use the `https` git URL as it doesn't
need authentication:

   ```console
   git clone https://github.com/$user/wks-quickstart-firekube.git
   cd wks-quickstart-firekube
   ```

1. (optional) If you are on macOS or want to use docker containers instead of [firecracker][gh-firecracker] virtual machines, change the backend to `docker` in `config.yaml`:

   ```console
   # Change backend: ignite to backend: docker in config.yaml
   vim config.yaml
   git add config.yaml
   git commit -m "Change backend to docker"
   ```

1. Start the cluster:

   ```console
   cd wks-quickstart-firekube
   ./setup.sh
   ```

   This step will take several minutes.

1. Export the `KUBECONFIG` environment variable as indicated at the end of the installation:

   ```console
   export KUBECONFIG=/home/damien/.wks/weavek8sops/example/kubeconfig
   ```

Enjoy your Kubernetes cluster!

   ```console
   $ kubectl get nodes
   NAME               STATUS   ROLES    AGE     VERSION
   67bb6c4812b19ce4   Ready    master   3m42s   v1.14.1
   a5cf619fa058882d   Ready    <none>   75s     v1.14.1
   ```

[gh-ignite]: https://github.com/weaveworks/ignite
[gh-firecracker]: https://github.com/firecracker-microvm/firecracker
[kvm]: https://en.wikipedia.org/wiki/Kernel-based_Virtual_Machine
[ww-gitops]: https://www.weave.works/technologies/gitops/

## Deleting a Firekube cluster

Run:

```console
./cleanup.sh
```

## Using a private git repository with firekube

To use a private git repository instead of a fork of `wks-quickstart-firekube`:

1. Create a private repository and push the `wks-quickstart-firekube`
   `master` branch there. Use the SSH git URL when cloning the private
   repository:

   ```
   git clone git@github.com:$user/$repository.git
   cd $repository
   git remote add quickstart git@github.com:weaveworks/wks-quickstart-firekube.git
   git fetch quickstart
   git merge quickstart/master
   git push
   ```

1. Create an SSH key pair:

   ```console
   ssh-keygen -t rsa -b 4096 -C "damien+firekube@weave.works" -f deploy-firekube  -N ""
   ```

1. Upload the deploy key to your private repository (with read/write access):

   ![deploy key upload](docs/deploy-key.png)

1. Start the cluster:

   ```console
   ./setup.sh --git-deploy-key  ./deploy-firekube
   ```

## Getting Help

If you have any questions about, feedback for or problems with `wksctl`:

- Invite yourself to the <a href="https://slack.weave.works/" target="_blank">Weave Users Slack</a>.
- Ask a question on the [#general](https://weave-community.slack.com/messages/general/) slack channel.
- [File an issue](https://github.com/weaveworks/wks-quickstart-firekube/issues/new).

Your feedback is always welcome!

## License

[Apache 2.0](LICENSE)
