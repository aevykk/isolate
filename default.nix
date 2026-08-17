# SPDX-License-Identifier: GPL-3.0-or-later
{ lib
, stdenv
, makeWrapper
, pkgsStatic
, coreutils
, util-linux
, gnugrep
, gnused
, bubblewrap
, lxc
, xhost
, procps
, nettools
, getent
}:

let
  # The seccomp wrapper runs *inside* the container, where only the template
  # rootfs is visible (bwrap never exposes the nix store), so it must be a
  # fully static binary that can be copied into any template.
  seccompWrapper = pkgsStatic.stdenv.mkDerivation {
    pname = "isolate-seccomp-wrapper";
    version = "1.0";
    src = ./.;
    dontConfigure = true;
    buildInputs = [ pkgsStatic.libseccomp ];
    buildPhase = ''
      runHook preBuild
      $CC seccomp_wrapper.c -static -o seccomp_wrapper -lseccomp
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 seccomp_wrapper $out/bin/seccomp_wrapper
      runHook postInstall
    '';
  };

  # runtime commands the isolate script shells out to. `zfs` is intentionally
  # omitted: its version must match the running kernel module, so the NixOS
  # module supplies it via the systemd unit PATH / the system environment.
  runtimeDeps = [
    coreutils   # realpath, dirname, basename, touch, chown, chmod, mkdir, rm, cat, wc, head, stat, seq, date, nproc, id, env, chroot
    util-linux  # findmnt, flock
    gnugrep
    gnused
    bubblewrap  # bwrap
    lxc         # lxc-start, lxc-stop, lxc-attach
    xhost
    procps      # ps
    nettools    # hostname (used by common.sh)
    getent      # split out of glibc.bin since glibc 2.42
  ];
in
stdenv.mkDerivation {
  pname = "isolate";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 isolate       $out/bin/isolate
    # sourced by isolate via `$(dirname "$(realpath "$0")")/common.sh`
    install -Dm644 common.sh     $out/bin/common.sh
    install -Dm755 ${seccompWrapper}/bin/seccomp_wrapper $out/bin/seccomp_wrapper
    runHook postInstall
  '';

  # wrap after patchShebangs; --prefix keeps the ambient PATH reachable so the
  # systemd unit's `zfs` (and interactive users' system `zfs`) still resolve.
  postFixup = ''
    wrapProgram $out/bin/isolate \
      --prefix PATH : ${lib.makeBinPath runtimeDeps}
  '';

  passthru.seccompWrapper = seccompWrapper;

  meta = with lib; {
    description = "Single-use ZFS-clone sandbox launcher (bubblewrap/lxc/chroot backends)";
    longDescription = ''
      isolate runs a command inside a container backend (bubblewrap, lxc or
      chroot) on a fresh, single-use ZFS clone of a template dataset that is
      discarded after use. A privileged regeneration daemon replenishes clones.
      The static seccomp_wrapper (passthru.seccompWrapper, also at
      $out/bin/seccomp_wrapper) must be copied into the template rootfs PATH.
    '';
    license = licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ rednael ];
    mainProgram = "isolate";
  };
}
