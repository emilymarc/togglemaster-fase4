#!/usr/bin/env bash
# Roda no Git Bash com gh CLI instalado e autenticado (gh auth login).
# Execute TODA VEZ que renovar as credenciais do Academy.
# Uso: bash scripts/set-github-secrets.sh

set -euo pipefail

REPO="emilymarc/togglemaster-fase4"
ENVIRONMENT="aws academy"   # environment do GitHub usado pelo job docker-build-push

echo "Lendo credenciais via aws configure get ..."
KEY_ID=$(aws configure get aws_access_key_id)
SECRET=$(aws configure get aws_secret_access_key)
TOKEN=$(aws configure get aws_session_token)

if [[ -z "$KEY_ID" || -z "$SECRET" || -z "$TOKEN" ]]; then
  echo "ERRO: credenciais nao encontradas."
  echo "Confirme que copiou o bloco 'AWS CLI' do painel do Academy para ~/.aws/credentials"
  exit 1
fi

gh secret set AWS_ACCESS_KEY_ID     --body "$KEY_ID" --repo "$REPO" --env "$ENVIRONMENT"
gh secret set AWS_SECRET_ACCESS_KEY --body "$SECRET" --repo "$REPO" --env "$ENVIRONMENT"
gh secret set AWS_SESSION_TOKEN     --body "$TOKEN"  --repo "$REPO" --env "$ENVIRONMENT"

echo ""
echo "Secrets atualizados em $REPO (environment: $ENVIRONMENT)"
echo "Lembre de rodar este script toda vez que o Academy renovar as credenciais (~4h)."
