#!/bin/sh
# Sauvegarde quotidienne de la base, à lancer par cron sur le VPS depuis le dossier backend/ :
#   0 3 * * * cd /opt/motivplan/backend && ./scripts/backup.sh >> backups/backup.log 2>&1
# Garde les 30 dernières sauvegardes.
set -eu

BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP="${KEEP:-30}"
mkdir -p "$BACKUP_DIR"

file="$BACKUP_DIR/motivplan-$(date +%Y-%m-%d-%H%M).sql.gz"
tmp="$file.partial"
# Dump d'abord dans un fichier : un échec de pg_dump arrête le script au lieu de produire une archive vide.
docker compose exec -T postgres pg_dump -U motivplan -d motivplan --no-owner > "$tmp" || { rm -f "$tmp"; exit 1; }
gzip -c "$tmp" > "$file"
rm -f "$tmp"
echo "$(date -Iseconds) sauvegarde : $file ($(wc -c < "$file") octets)"

ls -1t "$BACKUP_DIR"/motivplan-*.sql.gz | tail -n +"$((KEEP + 1))" | xargs -r rm --
