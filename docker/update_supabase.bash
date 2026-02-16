#!/bin/bash

# ==========================================
# Supabase Self-Hosted Update Script
# ==========================================

# 設定變數
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups"
DB_CONTAINER="supabase-db" # 注意：確認你的 container name，預設通常是 supabase-db 或 docker-db-1

# 1. 檢查並建立備份目錄
if [ ! -d "$BACKUP_DIR" ]; then
    echo "📂 Creating backup directory..."
    mkdir -p $BACKUP_DIR
fi

echo "🚀 Starting Supabase Update Process - $TIMESTAMP"

# 2. 執行資料庫備份 (Safety First!)
echo "💾 Backing up database..."
if docker ps | grep -q $DB_CONTAINER; then
    docker exec $DB_CONTAINER pg_dump -U postgres postgres | gzip > "$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"
    if [ $? -eq 0 ]; then
        echo "✅ Backup successful: $BACKUP_DIR/backup_$TIMESTAMP.sql.gz"
    else
        echo "❌ Backup failed! Aborting update."
        exit 1
    fi
else
    echo "⚠️ Database container not running. Skipping backup (Risk: High)."
    read -p "Do you want to continue without backup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 3. Git 操作：拉取 Upstream 更新
echo "qw Pulling updates from official repo (Upstream)..."
git fetch upstream

# 嘗試合併
echo "🔀 Merging upstream changes..."
if git merge upstream/master; then
    echo "✅ Git merge successful."
else
    echo "❌ Git merge conflict detected!"
    echo "請手動解決衝突後，再執行 docker compose up -d"
    exit 1
fi

# 4. 更新 Docker Images
echo "🐳 Pulling latest Docker images..."
docker compose pull

# 5. 重啟服務 (Zero-downtime if possible, but expect brief interruption)
echo "cw Restarting services..."
docker compose up -d --remove-orphans

# 6. 清理舊的 Docker Images (選用)
echo "🧹 Cleaning up unused images..."
docker image prune -f

echo "🎉 Update Complete! Check logs with: docker compose logs -f"
