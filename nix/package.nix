# Adapted from axioncs/harbor-flake (MIT); see LICENSE.
{ lib, stdenv, fetchurl, autoPatchelfHook, dpkg, makeWrapper, wrapGAppsHook3,
  mpv-unwrapped, openssl, systemd, dbus, gtk3, gdk-pixbuf, cairo, glib,
  webkitgtk_4_1, libsoup_3, libayatana-appindicator, libglvnd, vulkan-loader,
  glib-networking, gst_all_1, ffmpeg, yt-dlp, libplacebo, wayland, slang, libbsd, libxv ? null, xorg ? null, pname, info }:

let
  buildLibs = [
    mpv-unwrapped openssl systemd dbus gtk3 gdk-pixbuf cairo glib wayland
    webkitgtk_4_1 libsoup_3 stdenv.cc.cc.lib
  ];
  # The Ubuntu libmpv enables XVideo; its optional compatibility libraries
  # also need the host S-Lang and BSD support libraries.
  xvideo = if libxv != null then libxv else xorg.libXv;
  runtimeLibs = [ libayatana-appindicator libglvnd vulkan-loader xvideo slang libbsd ];
  gstPlugins = with gst_all_1; [
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
  ];
in
stdenv.mkDerivation {
  inherit pname;
  inherit (info) version;

  src = fetchurl { inherit (info) url hash; };
  nativeBuildInputs = [ autoPatchelfHook dpkg makeWrapper wrapGAppsHook3 ];
  # A newer DEB includes its own libmpv/FFmpeg/Wayland ABI family.
  # Include the Nix MPV and rendering dependencies for native host libraries;
  # the private libraries themselves must resolve inside the package.
  buildInputs = buildLibs ++ runtimeLibs ++ gstPlugins
    ++ (mpv-unwrapped.buildInputs or []) ++ (ffmpeg.buildInputs or [])
    ++ (libplacebo.buildInputs or []) ++ (wayland.buildInputs or []);
  runtimeDependencies = runtimeLibs;
  dontWrapGApps = true;
  dontBuild = true;
  # Preserve the exact shipped executable and resources (including Tauri's
  # relative resource directory). autoPatchelfHook supplies the Nix ELF paths.
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r usr/. "$out/"
    test -x "$out/bin/harbor"
    if [ -d "$out/lib/harbor-hdr" ]; then
      # Nix provides its own newer Wayland family; keep GTK, Mesa and the
      # renderer on that one ABI instead of overriding the Nix graphics stack.
      rm -f "$out/lib/harbor-hdr"/libwayland-*.so.* "$out/lib/harbor-hdr"/libvulkan.so.*
    fi
    # Desktop entries with a /usr/bin path cannot launch from the Nix store.
    for desktop in "$out"/share/applications/*.desktop; do
      if [ -f "$desktop" ]; then
        substituteInPlace "$desktop" --replace-warn "/usr/bin/harbor" "$out/bin/harbor"
      fi
    done
    runHook postInstall
  '';

  preFixup = ''
    if [ -d "$out/lib/harbor-hdr" ]; then
      addAutoPatchelfSearchPath "$out/lib/harbor-hdr"
    fi
  '';

  postFixup = ''
    hdrLibs=""
    if [ -d "$out/lib/harbor-hdr" ]; then
      hdrLibs="$out/lib/harbor-hdr:"
    fi
    wrapProgram "$out/bin/harbor" \
      "''${gappsWrapperArgs[@]}" \
      --set GIO_MODULE_DIR "${glib-networking}/lib/gio/modules" \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins}" \
      --prefix LD_LIBRARY_PATH : "$hdrLibs${lib.makeLibraryPath (buildLibs ++ runtimeLibs)}" \
      --prefix PATH : "${lib.makeBinPath [ ffmpeg yt-dlp ]}"
  '';

  # autoPatchelfHook is a post-fixup hook. Testing in postFixup itself
  # executes Debian's original loader before it has been rewritten.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    if [ -d "$out/lib/harbor-hdr" ]; then
      LD_LIBRARY_PATH="$out/lib/harbor-hdr:${lib.makeLibraryPath (buildLibs ++ runtimeLibs)}" \
        "$out/lib/harbor-hdr/check-api" "$out/lib/harbor-hdr/libharbor-linux-hdr.so"
      "$out/bin/harbor" --verify-linux-hdr-runtime
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Harbor media client (pre-built binary)";
    homepage = "https://github.com/HarborCommunity/Harbor";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "harbor";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
