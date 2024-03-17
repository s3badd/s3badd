#!/bin/bash
spark-submit \
    --master k8s://https://0.0.0.0.default.svc.cluster.local:16443 \
    --deploy-mode cluster \
    --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
    --conf spark.kubernetes.authenticate.caCertFile=/var/snap/microk8s/current/certs/ca.crt \
    --conf spark.kubernetes.authenticate.submission.oauthToken=$K8S_TOKEN \
    --conf spark.kubernetes.container.image=spark-rapids \
