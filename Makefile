# Variables
PYTHON := python
VENV := .venv
ifeq ($(OS),Windows_NT)
    VENV_BIN := $(VENV)/Scripts
    VENV_PYTHON := $(VENV_BIN)/python.exe
    VENV_PIP := $(VENV_BIN)/pip.exe
else
    VENV_BIN := $(VENV)/bin
    VENV_PYTHON := $(VENV_BIN)/python
    VENV_PIP := $(VENV_BIN)/pip
endif
NODE := node
NPM := npm
POSTGRES_USER := postgres
POSTGRES_PASSWORD := postgres
POSTGRES_DB := agentgateway
POSTGRES_PORT := 5432
# Nginx variables
NGINX_CONF_DIR := /etc/nginx
NGINX_CONF_FILE := $(NGINX_CONF_DIR)/nginx.conf
NGINX_SITES_DIR := $(NGINX_CONF_DIR)/sites-available
NGINX_SITES_ENABLED := $(NGINX_CONF_DIR)/sites-enabled
NGINX_SITE_CONF := agentgateway
PROJECT_DIR := $(shell pwd)
NGINX_LOCAL_CONF := $(PROJECT_DIR)/nginx.conf
STATIC_DIR := /var/www/static

# Default target
.PHONY: all
all: check-dependencies setup-backend setup-frontend setup-database

# Install Node.js and npm
.PHONY: install-node
install-node:
	@echo "Installing Node.js and npm..."
	@if [ "$(shell uname)" = "Windows_NT" ]; then \
		echo "Please download and install Node.js LTS from https://nodejs.org/"; \
		echo "This will also install npm"; \
	else \
		curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && \
		sudo apt-get update && \
		sudo apt-get install -y nodejs && \
		sudo npm install -g npm@10.8.2; \
	fi
	@echo "Node.js and npm installation complete."

# Install PostgreSQL
.PHONY: install-postgres
install-postgres:
	@echo "Installing PostgreSQL..."
	@if [ "$(shell uname)" = "Windows_NT" ]; then \
		echo "Please download and install PostgreSQL from https://www.postgresql.org/download/windows/"; \
		echo "Remember the password you set for the postgres user"; \
	else \
		sudo apt-get update && \
		sudo apt-get install -y postgresql postgresql-contrib; \
		sudo service postgresql start; \
	fi
	@echo "PostgreSQL installation complete."

# Install Nginx
.PHONY: install-nginx
install-nginx:
	@echo "Installing Nginx..."
	@if [ "$(shell uname)" = "Windows_NT" ]; then \
		echo "Nginx installation on Windows is not supported by this Makefile."; \
		echo "Please download and install Nginx from http://nginx.org/en/download.html"; \
	else \
		sudo apt-get update && \
		sudo apt-get install -y nginx && \
		sudo systemctl enable nginx; \
	fi
	@echo "Nginx installation complete."

# Install all tools
.PHONY: install-tools
install-tools: install-node install-postgres install-nginx
	@echo "All tools installed successfully."

# Check if required tools are installed
.PHONY: check-dependencies
check-dependencies:
	@echo "Checking dependencies..."
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "Python is required but not installed. Please install Python 3.8 or higher."; exit 1; }
	@command -v $(NODE) >/dev/null 2>&1 || { echo "Node.js is required but not installed. Please run 'make install-node'."; exit 1; }
	@command -v $(NPM) >/dev/null 2>&1 || { echo "npm is required but not installed. Please run 'make install-node'."; exit 1; }
	@command -v psql >/dev/null 2>&1 || { echo "PostgreSQL is required but not installed. Please run 'make install-postgres'."; exit 1; }
	@echo "All dependencies are installed."

# Check if Nginx is installed
.PHONY: check-nginx
check-nginx:
	@echo "Checking if Nginx is installed..."
	@command -v nginx >/dev/null 2>&1 || { echo "Nginx is required but not installed. Please run 'make install-nginx'."; exit 1; }
	@echo "Nginx is installed."

# Check Nginx status
.PHONY: check-nginx-status
check-nginx-status:
	@echo "Checking Nginx status..."
	@sudo systemctl status nginx
	@echo "Checking Nginx processes..."
	@ps aux | grep nginx
	@echo "Checking Nginx ports..."
	@sudo netstat -tulpn | grep nginx
	@echo "Checking Nginx web server..."
	@curl -I http://localhost
	@echo "Checking Nginx error logs..."
	@sudo tail -n 20 /var/log/nginx/error.log

# Setup Python virtual environment
.PHONY: setup-venv
setup-venv:
	@echo "Setting up Python virtual environment..."
	@$(PYTHON) -m venv $(VENV)
	@echo "Virtual environment created."

# Install backend dependencies
.PHONY: setup-backend
setup-backend: setup-venv
	@echo "Setting up backend..."
	@$(VENV_PIP) install --upgrade pip
	@$(VENV_PIP) install -r backend/requirements.txt
	@echo "Backend setup complete."

# Install frontend dependencies
.PHONY: setup-frontend
setup-frontend:
	@echo "Setting up frontend..."
	@cd frontend && $(NPM) install
	@echo "Frontend setup complete."

# Setup database
.PHONY: setup-database
setup-database:
	@echo "Setting up database..."
	@PGPASSWORD=$(POSTGRES_PASSWORD) psql -U $(POSTGRES_USER) -h localhost -p $(POSTGRES_PORT) -c "CREATE DATABASE $(POSTGRES_DB);" || true
	@echo "Database setup complete."

# Create Nginx security configuration file
.PHONY: create-nginx-conf
create-nginx-conf:
	@echo "Creating Nginx security configuration file..."
	@echo "user www-data;" > $(NGINX_LOCAL_CONF)
	@echo "worker_processes auto;" >> $(NGINX_LOCAL_CONF)
	@echo "pid /run/nginx.pid;" >> $(NGINX_LOCAL_CONF)
	@echo "include /etc/nginx/modules-enabled/*.conf;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "events {" >> $(NGINX_LOCAL_CONF)
	@echo "    worker_connections 1024;" >> $(NGINX_LOCAL_CONF)
	@echo "}" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "http {" >> $(NGINX_LOCAL_CONF)
	@echo "    sendfile on;" >> $(NGINX_LOCAL_CONF)
	@echo "    tcp_nopush on;" >> $(NGINX_LOCAL_CONF)
	@echo "    tcp_nodelay on;" >> $(NGINX_LOCAL_CONF)
	@echo "    keepalive_timeout 65;" >> $(NGINX_LOCAL_CONF)
	@echo "    types_hash_max_size 2048;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    include /etc/nginx/mime.types;" >> $(NGINX_LOCAL_CONF)
	@echo "    default_type application/octet-stream;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    ssl_protocols TLSv1.2 TLSv1.3;" >> $(NGINX_LOCAL_CONF)
	@echo "    ssl_prefer_server_ciphers on;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    access_log /var/log/nginx/access.log;" >> $(NGINX_LOCAL_CONF)
	@echo "    error_log /var/log/nginx/error.log;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    gzip on;" >> $(NGINX_LOCAL_CONF)
	@echo "    gzip_disable \"msie6\";" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    # Ограничение размера запроса для защиты от DoS-атак" >> $(NGINX_LOCAL_CONF)
	@echo "    client_max_body_size 10m;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    # Ограничение скорости запросов (защита от DDoS)" >> $(NGINX_LOCAL_CONF)
	@echo "    limit_req_zone \$$binary_remote_addr zone=api_limit:10m rate=10r/s;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    # Блокировка подозрительных запросов" >> $(NGINX_LOCAL_CONF)
	@echo "    map \$$http_user_agent \$$bad_bot {" >> $(NGINX_LOCAL_CONF)
	@echo "        default 0;" >> $(NGINX_LOCAL_CONF)
	@echo "        ~*(bot|crawl|spider) 1;" >> $(NGINX_LOCAL_CONF)
	@echo "        \"\" 1;" >> $(NGINX_LOCAL_CONF)
	@echo "    }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    # Блокировка подозрительных запросов с SQL-инъекциями" >> $(NGINX_LOCAL_CONF)
	@echo "    map \$$request_uri \$$sql_injection {" >> $(NGINX_LOCAL_CONF)
	@echo "        default 0;" >> $(NGINX_LOCAL_CONF)
	@echo "        ~*(%27|\\'|%3D|=|%2F|\\*|/\\*|or%201=1|union%20select|concat|group_by) 1;" >> $(NGINX_LOCAL_CONF)
	@echo "    }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    # Блокировка подозрительных запросов с XSS-атаками" >> $(NGINX_LOCAL_CONF)
	@echo "    map \$$request_uri \$$xss_attack {" >> $(NGINX_LOCAL_CONF)
	@echo "        default 0;" >> $(NGINX_LOCAL_CONF)
	@echo "        ~*(<|>|script|alert|onerror|onload|eval|javascript:) 1;" >> $(NGINX_LOCAL_CONF)
	@echo "    }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "    server {" >> $(NGINX_LOCAL_CONF)
	@echo "        listen 80;" >> $(NGINX_LOCAL_CONF)
	@echo "        server_name localhost;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "        # Заголовки безопасности" >> $(NGINX_LOCAL_CONF)
	@echo "        add_header X-Content-Type-Options nosniff;" >> $(NGINX_LOCAL_CONF)
	@echo "        add_header X-Frame-Options SAMEORIGIN;" >> $(NGINX_LOCAL_CONF)
	@echo "        add_header X-XSS-Protection \"1; mode=block\";" >> $(NGINX_LOCAL_CONF)
	@echo "        add_header Content-Security-Policy \"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:;\";" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "        # Frontend" >> $(NGINX_LOCAL_CONF)
	@echo "        location / {" >> $(NGINX_LOCAL_CONF)
	@echo "            # Проксирование запросов к фронтенду" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_pass http://localhost:3000;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_http_version 1.1;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Upgrade \$$http_upgrade;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Connection 'upgrade';" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Host \$$host;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_cache_bypass \$$http_upgrade;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Добавляем явное разрешение на доступ" >> $(NGINX_LOCAL_CONF)
	@echo "            allow all;" >> $(NGINX_LOCAL_CONF)
	@echo "        }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "        # Backend API с проверкой безопасности" >> $(NGINX_LOCAL_CONF)
	@echo "        location /api {" >> $(NGINX_LOCAL_CONF)
	@echo "            # Проверка безопасности" >> $(NGINX_LOCAL_CONF)
	@echo "            if (\$$bad_bot = 1) {" >> $(NGINX_LOCAL_CONF)
	@echo "                return 403;" >> $(NGINX_LOCAL_CONF)
	@echo "            }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            if (\$$sql_injection = 1) {" >> $(NGINX_LOCAL_CONF)
	@echo "                return 403;" >> $(NGINX_LOCAL_CONF)
	@echo "            }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            if (\$$xss_attack = 1) {" >> $(NGINX_LOCAL_CONF)
	@echo "                return 403;" >> $(NGINX_LOCAL_CONF)
	@echo "            }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Ограничение скорости запросов" >> $(NGINX_LOCAL_CONF)
	@echo "            limit_req zone=api_limit burst=20 nodelay;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Проксирование запросов к бэкенду" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_pass http://localhost:8000;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_http_version 1.1;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Upgrade \$$http_upgrade;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Connection 'upgrade';" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Host \$$host;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_cache_bypass \$$http_upgrade;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header X-Real-IP \$$remote_addr;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header X-Forwarded-For \$$proxy_add_x_forwarded_for;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header X-Forwarded-Proto \$$scheme;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Добавляем явное разрешение на доступ" >> $(NGINX_LOCAL_CONF)
	@echo "            allow all;" >> $(NGINX_LOCAL_CONF)
	@echo "        }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "        # Специальный путь /query с проверкой безопасности" >> $(NGINX_LOCAL_CONF)
	@echo "        location /query {" >> $(NGINX_LOCAL_CONF)
	@echo "            # Проверка безопасности" >> $(NGINX_LOCAL_CONF)
	@echo "            if (\$$bad_bot = 1) {" >> $(NGINX_LOCAL_CONF)
	@echo "                return 403;" >> $(NGINX_LOCAL_CONF)
	@echo "            }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            if (\$$sql_injection = 1) {" >> $(NGINX_LOCAL_CONF)
	@echo "                return 403;" >> $(NGINX_LOCAL_CONF)
	@echo "            }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            if (\$$xss_attack = 1) {" >> $(NGINX_LOCAL_CONF)
	@echo "                return 403;" >> $(NGINX_LOCAL_CONF)
	@echo "            }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Проверка заголовка Origin для защиты от CSRF" >> $(NGINX_LOCAL_CONF)
	@echo "            if (\$$http_origin !~ \"^(https?://localhost(:[0-9]+)?|https?://127\\.0\\.0\\.1(:[0-9]+)?)$$\") {" >> $(NGINX_LOCAL_CONF)
	@echo "                return 403;" >> $(NGINX_LOCAL_CONF)
	@echo "            }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Ограничение скорости запросов" >> $(NGINX_LOCAL_CONF)
	@echo "            limit_req zone=api_limit burst=20 nodelay;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Проксирование запросов к бэкенду" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_pass http://localhost:8000/query;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_http_version 1.1;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Upgrade \$$http_upgrade;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Connection 'upgrade';" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header Host \$$host;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_cache_bypass \$$http_upgrade;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header X-Real-IP \$$remote_addr;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header X-Forwarded-For \$$proxy_add_x_forwarded_for;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header X-Forwarded-Proto \$$scheme;" >> $(NGINX_LOCAL_CONF)
	@echo "            proxy_set_header X-Security-Check \"passed\";" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Добавляем явное разрешение на доступ" >> $(NGINX_LOCAL_CONF)
	@echo "            allow all;" >> $(NGINX_LOCAL_CONF)
	@echo "        }" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "        # Static files" >> $(NGINX_LOCAL_CONF)
	@echo "        location /static {" >> $(NGINX_LOCAL_CONF)
	@echo "            # Используем более гибкий путь с правами доступа" >> $(NGINX_LOCAL_CONF)
	@echo "            root /var/www;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Добавляем обработку индексных файлов" >> $(NGINX_LOCAL_CONF)
	@echo "            index index.html index.htm;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Добавляем try_files для корректной обработки запросов" >> $(NGINX_LOCAL_CONF)
	@echo "            try_files \$$uri \$$uri/ =404;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Устанавливаем кеширование" >> $(NGINX_LOCAL_CONF)
	@echo "            expires 30d;" >> $(NGINX_LOCAL_CONF)
	@echo "" >> $(NGINX_LOCAL_CONF)
	@echo "            # Добавляем явное разрешение на доступ" >> $(NGINX_LOCAL_CONF)
	@echo "            allow all;" >> $(NGINX_LOCAL_CONF)
	@echo "        }" >> $(NGINX_LOCAL_CONF)
	@echo "    }" >> $(NGINX_LOCAL_CONF)
	@echo "}" >> $(NGINX_LOCAL_CONF)
	@echo "Nginx security configuration file created at $(NGINX_LOCAL_CONF)"

# Setup Nginx configuration and fix permissions
.PHONY: setup-nginx
setup-nginx: check-nginx create-nginx-conf
	@echo "Setting up Nginx configuration and fixing permissions..."
	@if [ "$(shell uname)" != "Windows_NT" ]; then \
		sudo mkdir -p $(STATIC_DIR); \
		sudo chown -R www-data:www-data $(STATIC_DIR); \
		sudo chmod -R 755 $(STATIC_DIR); \
		sudo cp $(NGINX_LOCAL_CONF) $(NGINX_CONF_FILE); \
		sudo chown www-data:www-data $(NGINX_CONF_FILE); \
		sudo chmod 644 $(NGINX_CONF_FILE); \
		sudo systemctl restart nginx; \
		echo "Creating test index file in static directory..."; \
		echo "<html><body><h1>Static files are working!</h1></body></html>" | sudo tee $(STATIC_DIR)/index.html > /dev/null; \
		sudo chown www-data:www-data $(STATIC_DIR)/index.html; \
		sudo chmod 644 $(STATIC_DIR)/index.html; \
	else \
		echo "Nginx configuration on Windows is not supported by this Makefile."; \
	fi
	@echo "Nginx configuration and permissions setup complete."

# Create .env file from example
.PHONY: setup-env
setup-env:
	@echo "Setting up environment variables..."
	@cp backend/.env.example backend/.env
	@echo "Please edit backend/.env with your configuration."

# Run backend development server
.PHONY: run-backend
run-backend:
	@echo "Starting backend server..."
	@cd backend && $(VENV_PYTHON) -B -m uvicorn app.main:app --reload

# Run frontend development server
.PHONY: run-frontend
run-frontend:
	@echo "Starting frontend server..."
	@cd frontend && $(NPM) run dev

# Run Nginx server
.PHONY: run-nginx
run-nginx: check-nginx
	@echo "Starting Nginx server..."
	@if [ "$(shell uname)" != "Windows_NT" ]; then \
		sudo systemctl start nginx; \
	else \
		echo "Starting Nginx on Windows is not supported by this Makefile."; \
	fi
	@echo "Nginx server started."

# Stop Nginx server
.PHONY: stop-nginx
stop-nginx: check-nginx
	@echo "Stopping Nginx server..."
	@if [ "$(shell uname)" != "Windows_NT" ]; then \
		sudo systemctl stop nginx; \
	else \
		echo "Stopping Nginx on Windows is not supported by this Makefile."; \
	fi
	@echo "Nginx server stopped."

# Restart Nginx server
.PHONY: restart-nginx
restart-nginx: check-nginx
	@echo "Restarting Nginx server..."
	@if [ "$(shell uname)" != "Windows_NT" ]; then \
		sudo systemctl restart nginx; \
	else \
		echo "Restarting Nginx on Windows is not supported by this Makefile."; \
	fi
	@echo "Nginx server restarted."

# Fix Nginx permissions
.PHONY: fix-nginx-permissions
fix-nginx-permissions:
	@echo "Fixing Nginx permissions..."
	@if [ "$(shell uname)" != "Windows_NT" ]; then \
		sudo mkdir -p $(STATIC_DIR); \
		sudo chown -R www-data:www-data $(STATIC_DIR); \
		sudo chmod -R 755 $(STATIC_DIR); \
		sudo chown www-data:www-data $(NGINX_CONF_FILE); \
		sudo chmod 644 $(NGINX_CONF_FILE); \
		sudo find /var/log/nginx -type d -exec chmod 755 {} \;; \
		sudo find /var/log/nginx -type f -exec chmod 644 {} \;; \
		sudo chown -R www-data:adm /var/log/nginx; \
		sudo systemctl restart nginx; \
	else \
		echo "Fixing Nginx permissions on Windows is not supported by this Makefile."; \
	fi
	@echo "Nginx permissions fixed."

# Test Nginx security
.PHONY: test-nginx-security
test-nginx-security:
	@echo "Testing Nginx security configuration..."
	@echo "Testing normal request to /query..."
	@curl -I -H "Origin: http://localhost:3000" http://localhost/query
	@echo "\nTesting SQL injection attack..."
	@curl -I "http://localhost/query?id=1%27%20OR%20%271%27=%271"
	@echo "\nTesting XSS attack..."
	@curl -I "http://localhost/query?param=<script>alert(1)</script>"
	@echo "\nTesting CSRF attack..."
	@curl -I -H "Origin: http://evil-site.com" http://localhost/query
	@echo "\nTesting rate limiting (this may take a moment)..."
	@for i in {1..15}; do curl -I http://localhost/query; done
	@echo "Security tests completed."

# Агрегированная функция для управления Nginx
.PHONY: nginx
nginx:
	@if [ "$(action)" = "" ]; then \
		echo "Ошибка: не указано действие. Используйте 'make nginx action=<действие>'"; \
		echo "Доступные действия:"; \
		echo "  install - установка Nginx"; \
		echo "  check - проверка установки Nginx"; \
		echo "  status - проверка статуса Nginx"; \
		echo "  config - создание конфигурационного файла"; \
		echo "  setup - настройка Nginx и прав доступа"; \
		echo "  start - запуск Nginx"; \
		echo "  stop - остановка Nginx"; \
		echo "  restart - перезапуск Nginx"; \
		echo "  fix-permissions - исправление прав доступа"; \
		echo "  test-security - тестирование безопасности"; \
		echo "  all - полная настройка (установка, настройка, запуск)"; \
		exit 1; \
	fi; \
	if [ "$(action)" = "install" ]; then \
		$(MAKE) install-nginx; \
	elif [ "$(action)" = "check" ]; then \
		$(MAKE) check-nginx; \
	elif [ "$(action)" = "status" ]; then \
		$(MAKE) check-nginx-status; \
	elif [ "$(action)" = "config" ]; then \
		$(MAKE) create-nginx-conf; \
	elif [ "$(action)" = "setup" ]; then \
		$(MAKE) setup-nginx; \
	elif [ "$(action)" = "start" ]; then \
		$(MAKE) run-nginx; \
	elif [ "$(action)" = "stop" ]; then \
		$(MAKE) stop-nginx; \
	elif [ "$(action)" = "restart" ]; then \
		$(MAKE) restart-nginx; \
	elif [ "$(action)" = "fix-permissions" ]; then \
		$(MAKE) fix-nginx-permissions; \
	elif [ "$(action)" = "test-security" ]; then \
		$(MAKE) test-nginx-security; \
	elif [ "$(action)" = "all" ]; then \
		$(MAKE) install-nginx; \
		$(MAKE) setup-nginx; \
		$(MAKE) run-nginx; \
	else \
		echo "Ошибка: неизвестное действие '$(action)'"; \
		echo "Используйте 'make nginx' для просмотра доступных действий"; \
		exit 1; \
	fi

# Build frontend for production
.PHONY: build-frontend
build-frontend:
	@echo "Building frontend for production..."
	@cd frontend && $(NPM) run build
	@echo "Frontend build complete."

# Run both servers in development mode
.PHONY: run
run: run-backend run-frontend

# Run in production mode with Nginx
.PHONY: run-production
run-production: build-frontend setup-nginx fix-nginx-permissions
	@echo "Starting production servers..."
	@cd backend && $(VENV_PYTHON) -B -m uvicorn app.main:app &
	@echo "Backend server started."
	@make restart-nginx
	@echo "Application is now running in production mode with Nginx."
	@echo "Access your application at http://localhost"
	@echo "Access static files at http://localhost/static/"
	@echo "Secure API endpoint available at http://localhost/query"

# Clean up
.PHONY: clean
clean:
	@echo "Cleaning up..."
	@rm -rf $(VENV)
	@rm -rf frontend/node_modules
	@rm -rf frontend/.next
	@echo "Cleanup complete."

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all              - Set up everything (backend, frontend, database)"
	@echo "  install-tools    - Install all required tools (Node.js, PostgreSQL, Nginx)"
	@echo "  install-node     - Install Node.js and npm"
	@echo "  install-postgres - Install PostgreSQL"
	@echo "  install-nginx    - Install Nginx"
	@echo "  check-dependencies - Check if all required tools are installed"
	@echo "  check-nginx      - Check if Nginx is installed"
	@echo "  check-nginx-status - Check Nginx running status and connectivity"
	@echo "  create-nginx-conf - Create Nginx configuration file with security features"
	@echo "  setup-backend    - Set up Python virtual environment and install backend dependencies"
	@echo "  setup-frontend   - Install frontend dependencies"
	@echo "  setup-database   - Create database"
	@echo "  setup-nginx      - Configure Nginx for the application and fix permissions"
	@echo "  fix-nginx-permissions - Fix Nginx permissions issues"
	@echo "  test-nginx-security - Test Nginx security configuration"
	@echo "  nginx            - Универсальная функция для управления Nginx (используйте 'make nginx' для справки)"
	@echo "  setup-env        - Create .env file from example"
	@echo "  run-backend      - Run backend development server"
	@echo "  run-frontend     - Run frontend development server"
	@echo "  run-nginx        - Start Nginx server"
	@echo "  stop-nginx       - Stop Nginx server"
	@echo "  restart-nginx    - Restart Nginx server"
	@echo "  build-frontend   - Build frontend for production"
	@echo "  run              - Run both servers in development mode"
	@echo "  run-production   - Run application in production mode with Nginx"
	@echo "  clean            - Remove all generated files and dependencies"
	@echo "  help             - Show this help message"
