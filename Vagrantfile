# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"

  config.vm.provision "shell", inline: <<-SHELL
    sudo /vagrant/bootstrap.sh
    sudo usermod -a -G mock vagrant
  SHELL
end
