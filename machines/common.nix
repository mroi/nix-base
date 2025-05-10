{ config, lib, pkgs, ... }: {

	system.defaultCommands = [ "activate" ];

	system.packages = lib.mkIf pkgs.stdenv.isLinux [
		"patch"
	];

	environment.profile = [
		"nix-base#nix"
		"nix-base#fish"
		"nixpkgs#micro"
	];

	networking.firewall = lib.mkIf (pkgs.stdenv.isDarwin && config.system.systemwideSetup) {
		allow = [
			"/System/Library/CoreServices/UniversalControl.app/Contents/MacOS/UniversalControl"
			"/System/Library/PrivateFrameworks/ChronoCore.framework/Support/chronod"
			"/System/Library/PrivateFrameworks/IDS.framework/identityservicesd.app/Contents/MacOS/identityservicesd"
			"/usr/libexec/AirPlayXPCHelper"
			"/usr/libexec/audioclocksyncd"
			"/usr/libexec/rapportd"
			"/usr/libexec/sharingd"
		];
	};

	environment.extensions = lib.mkIf pkgs.stdenv.isDarwin {
		"com.apple.photo-editing"."com.apple.MarkupUI.MarkupPhotoExtension" = true;
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

	time = lib.mkIf (pkgs.stdenv.isLinux && config.system.systemwideSetup) {
		timeZone = "Europe/Berlin";
	};
}
