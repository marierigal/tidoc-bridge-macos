# Installer TiDoc

Ce guide explique comment installer et configurer TiDoc sur votre Mac.

## 1. Ouvrir l'application

Double-cliquez sur **TiDoc Bridge**.

Un message apparaît indiquant que l'application ne peut pas être ouverte. C'est normal — l'application n'étant pas distribuée via l'App Store, macOS demande une confirmation de votre part avant de l'autoriser. Cliquez sur **OK** pour fermer ce message, puis :

1. Ouvrez **Réglages Système**.
2. Allez dans **Confidentialité et sécurité**.
3. Faites défiler jusqu'en bas, dans la section **Sécurité**. Vous devriez y voir une mention concernant "TiDoc".
4. Cliquez sur **Ouvrir quand même**.
5. Confirmez avec votre mot de passe ou Touch ID.
6. Une dernière fenêtre apparaît : cliquez sur **Ouvrir**.

Cette étape ne sera plus nécessaire aux lancements suivants.

## 2. Autoriser l'accès complet au disque

TiDoc a besoin d'accéder à certains dossiers pour installer le complément dans Word. macOS demande votre accord explicite pour ce type d'accès :

1. **Réglages Système → Confidentialité et sécurité → Accès complet au disque**.
2. Repérez **TiDoc** dans la liste et activez la case à côté.
3. Si l'application n'apparaît pas dans la liste, cliquez sur **+**, puis sélectionnez l'application dans le dossier où vous l'avez installée.

## 3. Confirmer la sécurité de la connexion

Au premier lancement, une fenêtre du **Trousseau d'accès** (l'outil de sécurité de macOS) peut apparaître, demandant à TiDoc la permission d'apporter une modification. C'est une étape normale, liée à la mise en place d'une connexion sécurisée en local sur votre machine. Entrez votre mot de passe de session pour confirmer.

Cette étape n'apparaît qu'une seule fois.

## 4. Se connecter au CRM

Une fois lancée, TiDoc s'installe dans la **barre de menu** en haut de votre écran (à côté de l'heure, de la Wi-Fi...) — elle ne s'ouvre pas comme une fenêtre classique.

1. Cliquez sur l'icône de TiDoc dans la barre de menu.
2. Cliquez sur **"Se connecter au CRM"**.
3. Une fenêtre s'ouvre avec la page de connexion habituelle du CRM — connectez-vous normalement avec vos identifiants.
4. Une fois connecté, la fenêtre se referme automatiquement.

Cette connexion reste active — vous n'aurez pas à la refaire à chaque lancement.

## 5. Installer le complément dans Word

Toujours depuis le menu de TiDoc :

1. Cliquez sur **"Installer l'add-in Word"**.
2. Un message vous invite à redémarrer Word — fermez complètement Word (Cmd+Q) si vous l'aviez ouvert, puis rouvrez-le.
3. Dans Word, le complément **TiDoc** devrait maintenant être accessible depuis l'onglet **Accueil** puis l'i^ocne **Compléments**.

## 6. Utilisation au quotidien

- Les données clients se synchronisent en cliquant sur **"Synchroniser maintenant"** dans le menu de TiDoc, à chaque fois que vous voulez récupérer les dernières informations du CRM.
- TiDoc doit rester ouvert (dans la barre de menu) pour que le complément Word puisse accéder aux données clients.
