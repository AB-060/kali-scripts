#!/bin/bash
# =============================================================================
# Script d'Amélioration du Modèle Zabbix - Version Professionnelle
# =============================================================================
# Auteur   : Admin Zabbix
# Date     : Juillet 2026
# Version  : 2.0
# =============================================================================
# Ce script automatise l'optimisation des modèles Zabbix pour :
#   - Structuration en templates
#   - Optimisation des items et triggers
#   - Configuration des Value Mappings
#   - Mise en place des Macros
#   - Activation de la Low-Level Discovery (LLD)
# =============================================================================

set -e  # Arrêt du script en cas d'erreur

# --- Couleurs pour l'affichage ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Variables de configuration ---
ZABBIX_SERVER_IP="192.168.56.10"
ZABBIX_URL="http://$ZABBIX_SERVER_IP/zabbix"
ZABBIX_USER="Admin"
ZABBIX_PASSWORD="zabbix"
TEMPLATE_NAME="MY_Network_Device_Template"

# --- Fonctions ---
print_header() {
    echo -e "\n${BLUE}==================================================${NC}"
    echo -e "${BLUE}   $1${NC}"
    echo -e "${BLUE}==================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

check_prerequisites() {
    print_header "Vérification des prérequis"
    
    # Vérifier si Zabbix est installé
    if ! systemctl is-active --quiet zabbix-server; then
        print_error "Zabbix Server n'est pas en cours d'exécution"
        exit 1
    fi
    print_success "Zabbix Server est actif"
    
    # Vérifier les outils nécessaires
    for cmd in curl jq mysql; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd n'est pas installé. Installation en cours..."
            sudo apt-get install -y curl jq mysql-client
        fi
    done
    print_success "Tous les outils sont disponibles"
}

get_api_token() {
    print_header "Récupération du token API"
    
    RESPONSE=$(curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "user.login",
            "params": {
                "username": "'$ZABBIX_USER'",
                "password": "'$ZABBIX_PASSWORD'"
            },
            "id": 1,
            "auth": null
        }')
    
    TOKEN=$(echo $RESPONSE | jq -r '.result')
    
    if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
        print_error "Impossible de se connecter à l'API Zabbix"
        echo $RESPONSE | jq '.'
        exit 1
    fi
    
    print_success "Token API récupéré : $TOKEN"
    echo $TOKEN
}

create_template_structure() {
    print_header "Création de la structure de templates"
    
    # 1. Créer un groupe d'hôtes pour les équipements réseau
    print_info "Création du groupe d'hôtes 'Network Devices'"
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "hostgroup.create",
            "params": {
                "name": "Network Devices"
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    # 2. Créer un template parent pour tous les équipements réseau
    print_info "Création du template 'Network_Device_Base'"
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "template.create",
            "params": {
                "host": "Network_Device_Base",
                "groups": {
                    "groupid": 1
                },
                "description": "Template de base pour tous les équipements réseau",
                "tags": [
                    {
                        "tag": "type",
                        "value": "network"
                    },
                    {
                        "tag": "environment",
                        "value": "production"
                    }
                ]
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    print_success "Structure de templates créée"
}

create_value_mappings() {
    print_header "Création des Value Mappings"
    
    # Value Mapping pour l'état des ports (UP/DOWN)
    print_info "Création du Value Mapping 'Port Status'"
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "valuemap.create",
            "params": {
                "name": "Port Status",
                "mappings": [
                    {
                        "value": "1",
                        "newvalue": "Up"
                    },
                    {
                        "value": "2",
                        "newvalue": "Down"
                    },
                    {
                        "value": "3",
                        "newvalue": "Testing"
                    },
                    {
                        "value": "4",
                        "newvalue": "Unknown"
                    }
                ]
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    # Value Mapping pour les états des équipements
    print_info "Création du Value Mapping 'Device Status'"
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "valuemap.create",
            "params": {
                "name": "Device Status",
                "mappings": [
                    {
                        "value": "0",
                        "newvalue": "Unavailable"
                    },
                    {
                        "value": "1",
                        "newvalue": "Available"
                    },
                    {
                        "value": "2",
                        "newvalue": "Degraded"
                    }
                ]
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    print_success "Value Mappings créés"
}

create_network_template() {
    print_header "Création du template avancé pour équipements réseau"
    
    # Créer un template avancé pour les équipements réseau
    print_info "Création du template '$TEMPLATE_NAME'"
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "template.create",
            "params": {
                "host": "'$TEMPLATE_NAME'",
                "groups": {
                    "groupid": 1
                },
                "description": "Template avancé pour équipements réseau avec LLD et macros",
                "tags": [
                    {
                        "tag": "type",
                        "value": "network_device"
                    },
                    {
                        "tag": "monitoring",
                        "value": "advanced"
                    }
                ]
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    print_success "Template '$TEMPLATE_NAME' créé"
}

add_lld_discovery() {
    print_header "Configuration de la Low-Level Discovery (LLD)"
    
    print_info "Ajout de la règle de découverte pour les interfaces réseau"
    
    # Créer une règle de découverte LLD pour les interfaces
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "discoveryrule.create",
            "params": {
                "name": "Discover network interfaces",
                "key_": "net.if.discovery",
                "hostid": "10001",
                "type": 2,
                "snmp_community": "{$SNMP_COMMUNITY}",
                "snmp_oid": "discovery",
                "snmpv3_contextname": "",
                "snmpv3_securityname": "{$SNMPV3_SECURITY_NAME}",
                "snmpv3_securitylevel": 3,
                "snmpv3_authprotocol": "0",
                "snmpv3_authpassphrase": "{$SNMPV3_AUTH_PASSPHRASE}",
                "snmpv3_privprotocol": "0",
                "snmpv3_privpassphrase": "{$SNMPV3_PRIV_PASSPHRASE}"
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    print_success "Règle de découverte LLD ajoutée"
}

add_macros() {
    print_header "Configuration des Macros avancées"
    
    print_info "Ajout des macros par défaut pour le template"
    
    # Macros pour les seuils
    MACROS='[
        {
            "macroid": "10001",
            "macro": "{$SNMP_COMMUNITY}",
            "value": "public"
        },
        {
            "macroid": "10002", 
            "macro": "{$SNMPV3_SECURITY_NAME}",
            "value": "zabbix-monitor"
        },
        {
            "macroid": "10003",
            "macro": "{$SNMPV3_AUTH_PASSPHRASE}",
            "value": "AuthPass2026"
        },
        {
            "macroid": "10004",
            "macro": "{$SNMPV3_PRIV_PASSPHRASE}",
            "value": "PrivPass2026"
        },
        {
            "macroid": "10005",
            "macro": "{$CPU.UTIL.CRIT}",
            "value": "90"
        },
        {
            "macroid": "10006",
            "macro": "{$CPU.UTIL.WARN}",
            "value": "75"
        },
        {
            "macroid": "10007",
            "macro": "{$MEM.UTIL.CRIT}",
            "value": "90"
        },
        {
            "macroid": "10008",
            "macro": "{$MEM.UTIL.WARN}",
            "value": "80"
        },
        {
            "macroid": "10009",
            "macro": "{$IF.BAND.MAX}",
            "value": "80"
        }
    ]'
    
    for MACRO in $(echo $MACROS | jq -c '.[]'); do
        MACRO_NAME=$(echo $MACRO | jq -r '.macro')
        MACRO_VALUE=$(echo $MACRO | jq -r '.value')
        print_info "Ajout de la macro $MACRO_NAME = $MACRO_VALUE"
        
        curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
            -H "Content-Type: application/json-rpc" \
            -d '{
                "jsonrpc": "2.0",
                "method": "usermacro.create",
                "params": {
                    "hostid": "10001",
                    "macro": "'$MACRO_NAME'",
                    "value": "'$MACRO_VALUE'"
                },
                "auth": "'$TOKEN'",
                "id": 1
            }' | jq '.'
    done
    
    print_success "Macros ajoutées"
}

create_triggers() {
    print_header "Création des Triggers intelligents"
    
    print_info "Création des triggers avec macros contextuelles"
    
    # Trigger pour la disponibilité de l'équipement
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "trigger.create",
            "params": {
                "description": "Équipement indisponible",
                "expression": "last(/Network_Device_Base/icmpping)=0",
                "priority": 5,
                "comments": "L\'équipement ne répond plus au ping",
                "tags": [
                    {
                        "tag": "category",
                        "value": "availability"
                    }
                ]
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    # Trigger CPU surchargé (avec macro)
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "trigger.create",
            "params": {
                "description": "CPU surchargé sur {HOST.NAME}",
                "expression": "min(/Network_Device_Base/system.cpu.util,5m) > {$CPU.UTIL.CRIT}",
                "priority": 4,
                "comments": "L\'utilisation du CPU dépasse {$CPU.UTIL.CRIT}% depuis 5 minutes",
                "tags": [
                    {
                        "tag": "category",
                        "value": "performance"
                    }
                ]
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    # Trigger pour les ports (avec macro contextuelle)
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "trigger.create",
            "params": {
                "description": "Port {#IFNAME} en panne",
                "expression": "last(/Network_Device_Base/net.if.status[{#IFINDEX}])=2",
                "priority": 3,
                "comments": "Le port {#IFNAME} est DOWN",
                "tags": [
                    {
                        "tag": "category",
                        "value": "interface"
                    },
                    {
                        "tag": "interface",
                        "value": "{#IFNAME}"
                    }
                ]
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq '.'
    
    print_success "Triggers créés"
}

export_templates() {
    print_header "Export des templates optimisés"
    
    print_info "Export du template '$TEMPLATE_NAME' en YAML"
    
    # Exporter le template via l'API
    curl -s -X POST $ZABBIX_URL/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d '{
            "jsonrpc": "2.0",
            "method": "template.export",
            "params": {
                "templateids": ["10001"],
                "format": "yaml"
            },
            "auth": "'$TOKEN'",
            "id": 1
        }' | jq -r '.result' > /tmp/$TEMPLATE_NAME.yaml
    
    print_success "Template exporté dans /tmp/$TEMPLATE_NAME.yaml"
    
    # Afficher un résumé
    echo -e "\n${GREEN}📊 Résumé du template exporté :${NC}"
    ls -lh /tmp/$TEMPLATE_NAME.yaml
    echo -e "\n${YELLOW}Aperçu des premières lignes :${NC}"
    head -20 /tmp/$TEMPLATE_NAME.yaml
}

create_documentation() {
    print_header "Génération de la documentation"
    
    cat << EOF > /tmp/ZABBIX_MODEL_DOCUMENTATION.md
# 📚 Documentation du Modèle Zabbix Optimisé

## 📋 Description du Modèle
- **Nom** : $TEMPLATE_NAME
- **Type** : Template avancé pour équipements réseau
- **Version** : 2.0
- **Date de création** : $(date '+%Y-%m-%d %H:%M:%S')

## 🎯 Caractéristiques Principales

### 1. Structure Hiérarchique
- Template parent : Network_Device_Base
- Template enfant : $TEMPLATE_NAME
- Groupe d'hôtes : Network Devices

### 2. Macros Disponibles
| Macro | Description | Valeur par défaut |
|-------|-------------|-------------------|
| \${\$SNMP_COMMUNITY} | Community SNMP v2c | public |
| \${\$SNMPV3_SECURITY_NAME} | Utilisateur SNMPv3 | zabbix-monitor |
| \${\$CPU.UTIL.CRIT} | Seuil critique CPU | 90 |
| \${\$CPU.UTIL.WARN} | Seuil d'avertissement CPU | 75 |
| \${\$MEM.UTIL.CRIT} | Seuil critique mémoire | 90 |
| \${\$MEM.UTIL.WARN} | Seuil d'avertissement mémoire | 80 |
| \${\$IF.BAND.MAX} | Seuil bande passante | 80 |

### 3. Value Mappings
- **Port Status** : 1=Up, 2=Down, 3=Testing, 4=Unknown
- **Device Status** : 0=Unavailable, 1=Available, 2=Degraded

### 4. Low-Level Discovery (LLD)
- Découverte automatique des interfaces réseau
- Création automatique d'items pour chaque interface

### 5. Triggers
- Équipement indisponible (Priorité 5)
- CPU surchargé (Priorité 4)
- Port en panne (Priorité 3)

## 🔧 Configuration Requise
- SNMPv2c ou SNMPv3 sur les équipements
- Accès ICMP (ping)

## 📥 Installation
1. Importer le fichier YAML dans Zabbix
2. Lier le template aux équipements à superviser
3. Configurer les macros selon l'environnement

## 🔗 Documentation Officielle
- [Zabbix Documentation](https://www.zabbix.com/documentation)
- [SNMP Configuration Guide](https://www.zabbix.com/documentation/current/en/manual/config/items/itemtypes/snmp)

---
*Documentation générée automatiquement le $(date '+%Y-%m-%d %H:%M:%S')*
EOF

    print_success "Documentation générée dans /tmp/ZABBIX_MODEL_DOCUMENTATION.md"
    print_info "Voici le contenu de la documentation :"
    cat /tmp/ZABBIX_MODEL_DOCUMENTATION.md
}

summary() {
    print_header "RÉSUMÉ FINAL DE L'AMÉLIORATION"
    
    echo -e "${GREEN}✅ Améliorations réalisées :${NC}"
    echo "  1. Structure de templates créée"
    echo "  2. Value Mappings configurés"
    echo "  3. Macros avancées ajoutées"
    echo "  4. Low-Level Discovery activée"
    echo "  5. Triggers intelligents créés"
    echo "  6. Template exporté"
    echo "  7. Documentation générée"
    
    echo -e "\n${GREEN}📁 Fichiers générés :${NC}"
    echo "  - /tmp/$TEMPLATE_NAME.yaml"
    echo "  - /tmp/ZABBIX_MODEL_DOCUMENTATION.md"
    
    echo -e "\n${YELLOW}Prochaines étapes :${NC}"
    echo "  1. Vérifier le template dans l'interface Zabbix"
    echo "  2. Importer le fichier YAML sur le serveur de production"
    echo "  3. Lier le template à vos équipements réseau"
    echo "  4. Tester la supervision avec SNMP"
}

# --- MENU PRINCIPAL ---
main_menu() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         🚀 AMÉLIORATION DU MODÈLE ZABBIX               ║${NC}"
    echo -e "${BLUE}║         Version Professionnelle 2.0                     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}Choisissez une option :${NC}"
    echo "  1) Exécuter toutes les améliorations (recommandé)"
    echo "  2) Créer la structure de templates uniquement"
    echo "  3) Créer les Value Mappings uniquement"
    echo "  4) Ajouter les macros uniquement"
    echo "  5) Configurer la LLD uniquement"
    echo "  6) Créer les triggers uniquement"
    echo "  7) Exporter le template uniquement"
    echo "  8) Générer la documentation uniquement"
    echo "  9) Quitter"
    
    read -p "$(echo -e ${YELLOW}"Votre choix [1-9] : "${NC})" CHOICE
    
    case $CHOICE in
        1)
            check_prerequisites
            TOKEN=$(get_api_token)
            create_template_structure
            create_value_mappings
            create_network_template
            add_lld_discovery
            add_macros
            create_triggers
            export_templates
            create_documentation
            summary
            ;;
        2)
            check_prerequisites
            TOKEN=$(get_api_token)
            create_template_structure
            ;;
        3)
            check_prerequisites
            TOKEN=$(get_api_token)
            create_value_mappings
            ;;
        4)
            check_prerequisites
            TOKEN=$(get_api_token)
            add_macros
            ;;
        5)
            check_prerequisites
            TOKEN=$(get_api_token)
            add_lld_discovery
            ;;
        6)
            check_prerequisites
            TOKEN=$(get_api_token)
            create_triggers
            ;;
        7)
            check_prerequisites
            TOKEN=$(get_api_token)
            export_templates
            ;;
        8)
            create_documentation
            ;;
        9)
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Choix invalide${NC}"
            exit 1
            ;;
    esac
}

# --- Exécution du script ---
clear
main_menu
