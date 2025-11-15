# 🔄 Credential Rotation Guide

## 🚨 **Emergency Rotation (If Credentials Exposed)**

### 1. **Supabase Credentials**
1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Navigate to Settings > API
3. Click "Generate new anon key"
4. Update `config/secure/.env` with new key
5. Test app functionality

### 2. **Firebase Credentials**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Project Settings > General
3. Delete current app registration
4. Add new Android app
5. Download new `google-services.json`
6. Replace `config/secure/google-services.json`
7. Update OAuth settings if needed

### 3. **Android Signing Key**
1. Generate new keystore:
   ```bash
   keytool -genkey -v -keystore app-release-key-new.jks \
           -keyalg RSA -keysize 2048 -validity 10000 \
           -alias oishimenu-new
   ```
2. Update `config/secure/key.properties`
3. Upload new key to Google Play Console
4. Test signing process

## 🔍 **Security Audit Commands**

Check for any remaining secrets in git:
```bash
# Search for common secret patterns
git log --all --full-history --grep="password\|key\|secret\|token"
git rev-list --all | xargs git grep -l "admin123\|AIza\|sk_"
```

## ⚡ **Quick Security Check**
```bash
# Verify secure files are ignored
git status --ignored | grep config/secure
git status --ignored | grep google-services.json
git status --ignored | grep key.properties
```