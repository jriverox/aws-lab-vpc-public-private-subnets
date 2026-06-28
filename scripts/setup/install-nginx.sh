#!/bin/bash
# =============================================================
# install-nginx.sh — Setup de la instancia team01-ui-server
# Ejecutar dentro de la instancia EC2 pública
# =============================================================
set -e

# IP privada de la API (reemplazar antes de ejecutar)
API_PRIVATE_IP="${1:-}"

if [ -z "$API_PRIVATE_IP" ]; then
  echo "Uso: bash install-nginx.sh <API_PRIVATE_IP>"
  echo "Ejemplo: bash install-nginx.sh 10.0.2.45"
  exit 1
fi

echo "========================================"
echo " Setup UI Server"
echo " API endpoint: http://$API_PRIVATE_IP:8000"
echo "========================================"

# Actualizar paquetes
echo "[1/4] Actualizando paquetes del sistema..."
sudo dnf update -y

# Instalar Nginx y Git
echo "[2/4] Instalando Nginx y Git..."
sudo dnf install -y nginx git

# Iniciar y habilitar Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Clonar UI
echo "[3/4] Clonando vanilla-customers-ui-demo..."
cd /tmp
rm -rf vanilla-customers-ui-demo
git clone https://github.com/jriverox/vanilla-customers-ui-demo.git

# Copiar al directorio web
sudo cp -r vanilla-customers-ui-demo/* /usr/share/nginx/html/
sudo chown -R nginx:nginx /usr/share/nginx/html/

# Configurar URL de la API
echo "[4/4] Configurando URL de la API ($API_PRIVATE_IP)..."
# Buscar y reemplazar la URL de la API en los archivos JS
sudo find /usr/share/nginx/html -name "*.js" -exec \
  sudo sed -i "s|http://localhost:8000|http://$API_PRIVATE_IP:8000|g" {} \;
sudo find /usr/share/nginx/html -name "*.js" -exec \
  sudo sed -i "s|http://127.0.0.1:8000|http://$API_PRIVATE_IP:8000|g" {} \;

# Recargar Nginx
sudo systemctl reload nginx

echo ""
echo "========================================"
echo " ✅ UI Server configurado"
echo "========================================"
echo " Nginx corriendo en puerto 80"
echo " La UI apunta a la API en: http://$API_PRIVATE_IP:8000"
