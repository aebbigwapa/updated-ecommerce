# ✅ DEPLOYMENT CHECKLIST - Tagalog

## Bago mag-deploy, gawin mo muna ito:

### 1. Database Optimization (5 minutes) ⚡
- [ ] Buksan ang Supabase Dashboard
- [ ] Go to SQL Editor
- [ ] Run ang **RUN_THIS_INDEXING.sql**
- [ ] Verify: Dapat walang errors

**Bakit importante?** Para mabilis ang lahat ng queries! 10-30x faster!

---

### 2. Backend Files (DONE!) ✅
- [x] render.yaml - Fixed na!
- [x] .gitignore - Created na!
- [x] requirements.txt - Updated na!

---

### 3. GitHub Setup (10 minutes) 📦

```bash
# Sa terminal/command prompt:
cd c:\Users\Administrator\Desktop\2\1

# Initialize git
git init

# Add files
git add .

# Commit
git commit -m "Initial commit - E-commerce platform"
```

**Then:**
1. Go to https://github.com/new
2. Create repository: `ecommerce-backend`
3. Copy the commands and run:
```bash
git remote add origin https://github.com/YOUR_USERNAME/ecommerce-backend.git
git branch -M main
git push -u origin main
```

---

### 4. Render Deployment (10 minutes) 🚀

**A. Sign up/Login:**
1. Go to https://render.com
2. Sign up with GitHub account

**B. Create Web Service:**
1. Click "New +" → "Web Service"
2. Connect your GitHub repository
3. Select `ecommerce-backend`

**C. Configure:**
- **Name**: `ecommerce-backend`
- **Region**: Singapore
- **Branch**: `main`
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `gunicorn app:create_app() --bind 0.0.0.0:$PORT`
- **Plan**: Free

**D. Add Environment Variables:**

Click "Advanced" → "Add Environment Variable" → Add these:

```
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
SECRET_KEY (⚠️ CHANGE THIS! Use: https://randomkeygen.com/)
SMTP_SERVER
SMTP_PORT
EMAIL_ADDRESS
EMAIL_PASSWORD
EMAIL_USE_TLS
RECAPTCHA_SITE_KEY
RECAPTCHA_SECRET_KEY
FLASK_DEBUG = false
FLASK_HOST = 0.0.0.0
ALLOWED_ORIGINS = *
```

**Copy from your .env file, pero CHANGE ang SECRET_KEY!**

**E. Deploy:**
1. Click "Create Web Service"
2. Wait 5-10 minutes
3. Done! ✅

---

### 5. Test Deployment (5 minutes) ✅

**Your URL:** `https://ecommerce-backend.onrender.com`

**Test these:**
- [ ] Home page: https://ecommerce-backend.onrender.com/
- [ ] Login: https://ecommerce-backend.onrender.com/login
- [ ] API: https://ecommerce-backend.onrender.com/api/products

**Dapat lahat working!** ✅

---

### 6. Update Mobile App (5 minutes) 📱

**File:** `mobile_application/lib/services/supabase_service.dart`

**Change:**
```dart
// OLD
static const String apiBaseUrl = 'http://localhost:5000/api';

// NEW
static const String apiBaseUrl = 'https://ecommerce-backend.onrender.com/api';
```

**Then test ang mobile app!**

---

## 🎯 SUMMARY

| Step | Time | Status |
|------|------|--------|
| 1. Run indexing SQL | 5 min | ⬜ TODO |
| 2. Backend files | 0 min | ✅ DONE |
| 3. GitHub setup | 10 min | ⬜ TODO |
| 4. Render deployment | 10 min | ⬜ TODO |
| 5. Test deployment | 5 min | ⬜ TODO |
| 6. Update mobile app | 5 min | ⬜ TODO |
| **TOTAL** | **35 min** | |

---

## 🚨 IMPORTANTE!

### Security:
- ⚠️ **CHANGE ang SECRET_KEY** sa production!
- ⚠️ **NEVER commit .env** to GitHub!
- ⚠️ **Use strong passwords** for admin accounts!

### Performance:
- ✅ **Run ang indexing SQL** para mabilis!
- ✅ **Monitor Render logs** for errors
- ✅ **Check Supabase usage** regularly

### Free Tier Limits:
- **Render Free**: Sleeps after 15 min inactivity (first request slow)
- **Supabase Free**: 500MB database, 1GB storage
- **Upgrade kung maraming users na!**

---

## 🆘 TROUBLESHOOTING

### "Build failed" sa Render:
- Check requirements.txt
- Check render.yaml
- View logs sa Render dashboard

### "Database connection error":
- Check SUPABASE_URL sa environment variables
- Check SUPABASE_SERVICE_ROLE_KEY

### "CORS error" sa mobile app:
- Set ALLOWED_ORIGINS = *
- Or add specific domain

### "Slow loading":
- Run ang indexing SQL!
- Upgrade Render plan
- Check Supabase performance

---

## 📞 RESOURCES

- **Render Dashboard**: https://dashboard.render.com
- **Supabase Dashboard**: https://supabase.com/dashboard
- **GitHub**: https://github.com
- **Deployment Guide**: DEPLOYMENT_GUIDE.md (detailed version)

---

## ✅ READY?

**Start with Step 1: Run ang indexing SQL!**

Then follow steps 3-6 para ma-deploy!

**Good luck!** 🚀
