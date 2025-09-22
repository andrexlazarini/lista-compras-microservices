#requires -Version 5.1
$ErrorActionPreference = "Stop"

function Invoke-Json ($Method, $Url, $Body = $null, $Headers=@{}) {
  Write-Host ">>> $Method $Url" -ForegroundColor Cyan
  if ($Body) { $json = $Body | ConvertTo-Json -Depth 10 } else { $json = $null }
  $resp = Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -Body $json -ContentType "application/json"
  $resp
}

# Health & Registry
$health = Invoke-Json GET "http://localhost:3000/health"
$registry = Invoke-Json GET "http://localhost:3000/registry"

# Register & Login
$reg = Invoke-Json POST "http://localhost:3000/api/auth/register" @{
    email="john.doe@example.com"; username="johndoe"; password="Senha@123"; firstName="John"; lastName="Doe"
}
$login = Invoke-Json POST "http://localhost:3000/api/auth/login" @{ username="johndoe"; password="Senha@123" }
$token = $login.data.token
$headers = @{ Authorization = "Bearer $token" }

# Items & Categories
$items = Invoke-Json GET "http://localhost:3000/api/items?active=true&limit=5"
$categories = Invoke-Json GET "http://localhost:3000/api/categories"

# Create List
$list = Invoke-Json POST "http://localhost:3000/api/lists" @{ name="Compras Teste"; description="Script PS1" } $headers
$listId = $list.data.id

# Add first item
$itemId = $items.data[0].id
$add = Invoke-Json POST "http://localhost:3000/api/lists/$listId/items" @{ itemId=$itemId; quantity=2; estimatedPrice=12.34 } $headers

# Summary & Dashboard
$summary = Invoke-Json GET "http://localhost:3000/api/lists/$listId/summary" $null $headers
$dashboard = Invoke-Json GET "http://localhost:3000/api/dashboard" $null $headers

Write-Host "`nOK! Testes básicos concluídos." -ForegroundColor Green
