# How to deploy and validate the Todo app with MySQL StatefulSet

This document explains how to:

- create a `kind` cluster from `cluster.yml`;
- deploy MySQL as a StatefulSet with persistent storage;
- deploy the Django Todo application;
- validate that everything works as required.

---

## 1. Create kind cluster

From the repository root:

```bash
kind create cluster --name todoapp --config cluster.yml

# Apply Kubernetes manifests
# Apply all manifests in the following order:
# 1. Namespaces
kubectl apply -f .infrastructure/namespace.yml

# 2. ConfigMaps and Secrets
kubectl apply -f .infrastructure/configMap.yml
kubectl apply -f .infrastructure/secret.yml

# 3. MySQL StatefulSet and headless Service
kubectl apply -f .infrastructure/statefulset.yml
kubectl apply -f .infrastructure/mysql-service.yml

# 4. Django Todo app: Deployment, Services and HPA
kubectl apply -f .infrastructure/deployment.yml
kubectl apply -f .infrastructure/clusterIp.yml
kubectl apply -f .infrastructure/nodeport.yml
kubectl apply -f .infrastructure/hpa.yml


# What each configuration is doing
# StatefulSet and headless Service
# statefulset.yml creates a StatefulSet named mysql in the mysql namespace with:
# 3 replicas;
# per-pod persistent volumes using volumeClaimTemplates;
# livenessProbe and readinessProbe on port 3306;
# initialization SQL mounted from mysql-init-config ConfigMap into /docker-entrypoint-initdb.d.
# mysql-service.yml is a headless service (clusterIP: None) used by the StatefulSet for stable DNS names:
# pods are reachable as mysql-0.mysql.mysql.svc.cluster.local, mysql-1.…, etc.
# 3.2 Secrets and ConfigMaps
# mysql-secret (namespace mysql) stores sensitive MySQL values:
# MYSQL_ROOT_PASSWORD, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE.
# app-db-secret (namespace todoapp) stores application DB connection data:
# NAME, USER, PASSWORD, HOST.
# app-config ConfigMap (namespace todoapp) provides the PYTHONUNBUFFERED setting.
# mysql-init-config ConfigMap (namespace mysql) provides init.sql that:
# creates the todoapp database;
# creates the todo_user account with password todo_password;
# grants access to the todoapp database.

# Todo application Deployment and Services
# deployment.yml creates a Deployment named todoapp in the todoapp namespace with:
# 2 replicas;
# resource requests and limits for CPU and memory;
# livenessProbe and readinessProbe hitting /api/health and /api/ready;
# environment variables for DB connection:
# DB_NAME, DB_USERNAME, DB_PASSWORD, DB_HOST –
# all taken from the app-db-secret Secret.
# clusterIp.yml exposes the app inside the cluster as todoapp-service on port 80 > 8080.
# nodeport.yml exposes the app outside the cluster as todoapp-nodeport on port 30007.
# hpa.yml configures the Horizontal Pod Autoscaler for the todoapp Deployment
# based on CPU and memory utilization.


# Validation steps
# Check that all resources are created
# Namespaces
kubectl get ns

# StatefulSet and MySQL pods
kubectl get statefulset -n mysql
kubectl get pods -n mysql -o wide
kubectl get pvc -n mysql

# Services
kubectl get svc -n mysql
kubectl get svc -n todoapp

# Deployment and HPA
kubectl get deploy -n todoapp
kubectl get hpa -n todoapp
kubectl get pods -n todoapp

# Connect to the first database pod (mysql-0):
kubectl exec -it mysql-0 -n mysql -- bash

# Inside the container:
mysql -u todo_user -p
# password: todo_password
SHOW DATABASES;
USE todoapp;
SHOW TABLES;
EXIT;
EXIT;

# Validate that the app uses the DB Secret
# Check environment variables in one of the Todo app pods:
POD_NAME=$(kubectl get pods -n todoapp -l app=todoapp -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD_NAME" -n todoapp | grep -A4 "DB_"

# Validate HTTP endpoints inside the cluster
# Use a temporary curl pod in the todoapp namespace:
kubectl run curl-pod --rm -i --tty --image=radial/busyboxplus:curl -n todoapp -- /bin/sh
# Inside the curl pod:
curl -s http://todoapp-service/api/health
curl -s http://todoapp-service/api/ready
exit

# Get the NodePort service:
kubectl get svc todoapp-nodeport -n todoapp

# Cleanup
kind delete cluster --name todoapp