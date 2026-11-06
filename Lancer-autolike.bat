@echo off
chcp 65001 >nul
title YouLikeHits - Twitter Likes automatique
cd /d "%~dp0"

echo ============================================================
echo   YouLikeHits - Twitter Likes automatique
echo ------------------------------------------------------------
echo   Profil Chrome : Livre (Profile 2)
echo   Like le tweet sur X, revient sur YouLikeHits et clique
echo   la confirmation "I Liked" pour encaisser les points.
echo   Extinction de Windows : 1 heure apres le lancement
echo   (annuler : shutdown /a dans une invite de commandes)
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ylh-autolike.ps1" -Cycles 30 -MaxWait 45 -EteindreOrdinateur

echo.
echo Termine. Journal : %~dp0ylh-autolike.log
echo Appuie sur une touche pour fermer cette fenetre.
pause >nul
