# Paso 5 — EC2 API en Subnet Privada

## ¿Qué vamos a hacer?

Lanzar la instancia EC2 en la subnet privada, acceder a ella vía bastion, instalar Python y las dependencias de FastAPI, y desplegar la API clonando el repositorio [fastapi-customers-api-demo](https://github.com/jriverox/fastapi-customers-api-demo).

## ¿Por qué importa entender esto?

Esta instancia no tiene IP pública y no puede recibir tráfico de internet directamente. Solo es accesible desde dentro de la VPC. Sin embargo, **sí puede salir a internet** gracias al NAT Gateway (necesario para clonar el repo y descargar dependencias).

Este es el patrón correcto para backends: aislados de internet, accesibles solo desde la capa de presentación o desde el bastion para administración.

---

## Paso 5.1 — Lanzar la instancia API

### Consola AWS

1. Ir a **EC2 → Instances → Launch instances**
2. Configurar:
   - **Name**: `team01-api-server`
   - **AMI**: Amazon Linux 2023
   - **Instance type**: `t2.micro`
   - **Key pair**: el mismo `.pem`
3. **Network settings → Edit**:
   - **VPC**: `team01-vpc`
   - **Subnet**: `team01-private-subnet`
   - **Auto-assign public IP**: `Disable` ← importante
   - **Security group**: `team01-sg-api`
4. Click en **Launch instance**

### AWS CLI

```bash
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t2.micro \
  --key-name <NOMBRE_DE_TU_KEY_PAIR> \
  --subnet-id <PRIVATE_SUBNET_ID> \
  --security-group-ids <SG_API_ID> \
  --no-associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-api-server}]'
```

---

## Paso 5.2 — Obtener la IP privada de la instancia API

### Consola AWS

En **EC2 → Instances**, seleccionar `team01-api-server`. Copiar el valor de **Private IPv4 address** (algo como `10.0.2.x`). No tendrá IP pública.

### AWS CLI

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=team01-api-server" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text
```

---

## Paso 5.3 — Conectarse a la instancia privada vía Bastion

Desde tu **máquina local** (con SSH Agent Forwarding activo):

```bash
# Primero, conectarse al bastion con Agent Forwarding
ssh -A -i ~/.ssh/team01-key.pem ec2-user@<BASTION_PUBLIC_IP>

# Desde el bastion, saltar a la instancia privada
ssh ec2-user@<API_PRIVATE_IP>
```

**Alternativa con ProxyJump (desde tu máquina local directamente):**

```bash
ssh -A -i ~/.ssh/team01-key.pem \
  -o ProxyCommand="ssh -A -i ~/.ssh/team01-key.pem -W %h:%p ec2-user@<BASTION_PUBLIC_IP>" \
  ec2-user@<API_PRIVATE_IP>
```

> 💡 Si configuraste `~/.ssh/config` en el paso 3, un simple `ssh team01-private-api` (con la IP configurada) hace todo esto automáticamente.

---

## Paso 5.4 — Instalar dependencias y desplegar la API

Una vez conectado a `team01-api-server`:

```bash
# Actualizar paquetes
sudo dnf update -y

# Instalar Python 3.11, pip y Git
sudo dnf install -y python3.11 python3.11-pip git

# Verificar versiones
python3.11 --version
git --version
```

```bash
# Clonar el repositorio de la API
cd ~
git clone https://github.com/jriverox/fastapi-customers-api-demo.git
cd fastapi-customers-api-demo
```

```bash
# Crear entorno virtual e instalar dependencias
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

```bash
# Verificar que la API arranca correctamente
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Si ves algo como `Application startup complete` en la salida, la API está funcionando. Presiona `Ctrl+C` para detenerla; en el siguiente paso la configuraremos como servicio.

---

## Paso 5.5 — Configurar la API como servicio systemd

Para que la API arranque automáticamente y se mantenga corriendo, la registramos como un servicio del sistema:

```bash
# Crear el archivo de servicio
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

[Install]
WantedBy=multi-user.target
EOF

# Habilitar e iniciar el servicio
sudo systemctl daemon-reload
sudo systemctl enable fastapi-customers
sudo systemctl start fastapi-customers

# Verificar estado
sudo systemctl status fastapi-customers
```

---

## Paso 5.6 — Verificar conectividad entre UI y API

Desde la instancia `team01-ui-server` (o desde el bastion), prueba que la API responde:

```bash
# Desde team01-ui-server o desde el bastion
curl http://<API_PRIVATE_IP>:8000/docs
# o
curl http://<API_PRIVATE_IP>:8000/customers
```

Si recibes una respuesta JSON o la página de Swagger, la conectividad está funcionando correctamente.

---

## Paso 5.7 — Actualizar la URL de la API en la UI

Vuelve a la instancia `team01-ui-server` y actualiza la URL de la API con la IP privada real:

```bash
sudo sed -i 's|http://localhost:8000|http://<API_PRIVATE_IP>:8000|g' /usr/share/nginx/html/config.js
```

Recarga Nginx:

```bash
sudo systemctl reload nginx
```

Ahora accede desde tu navegador a `http://<UI_PUBLIC_IP>` y la UI debería conectarse exitosamente a la API.

---

## ✅ Verificación final de la arquitectura

| Verificación | Cómo validarla |
|---|---|
| UI accesible desde internet | `http://<UI_PUBLIC_IP>` en el navegador |
| API NO accesible desde internet | `http://<API_PRIVATE_IP>:8000` desde tu navegador debe fallar |
| API accesible desde la subnet pública | `curl http://<API_PRIVATE_IP>:8000` desde `team01-ui-server` |
| Instancia privada sin IP pública | En la consola, `team01-api-server` no muestra Public IP |
| SSH a instancia privada solo vía bastion | Intentar SSH directo a la IP privada desde tu máquina debe fallar |

---

## Siguiente paso

Si quieres ver todos los pasos anteriores en formato AWS CLI automatizado:

👉 [Flujo alternativo — AWS CLI completo](06-aws-cli-alternative.md)

Cuando termines el lab:

👉 [Limpieza de recursos](../scripts/cli/cleanup.sh)
