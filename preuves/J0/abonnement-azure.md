# J0 · Vérifier l’abonnement Azure

Vérification effectuée le 17 novembre 2026 avec Azure CLI.

1. `az account show --query '{Abonnement:name,Etat:state}' -o table` affiche **Azure for Students** et **Enabled**.
2. `az policy assignment list --filter 'atScope()'` expose la règle **Allowed resource deployment regions**. Les régions autorisées sont Italie Nord, Norvège Est, Suisse Nord, Belgique Centre et Danemark Est.
3. `az provider show --namespace Microsoft.App --query registrationState -o tsv` et la commande équivalente pour `Microsoft.ContainerRegistry` renvoient toutes les deux `Registered`. Azure a accepté les ressources ACR et Container Apps en Belgique Centre.
4. Lors de la reconstruction, Azure a refusé un deuxième environnement en Belgique Centre à cause du quota. La vérification J3 a ensuite utilisé un groupe dédié en Suisse Nord, qui fait partie des régions autorisées. [Preuve J3](../J3/creation-cli-acr.md)
5. Le solde des crédits peut être consulté dans [Azure Sponsorships](https://www.microsoftazuresponsorships.com/balance) avec le compte étudiant. Le registre de production est en Basic et les apps utilisent le profil Consumption. Le groupe temporaire du J3 a servi à tester le nettoyage.
