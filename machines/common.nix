{ config, lib, pkgs, ... }: {

	system.defaultCommands = [ "activate" ];

	system.packages = lib.mkIf (pkgs.stdenv.isLinux && config.system.systemwideSetup) [
		"patch"
		"screen"
		"sqlite3"
	];

	environment.profile = [
		"nix-base#nix"
		"nix-base#fish"
		"nixpkgs#micro"
	] ++ lib.optionals pkgs.stdenv.isDarwin [
		"nix-base#extract-text"
	];

	security.pki.certificateTrust.system = lib.mkIf (pkgs.stdenv.isDarwin && config.system.systemwideSetup) {
		# DigiCert High Assurance EV Root CA: involved in geo services and commerce
		"5FB7EE0633E259DBAD0C4C9AE6D38F1A61C7DC25" = { basicX509 = true; sslServer = true; timeStamping = true; };
		# USERTrust RSA Certification Authority
		"2B8F1B57330DBBA2D07A6C51F70EE90DDAB9AD8E" = { sslServer = true; };
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
		# ISRG Root X1: Let’s encrypt, basicX509 needed by GitHub action runner
		"CABD2A79A1076A31F21D253635CB039D4329A5E8" = { basicX509 = true; sslServer = true; };
		# AAA Certificate Services: some Apple Server certs
		"D1EB23A46D17D68FD92564C2F1F1601764D8E349" = { sslServer = true; };
		# GlobalSign
		"D69B561148F01C77C54578C10926DF5B856976AD" = { sslServer = true; };
		# DigiCert Global Root G2
		"DF3C24F9BFD666761B268073FE06D1CC8D4F82A4" = { sslServer = true; };
	};

	system.files.connections = [
		# Git repositories
		"(.*/\.git)/refs"
		# SQLite database files
		"(.*)-shm"
		"(.*)-wal"
		# bundle-based documents
		"(.*\.(key|numbers|pages))/.*"
	];

	time = lib.mkIf (pkgs.stdenv.isLinux && config.system.systemwideSetup) {
		timeZone = "Europe/Berlin";
	};
}
