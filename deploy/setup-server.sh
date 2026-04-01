#!/bin/bash
# =============================================================================
# Swasth Server Setup — Run this ONCE on 65.109.226.36
# =============================================================================
# Usage: ssh into server, then run:
#   bash setup-server.sh
# =============================================================================

set -e

echo "=== Swasth Server Setup ==="

# --- 1. Create directory structure ---
echo "Creating directories..."
sudo mkdir -p /var/www/swasth/backend
sudo mkdir -p /var/www/swasth/web
sudo mkdir -p /var/www/swasth_prod/backend
sudo mkdir -p /var/www/swasth_prod/web

# --- 2. Clone the repo into both environments ---
echo "Cloning repo..."
cd /var/www/swasth
git clone https://github.com/amitrepos/swasth.git . || echo "Already cloned, pulling..."
git pull origin master

cd /var/www/swasth_prod
git clone https://github.com/amitrepos/swasth.git . || echo "Already cloned, pulling..."
git pull origin master

# --- 3. Create Python virtual environments ---
echo "Setting up Python venvs..."
cd /var/www/swasth
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r backend/requirements.txt
deactivate

cd /var/www/swasth_prod
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r backend/requirements.txt
deactivate

# --- 4. Create PostgreSQL databases ---
echo "Creating PostgreSQL databases..."
sudo -u postgres psql -c "CREATE DATABASE swasth_dev;" 2>/dev/null || echo "swasth_dev already exists"
sudo -u postgres psql -c "CREATE DATABASE swasth_prod;" 2>/dev/null || echo "swasth_prod already exists"

# --- 5. Create .env files ---
echo "Creating .env files..."
# DEV .env
cat > /var/www/swasth/backend/.env << 'DEVENV'
DATABASE_URL=postgresql://postgres@localhost:5432/swasth_dev
SERVER_HOST=0.0.0.0
SERVER_PORT=8007
SECRET_KEY=CHANGE_ME_DEV_SECRET_KEY
REQUIRE_HTTPS=False
CORS_ORIGINS=["http://65.109.226.36","http://65.109.226.36:8007","http://localhost:3000"]

# AI API Keys (fill in your real keys)
GEMINI_API_KEY=
DEEPSEEK_API_KEY=

# Brevo SMTP (fill in your real credentials)
BREVO_SMTP_SERVER=smtp-relay.brevo.com
BREVO_SMTP_PORT=587
BREVO_SENDER_EMAIL=
BREVO_SMTP_LOGIN=
BREVO_SMTP_PASSWORD=
BREVO_SENDER_NAME=Swasth Health App
DEVENV

# PROD .env
cat > /var/www/swasth_prod/backend/.env << 'PRODENV'
DATABASE_URL=postgresql://postgres@localhost:5432/swasth_prod
SERVER_HOST=0.0.0.0
SERVER_PORT=8008
SECRET_KEY=CHANGE_ME_PROD_SECRET_KEY
REQUIRE_HTTPS=False
CORS_ORIGINS=["http://65.109.226.36","http://65.109.226.36:8008"]

# AI API Keys (fill in your real keys)
GEMINI_API_KEY=
DEEPSEEK_API_KEY=

# Brevo SMTP (fill in your real credentials)
BREVO_SMTP_SERVER=smtp-relay.brevo.com
BREVO_SMTP_PORT=587
BREVO_SENDER_EMAIL=
BREVO_SMTP_LOGIN=
BREVO_SMTP_PASSWORD=
BREVO_SENDER_NAME=Swasth Health App
PRODENV

echo "⚠️  IMPORTANT: Edit the .env files and add your real API keys:"
echo "   nano /var/www/swasth/backend/.env"
echo "   nano /var/www/swasth_prod/backend/.env"

# --- 6. Install PM2 if not present ---
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    npm install -g pm2
fi

# --- 7. Start backend services via PM2 ---
echo "Starting DEV backend..."
cd /var/www/swasth/backend
source /var/www/swasth/venv/bin/activate
pm2 start "python -m uvicorn main:app --host 0.0.0.0 --port 8007" --name "swasth-dev"
deactivate

echo "Starting PROD backend..."
cd /var/www/swasth_prod/backend
source /var/www/swasth_prod/venv/bin/activate
pm2 start "python -m uvicorn main:app --host 0.0.0.0 --port 8008" --name "swasth-prod"
deactivate

pm2 save

# --- 8. Install Nginx config ---
echo "Setting up Nginx..."
sudo cp /var/www/swasth/deploy/nginx-swasth.conf /etc/nginx/sites-available/swasth
sudo ln -sf /etc/nginx/sites-available/swasth /etc/nginx/sites-enabled/swasth
sudo nginx -t && sudo systemctl reload nginx

echo ""
echo "=== Setup Complete ==="
echo ""
echo "DEV:  http://65.109.226.36:8007  (API)"
echo "      http://65.109.226.36        (Web — via Nginx)"
echo "PROD: http://65.109.226.36:8008  (API)"
echo ""
echo "PM2 status: pm2 status"
echo "PM2 logs:   pm2 logs swasth-dev"
echo ""
echo "Next steps:"
echo "1. Edit .env files with your real API keys"
echo "2. Add GitHub secrets: SERVER_HOST, SERVER_USER, SSH_PRIVATE_KEY"
echo "3. Push to master to trigger auto-deploy"
