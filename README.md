aws-multi-account
=================

An example of cross account CI/CD pipelines in AWS. 

You will need Terraform 0.12+ as well as several AWS accounts.


User Account:	mhc-admin       978911729932
CI/CD Account:	mhc-cicd        255013836461
App Account:	*APP*dev
App Account:	*APP*test
App Account:	*APP*prod

In AWS CLI, create a "default" account for your IAM user in mhc-home
and "cicd_root" for the root user of mhc-cicd.

Each account must have an admin role called *ACCOUNT-NAME*_Admin.

Create the required backend S3 bucket and DynamodDB table by running
the CloudFormation.
