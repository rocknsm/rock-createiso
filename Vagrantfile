# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/centos-7.3"

  config.vm.provision "shell", inline: <<-SHELL
    sudo /vagrant/bootstrap.sh
    sudo usermod -a -G mock vagrant
  SHELL
end
