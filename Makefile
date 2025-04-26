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

# Setup Nginx configuration
.PHONY: setup-nginx
setup-nginx: check-nginx
	@echo "Setting up Nginx configuration..."
	@if [ "$(shell uname)" != "Windows_NT" ]; then \
		sudo mkdir -p /var/www/static; \
		sudo cp nginx.conf $(NGINX_CONF_FILE); \
		sudo systemctl restart nginx; \
	else \
		echo "Nginx configuration on Windows is not supported by this Makefile."; \
	fi
	@echo "Nginx configuration complete."

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
run-production: build-frontend setup-nginx
	@echo "Starting production servers..."
	@cd backend && $(VENV_PYTHON) -B -m uvicorn app.main:app &
	@echo "Backend server started."
	@make restart-nginx
	@echo "Application is now running in production mode with Nginx."
	@echo "Access your application at http://localhost"

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
	@echo "  setup-backend    - Set up Python virtual environment and install backend dependencies"
	@echo "  setup-frontend   - Install frontend dependencies"
	@echo "  setup-database   - Create database"
	@echo "  setup-nginx      - Configure Nginx for the application"
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
