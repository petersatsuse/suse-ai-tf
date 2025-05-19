# Deploying SUSE AI Stack on AWS EC2 with Terraform

This project provides Terraform configurations to automate the deployment of the SUSE AI Stack on an Amazon Web Services (AWS) EC2 instance (default -> g4dn.xlarge for GPU) running SUSE Linux Enterprise Micro 6.1.

## Prerequisites

Before you begin, ensure you have the following:

* **AWS Account:** You need an active AWS account with appropriate permissions to create and manage EC2 instances, security groups, and other related resources.
* **Terraform:** Terraform version 1.0 or later installed on your local machine. You can find installation instructions on the [official Terraform website](https://www.terraform.io/downloads).
* **SUSE Customer Center Account:** A SUSE Customer Center (SCC) login with a current subscription for the following products is required:
    * SUSE AI
    * *(Optional)* SUSE Observability
* **SUSE Registration Code:** A valid and active registration code for registering the SLE Micro 6.1 instance obtained from the [SUSE Customer Center](https://scc.suse.com/). Find for 'SUSE Linux Micro', select the version either 6.1 or 6.2, then go to 'Employee Subscription' and click on 'Generate registration code'. After the registration code is generated, activate it.
* **AWS Credentials:** Your AWS credentials configured for Terraform to use. This can be done through environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) or an AWS CLI configuration profile.
* **SSH Key Pair:** *(Optional)* An existing EC2 key pair in your desired AWS region to allow SSH access to the deployed instance.
* **SUSE Application Collection:** If you have access to the SUSE customer Center (SCC) you should have access to [SUSE Application Collection](https://apps.rancher.io/). Login to the SUSE Application Collection and click on the top right corner at the gravatar/profile icon, then click on `Settings` and then click on `Access Token`. Here you will see a option to `Create` tokens. After clicking `Create` you should see tokens created for helm, docker, kubernetes and curl.

For example,
```bash
# docker login <registry_name> -u <registry_username> -p <password/token>
# helm registry login <registry_name> -u <registry_username> -p <password/token>
# kubectl create secret docker-registry <secret_name> --docker-server=<registry_name> --docker-username=<registry_username> --docker-password=<registry_password>
# curl -u <registry_username>:<registry_password> https://api.<registry_name>/v1/applications
```

## Overview

This Terraform setup will perform the following actions:

1.  **Launch an EC2 Instance:** Provisions a new EC2 instance of type g4dn.xlarge in your specified AWS region running the SLE Micro 6.1 AMI.
2.  **Register the System:** Automatically registers the EC2 instance with your SUSE Customer Center using the provided registration code.
3.  **Deploy RKE2:** Installs and configures RKE2, a lightweight Kubernetes distribution by Rancher, on the EC2 instance.
4.  **Deploy NVIDIA GPU Operator and Drivers:** Installs the NVIDIA GPU Operator within the RKE2 cluster to manage NVIDIA GPU resources (assuming a GPU-enabled EC2 instance type is used).
5.  **Deploy SUSE AI Stack:** Deploys the core components of the SUSE AI Stack on the RKE2 cluster:
    * **Milvus:** A cloud-native vector database built for scalable similarity search and AI applications.
    * **Ollama:** A lightweight and extensible framework for running large language models (LLMs) locally.
    * **Open WebUI:** A user-friendly web interface for interacting with LLMs served by Ollama.

## Getting Started

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/devenkulkarni/suse-ai-tf.git
    cd suse-ai-tf
    ```

2.  **Configure Terraform Variables:**
    
    - Copy `./terraform.tfvars.example` to `./terraform.tfvars`
    - Edit `./terraform.tfvars`
    - For example:
    ```bash
    instance_prefix = "myprefix"
    registration_code   = "<YOUR_REGISTRATION_CODE_HERE>"
    registry_secretname = "application-collection"
    registry_username   = "<YOUR_EMAIL_ID_HERE>"
    registry_password   = "<YOUR_PASSWORD/TOKEN_HERE>"
    ```

3.  **Initialize Terraform:**
    ```bash
    terraform init -upgrade
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
To access the webUI for the SUSE AI:

* **Add below entry in your system's `/etc/hosts`:**
    ```bash
    <PUBLIC_IP_OF_EC2_INSTANCE>  suse-ollama-webui
    
* **Open WebUI:** Now you can access the Open WebUI interface through your web browser using the below URL:
    ```
    https://suse-ollama-webui
    ```

* **Milvus and Ollama:** These services are running as application pods within the RKE2 cluster.

## Cleaning Up

To destroy the resources created by Terraform, run the following command:

```bash
terraform destroy -auto-approve
```
