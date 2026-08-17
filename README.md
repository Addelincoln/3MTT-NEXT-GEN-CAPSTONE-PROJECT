# SME Web App Migration to Azure
  ## Project Overview
Many Nigerian SMEs run their point-of-sale, inventory, or booking applications on a single on-premises PC or local server where they are to provide to make sure the server keep running. These setups fail during power outages with no trusted backup, and cannot be accessed remotely. This capstone migrates a simple LAMP (Linux, Apache, MySQL, PHP) application from a fragile local server to a resilient, remotely accessible cloud instance on the Microsoft Azure Free Tier — at zero or near-zero cost.
This migration to a cloud-hosted Azure VM was provisioned via both the Azure CLI and Terraform, secured with a network security group, and reachable through a free DNS name i.e. http://migrate-sme-app.duckdns.org.

# Objectives (MVP scope)
•	Provision a cloud virtual machine (server) on Azure.
•	Deploy a LAMP application to that server.
•	Configure a DNS name so the app is reachable by a human-friendly address.
Verify the deployment is live, correct, and reasonably secured.


# SME App Migration to Azure

Migrating a small business's local LAMP application (Apache, PHP, MySQL) to a
cloud-hosted Azure VM — provisioned via both the Azure CLI and Terraform,
secured with a network security group, and reachable through a free DNS
name.

## Architecture

- **Compute:** 1x `Standard_B1s` Ubuntu 22.04 LTS VM
- **Networking:** Single VNet (`10.1.0.0/16`) with one app subnet
  (`10.1.1.0/24`), protected by an NSG allowing only SSH (restricted to a
  single IP), HTTP, and HTTPS
- **App stack:** Apache2, PHP 8.1, MySQL 8, provisioned automatically via
  cloud-init at first boot
- **DNS:** Free DuckDNS subdomain pointed at a static public IP
- **IaC:** Terraform configuration reproducing the same architecture
  declaratively (separate resource group, safe to apply/destroy
  independently)
- **Region:** `indiasouthcentral` — see [Region availability](#region-availability)
  below for why this project isn't in `eastus`

## Prerequisites

- Azure CLI (`az`) installed and logged in (`az login`)
- Windows PowerShell (commands below assume PowerShell syntax)
- OpenSSH client (`ssh`, `scp`, `ssh-keygen`) — included by default on
  Windows 10/11
- Terraform (optional, only needed for the IaC section):
  `winget install HashiCorp.Terraform`

## 1. Resource group, network, and security group

```powershell
az group create --name rg-sme-migration-se --location indiasouthcentral

az network vnet create `
  --resource-group rg-sme-migration-se `
  --name vnet-sme-se `
  --address-prefix 10.1.0.0/16 `
  --subnet-name subnet-app `
  --subnet-prefix 10.1.1.0/24

az network nsg create --resource-group rg-sme-migration-se --name nsg-sme-app-se

$myIp = (Invoke-RestMethod -Uri "https://api.ipify.org")

az network nsg rule create --resource-group rg-sme-migration-se `
  --nsg-name nsg-sme-app-se --name Allow-SSH --priority 100 `
  --protocol Tcp --destination-port-ranges 22 `
  --source-address-prefixes "$myIp/32" --access Allow

az network nsg rule create --resource-group rg-sme-migration-se `
  --nsg-name nsg-sme-app-se --name Allow-HTTP --priority 110 `
  --protocol Tcp --destination-port-ranges 80 `
  --source-address-prefixes "*" --access Allow

az network nsg rule create --resource-group rg-sme-migration-se `
  --nsg-name nsg-sme-app-se --name Allow-HTTPS --priority 120 `
  --protocol Tcp --destination-port-ranges 443 `
  --source-address-prefixes "*" --access Allow

az network vnet subnet update `
  --resource-group rg-sme-migration-se `
  --vnet-name vnet-sme-se --name subnet-app `
  --network-security-group nsg-sme-app-se
```

> **Note:** the SSH rule is scoped to your public IP at the time you run
> this. If your IP changes later (common on residential ISPs), update it
> with `az network nsg rule update ... --source-address-prefixes "<new-ip>/32"`
> or SSH will silently time out.

## 2. cloud-init.txt (provisions Apache/PHP/MySQL at first boot)

```powershell
$lines = @(
'#cloud-config',
'package_update: true',
'package_upgrade: true',
'packages:',
'  - apache2',
'  - php',
'  - libapache2-mod-php',
'  - php-mysql',
'  - mysql-server',
'  - unzip',
'runcmd:',
'  - systemctl enable apache2',
'  - systemctl enable mysql',
'  - ufw allow OpenSSH',
'  - ufw allow "Apache Full"',
'  - ufw --force enable',
'  - mysql -e "CREATE DATABASE sme_app;"',
'  - chown -R www-data:www-data /var/www/html'
)
[System.IO.File]::WriteAllLines("$PWD\cloud-init.txt", $lines, (New-Object System.Text.UTF8Encoding $false))
```

> **Important:** write this with `[System.IO.File]::WriteAllLines(...,
> UTF8Encoding($false))`, not PowerShell's `Out-File -Encoding utf8`. The
> latter adds a UTF-8 byte-order mark (BOM), which breaks cloud-init's
> `#cloud-config` header detection and causes the whole file to be silently
> ignored on boot.

## 3. SSH key pair

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh"
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\vm_sme_key" -N '""'
Get-Content "$env:USERPROFILE\.ssh\vm_sme_key.pub"
```

Confirm the output is a single line starting with `ssh-rsa AAAA...` before
using it — a truncated or multi-line key causes base64
padding/length errors from Azure CLI's key validator.

## 4. Deploy the VM

```powershell
az vm create `
  --resource-group rg-sme-migration-se `
  --name vm-sme-app `
  --image Ubuntu2204 `
  --size Standard_B1s `
  --location indiasouthcentral `
  --vnet-name vnet-sme-se `
  --subnet subnet-app `
  --nsg nsg-sme-app-se `
  --admin-username azureuser `
  --ssh-key-values "$env:USERPROFILE\.ssh\vm_sme_key.pub" `
  --public-ip-sku Standard `
  --custom-data .\cloud-init.txt
```

> **Note:** `--public-ip-sku Basic` was retired September 30, 2025 — use
> `Standard`. Standard SKU public IPs are also static by default and
> secure-by-default (closed unless an NSG explicitly allows the traffic).

Verify provisioning finished before connecting:

```powershell
az vm run-command invoke --resource-group rg-sme-migration-se `
  --name vm-sme-app --command-id RunShellScript `
  --scripts "cloud-init status --long"
```

Look for `status: done` with no `Unhandled non-multipart userdata` warning.

## 5. Deploy the app and database

Create a dedicated MySQL user first — the default `root` account only
allows local socket auth, and the VM's `azureuser` has no MySQL privileges
by default:

```powershell
$lines = @(
"CREATE USER 'sme_app_user'@'localhost' IDENTIFIED BY 'ChangeMe123!';",
"GRANT ALL PRIVILEGES ON sme_app.* TO 'sme_app_user'@'localhost';",
"FLUSH PRIVILEGES;"
)
[System.IO.File]::WriteAllLines("$PWD\create_user.sql", $lines, (New-Object System.Text.UTF8Encoding $false))

scp -i "$env:USERPROFILE\.ssh\vm_sme_key" .\create_user.sql azureuser@<PUBLIC_IP>:/tmp/create_user.sql
ssh -i "$env:USERPROFILE\.ssh\vm_sme_key" azureuser@<PUBLIC_IP> "sudo mysql < /tmp/create_user.sql"
```

Copy the app files and import the schema:

```powershell
scp -i "$env:USERPROFILE\.ssh\vm_sme_key" -r .\sme-app azureuser@<PUBLIC_IP>:/tmp/sme-app

ssh -i "$env:USERPROFILE\.ssh\vm_sme_key" azureuser@<PUBLIC_IP> `
  "sudo cp /tmp/sme-app/*.php /var/www/html/ && sudo chown -R www-data:www-data /var/www/html && sudo rm -f /var/www/html/index.html"

ssh -i "$env:USERPROFILE\.ssh\vm_sme_key" azureuser@<PUBLIC_IP> "sudo mysql sme_app < /tmp/sme-app/schema.sql"
```

> Apache ships a default `index.html` that takes priority over `index.php`
> in the same directory — remove it or your PHP app won't be served.

## 6. DNS (free option)

```powershell
az network public-ip show --resource-group rg-sme-migration-se `
  --name vm-sme-appPublicIP --query publicIPAllocationMethod --output tsv
```

Deploying with `--public-ip-sku Standard` (step 4) already makes the IP
static, so no separate conversion step is usually needed — confirm with
the command above.

Then, at [duckdns.org](https://www.duckdns.org):

1. Sign in (GitHub/Google OAuth)
2. Claim a free subdomain, e.g. `your-app-name.duckdns.org`
3. Point it at the VM's static public IP from the dashboard
4. Confirm: `nslookup your-app-name.duckdns.org`

## 7. Infrastructure as Code (Terraform)

`main.tf` reproduces the same architecture declaratively, in its **own**
resource group (`rg-sme-migration-tf`) so it can be created and destroyed
independently without any risk to the manually-deployed environment above.

```powershell
terraform init
terraform plan -var="my_ip=$myIp"
terraform apply -var="my_ip=$myIp"

# When done demonstrating:
terraform destroy -var="my_ip=$myIp"
```

> **Warning:** give any Terraform-managed resource group a name distinct
> from your manually-created one. Reusing the same resource group name
> means `terraform destroy` will delete *everything* inside it — including
> resources Terraform didn't create — since Azure resource group deletion
> cascades to all contained resources.

## 8. Verification checklist

- [ ] `http://<dns-name>` loads the app in a browser
- [ ] Adding an inventory item writes to and reads back from MySQL
- [ ] `(Invoke-WebRequest -Uri "http://<dns-name>" -Method Head -UseBasicParsing).StatusCode` returns `200`
- [ ] `ssh ... "sudo systemctl status apache2 mysql --no-pager"` shows both `active (running)`
- [ ] An external port checker (e.g. yougetsignal.com/tools/open-ports)
      reports port 22 as **closed** from outside your allowed IP

## Region availability

This subscription (Azure Free Trial) restricted `Standard_B1s` in most
common regions — `eastus`, `eastus2`, `westus2`, `centralus`, etc. all
returned `NotAvailableForSubscription`, not a genuine capacity shortage.
Confirmed available regions were checked with:

```powershell
az vm list-skus --size Standard_B1s --all --output table
```

`indiasouthcentral` was selected from the results as a standard,
non-preview region with no restrictions for this subscription.

## Known issues and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `Invalid base64-encoded string` / `Incorrect padding` on `az vm create` | Corrupted, empty, or unresolved SSH key file | Regenerate with `ssh-keygen`, verify with `Get-Content`, reference with a full explicit path (not `~`) |
| `An RSA key file or key value must be supplied` | `--ssh-key-values` path didn't resolve to a real file | Confirm with `Test-Path` before deploying |
| `SkuNotAvailable` for `Standard_B1s`/`B2s` | Free Trial quota blocked in most regions | `az vm list-skus --size <size> --all` to find an unrestricted region |
| Cloud-init `Unhandled non-multipart userdata` | `cloud-init.txt` missing from the working directory, or saved with a UTF-8 BOM | Confirm the file exists; write it with `UTF8Encoding($false)` |
| SSH `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | Expected after deleting/recreating a VM that reuses the same IP | `ssh-keygen -R <ip-address>`, then reconnect |
| App shows the default Apache page instead of the PHP app | `index.html` takes priority over `index.php` | `sudo rm /var/www/html/index.html` |
| SSH suddenly times out after previously working | Residential ISP reassigned your public IP; NSG rule still has the old one | Check current IP with `api.ipify.org`, update the NSG rule |

## Cost notes (Free Tier)

| Resource | Free-tier coverage | Est. cost beyond free tier |
|---|---|---|
| `Standard_B1s` VM | 750 hrs/month free for 12 months | ~$7–9/month |
| Managed OS disk (Standard_LRS, ≤64GB) | Free for 12 months | ~$3–5/month |
| Public IP (Standard, static) | Not on the free list | ~$3–4/month |
| Outbound data transfer | 100 GB/month always free | ~$0.08/GB beyond |
| DuckDNS | Always free | $0 |

Deallocate (not just stop) the VM when not actively demoing to stay within
free allowances.
