# 🔒 Security Configuration Setup

This document explains how to set up the secure configuration for the OishiMenu app after the security fixes.

## 📁 **Secure Configuration Structure**

```
config/
├── secure/              # 🚫 Git-ignored directory containing actual credentials
│   ├── .env            # Supabase credentials
│   ├── google-services.json  # Firebase configuration
│   └── key.properties  # Android signing keys
├── .env.example        # Environment template
├── google-services.json.template  # Firebase template
└── key.properties.template        # Signing key template
```

## 🚀 **Setup Instructions**

### 1. **First Time Setup**

Copy the template files to create your secure configuration:

```bash
# Copy templates to secure directory
mkdir -p config/secure
cp .env.example config/secure/.env
cp config/google-services.json.template config/secure/google-services.json
cp config/key.properties.template config/secure/key.properties
```

### 2. **Fill in Your Credentials**

Edit each file with your actual credentials:

#### `config/secure/.env`
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-actual-anon-key
```

#### `config/secure/google-services.json`
Download from your Firebase Console and replace the template.

#### `config/secure/key.properties`
```properties
storePassword=your-strong-store-password
keyPassword=your-strong-key-password
keyAlias=your-key-alias
storeFile=../app-release-key.jks
```

### 3. **Before Building**

Always run the setup script before building:

```bash
./scripts/setup-secure-config.sh
```

This copies the secure config files to their expected locations.

## 🛠 **Build Process**

### Debug Build
```bash
./scripts/setup-secure-config.sh
flutter build apk --debug
```

### Release Build
```bash
./scripts/setup-secure-config.sh
flutter build appbundle --release
```

## 🔐 **Security Features Implemented**

### ✅ **Fixed Critical Issues**

1. **Removed Hardcoded Admin Credentials**
   - No more `admin@oishimenu.com` / `admin123`
   - Admin users must be created through proper registration

2. **Secured Firebase Configuration**
   - `google-services.json` moved to git-ignored location
   - Template provided for team members

3. **Protected Android Signing Keys**
   - `key.properties` moved to secure location
   - Build script handles file copying

4. **Environment Variables**
   - Supabase credentials in git-ignored `.env` file
   - Proper error handling for missing variables

### 🚫 **Git-Ignored Files**

These files are now git-ignored for security:
- `config/secure/` (entire directory)
- `android/app/google-services.json`
- `android/key.properties`
- `.env`

## 👥 **Team Setup**

For new team members:

1. **Get secure config files from team lead**
2. **Place in `config/secure/` directory**
3. **Run setup script before building**
4. **Never commit files from `config/secure/`**

## ⚠️ **Security Warnings**

- **Never commit actual credentials to git**
- **Always use strong passwords for signing keys**
- **Rotate credentials if accidentally exposed**
- **Use different credentials for dev/staging/production**

## 🔧 **Troubleshooting**

### Build Fails with "google-services.json not found"
```bash
./scripts/setup-secure-config.sh
```

### "Missing keystore properties"
Ensure `config/secure/key.properties` exists with correct values.

### "Supabase initialization failed"
Check that `config/secure/.env` has valid Supabase credentials.

## 📝 **Production Checklist**

Before production deployment:

- [ ] Rotate all credentials from templates
- [ ] Use strong, unique passwords
- [ ] Verify no credentials in git history
- [ ] Test build process on clean checkout
- [ ] Document credential rotation process

---

**Remember**: Security is ongoing! Regularly review and update credentials.