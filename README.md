# NetSPI_test

I have completed the test provided by NetSPI. 

## Overview

In this project, I have created a Terraform configuration file named `project.tf`, where I wrote the necessary Terraform code to provision the required AWS resources as specified in the assignment.

## Key Implementations

- **Terraform Code**: The `project.tf` file contains the Terraform code for provisioning:
  - An S3 bucket with private access permissions.
  - An EFS volume.
  - An EC2 instance (named **NetSPI_EC2**) with SSH access.
  - All required resources such as VPC, Subnets, Security Groups, etc.

- **Elastic IP**: I provisioned an Elastic IP and assigned it to the EC2 instance for public access.

- **SSH Key**: I created an SSH key named **NetSPI_Key**. This key will be used to SSH into the newly created EC2 instance.

## Instructions

To access the EC2 instance via SSH, use the following command:

```bash
ssh -i NetSPI_Key.pem ec2-user@<Elastic_IP_Address>
