#!/bin/bash
# Recursos que continuam cobrando depois de um destroy.
# Uso:  bash scripts/check-orphans.sh
# Saida vazia em todas as secoes = nada esta sendo cobrado.

echo "== Load balancers (criados pelo K8s, invisiveis ao Terraform) =="
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].LoadBalancerName' --output text
aws elb describe-load-balancers \
  --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text

echo "== NAT gateways (US\$ 1,08/dia cada) =="
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[].NatGatewayId' --output text

echo "== Elastic IPs soltos (cobrados quando NAO estao em uso) =="
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].PublicIp' --output text

echo "== Volumes EBS orfaos =="
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].[VolumeId,Size]' --output text

echo "== Instancias RDS ainda vivas =="
aws rds describe-db-instances \
  --query 'DBInstances[].DBInstanceIdentifier' --output text

echo "== Clusters EKS ainda vivos (US\$ 2,40/dia cada) =="
aws eks list-clusters --query 'clusters' --output text

echo "== Instancias EC2 rodando =="
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text

echo
echo "Se tudo acima veio vazio, nada esta sendo cobrado."
