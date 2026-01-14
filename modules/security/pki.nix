{ config, lib, pkgs, ... }: {

	options.security.pki.certificateTrust = let

		trustType = lib.types.nullOr (lib.types.attrsOf (lib.types.submodule { options = {
			intermediate = lib.mkEnableOption "intermediate CA certificate";
			allowedErrors = lib.mkOption {
				type = lib.types.listOf (lib.types.enum [ "hostNameMismatch" ]);
				default = [];
				description = "Allowed errors when validating the use of this certificate.";
			};
			basicX509 = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for signing other certificates.";
			};
			sslServer = lib.mkOption {
				type = lib.types.either lib.types.bool (lib.types.listOf lib.types.str);
				default = false;
				description = "Trust this certificate for TLS server authentication.";
			};
			SMIME = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for email signing and encryption.";
			};
			eapServer = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for EAP server authentication.";
			};
			ipsecServer = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for IPSec server authentication.";
			};
			updateSigning = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for software update signing.";
			};
			codeSigning = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for code signing.";
			};
			packageSigning = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for installer package signing.";
			};
			appStoreReceipt = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for signing Mac App Store receipts.";
			};
			timeStamping = lib.mkOption {
				type = lib.types.bool;
				default = false;
				description = "Trust this certificate for signing timestamps.";
			};
		};}));

	in {
		system = lib.mkOption {
			type = trustType;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = null;
				Darwin = {};
			};
			description = "Set of system-trusted certificates, keyed by their SHA-1 hash. Any other certificate will not be trusted.";
		};
		user = lib.mkOption {
			type = trustType;
			default = lib.getAttr pkgs.stdenv.hostPlatform.uname.system {
				Linux = null;
				Darwin = {};
			};
			description = "Set of user-trusted certificates, keyed by their SHA-1 hash.";
		};
	};

	config = let

		trustPlist = mode: pkgs.writeText "trust.plist" (lib.concatLines ([
			"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
			"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
			"<plist version=\"1.0\">"
			"<dict>"
			"\t<key>trustList</key>"
			(if config.security.pki.certificateTrust."${mode}" == {} then "\t<dict/>" else "\t<dict>")
		] ++ lib.mapAttrsToList (name: value: lib.concatStringsSep "\n" [
			"\t\t<key>${name}</key>"
			"\t\t<dict>"
			"\t\t\t<key>issuerName</key>"
			"\t\t\t<data>"
			"\t\t\t</data>"
			"\t\t\t<key>modDate</key>"
			"\t\t\t<date>2011-01-01T10:00:00Z</date>"
			"\t\t\t<key>serialNumber</key>"
			"\t\t\t<data>"
			"\t\t\t</data>"
			"\t\t\t<key>trustSettings</key>"
			"\t\t\t<array>"
			(lib.concatStringsSep "\n" (map (x: "\t\t\t\t${x}") (trustSettings value)))
			"\t\t\t</array>"
			"\t\t</dict>"
		]) config.security.pki.certificateTrust."${mode}" ++ lib.optionals (config.security.pki.certificateTrust."${mode}" != {}) [
			"\t</dict>"
		] ++ [
			"\t<key>trustVersion</key>"
			"\t<integer>1</integer>"
			"</dict>"
			"</plist>"
		]));

		trustSettings = config: lib.flatten (
			map (policy: [ "<dict>" (map (x: "\t${x}") policy) "</dict>" ]) (
				trustOptions config config.basicX509 [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAEC"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>basicX509</string>"
				] ++
				trustOptions config (config.sslServer != false && config.sslServer != []) (
					map (server: [
						"<key>kSecTrustSettingsPolicy</key>"
						"<data>"
						"KoZIhvdjZAED"
						"</data>"
						"<key>kSecTrustSettingsPolicyName</key>"
						"<string>sslServer</string>"
					] ++ lib.optionals (server != "") [
						"<key>kSecTrustSettingsPolicyString</key>"
						"<string>${server}</string>"
					]) (if lib.isList config.sslServer then (lib.naturalSort config.sslServer) else [ "" ])
				) ++
				trustOptions config config.SMIME [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAEI"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>SMIME</string>"
				] ++
				trustOptions config config.eapServer [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAEJ"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>eapServer</string>"
				] ++
				trustOptions config config.ipsecServer [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAEL"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>ipsecServer</string>"
				] ++
				trustOptions config config.updateSigning [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAEK"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>AppleSWUpdateSigning</string>"
				] ++
				trustOptions config config.codeSigning [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAEQ"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>CodeSigning</string>"
				] ++
				trustOptions config config.packageSigning [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAER"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>PackageSigning</string>"
				] ++
				trustOptions config config.appStoreReceipt [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAET"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>MacAppStoreReceipt</string>"
				] ++
				trustOptions config config.timeStamping [
					"<key>kSecTrustSettingsPolicy</key>"
					"<data>"
					"KoZIhvdjZAEU"
					"</data>"
					"<key>kSecTrustSettingsPolicyName</key>"
					"<string>AppleTimeStamping</string>"
				] ++
				lib.singleton [
					# deny all as fixed last rule
					"<key>kSecTrustSettingsResult</key>"
					"<integer>3</integer>"
				]
			)
		);

		trustOptions = config: enable: list: lib.optionals enable (
			lib.concatMap (policy:
				map (error: (lib.optionals (error != "") [
					"<key>kSecTrustSettingsAllowedError</key>"
					(lib.getAttr error {
						hostNameMismatch = "<integer>-2147408896</integer>";
					})
				]) ++ policy ++ (lib.optionals config.intermediate [
					"<key>kSecTrustSettingsResult</key>"
					"<integer>2</integer>"
				])) (if config.allowedErrors != [] then (lib.naturalSort config.allowedErrors) else [ "" ])
			) (if lib.isList (lib.head list) then list else lib.singleton list)
		);

		trustScript = mode: lib.optionalString (config.security.pki.certificateTrust."${mode}" != null) (''
			security trust-settings-export ${lib.optionalString (mode == "system") "-d"} trust-${mode}-current.plist > /dev/null

		'' + lib.optionalString (mode == "system") ''
			# sync the system trust settings with available system root certs
			systemRoots=$(security find-certificate -aZ /System/Library/Keychains/SystemRootCertificates.keychain | \
				sed -n '/^SHA-1 hash: / { s/^SHA-1 hash: // ; p ; }' | sort)
			systemCerts=$(security find-certificate -aZ /Library/Keychains/System.keychain | \
				sed -n '/^SHA-1 hash: / { s/^SHA-1 hash: // ; p ; }' | sort)
			config='${lib.concatLines (lib.attrNames config.security.pki.certificateTrust."${mode}")}'
			for hash in $config ; do
				if ! hasLine "$systemRoots" "$hash" && ! hasLine "$systemCerts" "$hash" ; then
					printWarning 'Unknown system certificate'
					printInfo "Remove this hash from trust configuration: $hash"
				fi
			done

			# add deny setting for any unconfigured certs
			{
				sed -n '1,5p' ${trustPlist mode}
				echo '<dict>'
				for hash in $systemRoots ; do
					case "$hash" in
						# Developer ID Certification Authority: intermediate cert
						3B166C3B7DC4B751C9FE2AFAB9135641E388E186) continue ;;
						# Apple Root CA: always trust
						611E5B662C593A08FF58D14AE22452D198DF6C60) continue ;;
						# Apple Root CA G2: always trust
						14698989BFB2950921A42452646D37B50AF017E2) continue ;;
						# Apple Root CA G3: must not be configured or notarization token validation fails
						B52CB02FD567E0359FE8FA4D4C41037970FE01B0) continue ;;
					esac
					if ! hasLine "$config" "$hash" ; then
						echo "<key>$hash</key><dict><key>issuerName</key><data></data><key>modDate</key><date>2011-01-01T10:00:00Z</date><key>serialNumber</key><data></data><key>trustSettings</key><array><dict><key>kSecTrustSettingsResult</key><integer>3</integer></dict></array></dict>"
					fi
				done
				test "$config" || echo '</dict>'
				sed -n '7,$p' ${trustPlist mode}
			} > trust-${mode}-target.plist

			# canonicalize trust plist
			plutil -convert xml1 trust-${mode}-target.plist

			if ! diff -I '<date>' trust-${mode}-current.plist trust-${mode}-target.plist > /dev/null ; then
		'' + lib.optionalString (mode == "user") ''
			if ! diff -I '<date>' trust-${mode}-current.plist ${trustPlist mode} > /dev/null ; then
				install -m 644 ${trustPlist mode} trust-${mode}-target.plist
		'' + ''

				# set modification date based on the current config
				plutil -extract trustList raw trust-${mode}-target.plist | while read -r hash ; do
					test "$hash" || continue  # empty target trustList runs one loop interation with empty hash
					trust1=$(plutil -extract "trustList.$hash.trustSettings" xml1 -o - trust-${mode}-current.plist 2> /dev/null || true)
					trust2=$(plutil -extract "trustList.$hash.trustSettings" xml1 -o - trust-${mode}-target.plist || true)
					if test "$trust1" = "$trust2" ; then
						# same trust settings, copy the modification date
						date=$(plutil -extract "trustList.$hash.modDate" raw trust-${mode}-current.plist)
						plutil -replace "trustList.$hash.modDate" -date "$date" trust-${mode}-target.plist
					else
						# different trust settings, set current modification date
						plutil -replace "trustList.$hash.modDate" -date "$(date -z UTC +%Y-%m-%dT%H:%M:%SZ)" trust-${mode}-target.plist
					fi
				done

				printDiff trust-${mode}-current.plist trust-${mode}-target.plist
				trace ${lib.optionalString (mode == "system") "sudo"} security trust-settings-import ${lib.optionalString (mode == "system") "-d"} trust-${mode}-target.plist || {
					status=$?
					install -m 600 trust-${mode}-target.plist "''${TMPDIR:-/tmp}/"
					printWarning 'Importing the trust settings failed'
					printInfo "Please install manually: ''${TMPDIR:-/tmp}/trust-${mode}-target.plist"
					exit $status
				}
			fi

			rm -f trust-${mode}-current.plist trust-${mode}-target.plist
		'');

	in {

		assertions = [{
			assertion = with config.security.pki.certificateTrust;
				(system != null || user != null) -> pkgs.stdenv.isDarwin;
			message = "Certificate trust currently can only be configured on Darwin";
		}];

		system.activationScripts.pki = ''
			storeHeading 'Certificate trust'
			${trustScript "system"}
			${trustScript "user"}
		'';
	};
}
