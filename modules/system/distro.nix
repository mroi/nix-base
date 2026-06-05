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
		})

		(lib.mkIf (config.system.distribution == "macOS") {

			networking.firewall = lib.mkIf config.system.systemwideSetup {
				allow = [
					"/System/Library/CoreServices/UniversalControl.app/Contents/MacOS/UniversalControl"
					"/System/Library/PrivateFrameworks/ChronoCore.framework/Support/chronod"
					"/System/Library/PrivateFrameworks/IDS.framework/identityservicesd.app/Contents/MacOS/identityservicesd"
					"/System/Library/PrivateFrameworks/ReplicatorCore.framework/Support/replicatord"
					"/usr/libexec/AirPlayXPCHelper"
					"/usr/libexec/audioclocksyncd"
					"/usr/libexec/rapportd"
					"/usr/libexec/sharingd"
				];
			};

			environment.extensions = lib.mkIf pkgs.stdenv.isDarwin {
				"com.apple.photo-editing"."com.apple.MarkupUI.MarkupPhotoExtension" = true;
				"com.apple.quicklook.preview"."com.apple.tips.TipsQuicklook" = true;
				"com.apple.share-services"."com.apple.CloudSharingUI.CopyLink" = true;
				"com.apple.share-services"."com.apple.CloudSharingUI.invite" = true;
				"com.apple.share-services"."com.apple.MailShareExtension" = true;
				"com.apple.share-services"."com.apple.Notes.SharingExtension" = true;
				"com.apple.share-services"."com.apple.freeform.sharingextension" = true;
				"com.apple.share-services"."com.apple.messages.ReplyExtension" = true;
				"com.apple.share-services"."com.apple.messages.ShareExtension" = true;
				"com.apple.share-services"."com.apple.reminders.sharingextension" = true;
				"com.apple.share-services"."com.apple.share.AirDrop.send" = true;
				"com.apple.share-services"."com.apple.share.Mail.compose" = true;
				"com.apple.share-services"."com.apple.share.Mail.compose-back-to-sender" = true;
				"com.apple.share-services"."com.apple.share.Messages.window" = true;
				"com.apple.share-services"."com.apple.share.System.add-to-iphoto" = true;
				"com.apple.share-services"."com.apple.share.System.add-to-safari-reading-list" = true;
				"com.apple.share-services"."com.apple.share.System.set-account-picture" = true;
				"com.apple.share-services"."com.apple.share.System.set-desktop-image" = true;
				"com.apple.ui-services"."com.apple.MarkupUI.Markup" = true;
				"com.apple.ui-services"."com.apple.sharing.ShareSheetUI" = true;
			};
		})
	];
}
