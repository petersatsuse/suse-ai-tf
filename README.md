# Deploying SUSE AI Stack on AWS EC2 with Terraform

This project provides Terraform configurations to automate the deployment of the SUSE AI Stack on an Amazon Web Services (AWS) EC2 instance running SUSE Linux Enterprise Micro 6.1.

## Prerequisites

Before you begin, ensure you have the following:

* **AWS Account:** You need an active AWS account with appropriate permissions to create and manage EC2 instances, security groups, and other related resources.
* **Terraform:** Terraform version 1.0 or later installed on your local machine. You can find installation instructions on the [official Terraform website](https://www.terraform.io/downloads).
* **SUSE Customer Center Account:** A SUSE Customer Center (SCC) login with a current subscription for the following products is required:
    * Rancher Prime
    * SUSE AI
    * *(Optional)* SUSE Observability
* **SUSE Registration Code:** A valid and active registration code for registering the SLE Micro 6.1 instance obtained from the SUSE Customer Center.
* **AWS Credentials:** Your AWS credentials configured for Terraform to use. This can be done through environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) or an AWS CLI configuration profile.
* **SSH Key Pair:** *(Optional)* An existing EC2 key pair in your desired AWS region to allow SSH access to the deployed instance.

## Overview

This Terraform setup will perform the following actions:

1.  **Launch an EC2 Instance:** Provisions a new EC2 instance in your specified AWS region running the SLE Micro 6.1 AMI.
2.  **Register the System:** Automatically registers the EC2 instance with your SUSE Customer Center using the provided registration code.
3.  **Deploy RKE2:** Installs and configures RKE2, a lightweight Kubernetes distribution by Rancher, on the EC2 instance.
4.  **Deploy NVIDIA GPU Operator:** Installs the NVIDIA GPU Operator within the RKE2 cluster to manage NVIDIA GPU resources (assuming a GPU-enabled EC2 instance type is used).
5.  **Deploy SUSE AI Stack:** Deploys the core components of the SUSE AI Stack on the RKE2 cluster:
    * **Milvus:** A cloud-native vector database built for scalable similarity search and AI applications.
    * **Ollama:** A lightweight and extensible framework for running large language models (LLMs) locally.
    * **Open WebUI (formerly Chatbox):** A user-friendly web interface for interacting with LLMs served by Ollama.

## Getting Started

1.  **Clone the Repository:**
    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```

2.  **Configure Terraform Variables:**
    Create a `terraform.tfvars` file (or modify the `variables.tf` file) with your specific configuration:

    ```terraform
    aws_region = "your_aws_region"
    instance_type = "your_desired_instance_type" # e.g., "t3.medium" or a GPU instance like "g4dn.xlarge"
    ami = "your_sle_micro_6_1_ami_id" # Find the appropriate SLE Micro 6.1 AMI for your region
    key_name = "your_ec2_key_pair_name"
    scc_username = "your_suse_customer_center_username"
    scc_password = "your_suse_customer_center_password"
    registration_code = "your_suse_registration_code"
    admin_password = "your_rke2_server_admin_password" # Choose a strong password for the RKE2 admin user
    # Optional: Configure observability
    # observability_registration_code = "your_suse_observability_registration_code"
    ```

    **Note:** It is recommended to use a secure method for managing sensitive information like passwords and registration codes, such as using Terraform Cloud or a secrets manager.

3.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

4.  **Plan the Deployment:**
    ```bash
    terraform plan
    ```
    Review the output of the plan to ensure that the changes Terraform will apply are as expected.

5.  **Apply the Configuration:**
    ```bash
    terraform apply -auto-approve
    ```
    Terraform will now provision the EC2 instance and deploy the SUSE AI Stack. This process may take some time.

## Accessing the Deployed Services

Once the deployment is complete, you can access the deployed services as follows:

* **SSH to the EC2 Instance:**
    ```bash
    ssh -i "path/to/your/private_key.pem" ec2-user@<public_ip_of_your_instance>
    ```

* **Open WebUI:** You can access the Open WebUI interface through your web browser using the public IP address of your EC2 instance on port `8080`.
    ```
    http://<public_ip_of_your_instance>:8080
    ```

* **Milvus and Ollama:** These services are running as application pods within the RKE2 cluster. You can interact with them using their respective services. Please refer to the documentation for Milvus and Ollama for more details.

## Cleaning Up

To destroy the resources created by Terraform, run the following command:

```bash
terraform destroy -auto-approve
```
