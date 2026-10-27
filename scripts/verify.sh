#!/bin/bash
# bash verify.sh
echo "── VPC ──"
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=ToggleMaster" \
  --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock}' --output table

echo "── EKS ──"
aws eks list-clusters --output table

echo "── RDS (expect 3) ──"
aws rds describe-db-instances \
  --query 'DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}' --output table

echo "── ElastiCache ──"
aws elasticache describe-cache-clusters --output table \
  --query 'CacheClusters[].{ID:CacheClusterId,Status:CacheClusterStatus}'

echo "── DynamoDB ──"
aws dynamodb list-tables --output table

echo "── SQS ──"
aws sqs list-queues --output table

echo "── ECR (expect 5) ──"
aws ecr describe-repositories \
  --query 'repositories[].repositoryName' --output table