# Paso 3 — EC2 Bastion Host

## ¿Qué vamos a hacer?

Lanzar la instancia EC2 que actuará como Bastion Host en la subnet pública, y configurar SSH Agent Forwarding para poder saltar desde el bastion hacia la instancia privada sin copiar el archivo `.pem` al bastion.

## ¿Por qué importa entender esto?

El Bastion Host (también llamado Jump Server) es el único punto de acceso SSH a los recursos de la red privada. La alternativa —abrir SSH directamente en la instancia privada hacia internet— eliminaría el propósito de tener una subnet privada.

Un detalle importante: **nunca copies tu archivo `.pem` al bastion**. Si el bastion fuera comprometido, el atacante tendría acceso a todas las instancias privadas. En cambio, usamos **SSH Agent Forwarding**: tu clave permanece en tu máquina local, y el bastion la "toma prestada" temporalmente para autenticarse en la instancia privada.

---

## Paso 3.1 — Lanzar la instancia Bastion

### Consola AWS

1. Ir a **EC2 → Instances → Launch instances**
2. Configurar:
   - **Name**: `team01-bastion`
   - **AMI**: Amazon Linux 2023 (gratuita en free tier)
   - **Instance type**: `t2.micro`
   - **Key pair**: seleccionar tu archivo `.pem` existente
3. **Network settings → Edit**:
   - **VPC**: `team01-vpc`
   - **Subnet**: `team01-public-subnet`
   - **Auto-assign public IP**: `Enable`
   - **Security group**: seleccionar `team01-sg-bastion`
4. Click en **Launch instance**

> ⏳ La instancia tarda ~1 minuto en pasar a estado `Running`.

### AWS CLI

```bash
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t2.micro \
  --key-name <NOMBRE_DE_TU_KEY_PAIR> \
  --subnet-id <PUBLIC_SUBNET_ID> \
  --security-group-ids <SG_BASTION_ID> \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team01-bastion}]'
```

> 💡 El AMI `ami-0c02fb55956c7d316` corresponde a Amazon Linux 2023 en us-east-1. Verifica el ID actualizado en la consola si hay problemas al lanzar.

---

## Paso 3.2 — Obtener la IP pública del Bastion

### Consola AWS

En **EC2 → Instances**, seleccionar `team01-bastion` y copiar el valor de **Public IPv4 address**.

### AWS CLI

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=team01-bastion" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text
```

---

## Paso 3.3 — Configurar SSH Agent Forwarding

Este paso se realiza en tu **máquina local**.

### macOS / Linux

```bash
# Agregar tu clave al agente SSH
ssh-add ~/.ssh/team01-key.pem

# Verificar que se agregó
ssh-add -l
```

Conéctate al bastion con el flag `-A` (Agent Forwarding) para verificar que funciona:

```bash
ssh -A -i ~/.ssh/team01-key.pem ec2-user@<BASTION_PUBLIC_IP>
```

> ℹ️ El salto desde el bastion hacia las otras instancias lo harás en los pasos 4 y 5, una vez que esas instancias estén creadas. Por ahora solo verificamos que el bastion es accesible y que el Agent Forwarding está activo.

### Windows (con PuTTY)

Si usas PuTTY, necesitas Pageant para el forwarding:

1. Convierte el `.pem` a `.ppk` con PuTTYgen
2. Carga la clave en Pageant
3. En PuTTY: **Connection → SSH → Auth → Allow agent forwarding** ✓
4. Conéctate al bastion; desde ahí usa `ssh ec2-user@<PRIVATE_IP>`

### Configuración permanente con `~/.ssh/config` (recomendado)

En lugar de recordar los flags cada vez, agrega esto a tu `~/.ssh/config` en tu máquina local. Puedes hacerlo ahora con la IP del bastion y completar las IPs de `team01-ui` y `team01-api` cuando las instancias estén creadas en los pasos 4 y 5:

```
Host team01-bastion
    HostName <BASTION_PUBLIC_IP>
    User ec2-user
    IdentityFile ~/.ssh/team01-key.pem
    ForwardAgent yes

Host team01-ui
    HostName <UI_PUBLIC_IP>
    User ec2-user
    IdentityFile ~/.ssh/team01-key.pem
    ProxyJump team01-bastion

Host team01-api
    HostName <API_PRIVATE_IP>
    User ec2-user
    IdentityFile ~/.ssh/team01-key.pem
    ProxyJump team01-bastion
```

Con esta config puedes conectarte a cualquier instancia desde tu máquina local con un solo comando:

```bash
ssh team01-ui    # EC2 pública — salta vía bastion automáticamente
ssh team01-api   # EC2 privada — salta vía bastion automáticamente
```

> 💡 `ProxyJump` hace el salto vía bastion de forma transparente. Nota que **incluso la instancia pública** requiere pasar por el bastion para SSH, porque su SG solo acepta conexiones SSH originadas desde `team01-sg-bastion`. Esto es intencional: el bastion es el único punto de entrada SSH a toda la VPC.

---

## ✅ Verificación

1. Puedes hacer SSH al bastion: `ssh -A -i ~/.ssh/team01-key.pem ec2-user@<BASTION_IP>`
2. Desde el bastion, `ssh-add -l` muestra tu clave (gracias al forwarding)
3. El archivo `.pem` NO existe en el bastion: `ls ~/.ssh/` no lo muestra

---

## Siguiente paso

👉 [Paso 4 — EC2 UI en subnet pública](04-ec2-public-ui.md)
