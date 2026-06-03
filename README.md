# Kali Linux Scripts
Scripts d'installation et configuration pour Kali Linux.

## Scripts disponibles
| Script | Description |
|--------|-------------|
| `install_packet_tracer.sh` | Installation automatique de Cisco Packet Tracer 9.0 sur Kali Linux |
| `install_gns3.sh` | Installation automatique de GNS3 3.0.6 avec FortiGate et OpenWrt |

## Utilisation

### Cisco Packet Tracer
```bash
bash install_packet_tracer.sh
```
> Télécharge d'abord le fichier `.deb` depuis [netacad.com](https://www.netacad.com)

### GNS3
```bash
bash install_gns3.sh
```
> Télécharge d'abord l'image FortiGate `.kvm.zip` depuis [support.fortinet.com](https://support.fortinet.com) (optionnel)

## Prérequis
- Kali Linux 2024/2025/2026
- Pour Packet Tracer : fichier `CiscoPacketTracer_900_Ubuntu_64bit.deb` dans `~/Downloads`
- Pour GNS3 : fichier `FGT_VM64_KVM-*.out.kvm.zip` dans `~/Downloads` (optionnel)

## Auteur
- **Abdallahi** - [GitHub](https://github.com/AB3288)
