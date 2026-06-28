# AWS Lab — VPC con Subnets Pública y Privada

> Lab práctico para implementar una arquitectura de red básica en AWS con VPC, subnets pública y privada, NAT Gateway y EC2 en dos capas, usando un Bastion Host para acceso seguro.

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![EC2](https://img.shields.io/badge/EC2-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![VPC](https://img.shields.io/badge/VPC-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)

---

## 📋 Descripción

Este lab te guía paso a paso en la implementación de una arquitectura de red clásica en AWS, cubriendo los conceptos fundamentales de redes en la nube: VPCs, subnets, tablas de rutas, gateways y seguridad a nivel de red.

La arquitectura despliega una aplicación web simple en dos capas:
- Una **capa de presentación** (UI en Nginx) en una subnet pública, accesible desde internet.
- Una **capa de backend** (API en FastAPI) en una subnet privada, sin acceso directo desde internet.
- Un **Bastion Host** en la subnet pública como único punto de entrada SSH hacia la instancia privada.

Cada sección incluye los pasos via **Consola AWS** y su equivalente en **AWS CLI**, para que puedas elegir el flujo que prefieras.

---

## 🏗️ Arquitectura

```
Internet
    │
    ▼
[Internet Gateway - team01-igw]
    │
    ▼
┌──────────────────────────────────────────────┐
│  VPC: team01-vpc  (10.0.0.0/16)              │
│                                              │
│  ┌─────────────────────────────────────┐     │
│  │  Subnet Pública (10.0.1.0/24)       │     │
│  │                                     │     │
│  │  [team01-bastion]   [team01-ui]     │     │
│  │  Bastion Host       Nginx + UI      │     │
│  │       │                             │     │
│  └───────┼─────────────────────────────┘     │
│          │ SSH           │                   │
│          │         [NAT Gateway]             │
│  ┌───────┼─────────────────────────────┐     │
│  │  Subnet Privada (10.0.2.0/24)       │     │
│  │                                     │     │
│  │  [team01-api]                       │     │
│  │  FastAPI                            │     │
│  └─────────────────────────────────────┘     │
└──────────────────────────────────────────────┘
```

---

## 📦 Recursos que se crean

| Recurso | Nombre | Descripción |
|---|---|---|
| VPC | `team01-vpc` | Red privada virtual, CIDR 10.0.0.0/16 |
| Subnet pública | `team01-public-subnet` | 10.0.1.0/24, us-east-1a |
| Subnet privada | `team01-private-subnet` | 10.0.2.0/24, us-east-1a |
| Internet Gateway | `team01-igw` | Permite tráfico hacia/desde internet |
| NAT Gateway | `team01-natgw` | Permite a la subnet privada salir a internet |
| Route Table pública | `team01-public-rt` | Rutas para subnet pública |
| Route Table privada | `team01-private-rt` | Rutas para subnet privada vía NAT |
| Security Group Bastion | `team01-sg-bastion` | SSH desde tu IP |
| Security Group UI | `team01-sg-ui` | HTTP público + SSH desde bastion |
| Security Group API | `team01-sg-api` | Puerto 8000 desde subnet pública + SSH desde bastion |
| EC2 Bastion | `team01-bastion` | t2.micro, subnet pública |
| EC2 UI | `team01-ui-server` | t2.micro, subnet pública, Nginx + UI |
| EC2 API | `team01-api-server` | t2.micro, subnet privada, FastAPI |

---

## 🚀 Prerrequisitos

- Cuenta de AWS activa con permisos para crear VPC, EC2, y recursos de red
- AWS CLI instalado y configurado (`aws configure`)
- Un Key Pair `.pem` disponible (se usará para las 3 instancias)
- Conocimiento básico de SSH y línea de comandos

> ⚠️ **Costo estimado**: Los recursos de este lab generan costos, principalmente el NAT Gateway (~$0.045/hora) y las instancias EC2. Recuerda ejecutar el script de limpieza al terminar.

---

## 📚 Guía del Lab

Sigue los documentos en orden:

| Paso | Documento | Qué cubre |
|---|---|---|
| 1 | [VPC y Networking](docs/01-vpc-and-networking.md) | VPC, subnets, IGW, NAT GW, Route Tables |
| 2 | [Security Groups](docs/02-security-groups.md) | Reglas de seguridad para cada capa |
| 3 | [EC2 Bastion Host](docs/03-ec2-bastion.md) | Lanzar el bastion y configurar SSH Agent Forwarding |
| 4 | [EC2 UI (pública)](docs/04-ec2-public-ui.md) | Lanzar instancia pública y desplegar la UI |
| 5 | [EC2 API (privada)](docs/05-ec2-private-api.md) | Acceder vía bastion y desplegar la API |
| — | [Flujo alternativo CLI](docs/06-aws-cli-alternative.md) | Todo el lab en AWS CLI con scripts |

---

## 🧹 Limpieza de recursos

Para eliminar todos los recursos y evitar cargos:

```bash
cd scripts/cli
cp config.env.example config.env  # edita con tus IDs reales
bash cleanup.sh
```

---

## ✍️ Autor

**Jhony Rivero**
- GitHub: [@jriverox](https://github.com/jriverox)

---

⭐ Si este lab te fue útil, considera darle una estrella en GitHub
