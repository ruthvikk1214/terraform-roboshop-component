#!/bin/bash
component=$1

dnf install ansible -y
ansible-galaxy collection install amazon.aws

cd /home/ec2-user

rm -rf roboshop-ansible-roles-tf
git clone https://github.com/ruthvikk1214/roboshop-ansible-roles-tf.git

cd roboshop-ansible-roles-tf
cd ansible-roboshop-roles-tf/

ansible-playbook -e "component=$component env=dev" roboshop.yaml