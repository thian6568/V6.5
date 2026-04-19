# Artist In Art — Project Brief (infra-deployment)

## Purpose
`infra-deployment` defines secure, cost-aware cloud deployment for all modules.

## Stack
- AWS (Singapore default target)
- Portable architecture for possible later approved hosting migration
- IaC (Terraform or CDK)
- CloudFront + S3 + ALB/ECS or Lambda
- Managed Postgres/Supabase connectivity
- CloudWatch + backups + alerts

## Scope
- Staging and production topology
- Network, storage, CDN, observability, backups
- Deployment pipelines and rollback strategy
