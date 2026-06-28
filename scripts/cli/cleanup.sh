#!/bin/bash
# =============================================================
# cleanup.sh — Eliminar todos los recursos del lab
# =============================================================
# ADVERTENCIA: Este script elimina permanentemente todos los
# recursos creados. Asegúrate de que ya no los necesitas.
# =============================================================
set -e

source "$(dirname "$0")/config.env"

RESOURCE_IDS_FILE="$(dirname "$0")/resource-ids.env"
if [ ! -f "$RESOURCE_IDS_FILE" ]; then
  echo "❌ No se encontró resource-ids.env. Ejecuta primero los scripts de creación."
  exit 1
fi

source "$RESOURCE_IDS_FILE"

echo "========================================"
echo " Limpieza de recursos del lab"
echo "========================================"
echo ""
echo "⚠️  Se eliminarán los siguientes recursos:"
echo "  - Instancias EC2: bastion, ui-server, api-server"
echo "  - Security Groups: sg-bastion, sg-ui, sg-api"
echo "  - NAT Gateway: team01-natgw"
echo "  - Elastic IP"
echo "  - Internet Gateway: team01-igw"
echo "  - Subnets: public y private"
echo "  - Route Tables: public y private"
echo "  - VPC: team01-vpc"
echo ""
read -p "¿Continuar? (escribe 'si' para confirmar): " CONFIRM
if [ "$CONFIRM" != "si" ]; then
  echo "Operación cancelada."
  exit 0
fi

echo ""

# 1. Terminar instancias EC2
echo "[1/9] Terminando instancias EC2..."
aws ec2 terminate-instances --instance-ids "$BASTION_ID" "$UI_ID" "$API_ID" > /dev/null
echo "  Esperando que las instancias terminen..."
aws ec2 wait instance-terminated --instance-ids "$BASTION_ID" "$UI_ID" "$API_ID"
echo "  ✓"

# 2. Eliminar Security Groups
echo "[2/9] Eliminando Security Groups..."
aws ec2 delete-security-group --group-id "$SG_API_ID"
aws ec2 delete-security-group --group-id "$SG_UI_ID"
aws ec2 delete-security-group --group-id "$SG_BASTION_ID"
echo "  ✓"

# 3. Eliminar NAT Gateway
echo "[3/9] Eliminando NAT Gateway (puede tardar ~60s)..."
aws ec2 delete-nat-gateway --nat-gateway-id "$NATGW_ID" > /dev/null
echo "  Esperando que el NAT Gateway se elimine..."
aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NATGW_ID" 2>/dev/null || \
  aws ec2 wait nat-gateway-available --nat-gateway-ids "$NATGW_ID" 2>/dev/null || true
# Espera adicional por si acaso
sleep 30
echo "  ✓"

# 4. Liberar Elastic IP
echo "[4/9] Liberando Elastic IP..."
aws ec2 release-address --allocation-id "$EIP_ALLOC_ID"
echo "  ✓"

# 5. Eliminar Route Tables
echo "[5/9] Eliminando Route Tables..."
# Desasociar antes de eliminar
PUBLIC_ASSOC=$(aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_RT_ID" \
  --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
  --output text)
PRIVATE_ASSOC=$(aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
  --output text)
[ -n "$PUBLIC_ASSOC" ] && aws ec2 disassociate-route-table --association-id "$PUBLIC_ASSOC"
[ -n "$PRIVATE_ASSOC" ] && aws ec2 disassociate-route-table --association-id "$PRIVATE_ASSOC"
aws ec2 delete-route-table --route-table-id "$PUBLIC_RT_ID"
aws ec2 delete-route-table --route-table-id "$PRIVATE_RT_ID"
echo "  ✓"

# 6. Desconectar y eliminar Internet Gateway
echo "[6/9] Eliminando Internet Gateway..."
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
echo "  ✓"

# 7. Eliminar Subnets
echo "[7/9] Eliminando Subnets..."
aws ec2 delete-subnet --subnet-id "$PUBLIC_SUBNET_ID"
aws ec2 delete-subnet --subnet-id "$PRIVATE_SUBNET_ID"
echo "  ✓"

# 8. Eliminar VPC
echo "[8/9] Eliminando VPC..."
aws ec2 delete-vpc --vpc-id "$VPC_ID"
echo "  ✓"

# 9. Limpiar archivo de IDs
echo "[9/9] Limpiando archivos locales..."
rm -f "$RESOURCE_IDS_FILE"
echo "  ✓"

echo ""
echo "========================================"
echo " ✅ Limpieza completada"
echo "========================================"
echo " Todos los recursos del lab han sido eliminados."
