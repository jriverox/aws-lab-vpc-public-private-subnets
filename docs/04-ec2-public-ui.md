# Paso 4 — EC2 UI en Subnet Pública

## ¿Qué vamos a hacer?

Lanzar la instancia EC2 pública que servirá la aplicación web (UI), instalar Nginx, y desplegar la aplicación clonando el repositorio [vanilla-customers-ui-demo](https://github.com/jriverox/vanilla-customers-ui-demo).

---

## Paso 4.1 — Lanzar la instancia

### Consola AWS

1. Ir a **EC2 → Instances → Launch instances**
2. Configurar:
   - **Name**: `team01-ui-server`
   - **AMI**: Amazon Linux 2023
   - **Instance type**: `t2.micro`
   - **Key pair**: el mismo `.pem` que usaste para el bastion
3. **Network settings → Edit**:
   - **VPC**: `team01-vpc`
   - **Subnet**: `team01-public-subnet`
   - **Auto-assign public IP**: `Enable`
   - **Security group**: `team01-sg-ui`
4. Click en **Launch instance**

### AWS CLI

```bash
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t2.micro \
  --key-name <NOMBRE_DE_TU_KEY_PAIR> \
  --subnet-id <PUBLIC_SUBNET_ID> \
  --security-group-ids <SG_UI_ID> \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-ui-server}]'
```

---

## Paso 4.2 — Conectarse a la instancia UI

A diferencia del bastion, puedes conectarte directamente a la UI (también está en la subnet pública):

```bash
ssh -i ~/.ssh/team01-key.pem ec2-user@<UI_PUBLIC_IP>
```

O si configuraste `~/.ssh/config` en el paso anterior, puedes usar ProxyJump desde el bastion. Cualquier opción funciona para esta instancia.

---

## Paso 4.3 — Instalar dependencias y desplegar la UI

Una vez conectado a `team01-ui-server`, ejecuta los siguientes comandos:

```bash
# Actualizar paquetes del sistema
sudo dnf update -y

# Instalar Nginx y Git
sudo dnf install -y nginx git

# Iniciar Nginx y habilitarlo para que arranque con el sistema
sudo systemctl start nginx
sudo systemctl enable nginx

# Verificar que Nginx está corriendo
sudo systemctl status nginx
```

```bash
# Clonar la aplicación UI en el directorio de Nginx
cd /tmp
git clone https://github.com/jriverox/vanilla-customers-ui-demo.git

# Copiar los archivos al directorio web de Nginx
sudo cp -r vanilla-customers-ui-demo/* /usr/share/nginx/html/
```

```bash
# Verificar los archivos copiados
ls /usr/share/nginx/html/
```

### Configurar la URL de la API

La UI necesita saber dónde está la API. Edita el archivo de configuración o la variable en el código que apunta al endpoint de la API:

```bash
# Revisar el archivo de configuración de la UI (puede variar según el repo)
cat /usr/share/nginx/html/config.js
# o buscar dónde está la URL de la API:
grep -r "localhost\|8000\|api" /usr/share/nginx/html/ --include="*.js"
```

Reemplaza la URL de la API con la IP privada de `team01-api-server` (la obtendrás en el paso 5):

```bash
# Ejemplo (ajusta el archivo y variable según corresponda):
sudo sed -i 's|http://localhost:8000|http://<API_PRIVATE_IP>:8000|g' /usr/share/nginx/html/config.js
```

---

## Paso 4.4 — Verificar el despliegue

En tu navegador, accede a:

```
http://<UI_PUBLIC_IP>
```

Deberías ver la aplicación UI cargando. En este punto la UI puede mostrar errores de conexión a la API, lo cual es esperado: todavía no hemos desplegado la API. Eso lo haremos en el siguiente paso.

> 💡 Si Nginx no sirve los archivos correctamente, verifica los permisos: `sudo chown -R nginx:nginx /usr/share/nginx/html/`

---

## ✅ Verificación

- La instancia `team01-ui-server` está en estado `Running`
- Nginx responde en el puerto 80: `curl http://<UI_PUBLIC_IP>`
- Los archivos de la UI están en `/usr/share/nginx/html/`

---

## Siguiente paso

👉 [Paso 5 — EC2 API en subnet privada](05-ec2-private-api.md)
