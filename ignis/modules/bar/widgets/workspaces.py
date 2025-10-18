from ignis import widgets
from ignis.services.hyprland import HyprlandService, HyprlandWorkspace

hyprland = HyprlandService.get_default()


def get_workspace_hotkey(workspace_id: int) -> str:
    """Map workspace ID to its hotkey"""
    hotkey_map = {
        1: "1", 2: "2", 3: "3", 4: "4", 5: "5", 
        6: "6", 7: "7", 8: "8", 9: "9", 10: "0",
        11: "O", 12: "C", 13: "N", 14: "M", 15: "T"
    }
    return hotkey_map.get(workspace_id, str(workspace_id))


class WorkspaceButton(widgets.Button):
    def __init__(self, workspace: HyprlandWorkspace) -> None:
        hotkey = get_workspace_hotkey(workspace.id)
        super().__init__(
            css_classes=["workspace", "unset"],
            on_click=lambda x: workspace.switch_to(),
            halign="start",
            valign="center",
            child=widgets.Label(
                label=hotkey,
                css_classes=["workspace-label"]
            )
        )
        if workspace.id == hyprland.active_workspace.id:
            self.add_css_class("active")


def scroll_workspaces(direction: str) -> None:
    current = hyprland.active_workspace.id
    if direction == "up":
        target = current - 1
        hyprland.switch_to_workspace(target)
    else:
        target = current + 1
        if target == 11:
            return
        hyprland.switch_to_workspace(target)


class Workspaces(widgets.Box):
    def __init__(self):
        if hyprland.is_available:
            child = [
                widgets.EventBox(
                    on_scroll_up=lambda x: scroll_workspaces("up"),
                    on_scroll_down=lambda x: scroll_workspaces("down"),
                    css_classes=["workspaces"],
                    child=hyprland.bind_many(
                        ["workspaces", "active_workspace"],
                        transform=lambda workspaces, *_: [
                            WorkspaceButton(i) for i in workspaces
                        ],
                    ),
                )
            ]
        else:
            child = []
        super().__init__(child=child)
