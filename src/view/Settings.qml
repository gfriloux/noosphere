// The plugin's settings (DMS's PluginSettings). Declarative: each *Setting auto-persists
// into pluginData through its settingKey. The widget (NoosphereWidget) reads flakePath /
// repoSlug / branch / githubToken / apiBase / checkMinutes and injects them into the
// Noosphere service.
//
// Every label, description and placeholder is English and wrapped for translation, like the
// cockpit's own copy: the settings panel is as user-facing as the popout.
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "noosphere"

    StyledText {
        width: parent.width
        text: I18n.trFor("noosphere", "Noosphere settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "flakePath"
        label: I18n.trFor("noosphere", "Flake path")
        description: I18n.trFor("noosphere", "Local path of the NixOS flake to follow (the directory holding flake.nix / flake.lock). E.g. \"/etc/nixos\" or \"~/nixos\".")
        placeholder: "/etc/nixos"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "hostname"
        label: I18n.trFor("noosphere", "Hostname (closure diff)")
        description: I18n.trFor("noosphere", "The nixosConfigurations key to build for the closure preview (the CLOSURE DIFF card). Leave empty to resolve the current host through `hostname`.")
        placeholder: I18n.trFor("noosphere", "(current host)")
        defaultValue: ""
    }

    StringSetting {
        settingKey: "repoSlug"
        label: I18n.trFor("noosphere", "Repository (display)")
        description: I18n.trFor("noosphere", "The flake's identity, shown in the cockpit's header. E.g. \"gfriloux/nixos\".")
        placeholder: "owner/repo"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "branch"
        label: I18n.trFor("noosphere", "Flake branch")
        description: I18n.trFor("noosphere", "The branch of the flake's own repository, shown in the header. Purely cosmetic (how far behind an input is gets measured against its own upstream branch).")
        placeholder: "main"
        defaultValue: "main"
    }

    StringSetting {
        settingKey: "githubToken"
        label: I18n.trFor("noosphere", "GitHub token (optional)")
        description: I18n.trFor("noosphere", "A public-scope token (fine-grained: read-only; or classic with no scope). Lifts the compare API's 60 requests/h limit. Stored in cleartext in the plugin's config; sent as an Authorization: Bearer header. Leave empty for the anonymous API.")
        placeholder: "github_pat_…"
        defaultValue: ""
    }

    SliderSetting {
        settingKey: "checkMinutes"
        label: I18n.trFor("noosphere", "Check interval")
        description: I18n.trFor("noosphere", "How often GitHub upstream is polled (minutes). Read-only, never a write.")
        defaultValue: 60
        minimum: 5
        maximum: 720
        unit: I18n.trFor("noosphere", "min")
        leftIcon: "schedule"
    }

    StringSetting {
        settingKey: "apiBase"
        label: I18n.trFor("noosphere", "GitHub API base (dev)")
        description: I18n.trFor("noosphere", "Overrides the GitHub API endpoint (default https://api.github.com). For the local mock during development (just mock → http://127.0.0.1:8385). Leave empty in normal use.")
        placeholder: "https://api.github.com"
        defaultValue: ""
    }
}
