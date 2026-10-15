---
name: ipa
description: Récupère le dernier MotivPlan.ipa construit par la CI GitHub sur main et le dépose dans Downloads\MotivPlan, prêt à installer sur l'iPhone avec iloader. À utiliser quand l'utilisateur veut tester la dernière version sur son téléphone, récupérer ou mettre à jour le .ipa.
---

# Récupérer le .ipa pour iloader

1. Lancer `powershell -ExecutionPolicy Bypass -File scripts/get-ipa.ps1` depuis la racine du dépôt.
   - Si l'utilisateur veut la toute dernière version et que le script avertit que le .ipa ne contient pas le dernier commit de main, relancer avec `-Build`. Lancer cette commande en arrière-plan, car la construction prend 20 à 40 minutes.
   - Si la CI refuse de démarrer (quota ou facturation GitHub), le signaler tel quel : la cause n'est pas le code.
2. Rapporter le chemin du fichier, la version (titre et commit), puis rappeler la suite à l'utilisateur :
   - ouvrir iloader, iPhone branché en USB ;
   - installer le fichier `Downloads\MotivPlan\MotivPlan.ipa` ;
   - **ne jamais supprimer l'app avant**, sinon les données locales sont perdues : l'installation par-dessus met à jour l'app et garde les tâches.
