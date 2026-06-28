#!/bin/bash
# =============================================================
# install-api.sh — Setup de la instancia team01-api-server
# Ejecutar dentro de la instancia EC2 privada (vía bastion)
# =============================================================
set -e

echo "========================================"
echo " Setup API Server (FastAPI)"
echo "========================================"

# Actualizar paquetes
echo "[1/5] Actualizando paquetes del sistema..."
sudo dnf update -y

# Instalar Python 3.11, pip y Git
echo "[2/5] Instalando Python 3.11, pip y Git..."
sudo dnf install -y python3.11 python3.11-pip git

# Verificar versiones
echo "  Python: $(python3.11 --version)"
echo "  Git: $(git --version)"

# Clonar el repositorio de la API
echo "[3/5] Clonando fastapi-customers-api-demo..."
cd ~
rm -rf fastapi-customers-api-demo
git clone https://github.com/jriverox/fastapi-customers-api-demo.git
cd fastapi-customers-api-demo

# Crear entorno virtual e instalar dependencias
echo "[4/5] Creando entorno virtual e instalando dependencias..."
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configurar como servicio systemd
echo "[5/5] Configurando servicio systemd..."
sudo tee /etc/systemd/system/fastapi-customers.service > /dev/null <<EOF
[Unit]
Description=FastAPI Customers API
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/fastapi-customers-api-demo
Environment="PATH=/home/ec2-user/fastapi-customers-api-demo/venv/bin"
ExecStart=/home/ec2-user/fastapi-customers-api-demo/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable fastapi-customers
sudo systemctl start fastapi-customers

# Verificar estado
sleep 2
sudo systemctl status fastapi-customers --no-pager

echo ""
echo "========================================"
echo " ✅ API Server configurado"
echo "========================================"
echo " FastAPI corriendo en puerto 8000"
echo " Verificar: curl http://localhost:8000/docs"
echo ""
echo " Para ver logs en tiempo real:"
echo " sudo journalctl -u fastapi-customers -f"
