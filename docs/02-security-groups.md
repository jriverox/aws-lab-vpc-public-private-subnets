# Paso 2 — Security Groups

## ¿Qué vamos a hacer?

Crear tres Security Groups, uno por cada instancia EC2: bastion, UI y API. Cada uno tendrá las reglas mínimas necesarias para que el sistema funcione.

## ¿Por qué importa entender esto?

Los Security Groups son el firewall stateful de AWS a nivel de instancia. A diferencia de las NACLs (que operan a nivel de subnet y son stateless), los Security Groups recuerdan el estado de las conexiones: si permites tráfico entrante en un puerto, la respuesta puede salir sin necesidad de una regla explícita de salida.

La filosofía correcta es **least privilege**: permitir únicamente lo estrictamente necesario. En esta arquitectura eso se traduce en:

- El bastion solo acepta SSH desde tu IP
- La UI acepta HTTP desde cualquier lugar, pero SSH solo desde el bastion
- La API no tiene ningún puerto expuesto a internet; solo acepta tráfico desde la subnet pública

---

## Paso 2.1 — Security Group del Bastion

### Consola AWS

1. Ir a **EC2 → Security Groups → Create security group**
2. Configurar:
   - **Name**: `team01-sg-bastion`
   - **Description**: `SSH access to bastion host`
   - **VPC**: `team01-vpc`
3. **Inbound rules → Add rule**:
   - Type: `SSH` | Protocol: `TCP` | Port: `22` | Source: `My IP`
4. **Outbound rules**: dejar la regla por defecto (`All traffic, 0.0.0.0/0`)
5. Click en **Create security group**

> 💡 Usar `My IP` en la regla SSH hace que AWS detecte automáticamente tu IP pública actual. En un entorno real, considera también documentar el rango CIDR de tu VPN corporativa si accedes desde ella.

### AWS CLI

```bash
# Crear el Security Group
aws ec2 create-security-group \
  --group-name team01-sg-bastion \
  --description "SSH access to bastion host" \
  --vpc-id <VPC_ID>

# Agregar regla SSH desde tu IP
aws ec2 authorize-security-group-ingress \
  --group-id <SG_BASTION_ID> \
  --protocol tcp \
  --port 22 \
  --cidr <TU_IP>/32
```

> Para obtener tu IP pública: `curl -s https://checkip.amazonaws.com`

---

## Paso 2.2 — Security Group de la UI

### Consola AWS

1. Crear nuevo Security Group:
   - **Name**: `team01-sg-ui`
   - **Description**: `HTTP public + SSH from bastion`
   - **VPC**: `team01-vpc`
2. **Inbound rules** — agregar 2 reglas:

   | Type | Protocol | Port | Source | Descripción |
   |---|---|---|---|---|
   | HTTP | TCP | 80 | `0.0.0.0/0` | Tráfico web público |
   | SSH | TCP | 22 | `team01-sg-bastion` | Solo desde el bastion |

3. **Outbound**: dejar por defecto

> 💡 En la regla SSH, en lugar de poner una IP, selecciona el Security Group del bastion como fuente. Esto es más robusto que una IP: si la IP del bastion cambia (porque se reinicia), la regla sigue funcionando.

### AWS CLI

```bash
aws ec2 create-security-group \
  --group-name team01-sg-ui \
  --description "HTTP public + SSH from bastion" \
  --vpc-id <VPC_ID>

# HTTP público
aws ec2 authorize-security-group-ingress \
  --group-id <SG_UI_ID> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# SSH solo desde el bastion (referencia por SG)
aws ec2 authorize-security-group-ingress \
  --group-id <SG_UI_ID> \
  --protocol tcp \
  --port 22 \
  --source-group <SG_BASTION_ID>
```

---

## Paso 2.3 — Security Group de la API

### Consola AWS

1. Crear nuevo Security Group:
   - **Name**: `team01-sg-api`
   - **Description**: `API access from public subnet + SSH from bastion`
   - **VPC**: `team01-vpc`
2. **Inbound rules** — agregar 2 reglas:

   | Type | Protocol | Port | Source | Descripción |
   |---|---|---|---|---|
   | Custom TCP | TCP | 8000 | `10.0.1.0/24` | FastAPI desde subnet publica |
   | SSH | TCP | 22 | `team01-sg-bastion` | Solo desde el bastion |

3. **Outbound**: dejar por defecto

> 💡 Para el puerto 8000 usamos el CIDR de la subnet pública (`10.0.1.0/24`) como fuente. Esto significa que cualquier instancia en esa subnet puede llamar a la API, que es exactamente lo que queremos (la UI llama a la API). Podrías ser más restrictivo y poner solo el SG de la UI, lo cual es la práctica recomendada en producción.

### AWS CLI

```bash
aws ec2 create-security-group \
  --group-name team01-sg-api \
  --description "API access from public subnet + SSH from bastion" \
  --vpc-id <VPC_ID>

# Puerto FastAPI desde subnet pública
aws ec2 authorize-security-group-ingress \
  --group-id <SG_API_ID> \
  --protocol tcp \
  --port 8000 \
  --cidr 10.0.1.0/24

# SSH solo desde el bastion
aws ec2 authorize-security-group-ingress \
  --group-id <SG_API_ID> \
  --protocol tcp \
  --port 22 \
  --source-group <SG_BASTION_ID>
```

---

## ✅ Verificación

En **EC2 → Security Groups** deberías ver los 3 grupos creados con sus reglas:

| Security Group | Inbound |
|---|---|
| `team01-sg-bastion` | SSH :22 desde tu IP |
| `team01-sg-ui` | HTTP :80 desde 0.0.0.0/0, SSH :22 desde sg-bastion |
| `team01-sg-api` | TCP :8000 desde 10.0.1.0/24, SSH :22 desde sg-bastion |

---

## Siguiente paso

👉 [Paso 3 — EC2 Bastion Host](03-ec2-bastion.md)
