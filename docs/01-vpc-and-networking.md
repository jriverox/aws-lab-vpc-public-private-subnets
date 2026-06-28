# Paso 1 — VPC y Networking

## ¿Qué vamos a hacer?

Crear la red base de nuestra arquitectura: una VPC con dos subnets (pública y privada), un Internet Gateway para dar acceso a internet a la subnet pública, un NAT Gateway para que la subnet privada pueda salir a internet sin ser accesible desde afuera, y las Route Tables que conectan todo.

## ¿Por qué importa entender esto?

Una VPC (Virtual Private Cloud) es tu red privada dentro de AWS. Todo lo que despliegues en AWS vive dentro de una VPC. Pensar bien en la segmentación de red desde el principio es lo que separa una arquitectura segura de una que expone más de lo necesario.

La diferencia clave entre subnet pública y privada no es mágica: **es simplemente la tabla de rutas**. Una subnet es "pública" porque su Route Table tiene una ruta hacia un Internet Gateway. Una subnet es "privada" porque no la tiene. El NAT Gateway permite que recursos privados inicien conexiones hacia internet (para descargar paquetes, por ejemplo) sin que internet pueda iniciar conexiones hacia ellos.

---

## Paso 1.1 — Crear la VPC

### Consola AWS

1. Ir a **VPC → Your VPCs → Create VPC**
2. Seleccionar **VPC only**
3. Configurar:
   - **Name tag**: `team01-vpc`
   - **IPv4 CIDR block**: `10.0.0.0/16`
   - **Tenancy**: Default
4. Click en **Create VPC**

> 💡 El bloque CIDR `/16` nos da 65,536 direcciones IP disponibles para distribuir entre subnets. Es más que suficiente para este lab y para arquitecturas reales de tamaño medio.

### AWS CLI

```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=team01-vpc}]' \
  --region us-east-1
```

Guarda el `VpcId` del output. Lo necesitarás en los siguientes pasos.

---

## Paso 1.2 — Crear las Subnets

### Consola AWS

**Subnet Pública:**

1. Ir a **VPC → Subnets → Create subnet**
2. Configurar:
   - **VPC**: seleccionar `team01-vpc`
   - **Subnet name**: `team01-public-subnet`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.1.0/24`
3. Click en **Create subnet**

**Subnet Privada:**

1. Click en **Create subnet** nuevamente
2. Configurar:
   - **VPC**: seleccionar `team01-vpc`
   - **Subnet name**: `team01-private-subnet`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.2.0/24`
3. Click en **Create subnet**

> 💡 Usamos `/24` para cada subnet, lo que da 256 direcciones (251 utilizables, AWS reserva 5). Mantenemos ambas en `us-east-1a` para simplificar el lab; en producción distribuirías entre múltiples AZs.

### AWS CLI

```bash
# Subnet pública
aws ec2 create-subnet \
  --vpc-id <VPC_ID> \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=team01-public-subnet}]'

# Subnet privada
aws ec2 create-subnet \
  --vpc-id <VPC_ID> \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=team01-private-subnet}]'
```

---

## Paso 1.3 — Crear el Internet Gateway

El Internet Gateway (IGW) es el componente que conecta tu VPC con internet. Sin él, nada dentro de la VPC puede comunicarse con el exterior.

### Consola AWS

1. Ir a **VPC → Internet Gateways → Create internet gateway**
2. **Name tag**: `team01-igw`
3. Click en **Create internet gateway**
4. Una vez creado, click en **Actions → Attach to VPC**
5. Seleccionar `team01-vpc` y confirmar

> ⚠️ El IGW queda en estado `detached` hasta que lo adjuntas a una VPC. No olvides este paso.

### AWS CLI

```bash
# Crear el IGW
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=team01-igw}]'

# Adjuntarlo a la VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id <IGW_ID> \
  --vpc-id <VPC_ID>
```

---

## Paso 1.4 — Crear el NAT Gateway

El NAT Gateway permite que las instancias en la subnet privada puedan salir a internet (para instalar dependencias, por ejemplo) sin ser accesibles desde afuera. Requiere una Elastic IP.

### Consola AWS

**Primero, asignar una Elastic IP:**

1. Ir a **EC2 → Elastic IPs → Allocate Elastic IP address**
2. Dejar configuración por defecto y click en **Allocate**
3. Anota el `Allocation ID`

**Crear el NAT Gateway:**

1. Ir a **VPC → NAT Gateways → Create NAT gateway**
2. Configurar:
   - **Name**: `team01-natgw`
   - **Subnet**: `team01-public-subnet` ← debe ir en la subnet **pública**
   - **Connectivity type**: Public
   - **Elastic IP**: seleccionar la IP que acabas de asignar
3. Click en **Create NAT gateway**

> 💡 El NAT Gateway siempre se crea en la subnet **pública** porque necesita acceso a internet. Las instancias privadas enrutan su tráfico de salida hacia él.

> ⏳ El NAT Gateway tarda 1-2 minutos en quedar en estado `Available`.

### AWS CLI

```bash
# Asignar Elastic IP
aws ec2 allocate-address --domain vpc

# Crear NAT Gateway en la subnet pública
aws ec2 create-nat-gateway \
  --subnet-id <PUBLIC_SUBNET_ID> \
  --allocation-id <EIP_ALLOCATION_ID> \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=team01-natgw}]'
```

---

## Paso 1.5 — Crear las Route Tables

Las Route Tables definen hacia dónde va el tráfico que sale de cada subnet. Este es el mecanismo real que hace que una subnet sea "pública" o "privada".

### Consola AWS

**Route Table pública:**

1. Ir a **VPC → Route Tables → Create route table**
2. Configurar:
   - **Name**: `team01-public-rt`
   - **VPC**: `team01-vpc`
3. Click en **Create route table**
4. Seleccionar `team01-public-rt` → pestaña **Routes → Edit routes**
5. Click en **Add route**:
   - **Destination**: `0.0.0.0/0`
   - **Target**: seleccionar `team01-igw`
6. Guardar cambios
7. Pestaña **Subnet associations → Edit subnet associations**
8. Seleccionar `team01-public-subnet` y guardar

**Route Table privada:**

1. Crear otra route table con nombre `team01-private-rt` en `team01-vpc`
2. Agregar ruta:
   - **Destination**: `0.0.0.0/0`
   - **Target**: seleccionar `team01-natgw`
3. Asociar a `team01-private-subnet`

> 💡 La ruta `0.0.0.0/0` significa "todo el tráfico que no tenga una ruta más específica". En la tabla pública apunta al IGW (internet real). En la privada apunta al NAT Gateway (salida controlada).

### AWS CLI

```bash
# Route table pública
aws ec2 create-route-table \
  --vpc-id <VPC_ID> \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=team01-public-rt}]'

aws ec2 create-route \
  --route-table-id <PUBLIC_RT_ID> \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id <IGW_ID>

aws ec2 associate-subnet-with-route-table \
  --subnet-id <PUBLIC_SUBNET_ID> \
  --route-table-id <PUBLIC_RT_ID>

# Route table privada
aws ec2 create-route-table \
  --vpc-id <VPC_ID> \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=team01-private-rt}]'

aws ec2 create-route \
  --route-table-id <PRIVATE_RT_ID> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <NATGW_ID>

aws ec2 associate-subnet-with-route-table \
  --subnet-id <PRIVATE_SUBNET_ID> \
  --route-table-id <PRIVATE_RT_ID>
```

---

## ✅ Verificación

Al terminar este paso, deberías poder ver en la consola:

- **VPC** `team01-vpc` en estado `Available`
- **2 subnets** asociadas a la VPC
- **IGW** `team01-igw` en estado `Attached`
- **NAT Gateway** `team01-natgw` en estado `Available`
- **2 Route Tables** con sus subnets asociadas y rutas configuradas

---

## Siguiente paso

👉 [Paso 2 — Security Groups](02-security-groups.md)
