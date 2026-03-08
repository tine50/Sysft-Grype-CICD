# Image officielle Syft (Anchore) - pas besoin d'installer Syft sur l'hôte
FROM anchore/syft:latest

WORKDIR /workspace

# Par défaut, afficher l'aide si aucune commande n'est passée
ENTRYPOINT ["syft"]
CMD ["--help"]
