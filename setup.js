import * as param from '@jkcfg/std/param'
import * as std from '@jkcfg/std'

const config = param.all();
let output = [];

const numNodes = config => config.cluster.controlPlane.nodes + config.cluster.workers.nodes;

const backend = {
  docker: {
    image: config.images.footloose,
    // The below is required for dockerd to run smoothly.
    // See also: https://github.com/weaveworks/footloose#running-dockerd-in-container-machines
    privileged: true,
    volumes: [{
      type: 'volume',
      destination: '/var/lib/docker',
    }]
  },
  ignite: {
    image: config.images.ignite,
    ignite: {
      cpus: config.cluster.cpus,
      memory: config.cluster.memory,
      diskSize: config.cluster.diskSize,
      kernel: config.images.kernel,
    }, 
    privileged: false,
    volumes: [],
  },
};

const image = config => backend[config.backend].image;
const privileged = config => backend[config.backend].privileged;
const volumes = config => backend[config.backend].volumes;
const ignite = config => backend[config.backend].ignite;

const footloose = config => ({
  cluster: {
    name: config.cluster.name,
    privateKey: 'cluster-key',
  },
  machines: [{
    count: numNodes(config),
    spec: {
      name: 'node%d',
      image: image(config),
      backend: config.backend,
      ignite: ignite(config),
      portMappings: [{
        containerPort: 22,
        hostPort: 2222,
      }, {
        containerPort: 6443,
        hostPort: 6443,
      }, {
        containerPort: 30443,
        hostPort: 30443,
      }, {
        containerPort: 30080,
        hostPort: 30080,
      }],
      privileged: privileged(config),
      volumes: volumes(config),
    },
  }],
});

output.push({ path: 'footloose.yaml', value: footloose(config) });

// List is a Kubernetes list.
const List = items => ({
  apiVersion: "v1",
  kind: "List",
  items
});

// Machine returns a WKS machine description from a configuration object describing its public IP, private IP, id, and its role.
const Machine = ({ id, privateIP, sshPort, role }) => ({
  apiVersion: 'cluster.k8s.io/v1alpha1',
  kind: 'Machine',
  metadata: {
    labels: {
      set: role,
    },
    name: `${role}-${id}`,
    namespace: config.cluster.namespace
  },
  spec: {
    providerSpec: {
      value: {
        apiVersion: 'baremetalproviderspec/v1alpha1',
        kind: 'BareMetalMachineProviderSpec',
        public: {
          address: '127.0.0.1',
          port: sshPort,
        },
        private: {
          address: privateIP,
          port: 22,
        }
      }
    },
    versions: {
      kubelet: config.versions.kubelet
    }
  }
});

const sshPort = machine => machine.ports.find(p => p.guest == 22).host;

if (config.machines !== undefined) {
  const machines = [];

  for (let i = 0; i < config.cluster.controlPlane.nodes; i++ ) {
    const machine = config.machines[i];
    machines.push(Machine({
      id: i,
      privateIP: machine.runtimeNetworks[0].ip,
      sshPort: sshPort(machine),
      role: 'master',
    }));
  } 

  for (let i = 0; i < config.cluster.workers.nodes; i++ ) {
    const machine = config.machines[config.cluster.controlPlane.nodes + i];
    machines.push(Machine({
      id: i,
      privateIP: machine.runtimeNetworks[0].ip,
      sshPort: sshPort(machine),
      role: 'worker',
    }));
  }

  output.push({ path: 'machines.yaml', value: List(machines) });
}

export default output;
