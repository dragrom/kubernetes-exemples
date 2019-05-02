# Local Kubernetes cluster using Vagrant and VirtualBox

Create a local Kubernetes cluster, with one master and 2 nodes

## How to use this cluster

- Clone this repository on your machine:

```
https://github.com/dragrom/kubernetes-exemples.git
```

- Install all dependiences
- Start the cluster
- Play with it
- Destroy the cluster, to save the resources


## Dependencies

You should install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads.html) before you start.

## Creating the cluster

You should create a `Vagrantfile` in an empty directory with the following content:

```servers = [
    {
        :name => "master",
        :type => "master",
        :box => "ubuntu/xenial64",
        :eth1 => "192.168.2.10",
        :mem => "1024",
        :cpu => "2"
    },
    {
        :name => "node1",
        :type => "node",
        :box => "ubuntu/xenial64",
        :eth1 => "192.168.2.11",
        :mem => "1024",
        :cpu => "2"
    },
    {
        :name => "node2",
        :type => "node",
        :box => "ubuntu/xenial64",
        :eth1 => "192.168.2.12",
        :mem => "1024",
        :cpu => "2"
    }
]

# This script to install k8s using kubeadm will get executed after a box is provisioned
$configureBox = <<-SCRIPT
    # surpress dpkg-preconfigure: unable to re-open stdin: No such file or directory warning
    export DEBIAN_FRONTEND=noninteractive

    # install docker
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
    apt-get update && apt-get install -y docker-ce
    # run docker commands as vagrant user (sudo not required)
    usermod -aG docker vagrant

    # install kubeadm
    apt-get install -y apt-transport-https curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
    deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    # kubelet requires swap off
    swapoff -a

    echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    # keep swap off after reboot
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # ip of this box
    IP_ADDR=`ifconfig enp0s8 | grep Mask | awk '{print $2}'| cut -f2 -d:`
    # set node-ip
    sudo echo 'Environment="KUBELET_EXTRA_ARGS=--node-ip=$IP_ADDR' | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
SCRIPT

$configureMaster = <<-SCRIPT
    echo "This is master"
    # ip of this box
    IP_ADDR=`ifconfig enp0s8 | grep Mask | awk '{print $2}'| cut -f2 -d:`

    # install kkubernetes master
    HOST_NAME=$(hostname -s)
    sudo kubeadm init --apiserver-advertise-address=$IP_ADDR --apiserver-cert-extra-sans=$IP_ADDR --node-name $HOST_NAME --pod-network-cidr=192.168.0.0/16

    #copying credentials to regular user - vagrant
    sudo --user=vagrant mkdir -p /home/vagrant/.kube
    cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
    
    # Configure flannel. Run command as vagrant user
    su - vagrant -c "kubectl create -f /vagrant/pod-networks/kube-flannel.yml"

    sudo systemctl daemon-reload
    sudo systemctl restart kubelet

    kubeadm token create --print-join-command >> /etc/kubeadm_join_cmd.sh
    chmod +x /etc/kubeadm_join_cmd.sh

    # required for setting up password less ssh between guest VMs
    sudo sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
    sudo service sshd restart
SCRIPT

$configureNode = <<-SCRIPT
    echo "This is worker"
    apt-get install -y sshpass
    sshpass -p "vagrant" scp -o StrictHostKeyChecking=no vagrant@192.168.2.10:/etc/kubeadm_join_cmd.sh .
    sh ./kubeadm_join_cmd.sh
SCRIPT

Vagrant.configure("2") do |config|

    servers.each do |opts|
        config.vm.define opts[:name] do |config|

            config.vm.box = opts[:box]
            config.vm.hostname = opts[:name]
            config.vm.network :private_network, ip: opts[:eth1]

            config.vm.provider "virtualbox" do |v|

                v.name = opts[:name]
            	v.customize ["modifyvm", :id, "--memory", opts[:mem]]
                v.customize ["modifyvm", :id, "--cpus", opts[:cpu]]

            end

            config.vm.provision "shell", inline: $configureBox

            if opts[:type] == "master"
                config.vm.provision "shell", inline: $configureMaster
            else
                config.vm.provision "shell", inline: $configureNode
            end

        end

    end

end  
```

## Starting the cluster

You can create the cluster with:

```bash
$ vagrant up
```

## Clean up

You can delete the cluster with:

```bash
 vagrant destroy -f
```

# Playing with kubernetes

After the cluster is up, you can start to play with kubernetes.
To access the master server, run:

```
vagrant ssh master
```

To access a node, run:

```
vagrant ssh <nodename>
```

## List the available node in cluster

```
kubectl get nodes -o wide
```

## Create namespaces

```
kubectl create -f /vagrant/exemples/create_namespaces.yaml
```

The ```dev``` and ```prod``` namespaces will be created

## Create a deployment

```
kubectl create -f /vagrant/exemples/deployment.yaml
```
A deployment called web-deployment will be created in dev namespace

To list the pods created by the deployment, run:

```
kubectl -n dev get pods
``` 

To vuew the list of deployments created in dev namespace, run:

```
kubectl -n dev get deployments
```

## Create a service to expose the deployment

```
kubectl create -f /vagrant/exemples/service.yaml
```

This command will create a service called web-service, in dev namespace.
To view the services created in dev namespace, run:

```
kubectl get svc -n dev
```


