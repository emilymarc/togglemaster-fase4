#!/bin/bash

VERSAO="v3.5.6"   # troque pela versão que o comando curl mostrou

# 1. Cria o namespace do ArgoCD
kubectl create namespace argocd

# 2. Instala o ArgoCD na versão escolhida
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$VERSAO/manifests/install.yaml

# 3. Espera o ArgoCD ficar pronto (até 5 minutos)
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 4. Aplica a root app; ela cria todas as outras Applications
kubectl apply -f gitops/root-app.yaml