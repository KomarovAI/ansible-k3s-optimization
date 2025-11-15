.PHONY: help install setup check deploy optimize security analyze backup clean install-audit run-audit show-config show-config-save

# Default target
help:
	@echo "🚀 Ansible K3s Optimization - Makefile Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make install    - Install Ansible and dependencies"
	@echo "  make setup      - Clone repository and setup environment"
	@echo ""
	@echo "Deployment:"
	@echo "  make check      - Dry run (check what would change)"
	@echo "  make deploy     - Deploy full setup (all roles)"
	@echo "  make optimize   - Run optimization only"
	@echo ""
	@echo "Analysis:"
	@echo "  make security   - Run security analysis"
	@echo "  make analyze    - Run system analysis"
	@echo "  make backup     - Backup configurations"
	@echo ""
	@echo "K3s Audit:"
	@echo "  make install-audit   - Install K3s audit tools"
	@echo "  make run-audit       - Run K3s cluster audit"
	@echo "  make show-config     - Display complete node configuration"
	@echo "  make show-config-save - Display and save node configuration"
	@echo ""
	@echo "Maintenance:"
	@echo "  make update     - Update playbooks from Git"
	@echo "  make clean      - Clean logs and temporary files"

install:
	@echo "📦 Installing dependencies..."
	apt update && apt install -y python3-pip python3-venv git
	python3 -m venv /opt/ansible-venv
	/opt/ansible-venv/bin/pip install ansible ansible-core
	@echo "✅ Installation complete!"

setup:
	@echo "🛠️ Setting up repository..."
	git clone https://github.com/KomarovAI/ansible-k3s-optimization.git /opt/k3s-ansible || true
	cd /opt/k3s-ansible && mkdir -p logs
	@echo "✅ Setup complete!"

check:
	@echo "🔍 Running dry-run check..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/full-setup.yml --check --diff

deploy:
	@echo "🚀 Deploying full setup..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/full-setup.yml

optimize:
	@echo "⚡ Running optimization..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/optimize-node.yml

security:
	@echo "🔒 Running security analysis..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/security-analysis.yml

analyze:
	@echo "📊 Running system analysis..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/analyze-master.yml

backup:
	@echo "💾 Creating backup..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/backup-configs.yml

# K3s Audit commands
install-audit:
	@echo "🔍 Installing K3s audit tools..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/setup-k3s-audit.yml

run-audit:
	@echo "📊 Running K3s cluster audit..."
	ansible k3s_masters -b -m command -a "k3s-cluster-audit"

show-config:
	@echo "📄 Displaying complete node configuration..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/show-node-config.yml

show-config-save:
	@echo "📄 Displaying and saving node configuration..."
	cd /opt/k3s-ansible && \
		source /opt/ansible-venv/bin/activate && \
		ansible-playbook playbooks/show-node-config.yml -e "save_to_file=true"

update:
	@echo "🔄 Updating from Git..."
	cd /opt/k3s-ansible && git pull origin main

clean:
	@echo "🧹 Cleaning logs and temp files..."
	cd /opt/k3s-ansible && rm -rf logs/*.log /tmp/ansible_facts
	@echo "✅ Cleanup complete!"
