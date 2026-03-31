# ─────────────────────────────────────────────────────────────────────────────
# Pre-requisite GitHub Actions Role
# ─────────────────────────────────────────────────────────────────────────────
# The OIDC Provider and the IAM role `github-actions-deploy-role` are managed 
# manually in the AWS Console to bootstrap the deployment pipeline.
# 
# Terraform should not attempt to recreate these bootstrapping resources.
