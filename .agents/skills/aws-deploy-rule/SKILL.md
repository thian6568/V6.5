# Skill: aws-deploy-rule

Default deployment target:
- AWS Singapore

Required environments:
- staging
- production

Deployment must include:
- storage
- CDN
- logs
- backups
- monitoring

Safety rules:
- apply cost-sensitive defaults
- avoid exposing production secrets in prompts or repo

Flexibility rule:
- keep deployment architecture portable enough to support a later move to another approved hosting provider if needed
