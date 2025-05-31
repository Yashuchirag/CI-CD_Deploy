# Windows-Compatible Makefile for Python Demo App
# Adjusted for `.venv` at root level and Windows shell commands

# Container config
IMAGE_REG ?= ghcr.io
IMAGE_REPO ?= benc-uk/python-demoapp
IMAGE_TAG ?= latest

# Azure deployment config
AZURE_RES_GROUP ?= temp-demoapps
AZURE_REGION ?= uksouth
AZURE_SITE_NAME ?= pythonapp-$(shell git rev-parse --short HEAD)

# API test host
TEST_HOST ?= localhost:5000

# Source directory
SRC_DIR := src

.PHONY: help lint lint-fix image push run deploy undeploy clean test test-report test-api venv
.DEFAULT_GOAL := help

help:  ## 💬 This help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

venv:
	python -m venv .venv
	.venv\Scripts\python.exe -m pip install -r $(SRC_DIR)/requirements.txt

lint: venv  ## 🔎 Lint & format, will not fix but sets exit code on error
	.venv\Scripts\python.exe -m black --check $(SRC_DIR)
	.venv\Scripts\python.exe -m flake8 src/app/
	.venv\Scripts\python.exe -m flake8 src/run.py

lint-fix: venv  ## 📜 Lint & format, will try to fix errors and modify code
	.venv\Scripts\python.exe -m black $(SRC_DIR)

image:  ## 🔨 Build container image from Dockerfile
	docker build . --file build/Dockerfile --tag $(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG)

push:  ## 📤 Push container image to registry
	docker push $(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG)

run: venv  ## 🏃 Run the server locally using Python & Flask
	.venv\Scripts\python.exe $(SRC_DIR)/run.py

deploy:  ## 🚀 Deploy to Azure Web App
	az group create --resource-group $(AZURE_RES_GROUP) --location $(AZURE_REGION) -o table
	az deployment group create --template-file deploy/webapp.bicep \
		--resource-group $(AZURE_RES_GROUP) \
		--parameters webappName=$(AZURE_SITE_NAME) \
		--parameters webappImage=$(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG) -o table
	@echo "### 🚀 Web app deployed to https://$(AZURE_SITE_NAME).azurewebsites.net/"

undeploy:  ## 💀 Remove from Azure
	@echo "### WARNING! Going to delete $(AZURE_RES_GROUP) 😲"
	az group delete -n $(AZURE_RES_GROUP) -o table --no-wait

test: venv  ## 🎯 Unit tests for Flask app
	.venv\Scripts\python.exe -m pytest -v

test-report: venv  ## 🎯 Unit tests for Flask app (with report output)
	.venv\Scripts\python.exe -m pytest -v --junitxml=test-results.xml

test-api:  ## 🚦 Run integration API tests, server must be running
	cd tests && npm install newman && node_modules\.bin\newman run postman_collection.json --env-var apphost=$(TEST_HOST)

clean:  ## 🧹 Clean up project
	rmdir /s /q .venv
	rmdir /s /q tests\node_modules
	del /q tests\package*
	del /q test-results.xml
	rmdir /s /q $(SRC_DIR)\app\__pycache__
	rmdir /s /q $(SRC_DIR)\app\tests\__pycache__
	rmdir /s /q .pytest_cache
	rmdir /s /q $(SRC_DIR)\.pytest_cache