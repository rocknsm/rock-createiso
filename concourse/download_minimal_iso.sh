#!/bin/bash -xeu
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

# mkdir
mkdir -p centos-minimal-iso

# download ISO
curl -L http://mirrors.usinternet.com/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1804.iso -o centos-minimal-iso/centos-minimal.iso
