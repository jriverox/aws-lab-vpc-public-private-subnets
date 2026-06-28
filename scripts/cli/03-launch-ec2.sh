#!/bin/bash
# =============================================================
# Script 03 — Lanzar instancias EC2
# =============================================================
set -e

source "$(dirname "$0")/config.env"
source "$(dirname "$0")/resource-ids.env"

echo "========================================"
echo " Paso 3: Lanzar instancias EC2"
echo "========================================"

# Bastion
echo "[1/3] Lanzando team01-bastion (subnet pública)..."
BASTION_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --security-group-ids "$SG_BASTION_ID" \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-bastion}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "  BASTION_ID=$BASTION_ID ✓"

# UI Server
echo "[2/3] Lanzando team01-ui-server (subnet pública)..."
UI_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --security-group-ids "$SG_UI_ID" \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-ui-server}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "  UI_ID=$UI_ID ✓"

# API Server
echo "[3/3] Lanzando team01-api-server (subnet privada, sin IP pública)..."
API_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --subnet-id "$PRIVATE_SUBNET_ID" \
  --security-group-ids "$SG_API_ID" \
  --no-associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-api-server}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "  API_ID=$API_ID ✓"

# Esperar estado Running
echo ""
echo "⏳ Esperando que las instancias estén en estado Running..."
aws ec2 wait instance-running --instance-ids "$BASTION_ID" "$UI_ID" "$API_ID"

# Obtener IPs
BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
UI_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$UI_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
API_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids "$API_ID" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

# Guardar IDs e IPs
cat >> "$(dirname "$0")/resource-ids.env" <<EOF
BASTION_ID=$BASTION_ID
UI_ID=$UI_ID
API_ID=$API_ID
BASTION_PUBLIC_IP=$BASTION_PUBLIC_IP
UI_PUBLIC_IP=$UI_PUBLIC_IP
API_PRIVATE_IP=$API_PRIVATE_IP
EOF

echo ""
echo "========================================"
echo " ✅ Paso 3 completado"
echo "========================================"
echo ""
echo " IPs de tus instancias:"
echo "  Bastion:    $BASTION_PUBLIC_IP  (pública)"
echo "  UI Server:  $UI_PUBLIC_IP       (pública)"
echo "  API Server: $API_PRIVATE_IP     (privada)"
echo ""
echo " Próximos pasos manuales:"
echo "  1. Conectarte al bastion: ssh -A -i $KEY_PATH ec2-user@$BASTION_PUBLIC_IP"
echo "  2. Desde el bastion, saltar a la UI:  ssh ec2-user@$UI_PUBLIC_IP"
echo "  3. Desde el bastion, saltar a la API: ssh ec2-user@$API_PRIVATE_IP"
echo ""
echo " Ver docs/04-ec2-public-ui.md y docs/05-ec2-private-api.md para el despliegue."
