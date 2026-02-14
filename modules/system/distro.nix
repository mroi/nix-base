{ config, pkgs, lib, ... }: {

	options.system.distribution = lib.mkOption {
		type = lib.types.enum [ "generic" "elementaryOS" "macOS" ];
		default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
			Linux = "generic";
			Darwin = "macOS";
		};
		description = "The system distribution variant.";
	};

	config = lib.mkMerge [
		{
			assertions = [{
				assertion = config.system.distribution != "macOS" -> pkgs.stdenv.isLinux;
				message = "The only supported Darwin variant is macOS";
			} {
				assertion = config.system.distribution == "macOS" -> pkgs.stdenv.isDarwin;
				message = "System variant macOS is only supported on Darwin";
			}];
		}

		(lib.mkIf (config.system.distribution == "elementaryOS") {

			system.packages = lib.mkIf config.system.systemwideSetup ([
				{ name = "elementary-minimal"; includeRecommends = true; }
				{ name = "elementary-standard"; includeRecommends = true; }
				{ name = "elementary-desktop"; includeRecommends = true; }
				{ name = "linux-image-generic-hwe-24.04"; includeRecommends = true; }
				"bsdutils" "diffutils" "findutils" "util-linux"
				"dash" "grep" "gzip" "hostname" "login" "ncurses-base" "ncurses-bin"
			] ++ lib.optionals pkgs.stdenv.isx86_64 [
				"grub-pc"
			] ++ lib.optionals pkgs.stdenv.isAarch64 [
				"grub-efi-arm64"
			]);

			environment.apps = lib.mkIf (config.environment.flatpak == "system") [
				"io.elementary.calculator"
				"io.elementary.camera"
				"io.elementary.capnet-assist"
				"io.elementary.music"
				"io.elementary.screenshot"
				"io.elementary.videos"
				"org.gnome.Epiphany"
				"org.gnome.Evince"
				"org.gnome.FileRoller"
				"org.gnome.font-viewer"
			];

			system.files.known = [
				"/"
			] ++ lib.optionals pkgs.stdenv.isAarch64 [
				"/boot/efi"
				"/boot/efi/EFI"
				"/boot/efi/EFI/*"
			] ++ [
				"/boot/grub"
				"/boot/grub/*"
				"/boot/initrd.img*"
				"/boot/lost+found"
				"/boot/vmlinuz*"
				"/etc/*"
				"/lost+found"
				"/media"
				"/mnt"
				"/opt"
				"/root/.cache"
				"/srv"
				"/tmp/*"
				"/usr/*/__pycache__"
				"/usr/*/__pycache__/*.pyc"
				"/usr/lib/*-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache"
				"/usr/lib/*-linux-gnu/gio/modules/giomodule.cache"
				"/usr/lib/*-linux-gnu/gtk-2.0/2.10.0/immodules.cache"
				"/usr/lib/*-linux-gnu/gtk-3.0/3.0.0/immodules.cache"
				"/usr/lib/*-linux-gnu/gtk-4.0/4.0.0/printbackends/giomodule.cache"
				"/usr/lib/cups/backend/*"
				"/usr/lib/locale/locale-archive"
				"/usr/lib/modules/*-generic/modules.*"
				"/usr/lib/systemd/system/screen-cleanup.service"
				"/usr/lib/udev/hwdb.bin"
				"/usr/local"
				"/usr/local/*"
				"/usr/share/applications/mimeinfo.cache"
				"/usr/share/fonts/X11/*/encodings.dir"
				"/usr/share/fonts/X11/*/fonts.alias"
				"/usr/share/fonts/X11/*/fonts.dir"
				"/usr/share/fonts/X11/*/fonts.scale"
				"/usr/share/glib-2.0/schemas/gschemas.compiled"
				"/usr/share/icons/elementary/icon-theme.cache"
				"/usr/share/icons/hicolor/icon-theme.cache"
				"/usr/share/info/dir"
				"/usr/share/mime/*"
				"/var/backups/*"
				"/var/cache/*"
				"/var/lib/*"
				"/var/log/*"
				"/var/mail"
				"/var/opt"
				"/var/spool/anacron/cron.daily"
				"/var/spool/anacron/cron.monthly"
				"/var/spool/anacron/cron.weekly"
				"/var/spool/mail"
				"/var/tmp/systemd-private-*"
				"/var/tmp/systemd-private-*/tmp"
			];
		})

		(lib.mkIf (config.system.distribution == "macOS") {

			system.files.known = [
				"/Library/Apple/System/Library/InstallerSandboxes/.PKInstallSandboxManager-SystemSoftware"
				"/Library/Apple/System/Library/InstallerSandboxes/.metadata_never_index"
				"/Library/Apple/System/Library/Receipts/*"
				"/Library/Application Support/*"
				"/Library/Bluetooth"
				"/Library/Bluetooth/*"
				"/Library/Caches/*"
				"/Library/Catacomb"
				"/Library/Catacomb/*"
				"/Library/ColorSync/Profiles/Displays/*.icc"
				"/Library/CoreAnalytics/taskedConfig.json"
				"/Library/InstallerSandboxes/.PKInstallSandboxManager"
				"/Library/InstallerSandboxes/.metadata_never_index"
				"/Library/Keychains/*"
				"/Library/Logs/*"
				"/Library/OSAnalytics"
				"/Library/OSAnalytics/*"
				"/Library/Preferences/*"
				"/Library/Receipts/InstallHistory.plist"
				"/Library/Trial"
				"/Library/Trial/*"
				"/Library/Updates/ProductMetadata.plist"
				"/Library/Updates/index.plist"
				"/System/Library/AssetsV2/*"
				"/System/Library/Caches/*"
				"/System/Volumes/Data/.DocumentRevisions-V100"
				"/System/Volumes/Data/.Spotlight-V100"
				"/System/Volumes/Data/.TemporaryItems"
				"/System/Volumes/Data/.fseventsd"
				"/System/Volumes/Data/System"
				"/System/Volumes/Data/System/Library"
				"/System/Volumes/Data/System/Library/CoreServices"
				"/System/Volumes/Data/System/Library/CoreServices/CoreTypes.bundle"
				"/System/Volumes/Data/System/Library/CoreServices/CoreTypes.bundle/Contents"
				"/System/Volumes/Data/mnt"
				"/System/Volumes/Data/sw"
				"/System/Volumes/Data/usr"
				"/System/Volumes/Data/usr/libexec"
				"/System/Volumes/Data/usr/share"
				"/Volumes/*"
				"/private/etc/cups/printers.conf"
				"/private/etc/krb5.keytab"
				"/private/etc/ntp.conf"
				"/private/tmp/*"
				"/private/var/containers"
				"/private/var/db/*"
				"/private/var/folders/*"
				"/private/var/log/*"
				"/private/var/logs"
				"/private/var/logs/*"
				"/private/var/networkd/*"
				"/private/var/protected/*"
				"/private/var/root/.CFUserTextEncoding"
				"/private/var/root/Library/*"
				"/private/var/rpc/*"
				"/private/var/run/*"
				"/private/var/sntpd/state.bin"
				"/private/var/spool/cups/cache/*"
				"/private/var/spool/postfix/*"
				"/private/var/vm/sleepimage"
			];
			system.files.used = [
				"/Library/InstallerSandboxes/.metadata_never_index"
				"/Library/Keychains/.fl043D1EDD"
				"/Library/Keychains/.fl947E1BDB"
				"/Library/Preferences/com.apple.apsd.launchd"
				"/System/Library/AssetsV2/com_apple_MobileAsset_*/*.asset/META-INF"
				"/System/Volumes/Data/.Spotlight-V100"
				"/private/var/networkd/db"
			];
		})
	];
}
