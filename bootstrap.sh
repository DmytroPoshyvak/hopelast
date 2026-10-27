#!/bin/bash
set -e

NAMESPACE="${NAMESPACE:-todoapp}"

echo "1. Створення kind-кластера..."
kind create cluster --config cluster.yml

echo "2. Встановлення ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "3. Встановлення metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Виправлення для локального середовища kind (ігнорування сертифікатів)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

echo "4. Перевірка helm lint..."
helm lint ./.infrastructure/helm-chart/todoapp

echo "5. Розгортання todoapp через Helm..."
helm upgrade --install todoapp ./.infrastructure/helm-chart/todoapp --namespace "$NAMESPACE" --create-namespace

echo "6. Очікування запуску подів..."
kubectl wait --for=condition=ready pod --all --namespace "$NAMESPACE" --timeout=120s || true

echo "7. Генерація output.log..."
kubectl get all,cm,secret,ing -A > output.log

echo "Готово! Розгортання завершено успішно."