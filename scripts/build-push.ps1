param(
    [Parameter(Mandatory = $true)]
    [string]$DockerHubUsername,
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"
$services = @(
    @{ Name = "user"; Dockerfile = "services/user/Dockerfile" },
    @{ Name = "products"; Dockerfile = "services/products/Dockerfile" },
    @{ Name = "orders"; Dockerfile = "services/orders/Dockerfile" },
    @{ Name = "cart"; Dockerfile = "services/cart/Dockerfile" },
    @{ Name = "frontend"; Dockerfile = "services/frontend/Dockerfile" }
)

foreach ($service in $services) {
    $image = "${DockerHubUsername}/ecommerce-$($service.Name):${Tag}"
    docker build -f $service.Dockerfile -t $image .
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $image" }
    docker push $image
    if ($LASTEXITCODE -ne 0) { throw "Push failed for $image" }
}
