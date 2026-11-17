{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  desktop-file-utils,
  # Bibliotecas de runtime do Electron/Chromium.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gst_all_1,
  gtk3,
  harfbuzz,
  hicolor-icon-theme,
  krb5,
  libappindicator-gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-wm,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  libsm,
  libice,
  libpciaccess,
  mesa,
  nspr,
  nss,
  pango,
  shared-mime-info,
  systemdLibs,
  vulkan-loader,
  wayland,
  xkeyboard_config,
  xdg-utils,
  zlib,
}:

let
  pname = "learnharness";
  version = "0.6.1";

  # Bibliotecas usadas pelo binário do Electron e por dlopen em runtime.
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    # libstdc++ é necessário para os módulos nativos do Node (sharp/libvips).
    stdenv.cc.cc.lib
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gtk3
    harfbuzz
    krb5
    libappindicator-gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libx11
    libxcb
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    libsm
    libice
    libpciaccess
    mesa
    nspr
    nss
    pango
    systemdLibs
    vulkan-loader
    wayland
    xkeyboard_config
    zlib
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  # O .deb oficial tem ~144 MB e não é versionado no repositório. O hash
  # corresponde ao asset LearnHarness-0.6.1-amd64.deb do release v0.6.1.
  src = fetchurl {
    url = "https://github.com/amosblomqvist/learnharness/releases/download/v${version}/LearnHarness-${version}-amd64.deb";
    hash = "sha256-LIZbewtw8c6p/EBVivA5l2i3uZZFf7b4HWKLLdJCzl0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    desktop-file-utils
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs ++ [
    gsettings-desktop-schemas
    hicolor-icon-theme
    shared-mime-info
  ];

  dontBuild = true;
  dontConfigure = true;
  dontPatchELF = true;
  dontStrip = true;
  dontWrapGApps = true;

  # O autoPatchelfHook não deve percorrer o node_modules embutido: o sharp
  # traz o próprio libvips com RPATH $ORIGIN, e reescrever esse RPATH quebra
  # o carregamento da biblioteca. Ele é chamado manualmente abaixo, apenas
  # nos binários de nível superior do Electron.
  dontAutoPatchelf = true;

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin \
      $out/share/applications \
      $out/share/icons/hicolor/512x512/apps \
      $out/share/doc/learnharness

    cp -a opt/LearnHarness $out/opt/
    cp -a usr/share/applications/learnharness.desktop $out/share/applications/
    cp -a usr/share/icons/hicolor/512x512/apps/learnharness.png \
      $out/share/icons/hicolor/512x512/apps/
    cp -a usr/share/doc/learnharness/. $out/share/doc/learnharness/

    # O Exec do .deb aponta para /opt/LearnHarness/learnharness.
    desktop-file-edit \
      --set-key=Exec --set-value="learnharness %U" \
      --set-key=Icon --set-value="learnharness" \
      $out/share/applications/learnharness.desktop

    runHook postInstall
  '';

  postFixup = ''
    # Somente os ELF de nível superior do Electron. Os módulos nativos do
    # servidor Node embutido (resources/server/standalone/node_modules)
    # ficam intocados, preservando os RPATHs relativos.
    autoPatchelf --no-recurse $out/opt/LearnHarness

    # makeShellWrapper (e não makeWrapper) para que a expansão de
    # NIXOS_OZONE_WL/WAYLAND_DISPLAY aconteça em runtime, no shell.
    makeShellWrapper $out/opt/LearnHarness/learnharness $out/bin/learnharness \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  meta = {
    description = "An agent harness for learning: adaptive teaching, practice, and a persistent knowledge graph";
    homepage = "https://learnharness.ai";
    downloadPage = "https://github.com/amosblomqvist/learnharness/releases";
    changelog = "https://github.com/amosblomqvist/learnharness/releases";
    license = lib.licenses.agpl3Only;
    mainProgram = "learnharness";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
