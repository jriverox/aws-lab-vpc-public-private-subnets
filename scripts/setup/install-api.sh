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

# Instalar make
echo "[4/6] Instalando make..."
sudo dnf install -y make

# Instalar Poetry e instalar dependencias
echo "[5/6] Instalando Poetry e instalando dependencias..."
pip3.11 install poetry
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
poetry install

# Verificar que la API arranca correctamente
echo "[6/6] Verificando que la API arranca con make run..."
make run &
sleep 3
curl -s http://localhost:8000/docs > /dev/null && echo "  API respondiendo en :8000 ✓" || echo "  ⚠️  La API no respondió, revisa los logs"
kill %1 2>/dev/null || true

echo ""
echo "========================================"
echo " ✅ API Server configurado"
echo "========================================"
echo " Para iniciar manualmente: make run"
echo " Para ver docs:            curl http://localhost:8000/docs"
