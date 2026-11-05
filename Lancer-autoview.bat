@echo off
chcp 65001 >nul
title YouLikeHits - Gains de points automatiques
cd /d "%~dp0"

echo ============================================================
echo   YouLikeHits - gain de points automatique
echo ------------------------------------------------------------
echo   Profil Chrome : Livre (Profile 2)
echo   Video fermee 5 s apres le clic sur View
echo   Attente du credit : jusqu'a 140 s par video
echo   Extinction de Windows : 1 heure apres le lancement
echo   (annuler : shutdown /a dans une invite de commandes)
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ylh-autoview.ps1" -Cycles 30 -StartWatch 5 -MaxWatch 140 -EteindreOrdinateur

echo.
echo Termine. Journal : %~dp0ylh-autoview.log
echo Appuie sur une touche pour fermer cette fenetre.
pause >nul
