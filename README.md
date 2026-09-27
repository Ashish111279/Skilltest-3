My instances details below

The deployment uses the two existing EC2 instances you provided:

- `i-037d7985c9ea0cd09` runs the frontend, user service, and products service.
- `i-0c8b52ea004883370` runs the orders and cart services.



I have built and started the five containers:

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


```powershell
docker login --username YOUR_DOCKERHUB_USERNAME
```

Built and pushed the five images with the same Docker Hub username:

```powershell
.\scripts\build-push.ps1 -DockerHubUsername YOUR_DOCKERHUB_USERNAME -Tag latest
```

Before moving on, confirmed these public repositories exist with the `latest` tag: `ecommerce-user`, `ecommerce-products`, `ecommerce-orders`, `ecommerce-cart`, and `ecommerce-frontend`.


```powershell
aws configure sso --profile ecommerce-deploy
aws sso login --profile ecommerce-deploy
aws sts get-caller-identity --profile ecommerce-deploy --output json
$env:AWS_PROFILE = "ecommerce-deploy"
```

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Initialized Terraform and review its plan:

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=terraform.tfvars -out=tfplan
```

deployed and read the Terraform outputs:

```powershell
terraform -chdir=terraform apply tfplan
terraform -chdir=terraform output
```

```powershell
terraform -chdir=terraform destroy -var-file=terraform.tfvars
```

