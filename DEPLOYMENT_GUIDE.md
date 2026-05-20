# 🚀 DEPLOYMENT GUIDE - E-Commerce Platform

## Your Setup:
- **Backend**: Flask (Python) → Deploy to Render
- **Web Frontend**: Flask Templates (HTML/CSS/JS) → Included in backend
- **Mobile App**: Flutter → Separate deployment
- **Database**: Supabase (Already hosted) ✅

---

## ✅ PRE-DEPLOYMENT CHECKLIST

### 1. Database (Supabase) - READY ✅
- [x] Database schema created
- [x] Tables and indexes exist
- [ ] **Run indexing** (RUN_THIS_INDEXING.sql) - DO THIS FIRST!
- [x] Environment variables ready

### 2. Backend Code - ALMOST READY ⚠️
- [x] Flask app configured
- [x] API routes working
- [x] CORS configured
- [x] Gunicorn installed
- [ ] **Need to fix render.yaml** (see below)
- [ ] **Need .gitignore**
- [ ] **Need environment variables**

### 3. Security - NEEDS ATTENTION ⚠️
- [ ] Change SECRET_KEY (production key)
- [ ] Remove .env from git
- [ ] Set up environment variables in Render
- [ ] Enable HTTPS only
- [ ] Update CORS origins

---

## 🔧 STEP 1: FIX BACKEND FILES (5 minutes)

### Fix 1: Update render.yaml
Your current render.yaml has an error. Replace it with this:

```yaml
services:
  - type: web
    name: marketplace-backend
    env: python
    region: singapore
    plan: free
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn app:create_app() --bind 0.0.0.0:$PORT
    envVars:
      - key: PYTHON_VERSION
        value: 3.11.0
```

### Fix 2: Create .gitignore
Create this file to protect sensitive data:

```
# Environment
.env
.env.local
.env.production

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/

# Flask
instance/
.webassets-cache

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
```

### Fix 3: Update requirements.txt
Add missing dependencies:

```
flask==3.0.0
supabase==2.3.0
python-dotenv==1.0.0
bcrypt==4.1.2
pandas==2.1.4
openpyxl==3.1.2
flask-cors==4.0.0
Pillow==10.2.0
gunicorn==21.2.0
requests==2.31.0
```

---

## 🚀 STEP 2: DEPLOY BACKEND TO RENDER (10 minutes)

### A. Prepare Your Code

1. **Run the indexing first!**
   ```
   Open Supabase → SQL Editor → Run RUN_THIS_INDEXING.sql
   ```

2. **Create a GitHub repository**
   ```bash
   cd c:\Users\Administrator\Desktop\2\1
   git init
   git add .
   git commit -m "Initial commit - E-commerce backend"
   ```

3. **Push to GitHub**
   - Go to https://github.com/new
   - Create new repository: `ecommerce-backend`
   - Follow instructions to push your code

### B. Deploy to Render

1. **Go to Render**: https://render.com
2. **Sign up/Login** (use GitHub account)
3. **Click "New +"** → **"Web Service"**
4. **Connect your GitHub repository**
5. **Configure:**
   - **Name**: `ecommerce-backend`
   - **Region**: Singapore (or closest to you)
   - **Branch**: `main`
   - **Root Directory**: Leave empty
   - **Runtime**: Python 3
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:create_app() --bind 0.0.0.0:$PORT`
   - **Plan**: Free

6. **Add Environment Variables** (Click "Advanced" → "Add Environment Variable"):
   ```
   SUPABASE_URL = https://opusrotqhtkhmeefvydh.supabase.co
   SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wdXNyb3RxaHRraG1lZWZ2eWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NTU3MzMsImV4cCI6MjA5MzEzMTczM30.-Lo362tNRftWbvXK2kds7r5CpDeXb5vYN6K3rBhQlvw
   SUPABASE_SERVICE_ROLE_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wdXNyb3RxaHRraG1lZWZ2eWRoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NzU1NTczMywiZXhwIjoyMDkzMTMxNzMzfQ.GYBLr1o5eH5iR0VA52Wab9B8Tysp9393Two7b7LvYdk
   SECRET_KEY = YOUR_NEW_PRODUCTION_SECRET_KEY_HERE_CHANGE_THIS
   SMTP_SERVER = smtp.gmail.com
   SMTP_PORT = 587
   EMAIL_ADDRESS = yasona.ryan11@gmail.com
   EMAIL_PASSWORD = chiu xztu lqkq vrbi
   EMAIL_USE_TLS = True
   RECAPTCHA_SITE_KEY = 6LdhWtcsAAAAAFtrjhnjbqO0zGWeoNPD8GT7Q518
   RECAPTCHA_SECRET_KEY = 6LdhWtcsAAAAAERiayKHwYP6zFRnVLBsfR1t3qAr
   FLASK_DEBUG = false
   FLASK_HOST = 0.0.0.0
   ALLOWED_ORIGINS = https://your-domain.com,https://www.your-domain.com
   ```

   **⚠️ IMPORTANT**: Change `SECRET_KEY` to a new random string!
   Generate one: https://randomkeygen.com/ (use "Fort Knox Password")

7. **Click "Create Web Service"**

8. **Wait 5-10 minutes** for deployment

9. **Your backend will be live at**: `https://ecommerce-backend.onrender.com`

---

## 🌐 STEP 3: WEB FRONTEND (Already Included!)

**Good news!** Your web frontend is already included in the Flask backend (HTML templates).

### Your web app will be accessible at:
```
https://ecommerce-backend.onrender.com/
```

### Routes:
- `/` - Home page (product listing)
- `/login` - Login page
- `/register` - Registration
- `/buyer/dashboard` - Buyer dashboard
- `/seller/dashboard` - Seller dashboard
- `/admin/dashboard` - Admin dashboard
- `/rider/dashboard` - Rider dashboard

**No separate Vercel deployment needed for web!** ✅

---

## 📱 STEP 4: UPDATE MOBILE APP (5 minutes)

Update your Flutter app to use the production backend:

### File: `mobile_application/lib/services/supabase_service.dart`

Find the API base URL and update it:

```dart
// OLD (local)
static const String apiBaseUrl = 'http://localhost:5000/api';

// NEW (production)
static const String apiBaseUrl = 'https://ecommerce-backend.onrender.com/api';
```

---

## ✅ STEP 5: VERIFY DEPLOYMENT (5 minutes)

### Test Backend:
1. Open: `https://ecommerce-backend.onrender.com/`
2. Should see the home page with products
3. Try login: `https://ecommerce-backend.onrender.com/login`

### Test API:
```bash
# Test products API
curl https://ecommerce-backend.onrender.com/api/products

# Should return JSON with products
```

### Test Mobile App:
1. Update API URL in Flutter app
2. Run the app
3. Try login, browse products, etc.

---

## 🔒 STEP 6: SECURITY CHECKLIST

### Before Going Live:

- [ ] **Change SECRET_KEY** to a strong random string
- [ ] **Update ALLOWED_ORIGINS** with your actual domain
- [ ] **Enable HTTPS only** (Render does this automatically)
- [ ] **Remove .env from git** (add to .gitignore)
- [ ] **Review Supabase RLS policies**
- [ ] **Test all user roles** (buyer, seller, rider, admin)
- [ ] **Set up email verification**
- [ ] **Test payment flow** (if using GCash)
- [ ] **Set up monitoring** (Render dashboard)

---

## 📊 STEP 7: MONITORING & MAINTENANCE

### Render Dashboard:
- View logs: Render Dashboard → Your Service → Logs
- Monitor performance: Check CPU/Memory usage
- Set up alerts: Settings → Notifications

### Supabase Dashboard:
- Monitor database: Database → Query Performance
- Check storage: Storage → Usage
- Review logs: Logs → API Logs

---

## 🐛 TROUBLESHOOTING

### Issue: "Application failed to start"
**Solution**: Check Render logs for errors
```
Render Dashboard → Your Service → Logs
```

### Issue: "Module not found"
**Solution**: Check requirements.txt has all dependencies
```bash
pip freeze > requirements.txt
git add requirements.txt
git commit -m "Update dependencies"
git push
```

### Issue: "Database connection failed"
**Solution**: Check environment variables in Render
- Verify SUPABASE_URL
- Verify SUPABASE_SERVICE_ROLE_KEY

### Issue: "CORS error from mobile app"
**Solution**: Update ALLOWED_ORIGINS
```
ALLOWED_ORIGINS = *
```
(For testing only, use specific domains in production)

### Issue: "Slow performance"
**Solution**: 
1. Run the indexing SQL (RUN_THIS_INDEXING.sql)
2. Upgrade Render plan (free tier has limitations)
3. Enable caching

---

## 💰 COST BREAKDOWN

### Free Tier (Good for testing):
- **Render**: Free (sleeps after 15 min inactivity)
- **Supabase**: Free (500MB database, 1GB storage)
- **Total**: $0/month

### Paid Tier (Recommended for production):
- **Render**: $7/month (always on, better performance)
- **Supabase**: $25/month (8GB database, 100GB storage)
- **Total**: $32/month

---

## 🎯 DEPLOYMENT SUMMARY

| Component | Platform | Status | URL |
|-----------|----------|--------|-----|
| Database | Supabase | ✅ Live | https://opusrotqhtkhmeefvydh.supabase.co |
| Backend API | Render | 🔄 Deploy now | https://ecommerce-backend.onrender.com |
| Web Frontend | Render (included) | 🔄 Deploy now | https://ecommerce-backend.onrender.com |
| Mobile App | Local/Store | 📱 Update API URL | - |

---

## 📝 NEXT STEPS

1. ✅ **Run indexing SQL** (RUN_THIS_INDEXING.sql in Supabase)
2. 🔧 **Fix render.yaml** (use the corrected version above)
3. 🔒 **Create .gitignore** (protect sensitive files)
4. 📦 **Push to GitHub**
5. 🚀 **Deploy to Render**
6. 🔐 **Add environment variables** in Render
7. 🌐 **Test web app**
8. 📱 **Update mobile app API URL**
9. ✅ **Test everything**
10. 🎉 **Go live!**

---

## 🆘 NEED HELP?

**Common Issues:**
- Render deployment fails → Check logs
- Database errors → Check Supabase connection
- CORS errors → Update ALLOWED_ORIGINS
- Slow performance → Run indexing SQL

**Resources:**
- Render Docs: https://render.com/docs
- Supabase Docs: https://supabase.com/docs
- Flask Docs: https://flask.palletsprojects.com/

---

**Ready to deploy? Start with Step 1!** 🚀
