# Copyright 2017, 2018 RockNSM
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"

  config.vm.provider :libvirt do |libvirt|
      libvirt.host = "192.168.73.5"
      libvirt.connect_via_ssh = true
      libvirt.username = "dcode"
      libvirt.memory = 2048
      libvirt.cpus = 2
  end
 
  config.vm.provision "shell", inline: <<-SHELL
    sudo yum clean all
    sudo yum makecache fast
    sudo /vagrant/bootstrap.sh
    sudo usermod -a -G mock vagrant
  SHELL
end
