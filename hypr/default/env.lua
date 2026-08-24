local environment = {
    XCURSOR_SIZE = "24",
    XCURSOR_THEME = "Adwaita",
    LIBVA_DRIVER_NAME = "nvidia",
    XDG_SESSION_TYPE = "wayland",
    GBM_BACKEND = "nvidia-drm",
    __GLX_VENDOR_LIBRARY_NAME = "nvidia",
    NVD_BACKEND = "direct",
    ELECTRON_OZONE_PLATFORM_HINT = "auto",
    MOZ_DISABLE_RDD_SANDBOX = "1",
    EGL_PLATFORM = "wayland",
    MOZ_ENABLE_WAYLAND = "1",
    QT_QPA_PLATFORM = "wayland",
    QT_QPA_PLATFORMTHEME = "qt5ct",
    GTK_THEME = "Material",
}

for name, value in pairs(environment) do
    hl.env(name, value)
end
