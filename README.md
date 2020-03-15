aws-multi-account
=================

An example of cross account CI/CD pipelines in AWS. 

You will need Terraform 0.12+ as well as several AWS accounts.

| Account Type | Alias     | Account ID   |
|--------------|:----------|:-------------|
| Governance   | mhc-admin | 978911729932 |
| CI/CD        | mhc-cicd  | 255013836461 |
| SDLC dev     | *APP*dev  | 008062881613 |
| SDLC test    | *APP*test | |
| SDLC prod    | *APP*prod | |

You will have one account for governance that contains all your IAM
users as well as your Terraform state.

You will have one other account that contains all your CI/CD infrastructure.

Finally, you will have a series of accounts, one per stage in your
SDLC, where the account aliases are a common prefix followed the SDLC
stage name. My SDLC stage names are dev, test and prod. 

In AWS CLI, create a "default" account for your IAM user in mhc-home
and "cicd_root" for the root user of mhc-cicd.

Each account must have an admin role called *ACCOUNT-NAME*_Admin.

Create the required backend S3 bucket and DynamodDB table by running
the CloudFormation. 

In each account create a role called *ALIAS*_admin.

Terraform workspace - create before starting.

 - `terraform workspace new gollum`

CloudFormation Conversion Status
--------------------------------

 CloudFormation           | Status
:-------------------------|:------
api-gateway.yml           | Not needed for the demo application
app-XXX-vis-api.yml       | Done
app-XXX-dash.yml          | Done
app-XXX-data-api.yml      | Done
app-XXX-static-content.yml | Not wanted
--------------------------|-----------------------------
app-adminer.yml           | Not wanted
app-egress.yml            | Not needed for the demo application
app-ingress.yml           | Not needed for the demo application
XXX-dash-search-log.yml   | Not needed for the demo application
check-ingress-files.yml   | Not needed for the demo application
--------------------------|-----------------------------
application-pipeline.yml  | Converted into "cicd" module
application-repos.yml     | Done
cloudtrail-athena.yml     | Todo
cloudtrailbucket.yml      | Todo
cloudtrail.yml            | For reference
codebuild-ecs-build.yml   | Done
codebuild-ecs-deploy.yml  | Needs to be merged into "cicd" module
codecommit-repo.yml       | Done
ecr-repo.yml              | Done
ecs.yml                   | Done
environment.yml           | Done
r53-app-alias.yml         | Todo
r53-zone.yml              | Todo
rds.yml                   | Not needed for the demo application
vpc.yml                   | Done
