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
