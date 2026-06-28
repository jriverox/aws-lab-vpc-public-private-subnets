#!/bin/bash
# =============================================================
# Script 01 — Crear VPC, Subnets, IGW, NAT GW y Route Tables
# =============================================================
set -e

# Cargar configuración
source "$(dirname "$0")/config.env"

echo "========================================"
echo " Paso 1: VPC y Networking"
echo "========================================"

# 1. Crear VPC
echo "[1/9] Creando VPC team01-vpc..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --region "$AWS_REGION" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=team01-vpc}]' \
  --query 'Vpc.VpcId' --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
echo "  VPC_ID=$VPC_ID ✓"

# 2. Subnet pública
echo "[2/9] Creando subnet pública..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$PUBLIC_SUBNET_CIDR" \
  --availability-zone "$AZ" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=team01-public-subnet}]' \
  --query 'Subnet.SubnetId' --output text)
echo "  PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID ✓"

# 3. Subnet privada
echo "[3/9] Creando subnet privada..."
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$PRIVATE_SUBNET_CIDR" \
  --availability-zone "$AZ" \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=team01-private-subnet}]' \
  --query 'Subnet.SubnetId' --output text)
echo "  PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID ✓"

# 4. Internet Gateway
echo "[4/9] Creando Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=team01-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
echo "  IGW_ID=$IGW_ID ✓"

# 5. Elastic IP para NAT Gateway
echo "[5/9] Asignando Elastic IP..."
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' --output text)
echo "  EIP_ALLOC_ID=$EIP_ALLOC_ID ✓"

# 6. NAT Gateway
echo "[6/9] Creando NAT Gateway (esto puede tardar ~60s)..."
NATGW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --allocation-id "$EIP_ALLOC_ID" \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=team01-natgw}]' \
  --query 'NatGateway.NatGatewayId' --output text)
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NATGW_ID"
echo "  NATGW_ID=$NATGW_ID ✓"

# 7. Route Table pública
echo "[7/9] Creando Route Table pública..."
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=team01-public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$PUBLIC_RT_ID" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" > /dev/null
aws ec2 associate-subnet-with-route-table \
  --subnet-id "$PUBLIC_SUBNET_ID" --route-table-id "$PUBLIC_RT_ID" > /dev/null
echo "  PUBLIC_RT_ID=$PUBLIC_RT_ID ✓"

# 8. Route Table privada
echo "[8/9] Creando Route Table privada..."
PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=team01-private-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id "$PRIVATE_RT_ID" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NATGW_ID" > /dev/null
aws ec2 associate-subnet-with-route-table \
  --subnet-id "$PRIVATE_SUBNET_ID" --route-table-id "$PRIVATE_RT_ID" > /dev/null
echo "  PRIVATE_RT_ID=$PRIVATE_RT_ID ✓"

# 9. Guardar IDs para scripts siguientes
echo "[9/9] Guardando IDs de recursos..."
cat > "$(dirname "$0")/resource-ids.env" <<EOF
VPC_ID=$VPC_ID
PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID
PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID
IGW_ID=$IGW_ID
EIP_ALLOC_ID=$EIP_ALLOC_ID
NATGW_ID=$NATGW_ID
PUBLIC_RT_ID=$PUBLIC_RT_ID
PRIVATE_RT_ID=$PRIVATE_RT_ID
EOF

echo ""
echo "========================================"
echo " ✅ Paso 1 completado"
echo "========================================"
echo " IDs guardados en resource-ids.env"
echo " Siguiente: bash 02-create-security-groups.sh"
