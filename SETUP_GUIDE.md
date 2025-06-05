# Setup Guide for Automated Builds

## 🚀 Quick Start

Your PostgreSQL image with pg_cron and pg_partman is now fully configured for automated builds! Here's what you need to do:

## ✅ Completed Setup

- [x] Alpine version support (`Dockerfile.alpine`)
- [x] GitHub Actions workflow (`.github/workflows/docker-build.yml`)
- [x] Multi-architecture builds (amd64, arm64)
- [x] Automated testing in CI
- [x] Security scanning with Trivy
- [x] Build system with Makefile
- [x] Repository pushed to GitHub

## 🔧 Required Configuration

### 1. Configure Docker Hub Secrets

You need to add these secrets to your GitHub repository:

1. Go to your GitHub repository: `https://github.com/qonics/postgres-pgcron`
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

   - **Name**: `DOCKER_USERNAME`
   - **Value**: Your Docker Hub username

   - **Name**: `DOCKER_PASSWORD`
   - **Value**: Your Docker Hub password or access token

> **💡 Pro Tip**: Use a Docker Hub access token instead of your password for better security.

### 2. Verify Workflow Triggers

The workflow will automatically trigger on:
- ✅ Push to `main` or `develop` branches
- ✅ Pull requests to `main`
- ✅ Git tags starting with `v*` (e.g., `v1.0.0`)
- ✅ Weekly scheduled builds (Sundays at 2 AM UTC)

## 🐳 Available Images

Once the workflow runs successfully, these images will be available:

### Standard (Debian-based)
```bash
docker pull qonicsinc/postgres-pgcron:17.5
docker pull qonicsinc/postgres-pgcron:latest
```

### Alpine (Smaller size)
```bash
docker pull qonicsinc/postgres-pgcron:17.5-alpine
docker pull qonicsinc/postgres-pgcron:alpine
```

## 🛠️ Local Development

### Build both variants locally:
```bash
make all
```

### Test both variants:
```bash
make test
make test-alpine
```

### Run containers for development:
```bash
# Standard version on port 5432
make run

# Alpine version on port 5433
make run-alpine
```

## 📊 Monitoring Builds

1. Check GitHub Actions: `https://github.com/qonics/postgres-pgcron/actions`
2. View Docker Hub images: `https://hub.docker.com/r/qonicsinc/postgres-pgcron`
3. Security scan results appear in GitHub Security tab

## 🏗️ Build Features

- **Multi-architecture**: amd64 and arm64
- **Caching**: Optimized build caching for faster builds
- **Testing**: Automated extension verification
- **Security**: Trivy vulnerability scanning
- **Documentation**: Auto-updated Docker Hub descriptions

## 🚨 Troubleshooting

### Build Fails
- Check GitHub Actions logs
- Verify Docker Hub credentials
- Ensure Dockerfile syntax is correct

### Missing Secrets
- Add `DOCKER_USERNAME` and `DOCKER_PASSWORD` to repository secrets
- Use Docker Hub access tokens for better security

### Tag Issues
- Use semantic versioning for tags (e.g., `v1.0.0`)
- Check tag naming conventions in workflow file

## 📚 Next Steps

1. Configure Docker Hub repository secrets ⚠️
2. Push a tag to trigger a release build
3. Monitor first automated build
4. Update Docker Hub description
5. Test multi-architecture images

## 🎉 Success Indicators

- ✅ GitHub Actions workflow shows green checkmarks
- ✅ Images appear on Docker Hub with both variants
- ✅ Security scan passes
- ✅ Docker Hub description is updated automatically
