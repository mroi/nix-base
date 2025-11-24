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
				assertion = config.system.distribution == "macOS" || pkgs.stdenv.isLinux;
				message = "The only supported Darwin variant is macOS";
			} {
				assertion = config.system.distribution != "macOS" || pkgs.stdenv.isDarwin;
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
				"/Library/Security/Trust Settings/*"
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
				"/private/var/audit/*"
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
		})
	];
}
