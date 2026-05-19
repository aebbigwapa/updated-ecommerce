@echo off
echo ========================================
echo PUSHING TO GITHUB
echo ========================================
echo.

echo [1/5] Initializing Git repository...
git init
if errorlevel 1 (
    echo Error: Git initialization failed
    pause
    exit /b 1
)
echo Done!
echo.

echo [2/5] Adding all files...
git add .
if errorlevel 1 (
    echo Error: Failed to add files
    pause
    exit /b 1
)
echo Done!
echo.

echo [3/5] Committing changes...
git commit -m "Initial commit - E-commerce platform ready for deployment"
if errorlevel 1 (
    echo Error: Commit failed
    pause
    exit /b 1
)
echo Done!
echo.

echo [4/5] Adding remote repository...
git remote add origin https://github.com/aebbigwapa/updated-ecommerce.git
if errorlevel 1 (
    echo Note: Remote might already exist, trying to set URL...
    git remote set-url origin https://github.com/aebbigwapa/updated-ecommerce.git
)
echo Done!
echo.

echo [5/5] Pushing to GitHub...
git branch -M main
git push -u origin main --force
if errorlevel 1 (
    echo Error: Push failed
    echo.
    echo Possible reasons:
    echo - You need to login to GitHub
    echo - Repository doesn't exist
    echo - No permission to push
    echo.
    pause
    exit /b 1
)
echo Done!
echo.

echo ========================================
echo SUCCESS! Code pushed to GitHub!
echo ========================================
echo.
echo Repository: https://github.com/aebbigwapa/updated-ecommerce
echo.
echo Next steps:
echo 1. Go to https://render.com
echo 2. Create new Web Service
echo 3. Connect this GitHub repository
echo 4. Deploy!
echo.
pause
