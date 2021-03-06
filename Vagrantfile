servers = [
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
    apt-get install -y apt-transport-https curl ebtables ethtool
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

    # echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
    # sudo sysctl -p
    # bridged traffic to iptables is enabled for kube-router.
    cat >> /etc/ufw/sysctl.conf <<EOF
    net/bridge/bridge-nf-call-ip6tables = 1
    net/bridge/bridge-nf-call-iptables = 1
    net/bridge/bridge-nf-call-arptables = 1
EOF
    sudo sysctl -p

    apt-get update
    apt-get install -y kubelet=1.13.11-00 kubeadm=1.13.11-00 kubectl=1.13.11-00
    apt-mark hold kubelet kubeadm kubectl

    # kubelet requires swap off
    swapoff -a

    # keep swap off after reboot
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # ip of this box
    IP_ADDR=`ifconfig enp0s8 | grep Mask | awk '{print $2}'| cut -f2 -d:`
    
    # set node-ip
    sudo echo Environment="KUBELET_EXTRA_ARGS=--node-ip=$IP_ADDR" | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet

    # Install multicast
    apt-get -qq install -y avahi-daemon libnss-mdns
SCRIPT

$configureMaster = <<-SCRIPT
    echo "This is master"
    # ip of this box
    IP_ADDR=`ifconfig enp0s8 | grep Mask | awk '{print $2}'| cut -f2 -d:`

    # install kkubernetes master
    HOST_NAME=$(hostname -s)
    sudo kubeadm init --apiserver-advertise-address=$IP_ADDR --pod-network-cidr=10.244.0.0/16

    #copying credentials to regular user - vagrant
    sudo --user=vagrant mkdir -p /home/vagrant/.kube
    cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
    
    # Configure flannel. Run command as vagrant user
    su - vagrant -c "kubectl apply -f /vagrant/pod-networks/kube-flannel.yml"

    # Need by metrics server
    sed -i "s/    - kube-controller-manager/    - kube-controller-manager \\n    - --horizontal-pod-autoscaler-use-rest-clients=true /g" /etc/kubernetes/manifests/kube-controller-manager.yaml

    sudo systemctl daemon-reload
    sudo systemctl restart kubelet

    kubeadm token create --print-join-command >> /etc/kubeadm_join_cmd.sh
    chmod +x /etc/kubeadm_join_cmd.sh

    # Install metrics server
    su - vagrant -c "kubectl create -f /vagrant/metrics-server/deploy/1.8+/"

    # Install dashboard
    su - vagrant -c "kubectl apply -f /vagrant/dashboard/"

    # required for setting up password less ssh between guest VMs
    sudo sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
    sudo service sshd restart    
SCRIPT

$configureNode = <<-SCRIPT
    echo "This is worker"
    apt-get install -y sshpass
    sshpass -p "vagrant" scp -o StrictHostKeyChecking=no vagrant@192.168.2.10:/etc/kubeadm_join_cmd.sh .
    sh ./kubeadm_join_cmd.sh
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
SCRIPT

Vagrant.configure("2") do |config|
    config.vm.synced_folder "~/volumes/", "/mnt/volumes",
        mount_options: ["dmode=777,fmode=777"]

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
