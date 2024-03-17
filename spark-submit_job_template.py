export SPARK_HOME=~/spark
export IMAGE_NAME=xxx/yyy:tag
export K8SMASTER=k8s://https://<k8s-apiserver-host>:<k8s-apiserver-port>
export SPARK_NAMESPACE=default
export SPARK_DRIVER_NAME=exampledriver

$SPARK_HOME/bin/spark-submit \
     --master $K8SMASTER \
     --deploy-mode cluster  \
     --name examplejob \
     --class org.apache.spark.examples.SparkPi \
     --conf spark.executor.instances=1 \
     --conf spark.executor.resource.gpu.amount=1 \
     --conf spark.executor.memory=4G \
     --conf spark.executor.cores=1 \
     --conf spark.task.cpus=1 \
     --conf spark.task.resource.gpu.amount=1 \
     --conf spark.rapids.memory.pinnedPool.size=2G \
     --conf spark.executor.memoryOverhead=3G \
     --conf spark.sql.files.maxPartitionBytes=512m \
     --conf spark.sql.shuffle.partitions=10 \
     --conf spark.plugins=com.nvidia.spark.SQLPlugin \
     --conf spark.kubernetes.namespace=$SPARK_NAMESPACE  \
     --conf spark.kubernetes.driver.pod.name=$SPARK_DRIVER_NAME  \
     --conf spark.executor.resource.gpu.discoveryScript=/opt/sparkRapidsPlugin/getGpusResources.sh \
     --conf spark.executor.resource.gpu.vendor=nvidia.com \
     --conf spark.kubernetes.container.image=$IMAGE_NAME \
     --conf spark.executor.extraClassPath=/opt/sparkRapidsPlugin/rapids-4-spark_<version>.jar \
     --conf spark.driver.extraClassPath=/opt/sparkRapidsPlugin/rapids-4-spark_<version>.jar \
     --driver-memory 2G \
     local:///opt/spark/examples/jars/spark-examples_2.12-3.0.2.jar
