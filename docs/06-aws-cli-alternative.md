# Flujo Alternativo — AWS CLI Completo

## ¿Qué es esto?

Esta guía reproduce toda la arquitectura del lab usando exclusivamente la AWS CLI. Es el equivalente directo a todos los pasos de consola de los documentos anteriores, pero en forma de comandos que puedes ejecutar secuencialmente.

## Prerrequisitos

- AWS CLI instalado y configurado (`aws configure`)
- `jq` instalado para parsear el output JSON (`brew install jq` en macOS, `sudo dnf install jq` en Linux)

## Cómo usar los scripts

Los scripts del directorio `scripts/cli/` están pensados para ejecutarse en orden. Todos leen las variables desde un único archivo `config.env`:

```bash
cd scripts/cli
cp config.env.example config.env
# Edita config.env con tus valores
bash 01-create-vpc.sh
bash 02-create-subnets.sh
# ... etc
```

> ⚠️ Cada script guarda los IDs de los recursos creados en un archivo `resource-ids.env` que los scripts siguientes cargan automáticamente. No elimines ese archivo entre ejecuciones.

---

## Referencia de comandos por sección

Si prefieres ejecutar los comandos manualmente en lugar de usar los scripts, aquí está la referencia completa con explicación de cada bloque.

### Sección 1 — VPC y Networking

```bash
# Variables base
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"
AZ="us-east-1a"
REGION="us-east-1"

# 1. Crear VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=team01-vpc}]' \
  --region $REGION \
  --query 'Vpc.VpcId' --output text)
echo "VPC_ID=$VPC_ID"

# 2. Habilitar DNS hostnames en la VPC (necesario para resolución de nombres)
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# 3. Subnet pública
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone $AZ \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=team01-public-subnet}]' \
  --query 'Subnet.SubnetId' --output text)
echo "PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID"

# 4. Subnet privada
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone $AZ \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=team01-private-subnet}]' \
  --query 'Subnet.SubnetId' --output text)
echo "PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID"

# 5. Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=team01-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
echo "IGW_ID=$IGW_ID"

# 6. Elastic IP para NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' --output text)
echo "EIP_ALLOC_ID=$EIP_ALLOC_ID"

# 7. NAT Gateway (en subnet pública)
NATGW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_ID \
  --allocation-id $EIP_ALLOC_ID \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=team01-natgw}]' \
  --query 'NatGateway.NatGatewayId' --output text)
echo "NATGW_ID=$NATGW_ID"

# Esperar a que el NAT Gateway esté disponible (puede tardar ~60 segundos)
echo "Esperando NAT Gateway..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NATGW_ID
echo "NAT Gateway disponible."

# 8. Route Table pública
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=team01-public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUBLIC_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-subnet-with-route-table --subnet-id $PUBLIC_SUBNET_ID --route-table-id $PUBLIC_RT_ID
echo "PUBLIC_RT_ID=$PUBLIC_RT_ID"

# 9. Route Table privada
PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=team01-private-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PRIVATE_RT_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NATGW_ID
aws ec2 associate-subnet-with-route-table --subnet-id $PRIVATE_SUBNET_ID --route-table-id $PRIVATE_RT_ID
echo "PRIVATE_RT_ID=$PRIVATE_RT_ID"
```

---

### Sección 2 — Security Groups

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)

# SG Bastion
SG_BASTION_ID=$(aws ec2 create-security-group \
  --group-name team01-sg-bastion \
  --description "SSH access to bastion host" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_BASTION_ID --protocol tcp --port 22 --cidr "${MY_IP}/32"
echo "SG_BASTION_ID=$SG_BASTION_ID"

# SG UI
SG_UI_ID=$(aws ec2 create-security-group \
  --group-name team01-sg-ui \
  --description "HTTP public + SSH from bastion" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_UI_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress \
  --group-id $SG_UI_ID --protocol tcp --port 22 --source-group $SG_BASTION_ID
echo "SG_UI_ID=$SG_UI_ID"

# SG API
SG_API_ID=$(aws ec2 create-security-group \
  --group-name team01-sg-api \
  --description "API access from public subnet + SSH from bastion" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_API_ID --protocol tcp --port 8000 --cidr $PUBLIC_SUBNET_CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $SG_API_ID --protocol tcp --port 22 --source-group $SG_BASTION_ID
echo "SG_API_ID=$SG_API_ID"
```

---

### Sección 3 — Instancias EC2

```bash
KEY_NAME="team01-key"   # Nombre de tu key pair en AWS (sin .pem)
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2023, us-east-1

# Bastion
BASTION_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --subnet-id $PUBLIC_SUBNET_ID \
  --security-group-ids $SG_BASTION_ID \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-bastion}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "BASTION_ID=$BASTION_ID"

# UI Server
UI_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --subnet-id $PUBLIC_SUBNET_ID \
  --security-group-ids $SG_UI_ID \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-ui-server}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "UI_ID=$UI_ID"

# API Server (sin IP pública)
API_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --subnet-id $PRIVATE_SUBNET_ID \
  --security-group-ids $SG_API_ID \
  --no-associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-api-server}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "API_ID=$API_ID"

# Esperar a que las instancias estén running
echo "Esperando instancias..."
aws ec2 wait instance-running --instance-ids $BASTION_ID $UI_ID $API_ID

# Obtener IPs
BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $BASTION_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
UI_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $UI_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
API_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $API_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

echo ""
echo "=== IPs de tus instancias ==="
echo "Bastion:    $BASTION_PUBLIC_IP"
echo "UI Server:  $UI_PUBLIC_IP"
echo "API Server: $API_PRIVATE_IP (privada)"
```
