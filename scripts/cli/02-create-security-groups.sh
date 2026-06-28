#!/bin/bash
# =============================================================
# Script 02 — Crear Security Groups
# =============================================================
set -e

source "$(dirname "$0")/config.env"
source "$(dirname "$0")/resource-ids.env"

echo "========================================"
echo " Paso 2: Security Groups"
echo "========================================"

# Detectar IP pública del operador
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "  Tu IP pública detectada: $MY_IP"

# SG Bastion
echo "[1/3] Creando SG team01-sg-bastion..."
SG_BASTION_ID=$(aws ec2 create-security-group \
  --group-name team01-sg-bastion \
  --description "SSH access to bastion host" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_BASTION_ID" --protocol tcp --port 22 --cidr "${MY_IP}/32"
echo "  SG_BASTION_ID=$SG_BASTION_ID ✓"

# SG UI
echo "[2/3] Creando SG team01-sg-ui..."
SG_UI_ID=$(aws ec2 create-security-group \
  --group-name team01-sg-ui \
  --description "HTTP public + SSH from bastion" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_UI_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_UI_ID" --protocol tcp --port 22 --source-group "$SG_BASTION_ID"
echo "  SG_UI_ID=$SG_UI_ID ✓"

# SG API
echo "[3/3] Creando SG team01-sg-api..."
SG_API_ID=$(aws ec2 create-security-group \
  --group-name team01-sg-api \
  --description "API access from public subnet + SSH from bastion" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_API_ID" --protocol tcp --port 8000 --cidr "$PUBLIC_SUBNET_CIDR"
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_API_ID" --protocol tcp --port 22 --source-group "$SG_BASTION_ID"
echo "  SG_API_ID=$SG_API_ID ✓"

# Guardar IDs
cat >> "$(dirname "$0")/resource-ids.env" <<EOF
SG_BASTION_ID=$SG_BASTION_ID
SG_UI_ID=$SG_UI_ID
SG_API_ID=$SG_API_ID
EOF

echo ""
echo "========================================"
echo " ✅ Paso 2 completado"
echo "========================================"
echo " Siguiente: bash 03-launch-ec2.sh"
