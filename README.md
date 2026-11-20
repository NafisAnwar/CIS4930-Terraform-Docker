# Terraform and Docker: Persistent Application Database

CIS4930 - Computing Tools for Workforce

Author: Nafis Anwar

## Project Overview

This project implements Option 2: Persistent Application Database.

The infrastructure consists of a Flask web application and a Redis database
managed through Terraform using the Docker provider. Both containers
communicate through a shared Docker network, while Redis uses persistent
storage to retain application data across container replacement.

The project demonstrates Infrastructure as Code, container networking,
database persistence, and automated infrastructure recovery.

## Prerequisites

- Docker Engine or Docker Desktop
- Terraform 1.5.2 or newer
- Bash, Python 3, and curl

## Deployment

```bash
cd terraform
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

The application is accessible at http://127.0.0.1:8081.

## Verification

From the repository root:

```bash
docker ps
docker network inspect cis4930-assignment5-net
docker volume inspect cis4930-assignment5-redis-data
bash scripts/verify.sh verify
```

## Database Recovery

```bash
bash scripts/verify.sh recover
```

The recovery test removes and recreates the Redis container through
Terraform and verifies that the original visit counter is preserved.

## Infrastructure Cleanup

```bash
cd terraform
terraform plan
terraform destroy
```

The plan should report no changes before destruction. Destroying
the named volume permanently removes the stored counter data.
