#!/bin/bash
sudo snap install microk8s --classic --channel=1.21/stable
microk8s status
sudo usermod -a -G microk8s ubuntu
sudo chown -f -R ubuntu ~/.kube
newgrp microk8s

microk8s status
microk8s enable dns storage ingress metallb:10.64.140.43-10.64.140.49
microk8s status --wait-ready
alias kubectl=’microk8s kubectl’
kubectl get po -A
microk8s status
sudo snap install juju --classic --channel=2.9/stable

kubectl get po -A
juju models
juju controllers

microk8s config > ~/.kube/config
juju add-k8s myk8s
juju clouds
juju bootstrap myk8s myctlr
kubectl get po -A
juju add-model kubeflow
juju models
juju status
juju deploy kubeflow --trust

kubectl get po -A
juju config dex-auth static-username
juju config dex-auth static-password
juju config dex-auth static-username=admin
juju config dex-auth static-password=mypassword
kubectl get services -n kubeflow

wget https://archive.apache.org/dist/spark/spark-3.1.2/spark-3.1.2-bin-hadoop3.2.tgz
https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz
tar xzf spark-3.5.1-bin-hadoop3.tgz
cd spark-3.5.1-bin-hadoop3

echo > Dockerfile <<EOF
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
FROM ubuntu:23.10

ARG spark_uid=185

# Before building the docker image, first build and make a Spark distribution following
# the instructions in http://spark.apache.org/docs/latest/building-spark.html.
# If this docker file is being used in the context of building your images from a Spark
# distribution, the docker build command should be invoked from the top level directory
# of the Spark distribution. E.g.:
# docker build -t spark:latest -f kubernetes/dockerfiles/spark/Dockerfile .
ENV DEBIAN_FRONTEND noninteractive

RUN set -ex && \
    sed -i 's/http:\/\/deb.\(.*\)/https:\/\/deb.\1/g' /etc/apt/sources.list && \
    apt-get update && \
    ln -s /lib /lib64 && \
    apt install -y python3 python3-pip openjdk-11-jre-headless bash tini libc6 libpam-modules krb5-user libnss3 procps && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/examples && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    rm -rf /var/cache/apt/*

COPY jars /opt/spark/jars
COPY bin /opt/spark/bin
COPY sbin /opt/spark/sbin
COPY kubernetes/dockerfiles/spark/entrypoint.sh /opt/
COPY kubernetes/dockerfiles/spark/decom.sh /opt/
COPY examples /opt/spark/examples
COPY kubernetes/tests /opt/spark/tests
COPY data /opt/spark/data

RUN pip install pyspark
RUN pip install findspark

ENV SPARK_HOME /opt/spark

WORKDIR /opt/spark/work-dir
RUN chmod g+w /opt/spark/work-dir
RUN chmod a+x /opt/decom.sh

ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Specify the User that the actual main process will run as
USER ${spark_uid}
EOF
sudo docker build . --no-cache -t localhost:32000/spark-on-uk8s-on-core-23:1.0

sudo docker push localhost:32000/spark-on-uk8s-on-core-23:1.0

sudo microk8s.kubectl run --port 6060 \
--port 37371 --port 8888 --image=ubuntu:23.10 jupyter -- \
bash -c "apt update && DEBIAN_FRONTEND=noninteractive apt install python3-pip wget openjdk-11-jre-headless -y && pip3 install jupyter && pip3 install pyspark && pip3 install findspark && wget https://archive.apache.org/dist/spark/spark-3.1.2/spark-3.1.2-bin-hadoop3.2.tgz && tar xzf spark-3.1.2-bin-hadoop3.2.tgz && jupyter notebook --allow-root --ip '0.0.0.0' --port 8888 --NotebookApp.token='' --NotebookApp.password=''"
sudo microk8s.kubectl cp /var/snap/microk8s/current/certs/ca.crt jupyter:.
sudo microk8s.kubectl expose pod jupyter --type=NodePort --name=jupyter-ext --port=8888
sudo microk8s.kubectl expose pod jupyter --type=ClusterIP --name=jupyter --port=37371,6060

echo > configure_spark.py <<EOF
import os
os.environ["SPARK_HOME"] = "/spark-3.5.1-bin-hadoop3"

import pyspark
import findspark
from pyspark import SparkContext, SparkConf
findspark.init()

conf = SparkConf().setAppName('spark-on-uk8s-on-core-23').setMaster('k8s://https://0.0.0.0.default.svc')
conf.set("spark.kubernetes.container.image", "localhost:32000/spark-on-uk8s-on-core-23:1.0")
conf.set("spark.kubernetes.allocation.batch.size", "50")
conf.set("spark.io.encryption.enabled", "true")
conf.set("spark.authenticate", "true")
conf.set("spark.network.crypto.enabled", "true")
conf.set("spark.executor.instances", "5")
conf.set('spark.kubernetes.authenticate.driver.caCertFile', '/ca.crt')
conf.set("spark.driver.host", "jupyter")
conf.set("spark.driver.port", "37371")
conf.set("spark.blockManager.port", "6060")

sc = SparkContext(conf=conf)
print(sc)

big_list = range(100000000000000)
rdd = sc.parallelize(big_list, 5)
odds = rdd.filter(lambda x: x % 2 != 0)
odds.take(20)
EOF
python3 configure_spark.py
