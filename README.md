# E-commerce services on AWS

This project is a small, runnable example of a five-container e-commerce setup. It includes four Node.js health-check services and a simple frontend that shows whether each service is responding. It demonstrates the deployment exercise; it is not the full MERN application from the linked repository and does not include a database or shopping-cart business logic.

## Where things run

The deployment uses the two existing EC2 instances you provided:

- `i-037d7985c9ea0cd09` runs the frontend, user service, and products service.
- `i-0c8b52ea004883370` runs the orders and cart services.

The instances need to be running in the same VPC. Terraform does not create or replace them. It adds the required security-group rules and uses AWS Systems Manager (SSM) to install Docker and start the containers. The frontend is served on port 80. Orders and cart listen on ports 3003 and 3004, reachable from the frontend instance. User and products communicate over the frontend host's Docker network. No SSH rule is added.

## Before you start

Install Docker Desktop with Compose, Terraform 1.5 or newer, and the AWS CLI. Both EC2 instances must be registered and online in Systems Manager, with SSM Agent running and an instance role that includes `AmazonSSMManagedInstanceCore` (or equivalent). They also need outbound internet access so they can install Docker and pull images. The frontend instance needs a public IPv4 address.

Use an AWS IAM Identity Center or other least-privilege profile. Do not put AWS credentials in this project. The profile needs permission to describe the instances, manage the relevant security-group rules, and create SSM documents and associations.

You’ll also need the Docker Hub username that owns the image repositories. The repositories must be public so the EC2 instances can pull them without Docker Hub credentials.

## Try it locally

From the project directory, build and start the five containers:

```powershell
docker compose up --build -d
```

Open `http://localhost:3000`. The page should say **Frontend is Live** and show the four backend statuses. You can also check the health endpoints from PowerShell:

```powershell
Invoke-RestMethod http://localhost:3000/health
Invoke-RestMethod http://localhost:3000/api/users/health
Invoke-RestMethod http://localhost:3000/api/products/health
Invoke-RestMethod http://localhost:3000/api/orders/health
Invoke-RestMethod http://localhost:3000/api/cart/health
docker compose ps
```

When you’re done testing, stop the local containers with `docker compose down`.

## Publish the images

Sign in to Docker Hub from your machine. When prompted, use an access token rather than putting a password or token in a command:

```powershell
docker login --username YOUR_DOCKERHUB_USERNAME
```

Build and push the five images with the same Docker Hub username:

```powershell
.\scripts\build-push.ps1 -DockerHubUsername YOUR_DOCKERHUB_USERNAME -Tag latest
```

Before moving on, confirm these public repositories exist with the `latest` tag: `ecommerce-user`, `ecommerce-products`, `ecommerce-orders`, `ecommerce-cart`, and `ecommerce-frontend`.

## Deploy to the existing EC2 instances

Sign in with your AWS profile and check that it is the intended non-root identity. For IAM Identity Center, the first-time setup looks like this:

```powershell
aws configure sso --profile ecommerce-deploy
aws sso login --profile ecommerce-deploy
aws sts get-caller-identity --profile ecommerce-deploy --output json
$env:AWS_PROFILE = "ecommerce-deploy"
```

Copy the example Terraform variables file and set your Docker Hub namespace and the instances’ AWS region:

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Then initialize Terraform and review its plan:

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=terraform.tfvars -out=tfplan
```

Read the plan before applying it. It should not create, replace, or destroy EC2 instances. It should only add the frontend HTTP rule, allow ports 3003 and 3004 from the frontend security group to the backend security group, and create the SSM deployment documents and associations. The configuration uses the first security group by ID on each instance; check the plan to confirm those are the right groups. If a matching rule already exists, AWS may reject the duplicate, so inspect the existing rules before proceeding.

If the plan is correct, deploy and read the Terraform outputs:

```powershell
terraform -chdir=terraform apply tfplan
terraform -chdir=terraform output
```

Terraform prints the frontend URL and the backend private IP. Wait for both SSM associations to finish, then visit the frontend URL and try `/api/users/health`. If deployment fails, check the association execution status in Systems Manager and verify the instance roles, SSM Agent, public image visibility, and outbound access.

If this Terraform directory has state from an earlier setup, inspect it with `terraform -chdir=terraform state list` and review the plan especially carefully. Back up the state and resolve old resource tracking before applying; do not proceed if the plan proposes destroying infrastructure you want to keep.

## Clean up

Terraform destroy removes the SSM documents and associations and the security-group rules it manages. It does not terminate either EC2 instance. Review the destroy plan before confirming:

```powershell
terraform -chdir=terraform destroy -var-file=terraform.tfvars
```

The instances, their storage, and their public IPv4 addresses may incur AWS charges while they’re running. This demo is not production-hardened: it has no TLS, database, load balancer, or persistent application data.
