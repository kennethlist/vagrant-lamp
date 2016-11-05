# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = "ubuntu/trusty64"
    config.vm.network "forwarded_port", guest: 80, host: 8888 # Apache
    config.vm.network "forwarded_port", guest: 3306, host: 8889 # MySQL
    config.vm.network "forwarded_port", guest: 8025, host: 8025 # Mailhog
    config.vm.provision "shell", path: "provision.sh"
    # config.vm.network "private_network", ip: "192.168.3.4"
end
