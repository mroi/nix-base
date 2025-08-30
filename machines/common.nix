{ config, lib, pkgs, ... }: {

	system.defaultCommands = [ "activate" ];

	system.packages = lib.mkIf pkgs.stdenv.isLinux [
		"patch"
		"screen"
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
			"/System/Library/PrivateFrameworks/ReplicatorCore.framework/Support/replicatord"
			"/usr/libexec/AirPlayXPCHelper"
			"/usr/libexec/audioclocksyncd"
			"/usr/libexec/rapportd"
			"/usr/libexec/sharingd"
			"/usr/libexec/sshd-session"
		];
	};

	security.pki.certificateTrust.system = lib.mkIf (pkgs.stdenv.isDarwin && config.system.systemwideSetup) {
		# Apple Root Certificate Authority: maybe deprecated
		"580F804792ABC63BBB80154D4DFDDD8B2EF2674E" = { basicX509 = true; ipsecServer = true; codeSigning = true; timeStamping = true; };
		# DigiCert High Assurance EV Root CA: involved in geo services and commerce
		"5FB7EE0633E259DBAD0C4C9AE6D38F1A61C7DC25" = { basicX509 = true; sslServer = true; timeStamping = true; };
		# USERTrust RSA Certification Authority: basicX509 needed by GitHub action runner
		"2B8F1B57330DBBA2D07A6C51F70EE90DDAB9AD8E" = { basicX509 = true; sslServer = true; };
		# T-TeleSec GlobalRoot Class 2
		"590D2D7D884F402E617EA562321765CF17D894E9" = { sslServer = true; };
		# DigiCert Global Root G3
		"7E04DE896A3E666D00E687D33FFAD93BE83D349E" = { sslServer = true; };
		# Starfield Services Root Certificate Authority - G2: Amazon-issued certs
		"925A8F8D2C6D04E0665F596AFF22D863E8256F3F" = { sslServer = true; };
		# COMODO ECC Certification Authority: some Apple online services (Maps, Stocks)
		"9F744E9F2B4DBAEC0F312C50B6563B8E2D93C311" = { sslServer = true; };
		# DigiCert Global Root CA
		"A8985D3A65E5E5C4B2D7D66D40C6DD2FB19C5436" = { sslServer = true; };
		# GlobalSign Root CA
		"B1BC968BD4F49D622AA89A81F2150152A41D829C" = { sslServer = true; };
		# ISRG Root X1: Let’s encrypt
		"CABD2A79A1076A31F21D253635CB039D4329A5E8" = { sslServer = true; };
		# AAA Certificate Services: some Apple Server certs
		"D1EB23A46D17D68FD92564C2F1F1601764D8E349" = { sslServer = true; };
		# GlobalSign
		"D69B561148F01C77C54578C10926DF5B856976AD" = { sslServer = true; };
		# DigiCert Global Root G2: basicX509 needed by GitHub action runner
		"DF3C24F9BFD666761B268073FE06D1CC8D4F82A4" = { basicX509 = true; sslServer = true; };
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

	time = lib.mkIf (pkgs.stdenv.isLinux && config.system.systemwideSetup) {
		timeZone = "Europe/Berlin";
	};
}
