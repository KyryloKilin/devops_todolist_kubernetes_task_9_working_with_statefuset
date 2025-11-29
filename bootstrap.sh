#!/usr/bin/env bash
set -e

# 1. Создаём кластер kind из cluster.yml (если уже есть — просто выводим сообщение)
if ! kind get clusters | grep -q "^todoapp$"; then
  kind create cluster --name todoapp --config cluster.yml
else
  echo "kind cluster 'todoapp' already exists, skipping creation"
fi

# 2. Применяем все манифесты в правильном порядке

# Namespaces
kubectl apply -f .infrastructure/namespace.yml

# ConfigMaps и Secrets
kubectl apply -f .infrastructure/configMap.yml
kubectl apply -f .infrastructure/secret.yml

# MySQL StatefulSet и headless service
kubectl apply -f .infrastructure/statefulset.yml
kubectl apply -f .infrastructure/mysql-service.yml

# Django app: Deployment + сервисы + HPA
kubectl apply -f .infrastructure/deployment.yml
kubectl apply -f .infrastructure/clusterIp.yml
kubectl apply -f .infrastructure/nodeport.yml
kubectl apply -f .infrastructure/hpa.yml
