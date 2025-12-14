#!/bin/bash
set -e

echo "Installing missing prerequisites for EKS microservices project..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Docker Desktop
if ! command -v docker &> /dev/null; then
    echo "Installing Docker Desktop..."
    brew install --cask docker
    echo "⚠️  Please start Docker Desktop app manually after installation"
else
    echo "✅ Docker already installed"
fi

# Install Helm
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    brew install helm
else
    echo "✅ Helm already installed"
fi

echo ""
echo "Verification:"
echo "AWS CLI: $(aws --version 2>&1 | head -1)"
echo "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'kubectl installed')"
echo "eksctl: $(eksctl version)"
echo "Docker: $(docker --version 2>/dev/null || echo 'Start Docker Desktop app')"
echo "Helm: $(helm version --short 2>/dev/null || echo 'helm installed')"

echo ""
echo "✅ Prerequisites installation completed!"
echo "🔄 Next steps:"
echo "1. Start Docker Desktop app"
echo "2. Run: aws configure (if not configured)"
echo "3. Run: ./scripts/build-and-push.sh"