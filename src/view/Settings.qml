// Réglages du plugin (PluginSettings de DMS). Déclaratif : chaque *Setting auto-persiste
// dans pluginData via son settingKey. Le widget (NoosphereWidget) lit flakePath / repoSlug /
// branch / githubToken / apiBase / checkMinutes et les injecte dans le service Noosphere.
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "noosphere"

    StyledText {
        width: parent.width
        text: "Réglages Noosphere"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "flakePath"
        label: "Chemin du flake"
        description: "Chemin local du flake NixOS à suivre (contenant flake.nix / flake.lock). Ex. « /etc/nixos » ou « /home/kuri/nixos »."
        placeholder: "/etc/nixos"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "repoSlug"
        label: "Dépôt (affichage)"
        description: "Identité du flake affichée dans l'en-tête du cockpit. Ex. « gfriloux/nixos »."
        placeholder: "owner/repo"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "branch"
        label: "Branche du flake"
        description: "Branche du dépôt du flake, affichée dans l'en-tête. Purement cosmétique (le retard des inputs se mesure sur leurs propres branches amont)."
        placeholder: "main"
        defaultValue: "main"
    }

    StringSetting {
        settingKey: "githubToken"
        label: "Token GitHub (optionnel)"
        description: "Token à portée publique (Fine-grained : lecture seule ; ou classic sans scope). Lève la limite de 60 requêtes/h de l'API compare. Stocké en clair dans la config du plugin ; envoyé en header Authorization: Bearer. Laisser vide pour l'API anonyme."
        placeholder: "github_pat_…"
        defaultValue: ""
    }

    SliderSetting {
        settingKey: "checkMinutes"
        label: "Cadence de check"
        description: "Fréquence d'interrogation de l'amont GitHub (minutes). Lecture seule, aucune écriture."
        defaultValue: 60
        minimum: 5
        maximum: 720
        unit: "min"
        leftIcon: "schedule"
    }

    StringSetting {
        settingKey: "apiBase"
        label: "Base de l'API GitHub (dev)"
        description: "Surcharge l'endpoint de l'API GitHub (défaut https://api.github.com). Sert au mock local en développement (just mock → http://127.0.0.1:8385). Laisser vide en usage normal."
        placeholder: "https://api.github.com"
        defaultValue: ""
    }
}
