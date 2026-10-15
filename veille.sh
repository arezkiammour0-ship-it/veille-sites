#!/usr/bin/env bash
# Contrôle chaque site de VEILLE_URLS ("nom|url" par ligne) ; panne = 2 échecs à 20 s d'écart.
# Répond = code 2xx, 3xx ou 401 (pages protégées). etat.txt garde les noms en panne.
set -u

ok() {
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$1")
    [[ $code =~ ^(2..|3..|401)$ ]]
}

telegram() {
    curl -s -o /dev/null --max-time 20 "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" --data-urlencode "text=$1"
}

touch etat.txt
avant=$(cat etat.txt)
: > nouveau.txt
while IFS='|' read -r nom url; do
    [ -z "$nom" ] && continue
    ok "$url" || { sleep 20; ok "$url"; } || echo "$nom" >> nouveau.txt
done <<< "$VEILLE_URLS"

while read -r nom; do
    [ -n "$nom" ] && ! grep -qxF "$nom" <<< "$avant" && telegram "🔴 PANNE : $nom ne répond plus (veille externe)"
done < nouveau.txt
while read -r nom; do
    [ -n "$nom" ] && ! grep -qxF "$nom" nouveau.txt && telegram "✅ Rétabli : $nom répond de nouveau"
done <<< "$avant"

mv nouveau.txt etat.txt
echo "En panne : $(wc -l < etat.txt)"
cat etat.txt
