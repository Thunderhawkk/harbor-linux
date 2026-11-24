# Adapted from axioncs/harbor-flake (MIT); see LICENSE.
{ lib, stdenv, fetchurl, autoPatchelfHook, dpkg, makeWrapper, wrapGAppsHook3,
  mpv-unwrapped, openssl, systemd, dbus, gtk3, gdk-pixbuf, cairo, glib,
  webkitgtk_4_1, libsoup_3, libayatana-appindicator, libglvnd, vulkan-loader,
  glib-networking, gst_all_1, ffmpeg, yt-dlp, pname, info }:

let
  buildLibs = [
    mpv-unwrapped openssl systemd dbus gtk3 gdk-pixbuf cairo glib
    webkitgtk_4_1 libsoup_3 stdenv.cc.cc.lib
  ];
  runtimeLibs = [ libayatana-appindicator libglvnd vulkan-loader ];
  gstPlugins = with gst_all_1; [
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
  ];
in
stdenv.mkDerivation {
  inherit pname;
  inherit (info) version;

  src = fetchurl { inherit (info) url hash; };
  nativeBuildInputs = [ autoPatchelfHook dpkg makeWrapper wrapGAppsHook3 ];
  buildInputs = buildLibs ++ runtimeLibs ++ gstPlugins;
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
    # Desktop entries with a /usr/bin path cannot launch from the Nix store.
    for desktop in "$out"/share/applications/*.desktop; do
      if [ -f "$desktop" ]; then
        substituteInPlace "$desktop" --replace-warn "/usr/bin/harbor" "$out/bin/harbor"
      fi
    done
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/harbor" \
      "''${gappsWrapperArgs[@]}" \
      --set GIO_MODULE_DIR "${glib-networking}/lib/gio/modules" \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath (buildLibs ++ runtimeLibs)}" \
      --prefix PATH : "${lib.makeBinPath [ ffmpeg yt-dlp ]}"
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
