# GitHub Actions Workflows

This repository includes several GitHub Actions workflows for automated building, testing, and releasing of the Recurra app.

## Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)
**Triggers:** Push to `main`/`develop` branches, Pull Requests to `main`

**What it does:**
- Builds the app in both Debug and Release configurations
- Creates an archive of the app
- Runs tests (if any are added)
- Runs SwiftLint for code quality checks
- Uploads build artifacts for download

### 2. Build Workflow (`.github/workflows/build.yml`)
**Triggers:** Push to `main`/`develop` branches, Pull Requests to `main`, Manual trigger

**What it does:**
- Builds the app in Release configuration
- Creates an archive
- Exports the app as a distributable format
- Creates a DMG file
- Uploads both the app and DMG as artifacts

### 3. Release Workflow (`.github/workflows/release.yml`)
**Triggers:** Git tags starting with 'v' (e.g., `v1.0.0`), Manual trigger

**What it does:**
- Builds and signs the app with Developer ID
- Creates a DMG file
- Notarizes the DMG with Apple
- Creates a GitHub release with the DMG attached

## Setup Instructions

### For Basic CI/CD (CI and Build workflows)
No additional setup required! These workflows will work out of the box.

### For Release Distribution (Release workflow)
You'll need to set up the following secrets in your GitHub repository:

1. Go to your repository → Settings → Secrets and variables → Actions
2. Add the following secrets:

#### Required Secrets:
- `CERTIFICATE_P12`: Your Developer ID Application certificate in P12 format (base64 encoded)
- `CERTIFICATE_PASSWORD`: Password for the P12 certificate
- `APPLE_ID`: Your Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password for your Apple ID
- `APPLE_TEAM_ID`: Your Apple Developer Team ID

#### How to get these values:

1. **CERTIFICATE_P12**: Export your Developer ID Application certificate from Keychain Access as a P12 file, then base64 encode it:
   ```bash
   base64 -i YourCertificate.p12 | pbcopy
   ```

2. **CERTIFICATE_PASSWORD**: The password you set when exporting the P12 file

3. **APPLE_ID**: Your Apple Developer account email

4. **APPLE_APP_SPECIFIC_PASSWORD**: Generate this in your Apple ID account settings under "App-Specific Passwords"

5. **APPLE_TEAM_ID**: Find this in your Apple Developer account under "Membership"

### Environment Setup
The Release workflow uses a GitHub Environment called "release". You may need to create this environment in your repository settings if it doesn't exist.

## Usage

### Running CI
- Push code to `main` or `develop` branches
- Create a Pull Request to `main`
- The CI workflow will automatically run

### Creating a Release
1. Create and push a git tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. The Release workflow will automatically build, sign, notarize, and create a GitHub release

### Manual Builds
- Go to Actions tab in your repository
- Select "Build Recurra" or "CI" workflow
- Click "Run workflow" button
- Choose the branch and click "Run workflow"

## Artifacts

All workflows produce artifacts that you can download:
- **Recurra-archive**: Xcode archive file
- **Recurra-build**: Built app bundle
- **Recurra-DMG**: DMG file for distribution
- **test-results**: Test results (if tests are run)

## Troubleshooting

### Common Issues:
1. **Build fails**: Check that all dependencies are properly configured in the Xcode project
2. **Code signing fails**: Verify that your certificates and provisioning profiles are correctly set up
3. **Notarization fails**: Ensure your Apple ID credentials are correct and you have the necessary permissions

### Viewing Logs:
- Go to the Actions tab in your repository
- Click on the failed workflow run
- Click on the failed job to see detailed logs
